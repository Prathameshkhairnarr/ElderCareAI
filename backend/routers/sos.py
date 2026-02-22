"""
SOS emergency endpoint. (Production Hardened)

Changes:
- Idempotency: dedup SOS from same user within 60 seconds
- Transaction safety: add_sos_risk inside the same transaction
- Wrapped in try/except with db.rollback()
- Optional idempotency_key from client
"""
import logging
from datetime import datetime, timezone, timedelta
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, SosLog, Alert
from schemas.schemas import SosRequest, SosResponse
from services.auth_service import get_current_user
from services.risk_service import add_sos_risk

logger = logging.getLogger("eldercare")
router = APIRouter(tags=["SOS"])


@router.post("/sos", response_model=SosResponse, status_code=status.HTTP_201_CREATED)
def trigger_sos(
    body: SosRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Log an emergency SOS trigger. Idempotent within 60 seconds."""
    try:
        # ── Idempotency Check ──
        # If client provides an idempotency_key, check for exact match.
        # Otherwise, time-based dedup (60 seconds).
        if body.idempotency_key:
            existing = db.query(SosLog).filter(
                SosLog.user_id == current_user.id,
                SosLog.message.contains(body.idempotency_key),
            ).first()
            if existing:
                logger.info(f"SOS duplicate (idempotency_key) for user {current_user.id}")
                return SosResponse.model_validate(existing)
        else:
            # Time-based dedup: same user within 60 seconds
            cutoff = datetime.now(timezone.utc) - timedelta(seconds=60)
            recent = db.query(SosLog).filter(
                SosLog.user_id == current_user.id,
                SosLog.created_at >= cutoff,
            ).first()
            if recent:
                logger.info(f"SOS duplicate (time-based) for user {current_user.id}")
                return SosResponse.model_validate(recent)

        # ── Create SOS Log ──
        sos_message = body.message or "Emergency SOS triggered"
        if body.idempotency_key:
            sos_message = f"{sos_message} [key:{body.idempotency_key}]"

        sos = SosLog(
            user_id=current_user.id,
            latitude=body.latitude,
            longitude=body.longitude,
            message=sos_message,
        )
        db.add(sos)
        db.flush()  # Get SOS id before commit

        # Also create a critical alert
        location = ""
        if body.latitude and body.longitude:
            location = f" at ({body.latitude}, {body.longitude})"
        alert = Alert(
            user_id=current_user.id,
            alert_type="sos",
            title=f"Emergency SOS from {current_user.name}",
            details=f"{body.message or 'Emergency SOS triggered'}{location}",
            severity="critical",
        )
        db.add(alert)

        # ── Risk score: SOS contributes +25 — INSIDE the transaction ──
        add_sos_risk(db, current_user.id, sos.id, commit=False)

        db.commit()
        db.refresh(sos)

        logger.info(f"SOS created id={sos.id} for user {current_user.id}")
        return SosResponse.model_validate(sos)

    except HTTPException:
        raise  # Let FastAPI handle HTTP exceptions normally
    except Exception as e:
        db.rollback()
        logger.error(f"SOS trigger error for user {current_user.id}: {e}")
        raise HTTPException(
            status_code=500,
            detail="Failed to process SOS. Your SMS was still sent.",
        )

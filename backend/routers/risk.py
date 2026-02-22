"""
Risk score endpoints. (Production Hardened)

Changes:
- Wrapped handle_sms_event in try/except with db.rollback()
- Structured logging
"""
import logging
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, ProcessedMessage, RiskState
from schemas.schemas import RiskResponse, SmsRiskEvent
from services.auth_service import get_current_user
from services.risk_service import get_current_risk, resolve_risk

logger = logging.getLogger("eldercare")
router = APIRouter(tags=["Risk Score"])


@router.get("/risk", response_model=RiskResponse)
def get_risk_score(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's dynamic risk score (0-100)."""
    result = get_current_risk(current_user.id, db)
    return RiskResponse(**result)


@router.get("/elder/risk-score", response_model=RiskResponse)
def get_elder_risk_score(
    elder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Guardian-accessible endpoint to fetch an elder's risk score.
    Also works for the elder themselves.
    """
    # Allow if: user IS the elder, OR user is a guardian
    if current_user.id != elder_id and current_user.role not in ("guardian", "admin"):
        raise HTTPException(status_code=403, detail="Not authorized")

    # Verify elder exists
    elder = db.query(User).filter(User.id == elder_id).first()
    if not elder:
        raise HTTPException(status_code=404, detail="Elder not found")

    result = get_current_risk(elder_id, db)
    return RiskResponse(**result)


@router.post("/risk/resolve/{entry_id}")
def resolve_risk_endpoint(
    entry_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark a specific risk entry as resolved (e.g. user handled the scam)."""
    try:
        resolve_risk(db, current_user.id, entry_id)
        return {"status": "resolved", "id": entry_id}
    except Exception as e:
        db.rollback()
        logger.error(f"resolve_risk error for user {current_user.id}, entry {entry_id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to resolve risk entry")


@router.post("/risk/sms-event")
def handle_sms_event(
    event: SmsRiskEvent,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Real-time SMS risk event handler with idempotency and robust formulas."""
    try:
        # 1. Idempotency Check
        existing = db.query(ProcessedMessage).filter_by(msg_hash=event.message_hash).first()
        if existing:
            logger.info(f"SMS event duplicate suppressed for user {current_user.id}")
            return {"status": "ignored", "reason": "duplicate"}

        # 2. Store Message Metadata
        new_msg = ProcessedMessage(msg_hash=event.message_hash, label=event.label)
        db.add(new_msg)

        # 3. Apply Risk Formula
        profile = db.query(RiskState).filter_by(user_id=current_user.id).first()
        if not profile:
            profile = RiskState(user_id=current_user.id, current_score=0)
            db.add(profile)
            db.flush()  # Ensure profile is available for update

        impact = -1 if event.label == 'SAFE' else (30 if event.label == 'PHISHING_LINK' else 15)

        # Check multiplier (if last scam was less than 2 hours ago)
        multiplier = 1.0
        now = datetime.now(timezone.utc)
        if profile.last_scam_at:
            last_scam = profile.last_scam_at
            if last_scam.tzinfo is None:
                last_scam = last_scam.replace(tzinfo=timezone.utc)
            if (now - last_scam).total_seconds() < 7200:
                multiplier = 1.5

        if impact > 0:
            profile.last_scam_at = now

        # Update Score — always bounded 0–100
        raw_new_score = profile.current_score + (impact * multiplier)
        profile.current_score = max(0, min(100, int(raw_new_score)))

        db.commit()
        logger.info(f"SMS risk event processed for user {current_user.id}: label={event.label}, new_score={profile.current_score}")
        return {"status": "success", "new_score": profile.current_score}

    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"handle_sms_event error for user {current_user.id}: {e}")
        raise HTTPException(status_code=500, detail="Failed to process SMS risk event")

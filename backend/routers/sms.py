"""
SMS scam analysis endpoint with idempotent deduplication.
"""
import hashlib
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from sqlalchemy import desc, func

from database.engine import get_db
from database.models import User, SmsAnalysis, Alert, RiskEntry, CorrectionLog
from schemas.schemas import (
    SmsRequest,
    SmsResponse,
    SmsHistoryItem,
    FalsePositiveRequest,
    FalsePositiveResponse,
)
from services.auth_service import get_current_user
from services.analysis_service import analyze_sms
from services.risk_service import add_risk_entry

router = APIRouter(tags=["SMS Analysis"])


def _normalize_and_hash(text: str) -> str:
    """Normalize text and return SHA256 hex digest for deduplication."""
    normalized = " ".join(text.lower().strip().split())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


@router.get("/sms-history", response_model=List[SmsHistoryItem])
def get_sms_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return all analyzed SMS for this user, with risk entry linkage."""
    records = (
        db.query(SmsAnalysis)
        .filter(SmsAnalysis.user_id == current_user.id)
        .order_by(desc(SmsAnalysis.created_at))
        .limit(50)
        .all()
    )

    result = []
    for rec in records:
        # Find linked risk entry (if scam)
        risk_entry = None
        if rec.is_scam and rec.content_hash:
            risk_entry = (
                db.query(RiskEntry)
                .filter(
                    RiskEntry.user_id == current_user.id,
                    RiskEntry.source_id == rec.content_hash,
                )
                .first()
            )

        result.append(SmsHistoryItem(
            id=rec.id,
            message=rec.message,
            is_scam=rec.is_scam,
            confidence=rec.confidence,
            category=rec.category,
            explanation=rec.explanation or "",
            risk_entry_id=risk_entry.id if risk_entry else None,
            is_resolved=(risk_entry.status == "RESOLVED") if risk_entry else False,
            created_at=rec.created_at,
        ))

    return result


@router.post("/analyze-sms", response_model=SmsResponse)
def analyze_sms_endpoint(
    body: SmsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Analyze an SMS message for scam indicators (idempotent)."""
    content_hash = _normalize_and_hash(body.message)

    # ── Dedup Check: return cached result if same content already analyzed ──
    existing = (
        db.query(SmsAnalysis)
        .filter(
            SmsAnalysis.user_id == current_user.id,
            SmsAnalysis.content_hash == content_hash,
        )
        .first()
    )

    if existing:
        # Return the previous result without creating new rows
        response = SmsResponse.model_validate(existing)
        response.previously_analyzed = True
        return response

    # ── New analysis ──
    metadata = {
        "sender": body.sender,
        "timestamp": body.timestamp,
        "is_repeated": body.is_repeated,
    }
    result = analyze_sms(body.message, metadata)

    record = SmsAnalysis(
        user_id=current_user.id,
        message=body.message,
        content_hash=content_hash,
        is_scam=result.is_scam,
        confidence=result.confidence,
        category=result.category,
        explanation=result.explanation,
    )
    db.add(record)

    # Create alert if scam detected
    if result.is_scam:
        severity = "high" if result.confidence >= 70 else "medium"
        alert = Alert(
            user_id=current_user.id,
            alert_type="sms_scam",
            title=f"SMS Scam Detected ({result.category})",
            details=result.explanation,
            severity=severity,
        )
        db.add(alert)
    
    # ── Update Active Risk Score ──
    add_risk_entry(db, current_user.id, "sms", content_hash, result.is_scam, confidence=result.confidence)

    db.commit()
    db.refresh(record)
    return SmsResponse.model_validate(record)


@router.post("/false-positive", response_model=FalsePositiveResponse)
def report_false_positive(
    body: FalsePositiveRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Log a false-positive user correction (Stage 5 feedback loop).
    - Appends entry to correction_logs table
    - Resolves linked active risk entry if present
    - Checks if 3+ distinct users marked the same sender header as false-positive;
      if so, flags promoted_to_whitelist = True.
    """
    sender = body.sender_header.strip().upper() if body.sender_header else None

    # Check if this user already reported this exact message_hash
    existing = (
        db.query(CorrectionLog)
        .filter(
            CorrectionLog.user_id == current_user.id,
            CorrectionLog.message_hash == body.message_hash,
        )
        .first()
    )
    if not existing:
        log_entry = CorrectionLog(
            user_id=current_user.id,
            sender_header=sender,
            message_hash=body.message_hash,
            message_content=body.message_content,
            false_positive=body.false_positive,
        )
        db.add(log_entry)

    # Auto-resolve active risk entry for this user + message_hash
    risk_entry = (
        db.query(RiskEntry)
        .filter(
            RiskEntry.user_id == current_user.id,
            RiskEntry.source_id == body.message_hash,
            RiskEntry.status == "ACTIVE",
        )
        .first()
    )
    if risk_entry:
        risk_entry.status = "RESOLVED"
        risk_entry.resolved_at = datetime.now(timezone.utc)

    db.commit()

    promoted = False
    if sender:
        # Count distinct users who marked this sender_header as false positive
        distinct_users = (
            db.query(func.count(func.distinct(CorrectionLog.user_id)))
            .filter(
                CorrectionLog.sender_header == sender,
                CorrectionLog.false_positive == True,
            )
            .scalar() or 0
        )
        if distinct_users >= 3:
            promoted = True

    return FalsePositiveResponse(
        status="success",
        message="Correction logged. Whitelist and models will incorporate this ground truth.",
        promoted_to_whitelist=promoted,
        sender_header=sender,
    )


"""
Voice / call fraud analysis endpoint.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, CallAnalysis, Alert
from schemas.schemas import CallRequest, CallResponse
from services.auth_service import get_current_user
from services.analysis_service import analyze_call

router = APIRouter(tags=["Voice Fraud"])


@router.post("/analyze-call", response_model=CallResponse)
def analyze_call_endpoint(
    body: CallRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Analyze a call transcript for fraud indicators."""
    result = analyze_call(body.transcript)

    record = CallAnalysis(
        user_id=current_user.id,
        transcript=body.transcript,
        is_scam=result.is_scam,
        confidence=result.confidence,
        category=result.category,
        explanation=result.explanation,
    )
    db.add(record)

    if result.is_scam:
        severity = "critical" if result.confidence >= 70 else "high"
        alert = Alert(
            user_id=current_user.id,
            alert_type="call_fraud",
            title=f"Voice Fraud Detected ({result.category})",
            details=result.explanation,
            severity=severity,
        )
        db.add(alert)

    db.commit()
    db.refresh(record)
    return CallResponse.model_validate(record)

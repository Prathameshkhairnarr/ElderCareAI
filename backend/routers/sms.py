"""
SMS scam analysis endpoint.
"""
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, SmsAnalysis, Alert
from schemas.schemas import SmsRequest, SmsResponse
from services.auth_service import get_current_user
from services.analysis_service import analyze_sms

router = APIRouter(tags=["SMS Analysis"])


@router.post("/analyze-sms", response_model=SmsResponse)
def analyze_sms_endpoint(
    body: SmsRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Analyze an SMS message for scam indicators."""
    result = analyze_sms(body.message)

    record = SmsAnalysis(
        user_id=current_user.id,
        message=body.message,
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

    db.commit()
    db.refresh(record)
    return SmsResponse.model_validate(record)

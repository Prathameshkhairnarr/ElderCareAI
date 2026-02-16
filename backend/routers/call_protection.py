"""
Call Protection API endpoints.
Truecaller-like reputation service for scam detection.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, timezone

from database.engine import get_db
from database.models import User
from database.call_models import PhoneReputation, UserReport, CallMetadata
from schemas.call_schemas import (
    PhoneCheckRequest,
    ReputationResponse,
    ReportRequest,
    ReportResponse,
    CallReportStats
)
from services.auth_service import get_current_user
from services.scam_scoring import (
    calculate_hybrid_risk_score,
    get_risk_level,
    get_recommended_action,
    generate_warning_message,
    recalculate_risk_score
)


router = APIRouter(tags=["Call Protection"])


@router.post("/check-number", response_model=ReputationResponse)
async def check_number_reputation(
    body: PhoneCheckRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Check reputation of a phone number.
    Returns risk score, category, and recommended action.
    """
    phone_hash = body.phone_hash
    metadata = body.metadata.dict() if body.metadata else {}
    
    # Lookup or create reputation entry
    reputation = db.query(PhoneReputation).filter(
        PhoneReputation.phone_hash == phone_hash
    ).first()
    
    if not reputation:
        # New number - create entry with default values
        reputation = PhoneReputation(
            phone_hash=phone_hash,
            risk_score=0,
            report_count=0,
            category=None,
            ml_confidence=0.5
        )
        db.add(reputation)
        db.commit()
        db.refresh(reputation)
    
    # Calculate current risk score
    risk_score = calculate_hybrid_risk_score(reputation, metadata, db)
    
    # Update reputation if score changed significantly
    if abs(risk_score - reputation.risk_score) > 5:
        reputation.risk_score = risk_score
        reputation.last_updated = datetime.now(timezone.utc)
        db.commit()
    
    # Build response
    return ReputationResponse(
        risk_score=risk_score,
        risk_level=get_risk_level(risk_score),
        category=reputation.category,
        report_count=reputation.report_count,
        warning_message=generate_warning_message(risk_score, reputation),
        recommended_action=get_recommended_action(risk_score),
        confidence=reputation.ml_confidence or 0.5
    )


@router.post("/report", response_model=ReportResponse, status_code=status.HTTP_201_CREATED)
async def report_scam_number(
    body: ReportRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Report a phone number as scam.
    Anti-spam: Rate limited to 10 reports per day per user.
    """
    # Anti-spam: Check user's report rate
    user_reports_today = db.query(UserReport).filter(
        UserReport.user_id == current_user.id,
        UserReport.created_at >= datetime.now(timezone.utc) - timedelta(days=1)
    ).count()
    
    if user_reports_today >= 10:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Report limit exceeded. You can submit 10 reports per day. Try again tomorrow."
        )
    
    # Check if user already reported this number
    existing_report = db.query(UserReport).filter(
        UserReport.user_id == current_user.id,
        UserReport.phone_hash == body.phone_hash
    ).first()
    
    if existing_report:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You have already reported this number."
        )
    
    # Create report
    report = UserReport(
        user_id=current_user.id,
        phone_hash=body.phone_hash,
        category=body.category,
        notes=body.notes,
        trust_score=1.0  # TODO: Implement user trust scoring
    )
    db.add(report)
    
    # Update or create phone reputation
    reputation = db.query(PhoneReputation).filter(
        PhoneReputation.phone_hash == body.phone_hash
    ).first()
    
    if not reputation:
        reputation = PhoneReputation(
            phone_hash=body.phone_hash,
            category=body.category,
            report_count=1,
            first_reported_at=datetime.now(timezone.utc),
            risk_score=0
        )
        db.add(reputation)
    else:
        reputation.report_count += 1
        reputation.last_updated = datetime.now(timezone.utc)
        
        # Update category if this category has more votes
        _update_category_vote(reputation, body.category, db)
    
    # Recalculate risk score
    reputation.risk_score = recalculate_risk_score(reputation, db)
    
    db.commit()
    db.refresh(reputation)
    
    return ReportResponse(
        message="Report submitted successfully. Thank you for helping protect the community!",
        updated_risk_score=reputation.risk_score,
        total_reports=reputation.report_count
    )


@router.get("/report-stats", response_model=CallReportStats)
async def get_report_stats(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get user's reporting statistics."""
    total_reports = db.query(UserReport).filter(
        UserReport.user_id == current_user.id
    ).count()
    
    reports_today = db.query(UserReport).filter(
        UserReport.user_id == current_user.id,
        UserReport.created_at >= datetime.now(timezone.utc) - timedelta(days=1)
    ).count()
    
    return CallReportStats(
        total_reports=total_reports,
        reports_today=reports_today,
        trust_score=1.0  # Placeholder
    )


def _update_category_vote(reputation: PhoneReputation, new_category: str, db: Session):
    """Update category based on majority voting from reports."""
    # Count reports by category
    category_counts = {}
    reports = db.query(UserReport).filter(
        UserReport.phone_hash == reputation.phone_hash
    ).all()
    
    for report in reports:
        category_counts[report.category] = category_counts.get(report.category, 0) + 1
    
    # Set category to the one with most reports
    if category_counts:
        reputation.category = max(category_counts, key=category_counts.get)

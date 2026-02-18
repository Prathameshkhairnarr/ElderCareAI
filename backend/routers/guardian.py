"""
Guardian management and dashboard.
"""
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from database.engine import get_db
from database.models import User, Guardian, Alert, SosLog, RiskState
from schemas import guardian_schemas, schemas
from services.auth_service import get_current_user
from utils.phone_utils import normalize_phone

router = APIRouter(tags=["Guardian"])


@router.post("/guardians", response_model=guardian_schemas.GuardianResponse, status_code=status.HTTP_201_CREATED)
def add_guardian(
    guardian: guardian_schemas.GuardianCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Add a guardian for the current user (Elder)."""
    # Check if already exists by phone for this user
    normalized_phone = normalize_phone(guardian.phone)
    existing = (
        db.query(Guardian)
        .filter(Guardian.user_id == current_user.id, Guardian.phone == normalized_phone)
        .first()
    )
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Guardian with this phone number already added.",
        )

    # Check limit? (Optional, maybe max 5)
    count = db.query(Guardian).filter(Guardian.user_id == current_user.id).count()
    if count >= 5:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Maximum 5 guardians allowed.",
        )

    new_guardian = Guardian(
        user_id=current_user.id,
        name=guardian.name,
        phone=normalized_phone,
        email=guardian.email,
        is_primary=guardian.is_primary,
    )
    
    # If this is primary, unset others
    if guardian.is_primary:
        db.query(Guardian).filter(Guardian.user_id == current_user.id).update({Guardian.is_primary: False})

    db.add(new_guardian)
    db.commit()
    db.refresh(new_guardian)
    return new_guardian


@router.get("/guardians", response_model=List[guardian_schemas.GuardianResponse])
def get_guardians(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """List guardians for the current user."""
    return db.query(Guardian).filter(Guardian.user_id == current_user.id).all()


@router.delete("/guardians/{guardian_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_guardian(
    guardian_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Remove a guardian."""
    guardian = (
        db.query(Guardian)
        .filter(Guardian.id == guardian_id, Guardian.user_id == current_user.id)
        .first()
    )
    if not guardian:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Guardian not found.",
        )

    db.delete(guardian)
    db.commit()
    return None


@router.get("/guardian/dashboard", response_model=guardian_schemas.GuardianDashboardResponse)
def get_guardian_dashboard(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get dashboard stats for a Guardian user.
    Shows status of all Elders who have added this user (by phone) as a guardian.
    """
    # 1. Find all Guardian entries where phone matches current_user.phone
    # Note: Phone numbers are normalized for robust matching.
    normalized_phone = normalize_phone(current_user.phone)
    guardian_entries = db.query(Guardian).filter(Guardian.phone == normalized_phone).all()

    elders_stats = []

    for entry in guardian_entries:
        elder = entry.user # The User object (Elder) via relationship
        if not elder:
            continue

        # Get Risk Score
        risk_score = 0
        if elder.risk_state:
            risk_score = elder.risk_state.current_score
        
        # Get Last SOS
        last_sos_log = (
            db.query(SosLog)
            .filter(SosLog.user_id == elder.id)
            .order_by(SosLog.created_at.desc())
            .first()
        )
        last_sos_at = last_sos_log.created_at if last_sos_log else None

        # Get Unread Alerts Count
        unread_count = (
            db.query(Alert)
            .filter(Alert.user_id == elder.id, Alert.is_read == False)
            .count()
        )

        # Get Recent Alerts (last 3)
        recent_alerts = (
            db.query(Alert)
            .filter(Alert.user_id == elder.id)
            .order_by(Alert.created_at.desc())
            .limit(3)
            .all()
        )

        elders_stats.append(
            guardian_schemas.ElderStats(
                elder_id=elder.id,
                elder_name=elder.name,
                elder_phone=elder.phone,
                risk_score=risk_score,
                last_sos_at=last_sos_at,
                unread_alerts_count=unread_count,
                recent_alerts=[schemas.AlertOut.model_validate(a) for a in recent_alerts],
            )
        )

    return guardian_schemas.GuardianDashboardResponse(elders=elders_stats)


@router.get("/guardian/elder/{elder_id}/alerts", response_model=List[schemas.AlertOut])
def get_elder_alerts(
    elder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get full alert history for a specific Elder.
    Security: Verifies that current_user is a Guardian for this Elder.
    """
    # 1. Verify Guardian Relationship
    normalized_phone = normalize_phone(current_user.phone)
    guardian_entry = (
        db.query(Guardian)
        .filter(Guardian.user_id == elder_id, Guardian.phone == normalized_phone)
        .first()
    )
    
    if not guardian_entry:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a guardian for this elder.",
        )

    # 2. Fetch Alerts
    alerts = (
        db.query(Alert)
        .filter(Alert.user_id == elder_id)
        .order_by(Alert.created_at.desc())
        .all()
    )
    
    return [schemas.AlertOut.model_validate(a) for a in alerts]

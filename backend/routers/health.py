from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from sqlalchemy import desc

from database.engine import get_db
from database.models import User, HealthVital, HealthProfile
from schemas.health_schemas import (
    VitalCreate, VitalResponse, HealthSummary,
    HealthProfileCreate, HealthProfileResponse,
)
from services.auth_service import get_current_user

router = APIRouter(tags=["Health Monitor"])


# ── Health Profile (demographic & medical) ────────────

@router.get("/profile", response_model=HealthProfileResponse)
def get_health_profile(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's health profile, or an empty template."""
    profile = db.query(HealthProfile).filter(
        HealthProfile.user_id == current_user.id
    ).first()

    if not profile:
        # Return an empty template (not persisted yet)
        return HealthProfileResponse(
            id=0,
            user_id=current_user.id,
            age=None,
            gender=None,
            blood_group=None,
            height_cm=None,
            weight_kg=None,
            medical_conditions="",
            emergency_contact=None,
            updated_at=None,
        )

    return HealthProfileResponse.model_validate(profile)


@router.post("/profile", response_model=HealthProfileResponse)
def upsert_health_profile(
    body: HealthProfileCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create or update the health profile (upsert — one per user)."""
    profile = db.query(HealthProfile).filter(
        HealthProfile.user_id == current_user.id
    ).first()

    if profile:
        # Update existing
        for field, value in body.model_dump(exclude_unset=True).items():
            setattr(profile, field, value)
        profile.updated_at = datetime.now(timezone.utc)
    else:
        # Create new
        profile = HealthProfile(
            user_id=current_user.id,
            **body.model_dump(),
        )
        db.add(profile)

    db.commit()
    db.refresh(profile)
    return HealthProfileResponse.model_validate(profile)


# ── Health Vitals (existing endpoints) ────────────────

@router.post("/", response_model=VitalResponse, status_code=status.HTTP_201_CREATED)
def add_vital(
    vital: VitalCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Record a new health vital."""
    new_vital = HealthVital(
        user_id=current_user.id,
        type=vital.type,
        value=vital.value,
        unit=vital.unit,
        recorded_at=vital.recorded_at or datetime.now(timezone.utc)
    )
    db.add(new_vital)
    db.commit()
    db.refresh(new_vital)
    return new_vital

@router.get("/history/{vital_type}", response_model=List[VitalResponse])
def get_vital_history(
    vital_type: str,
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get history for a specific vital type."""
    vitals = (
        db.query(HealthVital)
        .filter(HealthVital.user_id == current_user.id, HealthVital.type == vital_type)
        .order_by(desc(HealthVital.recorded_at))
        .limit(limit)
        .all()
    )
    return vitals

@router.get("/summary", response_model=HealthSummary)
def get_health_summary(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get the latest reading for each vital type."""
    summary = HealthSummary()
    
    # helper to get latest
    def get_latest(v_type):
        return (
            db.query(HealthVital)
            .filter(HealthVital.user_id == current_user.id, HealthVital.type == v_type)
            .order_by(desc(HealthVital.recorded_at))
            .first()
        )

    summary.heart_rate = get_latest("heart_rate")
    summary.bp = get_latest("bp")
    summary.steps = get_latest("steps")
    summary.spo2 = get_latest("spo2")
    summary.sleep = get_latest("sleep")
    summary.temperature = get_latest("temperature")
    
    return summary

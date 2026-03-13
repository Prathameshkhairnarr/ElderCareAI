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
    VitalsBatchCreate, HealthScoreResponse,
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


@router.post("/vitals", status_code=status.HTTP_201_CREATED)
def sync_vitals_batch(
    body: VitalsBatchCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Batch-sync vitals from Health Connect / sensors / manual entry.
    Accepts a unified JSON payload and inserts individual EAV rows.
    """
    now = datetime.now(timezone.utc)
    mapping = [
        ("steps",        body.steps,       "steps"),
        ("heart_rate",   body.heart_rate,  "bpm"),
        ("spo2",         body.spo2,        "%"),
        ("sleep",        body.sleep_hours, "hrs"),
        ("temperature",  body.temperature, "°F"),
        ("bp",           body.bp_systolic, "mmHg"),
    ]
    inserted = 0
    for v_type, value, unit in mapping:
        if value is not None:
            db.add(HealthVital(
                user_id=current_user.id,
                type=v_type,
                value=value,
                unit=unit,
                recorded_at=now,
            ))
            inserted += 1
    db.commit()
    return {"synced": inserted}


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


@router.get("/score", response_model=HealthScoreResponse)
def get_health_score(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Compute a health score (0-100) from latest vitals."""
    def latest_val(v_type):
        row = (
            db.query(HealthVital)
            .filter(HealthVital.user_id == current_user.id, HealthVital.type == v_type)
            .order_by(desc(HealthVital.recorded_at))
            .first()
        )
        return row.value if row else None

    score = 100
    breakdown = {}

    steps = latest_val("steps")
    if steps is not None and steps < 3000:
        score -= 15
        breakdown["steps"] = "Low activity (< 3000 steps)"
    elif steps is not None:
        breakdown["steps"] = "Good"

    sleep = latest_val("sleep")
    if sleep is not None and sleep < 6:
        score -= 15
        breakdown["sleep"] = "Insufficient sleep (< 6 hrs)"
    elif sleep is not None:
        breakdown["sleep"] = "Good"

    spo2 = latest_val("spo2")
    if spo2 is not None and spo2 < 95:
        score -= 20
        breakdown["spo2"] = "Low SpO2 (< 95%)"
    elif spo2 is not None:
        breakdown["spo2"] = "Good"

    hr = latest_val("heart_rate")
    if hr is not None and hr > 100:
        score -= 15
        breakdown["heart_rate"] = "Elevated heart rate (> 100 bpm)"
    elif hr is not None and hr < 50:
        score -= 10
        breakdown["heart_rate"] = "Low heart rate (< 50 bpm)"
    elif hr is not None:
        breakdown["heart_rate"] = "Good"

    temp = latest_val("temperature")
    if temp is not None and temp > 100.4:
        score -= 15
        breakdown["temperature"] = "Fever detected (> 100.4°F)"
    elif temp is not None:
        breakdown["temperature"] = "Good"

    # No data penalty
    data_count = sum(1 for v in [steps, sleep, spo2, hr, temp] if v is not None)
    if data_count == 0:
        score = 80  # Default when no data

    score = max(0, min(100, score))

    if score >= 90:
        status_label = "Excellent"
    elif score >= 75:
        status_label = "Good"
    elif score >= 50:
        status_label = "Fair"
    else:
        status_label = "Poor"

    return HealthScoreResponse(score=score, status=status_label, breakdown=breakdown)

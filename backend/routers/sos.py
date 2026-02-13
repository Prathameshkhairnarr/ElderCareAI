"""
SOS emergency endpoint.
"""
from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, SosLog, Alert
from schemas.schemas import SosRequest, SosResponse
from services.auth_service import get_current_user

router = APIRouter(tags=["SOS"])


@router.post("/sos", response_model=SosResponse, status_code=status.HTTP_201_CREATED)
def trigger_sos(
    body: SosRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Log an emergency SOS trigger."""
    sos = SosLog(
        user_id=current_user.id,
        latitude=body.latitude,
        longitude=body.longitude,
        message=body.message or "Emergency SOS triggered",
    )
    db.add(sos)

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

    db.commit()
    db.refresh(sos)
    return SosResponse.model_validate(sos)

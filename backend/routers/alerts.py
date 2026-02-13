"""
Alert history endpoint.
"""
from typing import List
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, Alert
from schemas.schemas import AlertOut
from services.auth_service import get_current_user

router = APIRouter(tags=["Alerts"])


@router.get("/alerts", response_model=List[AlertOut])
def get_alerts(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's alert history, newest first."""
    alerts = (
        db.query(Alert)
        .filter(Alert.user_id == current_user.id)
        .order_by(Alert.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [AlertOut.model_validate(a) for a in alerts]

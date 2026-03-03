"""
Alert history endpoint.
"""
from typing import List
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User, Alert, Guardian
from schemas.schemas import AlertOut
from services.auth_service import get_current_user

router = APIRouter(tags=["Alerts"])


@router.get("/alerts", response_model=List[AlertOut])
def get_alerts(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    is_read: bool = Query(default=None),  # Optional filter
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's alert history, newest first."""
    query = db.query(Alert).filter(Alert.user_id == current_user.id)
    
    if is_read is not None:
        query = query.filter(Alert.is_read == is_read)
        
    alerts = (
        query
        .order_by(Alert.created_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
    return [AlertOut.model_validate(a) for a in alerts]


@router.post("/alerts/{alert_id}/read", status_code=200)
def mark_alert_read(
    alert_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark an alert as read."""
    alert = (
        db.query(Alert)
        .filter(Alert.id == alert_id, Alert.user_id == current_user.id)
        .first()
    )
    if not alert:
        # If not found for current user, check if it's an alert for an elder this user guards?
        # For now, keep it simple: Guardian sees elder's alerts via dashboard, 
        # but technically marking them read might need to happen there too.
        # But the Requirement says "Guardian app/page fetches alerts via API."
        # If Guardian is fetching Elder's alerts, they are fetching them via `guardian/dashboard` or a specific endpoint.
        # The `get_alerts` is for `current_user`'s own alerts.
        # Guardian dashboard shows "Recent Alerts". 
        
        # Let's simple allow marking read if current user is a guardian of the alert's owner.
        guardian_entry = (
            db.query(Guardian)
            .join(User, Guardian.user_id == User.id) # Guardian.user_id is Elder
            .join(Alert, Alert.user_id == User.id)
            .filter(Alert.id == alert_id)
            .filter(Guardian.phone == current_user.phone)
            .first()
        )
        
        if guardian_entry:
            # It's an alert for an elder this user protects
            alert = db.query(Alert).filter(Alert.id == alert_id).first()
        else:
            raise HTTPException(status_code=404, detail="Alert not found.")

    alert.is_read = True
    db.commit()
    return {"status": "success"}

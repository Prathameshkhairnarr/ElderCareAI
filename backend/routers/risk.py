"""
Risk score endpoints.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User
from schemas.schemas import RiskResponse
from services.auth_service import get_current_user
from services.risk_service import get_current_risk, resolve_risk

router = APIRouter(tags=["Risk Score"])


@router.get("/risk", response_model=RiskResponse)
def get_risk_score(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's dynamic risk score (0-100)."""
    result = get_current_risk(current_user.id, db)
    return RiskResponse(**result)


@router.get("/elder/risk-score", response_model=RiskResponse)
def get_elder_risk_score(
    elder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Guardian-accessible endpoint to fetch an elder's risk score.
    Also works for the elder themselves.
    """
    # Allow if: user IS the elder, OR user is a guardian
    if current_user.id != elder_id and current_user.role not in ("guardian", "admin"):
        raise HTTPException(status_code=403, detail="Not authorized")

    # Verify elder exists
    elder = db.query(User).filter(User.id == elder_id).first()
    if not elder:
        raise HTTPException(status_code=404, detail="Elder not found")

    result = get_current_risk(elder_id, db)
    return RiskResponse(**result)


@router.post("/risk/resolve/{entry_id}")
def resolve_risk_endpoint(
    entry_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Mark a specific risk entry as resolved (e.g. user handled the scam)."""
    resolve_risk(db, current_user.id, entry_id)
    return {"status": "resolved", "id": entry_id}

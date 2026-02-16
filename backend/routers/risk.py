"""
Risk score endpoint.
"""
from fastapi import APIRouter, Depends
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
    # Use the new active-risk service
    result = get_current_risk(current_user.id, db)
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

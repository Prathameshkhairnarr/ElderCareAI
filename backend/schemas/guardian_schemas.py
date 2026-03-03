"""
Guardian schemas.
"""
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, Field
from .schemas import AlertOut

class GuardianCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    phone: str = Field(..., min_length=10, max_length=20)
    email: Optional[str] = None
    is_primary: bool = False

class GuardianResponse(BaseModel):
    id: int
    user_id: int
    name: str
    phone: str
    email: Optional[str]
    is_primary: bool
    created_at: datetime

    class Config:
        from_attributes = True

class ElderStats(BaseModel):
    elder_id: int
    elder_name: str
    elder_phone: str
    risk_score: int
    last_sos_at: Optional[datetime]
    unread_alerts_count: int
    recent_alerts: List[AlertOut]

class GuardianDashboardResponse(BaseModel):
    elders: List[ElderStats]

"""
Pydantic schemas for Call Protection API.
"""
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


# ── Request Schemas ──────────────────────────────────────


class CallMetadataInput(BaseModel):
    """Optional metadata about the call."""
    call_duration: Optional[int] = None  # seconds
    time_of_day: Optional[str] = None  # morning/afternoon/evening/night
    is_voip: Optional[bool] = False
    is_weekend: Optional[bool] = False


class PhoneCheckRequest(BaseModel):
    """Request to check phone number reputation."""
    phone_hash: str = Field(..., min_length=64, max_length=64)
    metadata: Optional[CallMetadataInput] = None


class ReportRequest(BaseModel):
    """Request to report a scam number."""
    phone_hash: str = Field(..., min_length=64, max_length=64)
    category: str = Field(..., min_length=1, max_length=50)
    notes: Optional[str] = Field(None, max_length=500)


# ── Response Schemas ─────────────────────────────────────


class ReputationResponse(BaseModel):
    """Response with phone number reputation."""
    risk_score: int = Field(..., ge=0, le=100)
    risk_level: str  # SAFE, UNKNOWN, SUSPICIOUS, HIGH
    category: Optional[str] = None
    report_count: int
    warning_message: str
    recommended_action: str  # allow, warn_only, warn_and_silence, block
    confidence: float = Field(..., ge=0, le=1)

    class Config:
        from_attributes = True


class ReportResponse(BaseModel):
    """Response after submitting a report."""
    message: str
    updated_risk_score: int
    total_reports: int


class CallReportStats(BaseModel):
    """Statistics for a user's reporting activity."""
    total_reports: int
    reports_today: int
    trust_score: float

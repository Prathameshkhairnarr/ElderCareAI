"""
Pydantic schemas for request / response validation.
"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field


# ── Auth ──────────────────────────────────────────────

class RegisterRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    phone: str = Field(..., min_length=10, max_length=20)
    password: str = Field(..., min_length=4)
    role: str = Field(default="elder", pattern="^(elder|caregiver|admin)$")
    firebase_token: Optional[str] = None


class LoginRequest(BaseModel):
    phone: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: "UserOut"


class UserOut(BaseModel):
    id: int
    name: str
    phone: str
    role: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── SMS Analysis ──────────────────────────────────────

class SmsRequest(BaseModel):
    message: str = Field(..., min_length=1)


class SmsResponse(BaseModel):
    id: int
    is_scam: bool
    confidence: int
    category: str
    explanation: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── Call / Voice Analysis ─────────────────────────────

class CallRequest(BaseModel):
    transcript: str = Field(..., min_length=1)


class CallResponse(BaseModel):
    id: int
    is_scam: bool
    confidence: int
    category: str
    explanation: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── Risk Score ────────────────────────────────────────

class RiskResponse(BaseModel):
    score: int
    level: str
    details: str


# ── Alert ─────────────────────────────────────────────

class AlertOut(BaseModel):
    id: int
    alert_type: str
    title: str
    details: str
    severity: str
    created_at: datetime

    class Config:
        from_attributes = True


# ── SOS ───────────────────────────────────────────────

class SosRequest(BaseModel):
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    message: Optional[str] = "Emergency SOS triggered"


class SosResponse(BaseModel):
    id: int
    message: str
    created_at: datetime

    class Config:
        from_attributes = True


# Resolve forward reference
TokenResponse.model_rebuild()

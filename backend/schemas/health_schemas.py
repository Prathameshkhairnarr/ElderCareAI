from pydantic import BaseModel, Field
from datetime import datetime
from typing import List, Optional

class VitalBase(BaseModel):
    type: str # heart_rate, bp, steps, sleep, spo2, temperature
    value: float
    unit: str
    recorded_at: Optional[datetime] = None

class VitalCreate(VitalBase):
    pass

class VitalResponse(VitalBase):
    id: int
    user_id: int
    recorded_at: datetime
    
    class Config:
        from_attributes = True

class HealthSummary(BaseModel):
    heart_rate: Optional[VitalResponse] = None
    bp: Optional[VitalResponse] = None 
    steps: Optional[VitalResponse] = None
    spo2: Optional[VitalResponse] = None
    sleep: Optional[VitalResponse] = None
    temperature: Optional[VitalResponse] = None


# ── Health Profile (demographic & medical) ────────────

class HealthProfileCreate(BaseModel):
    age: Optional[int] = Field(None, ge=1, le=150)
    gender: Optional[str] = Field(None, max_length=20)
    blood_group: Optional[str] = Field(None, max_length=10)
    height_cm: Optional[float] = Field(None, ge=30, le=300)
    weight_kg: Optional[float] = Field(None, ge=5, le=500)
    medical_conditions: Optional[str] = ""
    emergency_contact: Optional[str] = Field(None, max_length=20)


class HealthProfileResponse(BaseModel):
    id: int
    user_id: int
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_group: Optional[str] = None
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    medical_conditions: Optional[str] = ""
    emergency_contact: Optional[str] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True


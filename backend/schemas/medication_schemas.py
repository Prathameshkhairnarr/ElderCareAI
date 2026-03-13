from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

class MedicineBase(BaseModel):
    name: str
    composition: Optional[str] = None
    manufacturer: Optional[str] = None
    price: Optional[float] = None
    type: Optional[str] = None
    pack_size: Optional[str] = None

class MedicineCreate(MedicineBase):
    pass

class MedicineResponse(MedicineBase):
    id: int

    class Config:
        from_attributes = True


class UserMedicationBase(BaseModel):
    medicine_id: int
    dosage_value: Optional[float] = None
    dosage_unit: Optional[str] = None
    frequency_per_day: Optional[int] = 1
    time_of_day: Optional[str] = None
    start_date: Optional[datetime] = None
    end_date: Optional[datetime] = None
    notes: Optional[str] = None

class UserMedicationCreate(UserMedicationBase):
    pass

class UserMedicationResponse(UserMedicationBase):
    id: int
    user_id: int
    medicine: MedicineResponse
    created_at: datetime

    class Config:
        from_attributes = True


class PrescriptionItemBase(BaseModel):
    medicine_id: int
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    duration_days: Optional[int] = None

class PrescriptionItemCreate(PrescriptionItemBase):
    pass

class PrescriptionItemResponse(PrescriptionItemBase):
    id: int
    prescription_id: int
    medicine: MedicineResponse

    class Config:
        from_attributes = True


class PrescriptionBase(BaseModel):
    doctor_name: Optional[str] = None
    notes: Optional[str] = None

class PrescriptionCreate(PrescriptionBase):
    items: List[PrescriptionItemCreate]

class PrescriptionResponse(PrescriptionBase):
    id: int
    user_id: int
    prescription_date: datetime
    created_at: datetime
    items: List[PrescriptionItemResponse] = []

    class Config:
        from_attributes = True

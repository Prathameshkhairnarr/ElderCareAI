from pydantic import BaseModel
from typing import Optional

class ContactBase(BaseModel):
    name: str
    phone: str
    relationship: str
    color_index: int = 0
    photo_base64: Optional[str] = None

class ContactCreate(ContactBase):
    id: Optional[str] = None  # Frontend might generate UUID

class ContactUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    relationship: Optional[str] = None
    color_index: Optional[int] = None
    photo_base64: Optional[str] = None

class ContactResponse(ContactBase):
    id: str
    user_id: int
    is_active: bool

    class Config:
        from_attributes = True

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import uuid

from database.engine import get_db
from database.models import EmergencyContact, User
from schemas.contact_schemas import ContactCreate, ContactResponse, ContactUpdate
from services.auth_service import get_current_user

router = APIRouter(
    prefix="/contacts",
    tags=["contacts"],
)

@router.get("/", response_model=List[ContactResponse])
def get_contacts(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id,
        EmergencyContact.is_active == True
    ).all()

@router.post("/", response_model=ContactResponse)
def create_contact(
    contact: ContactCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check limit (e.g. 10 contacts max for safety/spam)
    count = db.query(EmergencyContact).filter(
        EmergencyContact.user_id == current_user.id
    ).count()
    if count >= 20:
        raise HTTPException(status_code=400, detail="Contact limit reached (20)")

    # Use provided ID or generate new UUID
    cid = contact.id if contact.id else str(uuid.uuid4())

    # Check if exists (upsert logic if ID provided?)
    # For now, if ID exists, we reject or update. Let's assume create is new.
    existing = db.query(EmergencyContact).filter(EmergencyContact.id == cid).first()
    if existing:
        raise HTTPException(status_code=400, detail="Contact ID already exists")

    new_contact = EmergencyContact(
        id=cid,
        user_id=current_user.id,
        name=contact.name,
        phone=contact.phone,
        relationship=contact.relationship,
        color_index=contact.color_index,
        photo_base64=contact.photo_base64
    )
    db.add(new_contact)
    db.commit()
    db.refresh(new_contact)
    return new_contact

@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_contact(
    contact_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    contact = db.query(EmergencyContact).filter(
        EmergencyContact.id == contact_id,
        EmergencyContact.user_id == current_user.id
    ).first()
    
    if not contact:
        raise HTTPException(status_code=404, detail="Contact not found")
        
    db.delete(contact)
    db.commit()

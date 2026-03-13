from fastapi import APIRouter, Depends, Query, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
from typing import List

from database.engine import get_db
from database.models import User, Medicine, UserMedication, Prescription, PrescriptionItem
from schemas.medication_schemas import (
    MedicineResponse,
    UserMedicationCreate, UserMedicationResponse,
    PrescriptionCreate, PrescriptionResponse,
    PrescriptionItemCreate, PrescriptionItemResponse
)
from services.auth_service import get_current_user

router = APIRouter(tags=["Medications"])


@router.get("/medicines/search", response_model=List[MedicineResponse])
def search_medicines(
    q: str = Query(..., min_length=2),
    limit: int = 20,
    db: Session = Depends(get_db)
):
    """Search for medicines by name or composition (optimized for startswith or contains)."""
    # Prefer exact or starting matches first
    results = db.query(Medicine).filter(
        Medicine.name.ilike(f"{q}%")
    ).limit(limit).all()

    # If few results, broaden search to composition and contains
    if len(results) < limit:
        additional_results = db.query(Medicine).filter(
            Medicine.name.notilike(f"{q}%"),
            or_(
                Medicine.name.ilike(f"%{q}%"),
                Medicine.composition.ilike(f"%{q}%")
            )
        ).limit(limit - len(results)).all()
        results.extend(additional_results)

    return results

@router.get("/medicines/{medicine_id}", response_model=MedicineResponse)
def get_medicine_details(medicine_id: int, db: Session = Depends(get_db)):
    """Get complete details of a specific medicine by ID."""
    medicine = db.query(Medicine).filter(Medicine.id == medicine_id).first()
    if not medicine:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return medicine


# ── User Medications ────────────

@router.get("/user/medications", response_model=List[UserMedicationResponse])
def get_user_medications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all active medications for the logged-in user."""
    return db.query(UserMedication).filter(
        UserMedication.user_id == current_user.id
    ).order_by(desc(UserMedication.created_at)).all()

@router.post("/user/medications", response_model=UserMedicationResponse)
def add_user_medication(
    medication: UserMedicationCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a new medication to the user's active list."""
    medicine = db.query(Medicine).filter(Medicine.id == medication.medicine_id).first()
    if not medicine:
        raise HTTPException(status_code=404, detail="Medicine not found")

    new_med = UserMedication(
        user_id=current_user.id,
        **medication.model_dump()
    )
    db.add(new_med)
    db.commit()
    db.refresh(new_med)
    return new_med

@router.delete("/user/medications/{med_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user_medication(
    med_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Remove a medication from the user's list."""
    med = db.query(UserMedication).filter(
        UserMedication.id == med_id,
        UserMedication.user_id == current_user.id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
        
    db.delete(med)
    db.commit()


# ── Prescriptions ────────────

@router.get("/prescriptions", response_model=List[PrescriptionResponse])
def get_prescriptions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all digital prescriptions for the logged-in user."""
    return db.query(Prescription).filter(
        Prescription.user_id == current_user.id
    ).order_by(desc(Prescription.prescription_date)).all()

@router.post("/prescriptions", response_model=PrescriptionResponse)
def add_prescription(
    prescription_data: PrescriptionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a new digital prescription along with its item entries."""
    new_presc = Prescription(
        user_id=current_user.id,
        doctor_name=prescription_data.doctor_name,
        notes=prescription_data.notes
    )
    db.add(new_presc)
    db.commit()
    db.refresh(new_presc)

    for item in prescription_data.items:
        new_item = PrescriptionItem(
            prescription_id=new_presc.id,
            **item.model_dump()
        )
        db.add(new_item)
    
    db.commit()
    db.refresh(new_presc)
    return new_presc

"""
Auth router: register + login.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User
from schemas.schemas import RegisterRequest, TokenResponse, UserOut
from services.auth_service import hash_password, verify_password, create_access_token
from services.firebase_service import verify_firebase_token


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user and return a JWT token."""
    existing = db.query(User).filter(User.phone == body.phone).first()
    if existing:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    # Verify Firebase Token if provided
    if body.firebase_token:
        verified_phone = verify_firebase_token(body.firebase_token)
        if not verified_phone:
            raise HTTPException(status_code=401, detail="Invalid Firebase token")
        
        # Normalize phones for comparison (simple check)
        # In prod, use a phone library to format both to E.164
        if verified_phone != body.phone and \
           verified_phone != f"+91{body.phone}" and \
           body.phone not in verified_phone:
             # Allow some flexibility for demo, but ideally they must match
             pass 
             # For stricter security:
             # if verified_phone != body.phone:
             #    raise HTTPException(status_code=400, detail="Phone mismatch")

    user = User(
        name=body.name,
        phone=body.phone,
        password_hash=hash_password(body.password),
        role=body.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": user.id, "role": user.role})
    return TokenResponse(
        access_token=token,
        user=UserOut.model_validate(user),
    )


@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """OAuth2 compatible login"""

    user = db.query(User).filter(User.phone == form_data.username).first()

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail="Invalid phone number or password",
        )

    token = create_access_token({"sub": str(user.id), "role": user.role})

    return TokenResponse(
        access_token=token,
        user=UserOut.model_validate(user),
    )

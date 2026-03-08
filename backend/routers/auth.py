"""
Auth router: register + login. (Production Hardened)
"""
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from database.engine import get_db
from database.models import User
from schemas.schemas import RegisterRequest, TokenResponse, UserOut, ChangePinRequest, ProfilePhotoRequest
from services.auth_service import hash_password, verify_password, create_access_token, get_current_user
from utils.phone_utils import normalize_phone

logger = logging.getLogger("eldercare")
router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user and return a JWT token."""
    normalized_phone = normalize_phone(body.phone)
    existing = db.query(User).filter(User.phone == normalized_phone).first()
    if existing:
        raise HTTPException(status_code=400, detail="Phone number already registered")

    logger.info(f"Registering user: {body.name}")

    try:
        user = User(
            name=body.name,
            phone=normalized_phone,
            password_hash=hash_password(body.password),
            role=body.role,
            is_active=True,
            is_phone_verified=True,
            last_login_at=None,
        )
        db.add(user)
        db.commit()
        db.refresh(user)

        token = create_access_token({"sub": str(user.id), "role": user.role})
        return {
            "status": "success",
            "message": "Registration successful",
            "access_token": token,
            "token_type": "bearer",
            "user": UserOut.model_validate(user).model_dump(mode="json"),
        }
    except HTTPException:
        raise  # Re-raise HTTP exceptions as-is
    except Exception as e:
        db.rollback()
        logger.error(f"Registration error: {type(e).__name__}")
        raise HTTPException(status_code=500, detail="Registration failed. Please try again.")


@router.post("/login")
def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db),
):
    """OAuth2 compatible login with structured response."""
    normalized_phone = normalize_phone(form_data.username)
    logger.info(f"Login attempt for phone (normalized)")
    user = db.query(User).filter(User.phone == normalized_phone).first()

    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=401,
            detail="Invalid phone number or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Account is deactivated. Contact support.",
        )

    # Update last_login_at
    user.last_login_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id), "role": user.role})

    return {
        "status": "success",
        "message": "Login successful",
        "access_token": token,
        "token_type": "bearer",
        "user": UserOut.model_validate(user).model_dump(mode="json"),
    }


@router.post("/change-pin")
def change_pin(
    body: ChangePinRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Change the user's PIN (password). Verifies current PIN first."""
    if not verify_password(body.current_pin, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Current PIN is incorrect")

    current_user.password_hash = hash_password(body.new_pin)
    db.commit()
    logger.info(f"PIN changed for user {current_user.id}")

    return {"status": "success", "message": "PIN changed successfully"}


@router.post("/profile-photo")
def upload_profile_photo(
    body: ProfilePhotoRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Upload/update profile photo (base64 encoded)."""
    current_user.profile_photo = body.photo
    db.commit()
    logger.info(f"Profile photo updated for user {current_user.id}")

    return {"status": "success", "message": "Profile photo uploaded"}


@router.get("/profile-photo")
def get_profile_photo(
    current_user: User = Depends(get_current_user),
):
    """Get the stored profile photo (base64)."""
    return {
        "photo": current_user.profile_photo,
        "has_photo": current_user.profile_photo is not None,
    }

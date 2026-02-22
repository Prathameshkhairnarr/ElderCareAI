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
from schemas.schemas import RegisterRequest, TokenResponse, UserOut
from services.auth_service import hash_password, verify_password, create_access_token
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

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
from schemas.schemas import RegisterRequest, TokenResponse, UserOut, ChangePinRequest, ProfilePhotoRequest, SendOtpRequest, VerifyOtpResetRequest
from services.auth_service import hash_password, verify_password, create_access_token, get_current_user
from services.otp_service import send_otp, verify_otp, is_fallback_mode
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


from schemas.schemas import ResetPinRequest

@router.post("/reset-pin")
def reset_pin(
    body: ResetPinRequest,
    db: Session = Depends(get_db),
):
    """Reset PIN via phone number (Unauthenticated flow)"""
    normalized_phone = normalize_phone(body.phone)
    user = db.query(User).filter(User.phone == normalized_phone).first()

    if not user:
        raise HTTPException(status_code=404, detail="No account found with this phone number")

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Account is deactivated. Contact support.",
        )

    user.password_hash = hash_password(body.new_pin)
    db.commit()
    logger.info(f"PIN reset executed for phone {normalized_phone}")

    return {"status": "success", "message": "PIN reset successfully. You can now login with your new PIN."}


# ─────────────────────────────────────────────────────────────────────────────
# NEW: 2-Step OTP Reset (Fast2SMS with fallback)
# Existing /reset-pin above is kept intact for backward compatibility
# ─────────────────────────────────────────────────────────────────────────────

@router.post("/otp/send")
def otp_send(
    body: SendOtpRequest,
    db: Session = Depends(get_db),
):
    """
    Step 1 — Send OTP to the phone number.
    Uses Fast2SMS if configured, silently falls back to console log (dev/demo).
    Existing users are never modified here.
    """
    normalized_phone = normalize_phone(body.phone)

    # Check user exists (don't reveal if not found — security)
    user = db.query(User).filter(User.phone == normalized_phone).first()
    if not user or not user.is_active:
        # Return generic success to prevent phone enumeration attacks
        return {
            "status": "success",
            "message": "If this number is registered, an OTP will be sent.",
            "fallback": False,
        }

    result = send_otp(normalized_phone)
    logger.info(f"OTP send result for phone ending {normalized_phone[-4:]}: sent={result['sent']}, fallback={result['fallback']}")

    return {
        "status": "success",
        "message": result["message"],
        "fallback": result["fallback"],  # Flutter can show hint if fallback
    }


@router.post("/otp/verify-reset")
def otp_verify_reset(
    body: VerifyOtpResetRequest,
    db: Session = Depends(get_db),
):
    """
    Step 2 — Verify OTP and reset PIN atomically.
    Falls back gracefully if OTP service had issues.
    Existing users and their data are NEVER deleted.
    """
    normalized_phone = normalize_phone(body.phone)

    user = db.query(User).filter(User.phone == normalized_phone).first()
    if not user:
        raise HTTPException(status_code=404, detail="No account found with this phone number")

    if not user.is_active:
        raise HTTPException(status_code=403, detail="Account is deactivated. Contact support.")

    # ── OTP Verification ──
    otp_valid = verify_otp(normalized_phone, body.otp)

    if not otp_valid:
        # Fallback mode check: if Fast2SMS was unavailable, be lenient in DEV only
        if is_fallback_mode():
            logger.warning(
                f"[FALLBACK MODE] OTP mismatch for {normalized_phone[-4:]} — "
                "Fast2SMS not configured. Check server logs for OTP."
            )
            raise HTTPException(
                status_code=400,
                detail="Invalid or expired OTP. (Dev mode: check server logs for OTP)",
            )
        raise HTTPException(status_code=400, detail="Invalid or expired OTP. Please request a new one.")

    # ✅ OTP valid — reset PIN
    user.password_hash = hash_password(body.new_pin)
    db.commit()
    logger.info(f"PIN reset via OTP for user {user.id}")

    return {
        "status": "success",
        "message": "PIN reset successfully. You can now login with your new PIN.",
    }

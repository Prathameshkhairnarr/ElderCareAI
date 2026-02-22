"""
Authentication service: password hashing + JWT token management. (Production Hardened)

Changes:
- Wrap verify_password in try/except (bcrypt can crash on corrupt hashes)
- Fix user_id type: payload.get("sub") returns string, cast to int safely
- Explicit expired token handling
- Never log password hashes or tokens
"""
import os
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, ExpiredSignatureError, jwt
from passlib.context import CryptContext
from sqlalchemy.orm import Session
from dotenv import load_dotenv

from database.engine import get_db
from database.models import User

load_dotenv()

logger = logging.getLogger("eldercare")

SECRET_KEY = os.getenv("SECRET_KEY", "fallback-dev-key")
ALGORITHM = os.getenv("ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "1440"))

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


# ── Password ──────────────────────────────────────────

def hash_password(password: str):
    password = password[:72]   # truncate for bcrypt safety
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password — crash-safe against corrupt hashes."""
    try:
        plain_password = plain_password[:72]
        return pwd_context.verify(plain_password, hashed_password)
    except Exception as e:
        logger.error(f"Password verification error: {type(e).__name__}")
        return False


# ── JWT ───────────────────────────────────────────────

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    except ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired. Please login again.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ── Dependencies ──────────────────────────────────────

def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """FastAPI dependency – extracts & validates user from JWT."""
    payload = decode_token(token)
    raw_user_id = payload.get("sub")
    if raw_user_id is None:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    # Safely cast to int — sub is stored as string
    try:
        user_id = int(raw_user_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=401, detail="Invalid token payload: bad user id")

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")
    return user


def require_role(*roles: str):
    """Returns a dependency that enforces one of the given roles."""
    def role_checker(current_user: User = Depends(get_current_user)) -> User:
        if current_user.role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Role '{current_user.role}' not authorized. Required: {', '.join(roles)}",
            )
        return current_user
    return role_checker

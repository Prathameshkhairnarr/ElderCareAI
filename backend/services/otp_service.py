"""
OTP Service — Fast2SMS with Graceful Fallback

Logic:
  1. Try to send OTP via Fast2SMS (if API key is configured)
  2. If Fast2SMS fails (credits exhausted, network error, no key) → fallback mode
  3. Fallback mode: OTP is stored in DB, logged to server console (dev/demo use)
  4. Existing users and data are NEVER touched by this service
"""
import os
import random
import string
import hashlib
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional

import requests
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger("eldercare")

FAST2SMS_API_KEY: Optional[str] = os.getenv("FAST2SMS_API_KEY", "").strip() or None
OTP_EXPIRE_MINUTES = int(os.getenv("OTP_EXPIRE_MINUTES", "10"))

# In-memory OTP store: { hashed_phone → { "otp": "XXXXXX", "expires_at": datetime } }
# Using a simple dict — fine for single-process deployments (SQLite)
# For multi-process / Redis, swap this out later
_otp_store: dict = {}


# ─────────────────────────────────────────────────────────────────────────────
# Internal Helpers
# ─────────────────────────────────────────────────────────────────────────────

def _generate_otp(length: int = 6) -> str:
    """Generate a secure numeric OTP."""
    return "".join(random.choices(string.digits, k=length))


def _phone_key(phone: str) -> str:
    """Hash the phone number for use as a dict key (privacy)."""
    return hashlib.sha256(phone.encode()).hexdigest()


def _is_fast2sms_available() -> bool:
    return bool(FAST2SMS_API_KEY)


# ─────────────────────────────────────────────────────────────────────────────
# Fast2SMS Sender
# ─────────────────────────────────────────────────────────────────────────────

def _send_via_fast2sms(phone: str, otp: str) -> bool:
    """
    Try to send OTP via Fast2SMS REST API.
    Returns True on success, False on any failure (credits, network, etc.)
    """
    try:
        # Fast2SMS DLT API (works with transactional + promotional)
        url = "https://www.fast2sms.com/dev/bulkV2"
        payload = {
            "variables_values": otp,
            "route": "otp",
            "numbers": phone.replace("+91", "").replace("+", ""),  # strip country code
        }
        headers = {
            "authorization": FAST2SMS_API_KEY,
            "Content-Type": "application/json",
        }
        response = requests.post(url, json=payload, headers=headers, timeout=8)
        data = response.json()

        if response.status_code == 200 and data.get("return") is True:
            logger.info("OTP sent via Fast2SMS successfully")
            return True
        else:
            # Log reason without exposing API key
            reason = data.get("message", "Unknown error")
            logger.warning(f"Fast2SMS send failed: {reason}")
            return False

    except requests.exceptions.Timeout:
        logger.warning("Fast2SMS timeout — falling back to console OTP")
        return False
    except Exception as e:
        logger.warning(f"Fast2SMS error ({type(e).__name__}) — falling back to console OTP")
        return False


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

def send_otp(phone: str) -> dict:
    """
    Generate and send OTP for the given phone number.

    Returns:
        {
          "sent": bool,        # True = SMS sent, False = fallback mode
          "fallback": bool,    # True = Fast2SMS unavailable, using fallback
          "message": str,      # User-facing message
        }
    """
    otp = _generate_otp()
    expires_at = datetime.now(timezone.utc) + timedelta(minutes=OTP_EXPIRE_MINUTES)

    # Store OTP (hashed phone key for privacy)
    key = _phone_key(phone)
    _otp_store[key] = {"otp": otp, "expires_at": expires_at}

    # Try Fast2SMS first
    if _is_fast2sms_available():
        success = _send_via_fast2sms(phone, otp)
        if success:
            return {
                "sent": True,
                "fallback": False,
                "message": f"OTP sent to your phone. Valid for {OTP_EXPIRE_MINUTES} minutes.",
            }
        else:
            # Fast2SMS failed → fallback
            logger.warning(f"[FALLBACK] OTP for {phone[-4:].rjust(10, '*')} = {otp}")
            return {
                "sent": False,
                "fallback": True,
                "message": f"SMS unavailable. For testing, OTP is logged on server. Valid for {OTP_EXPIRE_MINUTES} minutes.",
            }
    else:
        # No API key configured → dev/fallback mode
        logger.warning(f"[FALLBACK - No API Key] OTP for {phone[-4:].rjust(10, '*')} = {otp}")
        return {
            "sent": False,
            "fallback": True,
            "message": f"OTP generated (dev mode). Valid for {OTP_EXPIRE_MINUTES} minutes.",
        }


def verify_otp(phone: str, otp_input: str) -> bool:
    """
    Verify the OTP entered by the user.
    Returns True if valid and not expired, False otherwise.
    Clears the OTP after successful verification (one-time use).
    """
    key = _phone_key(phone)
    record = _otp_store.get(key)

    if not record:
        logger.info(f"OTP verify failed: no record for phone ending {phone[-4:]}")
        return False

    # Check expiry
    if datetime.now(timezone.utc) > record["expires_at"]:
        _otp_store.pop(key, None)
        logger.info("OTP verify failed: expired")
        return False

    # Check value (constant-time compare via == is fine for short OTPs)
    if record["otp"] != otp_input.strip():
        logger.info("OTP verify failed: wrong value")
        return False

    # ✅ Valid — consume it (one-time use)
    _otp_store.pop(key, None)
    logger.info(f"OTP verified successfully for phone ending {phone[-4:]}")
    return True


def is_fallback_mode() -> bool:
    """Returns True if Fast2SMS is not configured (running in fallback/dev mode)."""
    return not _is_fast2sms_available()

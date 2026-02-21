"""
SQLAlchemy ORM models for ElderCare AI.
"""
from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, Boolean, Float, Text, DateTime, ForeignKey,
)
from sqlalchemy.orm import relationship as sqlalchemy_relationship
from database.engine import Base


def _utcnow():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    password_hash = Column(String(256), nullable=False)
    role = Column(String(20), nullable=False, default="elder")  # elder | guardian | admin
    is_active = Column(Boolean, default=True)
    is_phone_verified = Column(Boolean, default=True)  # True by default (no OTP provider)
    created_at = Column(DateTime, default=_utcnow)
    last_login_at = Column(DateTime, nullable=True)

    sms_analyses = sqlalchemy_relationship("SmsAnalysis", back_populates="user")
    call_analyses = sqlalchemy_relationship("CallAnalysis", back_populates="user")
    alerts = sqlalchemy_relationship("Alert", back_populates="user")
    sos_logs = sqlalchemy_relationship("SosLog", back_populates="user")
    emergency_contacts = sqlalchemy_relationship("EmergencyContact", back_populates="user")
    risk_entries = sqlalchemy_relationship("RiskEntry", back_populates="user")
    risk_state = sqlalchemy_relationship("RiskState", back_populates="user", uselist=False)
    health_vitals = sqlalchemy_relationship("HealthVital", back_populates="user")
    health_profile = sqlalchemy_relationship("HealthProfile", back_populates="user", uselist=False)
    guardians = sqlalchemy_relationship("Guardian", back_populates="user")


class HealthProfile(Base):
    """One-to-one health profile for a user — stores demographic & medical info."""
    __tablename__ = "health_profiles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    age = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=True)
    blood_group = Column(String(10), nullable=True)
    height_cm = Column(Float, nullable=True)
    weight_kg = Column(Float, nullable=True)
    medical_conditions = Column(Text, nullable=True, default="")
    emergency_contact = Column(String(20), nullable=True)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="health_profile")



class SmsAnalysis(Base):
    __tablename__ = "sms_analyses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message = Column(Text, nullable=False)
    content_hash = Column(String(64), nullable=True, index=True)  # SHA256 dedup
    is_scam = Column(Boolean, default=False)
    confidence = Column(Integer, default=0)
    category = Column(String(50), default="safe")
    explanation = Column(Text, default="")
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="sms_analyses")


class CallAnalysis(Base):
    __tablename__ = "call_analyses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    transcript = Column(Text, nullable=False)
    is_scam = Column(Boolean, default=False)
    confidence = Column(Integer, default=0)
    category = Column(String(50), default="safe")
    explanation = Column(Text, default="")
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="call_analyses")


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    alert_type = Column(String(30), nullable=False)   # sms_scam | call_fraud | sos | system
    title = Column(String(200), nullable=False)
    details = Column(Text, default="")
    severity = Column(String(20), default="medium")    # low | medium | high | critical
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="alerts")


class SosLog(Base):
    __tablename__ = "sos_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    message = Column(Text, default="Emergency SOS triggered")
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="sos_logs")


class EmergencyContact(Base):
    __tablename__ = "emergency_contacts"

    id = Column(String(36), primary_key=True, index=True)  # UUID from frontend or backend
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False)
    relationship = Column(String(50), default="Other")
    color_index = Column(Integer, default=0)
    photo_base64 = Column(Text, nullable=True)  # Store small thumbnail directly
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="emergency_contacts")


class RiskEntry(Base):
    """
    Tracks individual active threats (scams/frauds) that contribute to the risk score.
    When a threat is resolved or decays, this entry is updated.
    """
    __tablename__ = "risk_entries"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    source_type = Column(String(20), nullable=False)  # sms | call
    source_id = Column(String(64), index=True)        # hash or call_id
    risk_score_contribution = Column(Integer, default=0)
    status = Column(String(20), default="ACTIVE")     # ACTIVE | RESOLVED | DECAYED
    created_at = Column(DateTime, default=_utcnow)
    resolved_at = Column(DateTime, nullable=True)

    user = sqlalchemy_relationship("User", back_populates="risk_entries")


class RiskState(Base):
    """
    Optimization table to store the current aggregate risk score for a user.
    """
    __tablename__ = "risk_states"

    user_id = Column(Integer, ForeignKey("users.id"), primary_key=True)
    current_score = Column(Integer, default=0)
    last_scam_at = Column(DateTime, nullable=True)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="risk_state")


class HealthVital(Base):
    __tablename__ = "health_vitals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    type = Column(String(50), nullable=False) # heart_rate, bp, etc.
    value = Column(Float, nullable=False)
    unit = Column(String(20), nullable=False)
    recorded_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="health_vitals")


class Guardian(Base):
    __tablename__ = "guardians"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    phone = Column(String(20), nullable=False, index=True)
    email = Column(String(100), nullable=True)
    is_primary = Column(Boolean, default=False)
    created_at = Column(DateTime, default=_utcnow)

    user = sqlalchemy_relationship("User", back_populates="guardians")


class ProcessedMessage(Base):
    """
    Idempotency tracking for local SMS risk evaluation.
    Stores the hash of messages to prevent duplicate score inflations.
    """
    __tablename__ = "processed_messages"

    id = Column(Integer, primary_key=True, index=True)
    msg_hash = Column(String(64), unique=True, index=True, nullable=False)
    label = Column(String(20), nullable=False)
    created_at = Column(DateTime, default=_utcnow)


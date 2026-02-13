"""
SQLAlchemy ORM models for ElderCare AI.
"""
from datetime import datetime, timezone
from sqlalchemy import (
    Column, Integer, String, Boolean, Float, Text, DateTime, ForeignKey,
)
from sqlalchemy.orm import relationship
from database.engine import Base


def _utcnow():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=False)
    phone = Column(String(20), unique=True, nullable=False, index=True)
    password_hash = Column(String(256), nullable=False)
    role = Column(String(20), nullable=False, default="elder")  # elder | caregiver | admin
    created_at = Column(DateTime, default=_utcnow)

    sms_analyses = relationship("SmsAnalysis", back_populates="user")
    call_analyses = relationship("CallAnalysis", back_populates="user")
    alerts = relationship("Alert", back_populates="user")
    sos_logs = relationship("SosLog", back_populates="user")


class SmsAnalysis(Base):
    __tablename__ = "sms_analyses"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    message = Column(Text, nullable=False)
    is_scam = Column(Boolean, default=False)
    confidence = Column(Integer, default=0)
    category = Column(String(50), default="safe")
    explanation = Column(Text, default="")
    created_at = Column(DateTime, default=_utcnow)

    user = relationship("User", back_populates="sms_analyses")


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

    user = relationship("User", back_populates="call_analyses")


class Alert(Base):
    __tablename__ = "alerts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    alert_type = Column(String(30), nullable=False)   # sms_scam | call_fraud | sos | system
    title = Column(String(200), nullable=False)
    details = Column(Text, default="")
    severity = Column(String(20), default="medium")    # low | medium | high | critical
    created_at = Column(DateTime, default=_utcnow)

    user = relationship("User", back_populates="alerts")


class SosLog(Base):
    __tablename__ = "sos_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    message = Column(Text, default="Emergency SOS triggered")
    created_at = Column(DateTime, default=_utcnow)

    user = relationship("User", back_populates="sos_logs")

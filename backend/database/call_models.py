"""
Database models for Call Protection System.
"""
from sqlalchemy import Column, Integer, String, Float, Boolean, Text, DateTime, Index, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from database.engine import Base


class PhoneReputation(Base):
    """Store reputation data for phone numbers."""
    __tablename__ = "phone_reputation"

    id = Column(Integer, primary_key=True, index=True)
    phone_hash = Column(String(64), unique=True, nullable=False, index=True)  # SHA256 hash
    risk_score = Column(Integer, default=0)  # 0-100
    category = Column(String(50), nullable=True)  # loan_scam, bank_fraud, otp_scam, etc.
    report_count = Column(Integer, default=0)
    first_reported_at = Column(DateTime(timezone=True), nullable=True)
    last_updated = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    ml_confidence = Column(Float, nullable=True)  # ML model confidence (0-1)
    
    # Relationships
    reports = relationship("UserReport", back_populates="reputation")
    call_metadata = relationship("CallMetadata", back_populates="reputation", uselist=False)

    __table_args__ = (
        Index('idx_phone_hash', 'phone_hash'),
        Index('idx_risk_score', 'risk_score'),
    )


class UserReport(Base):
    """User-submitted scam reports."""
    __tablename__ = "user_reports"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    phone_hash = Column(String(64), ForeignKey("phone_reputation.phone_hash"), nullable=False)
    category = Column(String(50), nullable=False)  # loan_scam, bank_fraud, otp_scam, etc.
    notes = Column(Text, nullable=True)
    trust_score = Column(Float, default=1.0)  # User's reputation/trust score
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    
    # Relationships
    user = relationship("User")
    reputation = relationship("PhoneReputation", back_populates="reports")

    __table_args__ = (
        Index('idx_phone_hash_reports', 'phone_hash'),
        Index('idx_user_id_reports', 'user_id'),
    )


class CallMetadata(Base):
    """Call pattern metadata for ML feature extraction."""
    __tablename__ = "call_metadata"

    id = Column(Integer, primary_key=True, index=True)
    phone_hash = Column(String(64), ForeignKey("phone_reputation.phone_hash"), unique=True, nullable=False)
    call_frequency = Column(Integer, default=1)  # Number of calls in last 24h
    avg_duration = Column(Integer, nullable=True)  # Average call duration in seconds
    short_call_ratio = Column(Float, default=0.0)  # Percentage of calls < 10s
    voip_indicator = Column(Boolean, default=False)  # Detected as VoIP
    time_pattern = Column(String(20), nullable=True)  # morning/afternoon/evening/night
    created_at = Column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    
    # Relationships
    reputation = relationship("PhoneReputation", back_populates="call_metadata")

    __table_args__ = (
        Index('idx_phone_hash_metadata', 'phone_hash'),
    )

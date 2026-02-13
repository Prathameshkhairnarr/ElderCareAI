"""
Dynamic risk score calculation combining SMS, Call, and Alert data.
"""
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from database.models import SmsAnalysis, CallAnalysis, Alert


def calculate_risk(user_id: int, db: Session) -> dict:
    """Compute a 0-100 risk score for the given user."""
    since = datetime.now(timezone.utc) - timedelta(days=30)

    # Count recent scam detections
    sms_scams = (
        db.query(SmsAnalysis)
        .filter(SmsAnalysis.user_id == user_id, SmsAnalysis.is_scam == True, SmsAnalysis.created_at >= since)
        .count()
    )
    call_scams = (
        db.query(CallAnalysis)
        .filter(CallAnalysis.user_id == user_id, CallAnalysis.is_scam == True, CallAnalysis.created_at >= since)
        .count()
    )
    high_alerts = (
        db.query(Alert)
        .filter(
            Alert.user_id == user_id,
            Alert.severity.in_(["high", "critical"]),
            Alert.created_at >= since,
        )
        .count()
    )
    total_alerts = (
        db.query(Alert)
        .filter(Alert.user_id == user_id, Alert.created_at >= since)
        .count()
    )

    # Weighted scoring
    score = 0
    score += min(sms_scams * 10, 35)       # SMS scams: up to 35
    score += min(call_scams * 15, 35)       # Call frauds: up to 35
    score += min(high_alerts * 8, 20)       # High-severity alerts: up to 20
    score += min(total_alerts * 2, 10)      # General alert volume: up to 10
    score = min(score, 100)

    # Level
    if score < 30:
        level = "Low"
    elif score < 60:
        level = "Moderate"
    else:
        level = "High"

    # Human-readable details
    parts = []
    if sms_scams:
        parts.append(f"{sms_scams} SMS scam(s) detected")
    if call_scams:
        parts.append(f"{call_scams} fraudulent call(s) flagged")
    if high_alerts:
        parts.append(f"{high_alerts} high-severity alert(s)")
    if not parts:
        parts.append("No threats detected in the last 30 days. You're safe!")

    details = " · ".join(parts) + f" — Risk level: {level}"

    return {"score": score, "level": level, "details": details}

"""
ML-based scam scoring engine.
Hybrid approach: 60% ML model + 40% community reports.
"""
import math
from typing import Dict
from sqlalchemy.orm import Session
from database.call_models import PhoneReputation, UserReport, CallMetadata


def extract_features(phone_hash: str, metadata: dict, db: Session) -> Dict[str, float]:
    """Extract features for ML model from call data."""
    
    # Get call metadata
    call_meta = db.query(CallMetadata).filter(
        CallMetadata.phone_hash == phone_hash
    ).first()
    
    # Get reports
    reports = db.query(UserReport).filter(
        UserReport.phone_hash == phone_hash
    ).all()
    
    # Build feature vector
    features = {
        # Call pattern features
        "call_frequency_24h": call_meta.call_frequency if call_meta else 0,
        "avg_call_duration": call_meta.avg_duration if call_meta else 0,
        "short_call_ratio": call_meta.short_call_ratio if call_meta else 0.0,
        "is_voip": 1.0 if metadata.get("is_voip", False) else 0.0,
        
        # Community features
        "report_count": len(reports),
        "unique_reporters": len(set(r.user_id for r in reports)),
        "avg_reporter_trust": sum(r.trust_score for r in reports) / max(len(reports), 1),
        
        # Time pattern features
        "night_call_indicator": 1.0 if metadata.get("time_of_day") == "night" else 0.0,
        "weekend_call_indicator": 1.0 if metadata.get("is_weekend", False) else 0.0,
        
        # Category features (one-hot encoding)
        "is_loan_category": 1.0 if any(r.category == "loan_scam" for r in reports) else 0.0,
        "is_bank_category": 1.0 if any(r.category == "bank_fraud" for r in reports) else 0.0,
        "is_otp_category": 1.0 if any(r.category == "otp_scam" for r in reports) else 0.0,
    }
    
    return features


def predict_scam_probability(features: Dict[str, float]) -> float:
    """
    Simple rule-based scam probability (placeholder for actual ML model).
    In production, replace with trained LightGBM/scikit-learn model.
    """
    # Weighted scoring based on features
    score = 0.0
    
    # High frequency calls are suspicious
    if features["call_frequency_24h"] > 5:
        score += 0.3
    elif features["call_frequency_24h"] > 2:
        score += 0.15
    
    # Short calls (likely robocalls)
    if features["short_call_ratio"] > 0.7:
        score += 0.25
    
    # VoIP calls (common for scammers)
    if features["is_voip"]:
        score += 0.2
    
    # Night calls are suspicious
    if features["night_call_indicator"]:
        score += 0.15
    
    # Community reports are strong signal
    if features["report_count"] > 10:
        score += 0.4
    elif features["report_count"] > 3:
        score += 0.2
    
    # Category-specific boosts
    if features["is_loan_category"] or features["is_bank_category"]:
        score += 0.2
    
    # Clamp to [0, 1]
    return min(1.0, score)


def calculate_hybrid_risk_score(
    reputation: PhoneReputation,
    metadata: dict,
    db: Session
) -> int:
    """
    Calculate hybrid risk score (0-100).
    Formula: 60% ML score + 40% Community score
    """
    # Extract features
    features = extract_features(reputation.phone_hash, metadata or {}, db)
    
    # ML score (0-1 probability)
    ml_prob = predict_scam_probability(features)
    ml_score = int(ml_prob * 100)
    
    # Community score based on reports
    report_count = features["report_count"]
    unique_reporters = features["unique_reporters"]
    avg_trust = features["avg_reporter_trust"]
    
    # Logarithmic scaling for report count (diminishing returns)
    community_score = min(
        int(math.log1p(report_count * unique_reporters * avg_trust) * 15),
        100
    )
    
    # Combine: 60% ML + 40% Community
    final_score = int(ml_score * 0.6 + community_score * 0.4)
    
    # Clamp to 0-100
    return max(0, min(100, final_score))


def get_risk_level(score: int) -> str:
    """Categorize risk score into levels."""
    if score < 30:
        return "SAFE"
    elif score < 50:
        return "UNKNOWN"
    elif score < 70:
        return "SUSPICIOUS"
    else:
        return "HIGH"


def get_recommended_action(score: int) -> str:
    """Recommend action based on risk score."""
    if score >= 80:
        return "block"
    elif score >= 60:
        return "warn_and_silence"
    elif score >= 40:
        return "warn_only"
    else:
        return "allow"


def generate_warning_message(score: int, reputation: PhoneReputation) -> str:
    """Generate human-readable warning message."""
    level = get_risk_level(score)
    category = reputation.category or "unknown"
    count = reputation.report_count
    
    if level == "HIGH":
        return f"⚠️ HIGH RISK: {count} users reported this as {category.replace('_', ' ')}. Do not answer."
    elif level == "SUSPICIOUS":
        return f"⚠️ Suspicious: {count} reports for {category.replace('_', ' ')}. Be very careful."
    elif level == "UNKNOWN":
        return f"⚠️ Unknown number. {count} user reports. Proceed with caution."
    else:
        return "✓ This number appears safe. No known reports."


def recalculate_risk_score(reputation: PhoneReputation, db: Session) -> int:
    """Recalculate risk score after new report."""
    return calculate_hybrid_risk_score(reputation, {}, db)

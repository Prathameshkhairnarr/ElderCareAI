"""
Dynamic risk score calculation and lifecycle management.
Uses RiskEntry and RiskState for active/resolved threat tracking.
"""
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from sqlalchemy import desc
from database.models import RiskEntry, RiskState, User, HealthProfile, Alert

# Constants
RISK_CONTRIBUTION_SMS = 15
RISK_CONTRIBUTION_CALL = 20
RISK_DECAY_DAILY = 5
SAFE_THRESHOLD_DAYS = 7


def get_current_risk(user_id: int, db: Session) -> dict:
    """
    Get the current risk state. If missing, calculate from scratch.
    Integrates health profile data for vulnerability detection.
    """
    state = db.query(RiskState).filter(RiskState.user_id == user_id).first()
    
    if not state:
        # Initialize if not exists
        state = RiskState(user_id=user_id, current_score=0)
        db.add(state)
        db.commit()
        db.refresh(state)

    # Check for decay opportunity
    _apply_decay(state, db)

    score = min(state.current_score, 100)
    
    # ── Health profile integration ─────────────────
    is_vulnerable = False
    health_profile = db.query(HealthProfile).filter(
        HealthProfile.user_id == user_id
    ).first()

    if health_profile:
        # Age-based sensitivity: elderly users get +5 to effective score display
        if health_profile.age and health_profile.age > 65:
            score = min(score + 5, 100)
        # Vulnerability flag: medical conditions present
        if health_profile.medical_conditions and health_profile.medical_conditions.strip():
            is_vulnerable = True

    # Determine level
    if score < 10:
        level = "Safe"
    elif score < 40:
        level = "Low"
    elif score < 70:
        level = "Moderate"
    else:
        level = "High"

    # Get active active_threats count
    active_threats = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id, 
        RiskEntry.status == "ACTIVE"
    ).count()

    details = _generate_details(score, active_threats, is_vulnerable)

    return {
        "score": score,
        "level": level,
        "details": details,
        "active_threats": active_threats,
        "last_scam_at": state.last_scam_at,
        "is_vulnerable": is_vulnerable,
    }


def add_risk_entry(db: Session, user_id: int, source_type: str, source_id: str, is_scam: bool):
    """
    Called when a new analysis completes.
    If SCAM: Creates a new ACTIVE risk entry and increases score.
    If SAFE: Does nothing to score (unless we implement 'good behavior' bonus later).
    Idempotency: Checks if this specific source_id (hash) is already ACTIVE.
    """
    if not is_scam:
        return

    # Check existence
    existing = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id,
        RiskEntry.source_id == source_id
    ).first()

    if existing:
        # Already tracked. If it was resolved, do we re-activate? 
        # For now, NO. Once resolved, stays resolved to avoid annoyance.
        return

    # Create new entry
    contribution = RISK_CONTRIBUTION_CALL if source_type == 'call' else RISK_CONTRIBUTION_SMS
    new_entry = RiskEntry(
        user_id=user_id,
        source_type=source_type,
        source_id=source_id,
        status="ACTIVE",
        risk_score_contribution=contribution
    )
    db.add(new_entry)

    # Update State
    state = db.query(RiskState).filter(RiskState.user_id == user_id).first()
    if not state:
        state = RiskState(user_id=user_id, current_score=0)
        db.add(state)
    
    state.current_score = min(state.current_score + contribution, 100)
    state.last_scam_at = datetime.now(timezone.utc)

    # ── Vulnerability-aware alert ─────────────────
    health_profile = db.query(HealthProfile).filter(
        HealthProfile.user_id == user_id
    ).first()

    is_elderly = health_profile and health_profile.age and health_profile.age > 65
    has_conditions = (
        health_profile
        and health_profile.medical_conditions
        and health_profile.medical_conditions.strip()
    )

    if is_elderly or has_conditions:
        # Vulnerable user + scam → high severity alert
        alert = Alert(
            user_id=user_id,
            alert_type="vulnerable_user",
            title="High-risk scam detected for vulnerable user",
            details=f"Scam detected via {source_type}. User is flagged as vulnerable "
                    f"({'elderly' if is_elderly else ''}"
                    f"{' + ' if is_elderly and has_conditions else ''}"
                    f"{'has medical conditions' if has_conditions else ''}).",
            severity="high",
        )
        db.add(alert)
    
    db.commit()


def resolve_risk(db: Session, user_id: int, entry_id: int):
    """
    User marks a specific risk as resolved.
    Decreases score by the original contribution.
    """
    entry = db.query(RiskEntry).filter(RiskEntry.id == entry_id, RiskEntry.user_id == user_id).first()
    if not entry or entry.status != "ACTIVE":
        return

    entry.status = "RESOLVED"
    entry.resolved_at = datetime.now(timezone.utc)

    # Update state
    state = db.query(RiskState).filter(RiskState.user_id == user_id).first()
    if state:
        state.current_score = max(0, state.current_score - entry.risk_score_contribution)
    
    db.commit()


def _apply_decay(state: RiskState, db: Session):
    """
    If no scams in last 24h, reduce score slightly.
    If no scams in 7 days, massive reduction.
    """
    if not state.last_scam_at:
        if state.current_score > 0:
            state.current_score = 0
            db.commit()
        return

    now = datetime.now(timezone.utc)
    # Ensure timezone awareness
    if state.last_scam_at.tzinfo is None:
        last_scam = state.last_scam_at.replace(tzinfo=timezone.utc)
    else:
        last_scam = state.last_scam_at
        
    diff = now - last_scam

    # Full reset if safe for 7 days
    if diff.days >= SAFE_THRESHOLD_DAYS:
        if state.current_score > 0:
            state.current_score = 0
            # Also auto-resolve old entries? Optional.
            db.commit()
        return

    # Daily decay
    # We simple check if updated_at was more than 24h ago to avoid spamming decay
    if state.updated_at:
        if state.updated_at.tzinfo is None:
            last_update = state.updated_at.replace(tzinfo=timezone.utc)
        else:
            last_update = state.updated_at
            
        hours_since_update = (now - last_update).total_seconds() / 3600
        
        if hours_since_update >= 24 and state.current_score > 0:
            # Decay Logic
            state.current_score = max(0, state.current_score - RISK_DECAY_DAILY)
            # We don't update last_scam_at, just the score
            db.commit()


def _generate_details(score: int, active_threats: int, is_vulnerable: bool = False) -> str:
    if score == 0:
        return "You are safe. No active threats detected."
    
    parts = []
    if active_threats > 0:
        parts.append(f"{active_threats} active threat(s) contributing to risk.")
    else:
        parts.append("Risk score is elevated due to past activity.")
    
    if is_vulnerable:
        parts.append("⚠️ Vulnerable user — enhanced monitoring active.")
    
    return " ".join(parts)

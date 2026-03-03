"""
Dynamic Risk Intelligence Engine — backend service.

Unified scoring model:
  - Backend is the single source of truth
  - Scam SMS, SOS, and call events increase score
  - Safe SMS and time-based decay decrease score
  - Spike detection for burst of scams
  - Smooth hourly decay, NOT coarse daily decay
"""
import logging
from datetime import datetime, timedelta, timezone
from sqlalchemy.orm import Session
from sqlalchemy import desc
from database.models import RiskEntry, RiskState, User, HealthProfile, Alert

logger = logging.getLogger("eldercare")


# ── Event Weights ──
W_SMS = 15        # base points per scam SMS
W_SOS = 25        # points per SOS trigger
W_CALL = 20       # points per scam call (future)
D_SAFE = 1        # points removed per safe SMS
HOURLY_DECAY = 2.0   # points per hour since last scam
SAFE_RESET_DAYS = 7  # full reset after this many clean days

# ── Spike Detection ──
SPIKE_WINDOW_MIN = 10   # minutes
SPIKE_THRESHOLD = 3     # scams in window to trigger spike
SPIKE_MULTIPLIER = 1.5  # bonus multiplier during spike


def get_current_risk(user_id: int, db: Session) -> dict:
    """
    Get the current risk state with hourly decay applied.
    Integrates health profile data for vulnerability detection.
    """
    state = _get_or_create_state(user_id, db)

    # Apply smooth hourly decay
    _apply_decay(state, db)

    score = min(max(state.current_score, 0), 100)

    # ── Health profile integration ─────────────────
    is_vulnerable = False
    display_score = score
    health_profile = db.query(HealthProfile).filter(
        HealthProfile.user_id == user_id
    ).first()

    if health_profile:
        if health_profile.age and health_profile.age > 65:
            display_score = min(score + 5, 100)
        if health_profile.medical_conditions and health_profile.medical_conditions.strip():
            is_vulnerable = True

    # Determine level
    if display_score < 10:
        level = "Safe"
    elif display_score < 40:
        level = "Low"
    elif display_score < 70:
        level = "Moderate"
    else:
        level = "High"

    active_threats = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id,
        RiskEntry.status == "ACTIVE"
    ).count()

    details = _generate_details(display_score, active_threats, is_vulnerable)

    return {
        "score": display_score,
        "level": level,
        "details": details,
        "active_threats": active_threats,
        "last_scam_at": state.last_scam_at,
        "is_vulnerable": is_vulnerable,
    }


def add_risk_entry(
    db: Session,
    user_id: int,
    source_type: str,
    source_id: str,
    is_scam: bool,
    confidence: int = 50,
):
    """
    Record a threat event and update the rolling risk score.

    - Scam → increase score (weighted by confidence, spike-aware)
    - Safe  → decrease score by D_SAFE
    - Idempotent via source_id dedup
    """
    state = _get_or_create_state(user_id, db)

    if not is_scam:
        # Safe event → slow decay
        state.current_score = max(0, state.current_score - D_SAFE)
        db.commit()
        return

    # ── Idempotency check ──
    existing = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id,
        RiskEntry.source_id == source_id
    ).first()
    if existing:
        return

    # ── Calculate contribution ──
    base_weight = W_CALL if source_type == "call" else W_SMS
    contribution = base_weight * max(0.5, min(confidence / 100.0, 1.0))

    # Spike detection
    if _is_spike(user_id, db):
        contribution *= SPIKE_MULTIPLIER

    # ── Create risk entry ──
    new_entry = RiskEntry(
        user_id=user_id,
        source_type=source_type,
        source_id=source_id,
        status="ACTIVE",
        risk_score_contribution=int(contribution)
    )
    db.add(new_entry)

    # ── Update state ──
    state.current_score = min(int(state.current_score + contribution), 100)
    state.last_scam_at = datetime.now(timezone.utc)

    # ── Vulnerability-aware alert ──
    _check_vulnerability_alert(db, user_id, source_type)

    # ── High-risk score alert ──
    if state.current_score >= 75:
        _check_high_risk_alert(db, user_id, state.current_score)

    db.commit()


def add_sos_risk(db: Session, user_id: int, sos_id: int, commit: bool = True):
    """
    Record an SOS event as a risk contribution.
    SOS = highest weight event (W_SOS = 25).
    When commit=False, caller is responsible for committing.
    """
    source_id = f"sos_{sos_id}"

    # Idempotent
    existing = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id,
        RiskEntry.source_id == source_id
    ).first()
    if existing:
        return

    state = _get_or_create_state(user_id, db)

    new_entry = RiskEntry(
        user_id=user_id,
        source_type="sos",
        source_id=source_id,
        status="ACTIVE",
        risk_score_contribution=W_SOS
    )
    db.add(new_entry)

    state.current_score = min(max(state.current_score + W_SOS, 0), 100)
    state.last_scam_at = datetime.now(timezone.utc)

    # SOS always triggers high-risk alert
    _check_high_risk_alert(db, user_id, state.current_score)

    if commit:
        db.commit()
    logger.info(f"SOS risk added for user {user_id}: score={state.current_score}")


def resolve_risk(db: Session, user_id: int, entry_id: int):
    """
    Mark a risk entry as resolved. Decreases score by original contribution.
    """
    entry = db.query(RiskEntry).filter(
        RiskEntry.id == entry_id,
        RiskEntry.user_id == user_id
    ).first()
    if not entry or entry.status != "ACTIVE":
        return

    entry.status = "RESOLVED"
    entry.resolved_at = datetime.now(timezone.utc)

    state = db.query(RiskState).filter(RiskState.user_id == user_id).first()
    if state:
        state.current_score = max(0, state.current_score - entry.risk_score_contribution)

    db.commit()


def decay_all_scores(db: Session):
    """
    Background task: apply smooth hourly decay to ALL active risk states.
    Called periodically by the scheduler (e.g. every hour).
    """
    states = db.query(RiskState).filter(RiskState.current_score > 0).all()
    now = datetime.now(timezone.utc)

    for state in states:
        if not state.last_scam_at:
            state.current_score = 0
            continue

        last_scam = _ensure_utc(state.last_scam_at)
        diff = now - last_scam

        # Full reset after 7 days clean
        if diff.days >= SAFE_RESET_DAYS:
            state.current_score = 0
            # Auto-resolve all active entries
            db.query(RiskEntry).filter(
                RiskEntry.user_id == state.user_id,
                RiskEntry.status == "ACTIVE"
            ).update({"status": "DECAYED", "resolved_at": now})
            continue

        # Smooth hourly decay
        last_update = _ensure_utc(state.updated_at) if state.updated_at else last_scam
        hours_since_update = (now - last_update).total_seconds() / 3600.0

        if hours_since_update >= 1.0:
            decay = hours_since_update * HOURLY_DECAY
            state.current_score = max(0, int(state.current_score - decay))

    db.commit()


# ══════════════════════════════════════════════════════════
#  PRIVATE HELPERS
# ══════════════════════════════════════════════════════════

def _get_or_create_state(user_id: int, db: Session) -> RiskState:
    """Get or initialize a RiskState row for a user."""
    state = db.query(RiskState).filter(RiskState.user_id == user_id).first()
    if not state:
        state = RiskState(user_id=user_id, current_score=0)
        db.add(state)
        db.commit()
        db.refresh(state)
    return state


def _apply_decay(state: RiskState, db: Session):
    """
    Apply smooth time-based decay when reading the score.
    This ensures score is always fresh even without the background scheduler.
    """
    if state.current_score <= 0:
        return

    now = datetime.now(timezone.utc)

    if not state.last_scam_at:
        state.current_score = 0
        db.commit()
        return

    last_scam = _ensure_utc(state.last_scam_at)
    diff = now - last_scam

    # Full reset after 7 days clean
    if diff.days >= SAFE_RESET_DAYS:
        state.current_score = 0
        db.commit()
        return

    # Hourly decay since last update (not since last scam, to avoid double-decay)
    if state.updated_at:
        last_update = _ensure_utc(state.updated_at)
        hours_since_update = (now - last_update).total_seconds() / 3600.0

        if hours_since_update >= 0.5:  # Min 30 min between decay applications
            decay = hours_since_update * HOURLY_DECAY
            state.current_score = max(0, int(state.current_score - decay))
            db.commit()


def _is_spike(user_id: int, db: Session) -> bool:
    """Check if 3+ scam entries were created in the last 10 minutes."""
    window_start = datetime.now(timezone.utc) - timedelta(minutes=SPIKE_WINDOW_MIN)
    recent_count = db.query(RiskEntry).filter(
        RiskEntry.user_id == user_id,
        RiskEntry.status == "ACTIVE",
        RiskEntry.created_at >= window_start
    ).count()
    return recent_count >= SPIKE_THRESHOLD


def _check_vulnerability_alert(db: Session, user_id: int, source_type: str):
    """Create alert for vulnerable users (elderly / medical conditions)."""
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


def _check_high_risk_alert(db: Session, user_id: int, current_score: int):
    """Create a critical alert if score crosses 75 (deduped)."""
    existing = (
        db.query(Alert)
        .filter(
            Alert.user_id == user_id,
            Alert.alert_type == "high_risk",
            Alert.is_read == False
        )
        .first()
    )
    if not existing:
        alert = Alert(
            user_id=user_id,
            alert_type="high_risk",
            title="Risk Score Critical",
            details=f"User risk score has reached {current_score}/100. Immediate attention required.",
            severity="critical",
        )
        db.add(alert)


def _ensure_utc(dt: datetime) -> datetime:
    """Ensure a datetime is timezone-aware (UTC)."""
    if dt and dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


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

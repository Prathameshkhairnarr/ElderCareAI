"""
SMS and Voice fraud analysis using rule-based detection.
"""
import re
from dataclasses import dataclass
from services.ml_model import classifier



@dataclass
class AnalysisResult:
    is_scam: bool
    confidence: int       # 0-100
    category: str
    explanation: str


# ── Keyword Sets ──────────────────────────────────────

URGENCY_WORDS = {
    "urgent", "immediately", "act now", "expire", "suspended",
    "last chance", "hurry", "deadline", "limited time", "warning",
    "final notice", "right away", "don't delay", "asap",
}

FINANCIAL_WORDS = {
    "bank", "account", "transfer", "upi", "otp", "pin", "credit card",
    "debit card", "loan", "emi", "payment", "refund", "kyc", "aadhar",
    "pan card", "blocked", "verify", "transaction", "wallet", "paytm",
    "phonepe", "gpay", "prize", "lottery", "reward", "cashback",
    "rupees", "lakh", "crore", "won", "winner",
}

IMPERSONATION_WORDS = {
    "rbi", "reserve bank", "sbi", "government", "police", "court",
    "income tax", "customs", "cbi", "ministry", "official",
    "department", "authority", "officer", "inspector", "magistrate",
}

THREAT_WORDS = {
    "arrest", "jail", "legal action", "case filed", "warrant",
    "fine", "penalty", "blacklisted", "terminate", "seize",
    "freeze", "suspend", "cancel",
}

LINK_PATTERN = re.compile(
    r"https?://[^\s]+|www\.[^\s]+|bit\.ly/[^\s]+|t\.co/[^\s]+|"
    r"[a-zA-Z0-9.-]+\.(tk|ml|ga|cf|gq|xyz|top|buzz|click|link)/[^\s]*",
    re.IGNORECASE,
)


# ── Core Analysis ─────────────────────────────────────

def _analyze_text(text: str) -> AnalysisResult:
    """Shared analysis logic for both SMS and voice transcripts."""
    text_lower = text.lower()
    words = set(text_lower.split())

    urgency_hits = URGENCY_WORDS & words | {w for w in URGENCY_WORDS if len(w.split()) > 1 and w in text_lower}
    financial_hits = FINANCIAL_WORDS & words | {w for w in FINANCIAL_WORDS if len(w.split()) > 1 and w in text_lower}
    impersonation_hits = IMPERSONATION_WORDS & words | {w for w in IMPERSONATION_WORDS if len(w.split()) > 1 and w in text_lower}
    threat_hits = THREAT_WORDS & words | {w for w in THREAT_WORDS if len(w.split()) > 1 and w in text_lower}
    links = LINK_PATTERN.findall(text)

    # Confidence scoring
    score = 0
    reasons = []

    if urgency_hits:
        score += min(len(urgency_hits) * 12, 25)
        reasons.append(f"Urgency language detected: {', '.join(list(urgency_hits)[:3])}")

    if financial_hits:
        score += min(len(financial_hits) * 15, 30)
        reasons.append(f"Financial keywords found: {', '.join(list(financial_hits)[:3])}")

    if impersonation_hits:
        score += min(len(impersonation_hits) * 18, 25)
        reasons.append(f"Possible impersonation: {', '.join(list(impersonation_hits)[:3])}")

    if threat_hits:
        score += min(len(threat_hits) * 15, 20)
        reasons.append(f"Threatening language: {', '.join(list(threat_hits)[:3])}")

    if links:
        score += 20
        reasons.append(f"Suspicious link(s) detected: {', '.join(links[:2])}")

    score = min(score, 100)

    # Category classification
    if financial_hits and impersonation_hits:
        category = "financial_impersonation"
    elif financial_hits:
        category = "financial_scam"
    elif impersonation_hits:
        category = "impersonation"
    elif threat_hits:
        category = "threat_scam"
    elif links and urgency_hits:
        category = "phishing"
    elif links:
        category = "suspicious_link"
    elif urgency_hits:
        category = "social_engineering"
    else:
        category = "safe"

    # ── ML Analysis ───────────────────────────────────────
    ml_result = classifier.predict(text)
    ml_confidence = ml_result["confidence"]
    
    # Combine scores (Weight: 60% Rule-based, 40% ML)
    final_score = int((score * 0.6) + (ml_confidence * 0.4))
    
    # Update is_scam based on final score
    is_scam = final_score >= 40 # Threshold

    if ml_result["is_scam"]:
        reasons.append(f"ML Model detected scam pattern ({ml_confidence}% confidence)")

    if not reasons:
         reasons.append("No suspicious patterns detected. Message appears safe.")

    return AnalysisResult(
        is_scam=is_scam,
        confidence=final_score,
        category=category,
        explanation=" | ".join(reasons),
    )


def analyze_sms(message: str) -> AnalysisResult:
    return _analyze_text(message)


def analyze_call(transcript: str) -> AnalysisResult:
    return _analyze_text(transcript)

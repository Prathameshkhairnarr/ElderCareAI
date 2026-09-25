"""
SMS Scam ML Classifier — Upgraded with Intent-Feature Ensemble and Feedback Loop Retraining.

Integrates:
1. TF-IDF text scoring (from trained model / fallback)
2. 5-dimensional Intent Feature Vector from Stage 3:
   - has_shortened_or_unknown_url (weight: 30)
   - asks_for_OTP_PIN_CVV_KYC (weight: 40)
   - urgency_language + call_to_action_combo (weight: 25)
   - impersonates_bank_govt_without_matching_DLT_header (weight: 35)
   - requests_callback_to_unlisted_number (weight: 20)
3. Ensemble blending: (TF-IDF score * 0.5) + (intent_score * 0.5)
4. Periodic/weekly retrain using correction_logs as negative-class (safe) ground truth.
"""

import os
import re
import json
import logging
from typing import List, Optional, Tuple, Dict, Any

logger = logging.getLogger("eldercare_ai")

_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_MODEL_PATH = os.path.join(_BASE_DIR, "sms_model.pkl")
_UCI_DATA_PATH = os.path.join(_BASE_DIR, "SMSSpamCollection")
_ASSETS_CARRIER_HEADERS = os.path.join(os.path.dirname(_BASE_DIR), "assets", "carrier_headers.json")

# ─────────────────────────────────────────────────────────────────
#  STAGE 1 & 2 DLT Whitelist & Informational Templates for Python
# ─────────────────────────────────────────────────────────────────
_DLT_PATTERN = re.compile(r'^[A-Z]{2}-[A-Z0-9]{3,8}$', re.IGNORECASE)

# Built-in carrier/bank suffixes if JSON asset not found
_DEFAULT_DLT_SUFFIXES = {
    "AIRTEL", "AIRTL", "ARTLNW", "JIO", "JIOOO", "JIOFBR",
    "BSNL", "BSNLM", "BSNLOB", "VODAFO", "VI", "VIIND", "IDEA", "IDEACL",
    "SBIINB", "SBIPSG", "SBMSMS", "SBIBNK", "SBIATM", "PNBSMS", "PNBALR",
    "BOBIMT", "BOISMS", "BOBBNK", "CANBNK", "CANARA", "UNIONB", "UBIBNK",
    "HDFCBK", "HDFCBN", "HDFCSM", "ICICIB", "ICICBA", "ICICBK",
    "AXISBK", "AXISBN", "KOTAKB", "KOTKBK", "YESBNK", "YESBK",
    "PAYTMB", "PAYTMS", "PAYTM", "PHONEPE", "PHNPE", "GPAY", "GOOGLP",
    "UIDAI", "AADHAR", "IRCTC", "EPFOHO", "EPFO", "RBI", "INCOMETX"
}

_DEFAULT_INFO_PATTERNS = [
    re.compile(r'you (missed|had|received) a call from \+?91?\d{7,10}', re.I),
    re.compile(r'missed call.{0,20}\+?91?\d{7,10}', re.I),
    re.compile(r'your (data|talktime|main|account) balance is', re.I),
    re.compile(r'recharge (of rs|successful|done|for|now)', re.I),
    re.compile(r'last recharge of rs', re.I),
    re.compile(r'your (plan|pack|validity) (expires?|is valid till|will end)', re.I),
    re.compile(r'your (prepaid|postpaid) number', re.I),
    re.compile(r'your sim.{0,15}(activated|deactivated|ported)', re.I),
    re.compile(r'welcome to (airtel|jio|vi|bsnl|vodafone)', re.I),
    re.compile(r'(rs|inr|₹)\s*[\d,.]+\s*(has been |was )?(credited|debited)', re.I),
    re.compile(r'your (bill|invoice) (for|of|amount) (rs|inr|₹)', re.I),
    re.compile(r'your order.{0,30}(delivered|shipped|dispatched|out for delivery)', re.I),
    re.compile(r'otp (is|for|:)\s*\d{4,8}', re.I),
]


def load_dlt_registry() -> Tuple[set, list]:
    """Load DLT suffixes and informational templates from carrier_headers.json."""
    suffixes = set(_DEFAULT_DLT_SUFFIXES)
    templates = list(_DEFAULT_INFO_PATTERNS)

    if os.path.exists(_ASSETS_CARRIER_HEADERS):
        try:
            with open(_ASSETS_CARRIER_HEADERS, "r", encoding="utf-8") as f:
                data = json.load(f)
            for k, val in data.items():
                if k.startswith("_"):
                    continue
                if k == "informational_templates" and isinstance(val, list):
                    for pat in val:
                        try:
                            templates.append(re.compile(pat, re.I))
                        except Exception:
                            pass
                elif isinstance(val, list):
                    for item in val:
                        if isinstance(item, str):
                            suffixes.add(item.upper())
            logger.info(f"Loaded {len(suffixes)} DLT suffixes from {_ASSETS_CARRIER_HEADERS}")
        except Exception as e:
            logger.warning(f"Failed to load carrier_headers.json: {e}")

    return suffixes, templates


_DLT_SUFFIXES, _INFO_TEMPLATES = load_dlt_registry()


def is_dlt_registered_sender(sender: Optional[str]) -> bool:
    """Check if sender matches known DLT carrier/bank/utility naming format."""
    if not sender:
        return False
    su = sender.strip().upper()
    for s in _DLT_SUFFIXES:
        if su == s or su.endswith(f"-{s}") or s in su:
            return True
    if _DLT_PATTERN.match(su):
        parts = su.split("-")
        if len(parts) == 2 and (parts[1] in _DLT_SUFFIXES or any(parts[1].startswith(s[:3]) for s in _DLT_SUFFIXES if len(s) >= 3)):
            return True
    return False


def matches_informational_template(text: str) -> bool:
    """Check if message matches legitimate non-scam telecom/utility patterns."""
    text_lower = text.lower()
    return any(rx.search(text_lower) for rx in _INFO_TEMPLATES)


# ─────────────────────────────────────────────────────────────────
#  STAGE 3: INTENT FEATURE EXTRACTION (5 Intent Signals)
# ─────────────────────────────────────────────────────────────────

_SHORTENER_DOMAINS = {
    "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "buff.ly",
    "is.gd", "cutt.ly", "rb.gy", "shorturl.at", "tiny.cc", "v.gd", "tr.im"
}

_SUSPICIOUS_TLDS = {
    ".xyz", ".top", ".club", ".work", ".click", ".buzz", ".guru",
    ".live", ".app", ".link", ".site", ".online", ".tk", ".ml", ".ga", ".cf", ".gq"
}

_CREDENTIAL_WORDS = [
    "otp", "pin", "cvv", "password", "passcode", "kyc", "netbanking",
    "card number", "expiry date", "secret code", "pan card", "aadhaar number"
]

_URGENCY_WORDS = [
    "urgent", "immediately", "act now", "action required", "expiring", "expired",
    "suspended", "blocked", "disconnected", "last chance", "within 24 hours",
    "within 12 hours", "today only", "turant", "jaldi", "abhi karein", "band ho jayega"
]

_ACTION_WORDS = [
    "click", "tap", "call", "dial", "visit", "link", "download", "pay", "login",
    "verify", "update", "reply", "contact"
]

_BANK_GOVT_NAMES = [
    "sbi", "hdfc", "icici", "axis", "punjab national bank", "pnb", "bank of baroda",
    "income tax", "it dept", "gst", "uidai", "aadhaar", "electricity board", "power corp",
    "bsnl", "airtel", "jio", "vodafone", "paytm", "phonepe", "speed post"
]

_URL_REGEX = re.compile(r'https?://[^\s<>"]+|www\.[^\s<>"]+|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}/[^\s<>"]*', re.I)
_PHONE_REGEX = re.compile(r'(?:call|dial|whatsapp|contact|reach).{0,15}(\+?91[\-\s]?)?[6-9]\d{9}', re.I)


def extract_intent_features(text: str, sender: Optional[str] = None) -> List[float]:
    """
    Extract the 5 Stage 3 intent features as a normalized float vector [0.0..1.0]:
    1. has_shortened_or_unknown_url
    2. asks_for_OTP_PIN_CVV_KYC
    3. urgency_language + call_to_action_combo (BOTH must be present)
    4. impersonates_bank_govt_without_matching_DLT_header
    5. requests_callback_to_unlisted_number
    """
    text_lower = text.lower()
    urls = _URL_REGEX.findall(text)

    # Feature 1: Shortened or unknown / suspicious URL
    f1 = 0.0
    for u in urls:
        u_lower = u.lower()
        if any(short in u_lower for short in _SHORTENER_DOMAINS):
            f1 = 1.0
            break
        if any(tld in u_lower for tld in _SUSPICIOUS_TLDS):
            f1 = 1.0
            break
        if re.search(r'[a-z]+\d+[a-z]+', u_lower) or u_lower.count('-') >= 2 or u_lower.count('/') > 4:
            f1 = 1.0
            break
    if not f1 and urls:
        # Unknown link that is not a recognized safe domain
        known_safe = ["airtel.in", "jio.com", "sbi.co.in", "hdfcbank.com", "icicibank.com", "amazon.in", "flipkart.com"]
        if not any(k in urls[0].lower() for k in known_safe):
            f1 = 0.8

    # Feature 2: Asks for OTP / PIN / CVV / KYC credentials
    f2 = 0.0
    has_cred_word = any(cw in text_lower for cw in _CREDENTIAL_WORDS)
    has_ask_verb = any(v in text_lower for v in ["share", "send", "enter", "update", "verify", "provide", "submit", "fill", "click"])
    if has_cred_word and has_ask_verb:
        f2 = 1.0
    elif has_cred_word and (urls or "http" in text_lower):
        f2 = 0.9
    elif has_cred_word:
        f2 = 0.5

    # Feature 3: Urgency language + Call-to-action combo (only counts if BOTH present)
    has_urgency = any(uw in text_lower for uw in _URGENCY_WORDS)
    has_action = any(aw in text_lower for aw in _ACTION_WORDS)
    f3 = 1.0 if (has_urgency and has_action) else 0.0

    # Feature 4: Impersonates bank / govt / utility without matching DLT header
    f4 = 0.0
    claims_bank_or_govt = any(b in text_lower for b in _BANK_GOVT_NAMES)
    is_dlt = is_dlt_registered_sender(sender)
    if claims_bank_or_govt and not is_dlt:
        f4 = 1.0
    elif claims_bank_or_govt and is_dlt:
        f4 = 0.0  # Legitimate DLT entity

    # Feature 5: Requests callback to unlisted / random mobile number
    f5 = 0.0
    if _PHONE_REGEX.search(text_lower):
        f5 = 1.0
    elif re.search(r'\b[6-9]\d{9}\b', text_lower) and any(w in text_lower for w in ["call", "contact", "whatsapp"]):
        f5 = 0.8

    return [f1, f2, f3, f4, f5]


def compute_intent_score(features: List[float]) -> int:
    """
    Weighted sum of 5 intent features:
    - f1 (shortened/unknown url): weight 30
    - f2 (asks credentials): weight 40
    - f3 (urgency + action combo): weight 25
    - f4 (impersonation no DLT): weight 35
    - f5 (callback unlisted): weight 20
    Clamped to 0..100.
    """
    w = [30.0, 40.0, 25.0, 35.0, 20.0]
    total = sum(f * weight for f, weight in zip(features, w))
    return int(max(0.0, min(100.0, total)))


# ─────────────────────────────────────────────────────────────────
#  SCAM CLASSIFIER (Ensemble: TF-IDF + Intent Vector)
# ─────────────────────────────────────────────────────────────────

class ScamClassifier:
    def __init__(self):
        self.model = None
        self._using_trained = False
        self._model_type = "fallback"
        self._load_model()

    def _load_model(self):
        """Try to load trained model from disk, fall back to small in-memory model."""
        if os.path.exists(_MODEL_PATH):
            try:
                import joblib
                self.model = joblib.load(_MODEL_PATH)
                self._using_trained = True
                self._model_type = "trained"
                logger.info(f"ScamClassifier loaded model from {_MODEL_PATH}")
                return
            except Exception as e:
                logger.warning(f"Failed to load {_MODEL_PATH}: {e}. Building fallback model.")

        self._train_fallback()

    def _train_fallback(self):
        """Train a fallback TF-IDF model."""
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.linear_model import LogisticRegression
        from sklearn.pipeline import make_pipeline

        self.model = make_pipeline(
            TfidfVectorizer(ngram_range=(1, 2), max_features=1000),
            LogisticRegression(class_weight="balanced", random_state=42)
        )

        X_train = [
            # Scam samples
            "Your bank account is locked due to suspicious activity. Click here.",
            "Click here to claim your lottery prize now!",
            "Urgent: Update your KYC immediately to avoid account blocking.",
            "Verify your identity immediately or face legal action.",
            "Congratulations! You won Rs 50000 cash prize. Click link to claim.",
            "IRS / IT Dept detected tax fraud. Call us back immediately at 9876543210.",
            "Your SIM card will be deactivated within 24 hours. Call customer care 9823456789.",
            "Electricity bill unpaid. Power disconnected tonight at 9 PM. Pay immediately at bit.ly/pay-bill.",
            "Part-time job: Earn Rs 5000 daily from home. WhatsApp now at 9988776655.",
            "Dear customer your SBI account is suspended. Update PAN immediately http://sbi-kyc.top.",
            # Safe samples
            "Hey, are we still meeting for lunch today?",
            "Your appointment is confirmed for tomorrow at 2 PM.",
            "Happy birthday! Hope you have a wonderful year ahead.",
            "Can you pick up groceries on your way back home?",
            "Your OTP for login is 482910. Do not share it with anyone.",
            "Rs 500.00 debited from A/c XX1234 on 25-Sep-26. UPI ref 123456789.",
            "Your recharge of Rs 299 is successful. 1.5GB/day data valid for 28 days.",
            "You missed a call from +919876543210 on 25-Sep-26 11:30 AM.",
            "Your data balance is 1.2 GB, valid till midnight.",
            "Your package has been delivered to your doorstep. Thank you for shopping with us.",
        ]
        y_train = [1] * 10 + [0] * 10
        self.model.fit(X_train, y_train)
        self._using_trained = False
        self._model_type = "fallback"

    def predict(
        self,
        text: str,
        sender: Optional[str] = None,
        intent_features: Optional[List[float]] = None
    ) -> Dict[str, Any]:
        """
        Ensemble prediction blending TF-IDF text score and Stage 3 Intent score.
        Formula: blended_confidence = int(tfidf_score * 0.5 + intent_score * 0.5)
        """
        # 1. Stage 1 & 2 Fast Early Exit: Telecom / Bank DLT sender + informational template
        if sender and is_dlt_registered_sender(sender) and matches_informational_template(text):
            return {
                "is_scam": False,
                "confidence": 0,
                "tfidf_confidence": 0,
                "intent_confidence": 0,
                "intent_features": [0.0] * 5,
                "model_type": "dlt_early_exit",
                "early_exit": True,
            }

        # 2. Extract or use provided intent features
        if intent_features is None:
            features = extract_intent_features(text, sender)
        else:
            features = intent_features

        intent_score = compute_intent_score(features)

        # 3. TF-IDF Model prediction
        tfidf_score = 50
        try:
            proba = self.model.predict_proba([text])[0]
            if len(proba) > 1:
                tfidf_score = int(proba[1] * 100)
            else:
                pred = self.model.predict([text])[0]
                tfidf_score = 90 if pred == 1 else 10
        except Exception as e:
            logger.warning(f"Model prediction error: {e}. Using neutral TF-IDF score.")
            tfidf_score = 50

        # 4. Ensemble Blend: (TF-IDF * 0.5) + (Intent * 0.5)
        blended_score = int((tfidf_score * 0.5) + (intent_score * 0.5))
        blended_score = max(0, min(100, blended_score))

        return {
            "is_scam": bool(blended_score >= 50),
            "confidence": blended_score,
            "tfidf_confidence": tfidf_score,
            "intent_confidence": intent_score,
            "intent_features": features,
            "model_type": self._model_type,
            "early_exit": False,
        }

    def retrain_with_corrections(self, db_session) -> Dict[str, Any]:
        """
        Stage 5 Retraining:
        Uses user-reported false positives from correction_logs as negative-class (safe) ground truth.
        Trains an XGBoost pipeline (with graceful fallback to GradientBoosting / LogisticRegression),
        saves to sms_model.pkl, and reloads in memory.
        """
        import pandas as pd
        import joblib
        from database.models import CorrectionLog

        logger.info("Starting model retraining with feedback loop correction logs...")

        # 1. Load base training data (SMSSpamCollection or default corpus)
        texts = []
        labels = []

        if os.path.exists(_UCI_DATA_PATH):
            try:
                df_uci = pd.read_csv(
                    _UCI_DATA_PATH,
                    sep="\t",
                    header=None,
                    names=["label", "message"],
                    encoding="latin-1"
                ).dropna()
                texts.extend(df_uci["message"].astype(str).tolist())
                labels.extend([1 if l == "spam" else 0 for l in df_uci["label"]])
                logger.info(f"Loaded {len(df_uci)} samples from SMSSpamCollection")
            except Exception as e:
                logger.warning(f"Could not load SMSSpamCollection: {e}")

        # 2. Fetch correction logs from DB (false positives mark messages as safe: label 0)
        correction_count = 0
        try:
            corrections = (
                db_session.query(CorrectionLog)
                .filter(
                    CorrectionLog.false_positive == True,
                    CorrectionLog.message_content.isnot(None),
                )
                .all()
            )
            for entry in corrections:
                if entry.message_content and len(entry.message_content.strip()) > 5:
                    texts.append(entry.message_content.strip())
                    labels.append(0)  # User ground truth: NOT A SCAM
                    correction_count += 1
            logger.info(f"Incorporated {correction_count} ground-truth false-positive corrections from users.")
        except Exception as e:
            logger.error(f"Error reading CorrectionLog: {e}")

        if not texts:
            logger.warning("No data available to retrain.")
            return {"status": "skipped", "reason": "No data"}

        # 3. Train model (XGBoost classifier with TF-IDF)
        from sklearn.feature_extraction.text import TfidfVectorizer
        from sklearn.pipeline import make_pipeline

        vectorizer = TfidfVectorizer(
            max_features=12000,
            ngram_range=(1, 2),
            min_df=2,
            max_df=0.95,
            strip_accents="unicode",
            lowercase=True,
        )

        try:
            import xgboost as xgb
            clf = xgb.XGBClassifier(
                n_estimators=100,
                max_depth=5,
                learning_rate=0.1,
                eval_metric="logloss",
                random_state=42,
            )
            model_type_trained = "xgboost"
        except Exception:
            from sklearn.linear_model import LogisticRegression
            clf = LogisticRegression(C=5.0, max_iter=1000, class_weight="balanced", random_state=42)
            model_type_trained = "logistic_regression"

        pipeline = make_pipeline(vectorizer, clf)
        pipeline.fit(texts, labels)

        # 4. Save and reload
        joblib.dump(pipeline, _MODEL_PATH)
        self.model = pipeline
        self._using_trained = True
        self._model_type = model_type_trained

        logger.info(f"Model retrained successfully ({model_type_trained}). Saved to {_MODEL_PATH}")
        return {
            "status": "success",
            "model_type": model_type_trained,
            "total_samples": len(texts),
            "corrections_used": correction_count,
        }


# Singleton instance
classifier = ScamClassifier()

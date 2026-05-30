"""
AI-Powered SMS Scam Analyzer using Gemini API.

This is the deep analysis layer — called only for SUSPICIOUS messages
that the rule-based engine couldn't confidently classify.

Uses the comprehensive Indian DLT-aware prompt for accurate verdicts.
"""
import os
import json
import logging
import httpx
from dataclasses import dataclass

logger = logging.getLogger("eldercare")

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = "gemini-2.0-flash"
GEMINI_ENDPOINT = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"

# The comprehensive Indian SMS scam detection prompt
SMS_ANALYSIS_PROMPT = """You are an expert Indian SMS scam detector with deep knowledge of India's DLT (Distributed Ledger Technology) sender ID system regulated by TRAI.

## YOUR TASK
Analyze the given SMS and return a JSON verdict.

## INDIAN DLT SENDER WHITELIST (These are ALWAYS safe — never flag as scam)

### Telecom Operators
AIRTEL, JM-AIRTEL, VM-AIRTEL, BM-AIRTEL, DM-AIRTEL, JIO, JM-JIO, VM-JIO, BM-JIO, BSNL, JM-BSNL, VM-BSNL, VODAFONE, VI, JM-VI, VM-VI, IDEA, TATADOCOMO, TATA, MTS, TELENOR

### Banks (Public)
SBIINB, SBIPSG, SBMSMS, PNBSMS, BOBIMT, BOISMS, CANBNK, UNIONB, CENTBK, INDBNK, ALBANK, SYNBNK, UCOBNK, OBCSMS, IOBSMS, ANDBSM, VIJBNK, DENABN, CORPBK, MAHABK

### Banks (Private)
HDFCBK, HDFCBN, ICICIB, AXISBK, AXISBN, KOTAKB, YESBNK, INDUSB, FEDBK, KVBSMS, DCBBNK, RBLBNK, IDBIBK, BANDHN, AUBANK, SURYOD, CSBBNK

### Payment & Fintech
PAYTMB, PAYTMS, PAYTM, PHONEPE, FREECHARGE, MOBIKWIK, AMAZON, FLIPKRT, GPAY, CRED, SLICE, BHARPE, LAZYPAY, SIMPL, JUPITER, FAMPAY, NIYO

### Government & Utilities
UIDAI, IRCTC, EPFOHO, NSDL, CDSL, SEBI, RBI, INCOMETX, GSTNOF, COWIN, NHMSMS, AYUSHM, BESCOM, MSEDCL, TPDDL, CESC, WBSEDCL, MAHAGS, IOCL, HPCL, BPCL, ATPGAS

### E-commerce & Delivery
AMAZON, FLIPKRT, MYNTRA, MEESHO, SNAPDL, DELHVR, EKART, XPRESB, ZOMATO, SWIGGY, BLINKT, ZEPTO, DUNZO, BIGBSK

## CONTEXT-BASED SAFE PATTERNS (Always SAFE regardless of content)
1. OTP Messages: Contains "OTP", "one time password", "verification code" with 4-8 digit code → ALWAYS SAFE
2. Transaction Alerts: "debited", "credited", "INR", "Rs.", "₹" + amount from bank sender → ALWAYS SAFE
3. Delivery Updates: "out for delivery", "delivered", "shipment", "order #", "AWB" with no suspicious link → ALWAYS SAFE
4. Recharge Confirmations: "recharge successful", "validity", "GB data" → ALWAYS SAFE
5. Bill Reminders from DLT sender: "bill generated", "due date", "pay before" → ALWAYS SAFE

## SCAM SIGNALS (Red flags)
HIGH RISK: Sender is 10-digit mobile number, "KYC expire/block" + unknown link, "Won prize/lottery" + link, Impersonates RBI/Police, "Account blocked" from non-bank sender, Link shorteners (bit.ly, tinyurl, cutt.ly, rb.gy, t.ly)
MEDIUM RISK: Urgency words + link, "Click here" + unknown domain, "Dear Customer" (no name) + threat
INDIA-SPECIFIC SCAM PHRASES: "bijli kategi aaj", "cylinder band", "SIM band hoga", "PM Kisan" from mobile number, "part time job", "ghar baithe kamao", "loan approved" from unknown sender

## DECISION LOGIC
STEP 1: Is sender a known DLT ID? → SAFE
STEP 2: Is sender a 10-digit mobile number? → HIGH suspicion
STEP 3: Does content match OTP/Transaction/Delivery pattern? → SAFE
STEP 4: Count scam signals → calculate risk
STEP 5: Apply verdict

## OUTPUT FORMAT (strict JSON only, no extra text)
{"verdict": "SAFE" | "SUSPICIOUS" | "SCAM", "confidence": 0-100, "reason": "1 line explanation in simple English", "triggered_signals": ["list", "of", "what", "flagged"], "safe_signals": ["list", "of", "what", "cleared", "it"], "sender_type": "DLT_TRUSTED" | "MOBILE_NUMBER" | "UNKNOWN_DLT" | "SHORTCODE"}

## IMPORTANT RULES
- If confidence < 75, verdict must be SUSPICIOUS not SCAM
- DLT sender = NEVER SCAM (max SUSPICIOUS if content extremely weird)
- OTP from any sender = SAFE
- When in doubt → SUSPICIOUS, never false SCAM
- Indian context: "Aadhaar", "UPI", "BHIM", "Jan Dhan" are normal words, not scam signals alone"""


@dataclass
class AiSmsVerdict:
    verdict: str  # SAFE, SUSPICIOUS, SCAM
    confidence: int
    reason: str
    triggered_signals: list
    safe_signals: list
    sender_type: str


def analyze_with_ai(message: str, sender: str = "") -> AiSmsVerdict | None:
    """
    Analyze an SMS using Gemini AI with the comprehensive Indian scam detection prompt.
    Returns None if AI is unavailable or fails.
    """
    if not GEMINI_API_KEY:
        logger.warning("[AI-SMS] Gemini API key not configured, skipping AI analysis")
        return None

    user_message = f"Sender: {sender}\nMessage: {message}"

    request_body = {
        "systemInstruction": {
            "parts": [{"text": SMS_ANALYSIS_PROMPT}]
        },
        "contents": [
            {"role": "user", "parts": [{"text": user_message}]}
        ],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 300,
            "responseMimeType": "application/json",
        },
    }

    try:
        response = httpx.post(
            GEMINI_ENDPOINT,
            json=request_body,
            headers={"Content-Type": "application/json"},
            timeout=8.0,
        )

        if response.status_code != 200:
            logger.warning(f"[AI-SMS] Gemini HTTP {response.status_code}")
            return None

        data = response.json()
        candidates = data.get("candidates", [])
        if not candidates:
            return None

        content = candidates[0].get("content", {})
        parts = content.get("parts", [])
        if not parts:
            return None

        raw_text = parts[0].get("text", "").strip()

        # Parse JSON response
        result = json.loads(raw_text)

        return AiSmsVerdict(
            verdict=result.get("verdict", "SUSPICIOUS"),
            confidence=result.get("confidence", 50),
            reason=result.get("reason", "AI analysis completed"),
            triggered_signals=result.get("triggered_signals", []),
            safe_signals=result.get("safe_signals", []),
            sender_type=result.get("sender_type", "UNKNOWN_DLT"),
        )

    except json.JSONDecodeError as e:
        logger.warning(f"[AI-SMS] Failed to parse AI response: {e}")
        return None
    except Exception as e:
        logger.warning(f"[AI-SMS] AI analysis error: {e}")
        return None

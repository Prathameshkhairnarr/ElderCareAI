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
    "final notice", "right away", "don't delay", "asap", "within 24 hours",
    "within 12 hours", "today only", "ending soon", "immediate action", "urgent request",
    "action required", "do it now", "last warning", "critical", "mandatory",
    "required immediately", "without fail", "time sensitive", "fast", "quick",
    "soon", "before it expires", "expiring today", "will be blocked", "will be suspended",
    "deactivation", "deactivate soon", "account closed", "closure warning", "immediate attention",
    "action needed", "respond now", "must reply", "last day", "closing soon",
    "turant", "jaldi", "abhi karein", "aakhri mauka", "khatam ho raha",
    "aaj hi", "block ho jayega", "band ho jayega", "warn kiya jata hai", "antim din",
    "samay seema", "jald se jald", "tatkal", "urgnt", "imediately",
    "expir", "suspendd", "hurrei", "deadlin", "act fast",
    "quick reply", "reply asap", "urgent update", "critical update", "security update required",
    "immediate update", "mandatory update", "compulsory", "compulsory action", "must act",
    "failure to do so", "if not done", "action pending", "pending action", "resolve now",
    "fix now", "issue detected", "attention required", "please act", "kindly act",
    "urgent notice", "final reminder", "last reminder", "reminder 1", "reminder 2",
    "reminder 3", "account deletion", "profile suspension", "login immediately", "verify now",
    "verify instantly", "immediate verification", "instant verification", "alert", "security alert",
}

FINANCIAL_WORDS = {
    "bank", "account", "transfer", "upi", "otp",
    "pin", "credit card", "debit card", "loan", "emi",
    "payment", "refund", "kyc", "aadhar", "pan card",
    "blocked", "verify", "transaction", "wallet", "paytm",
    "phonepe", "gpay", "bhim", "rupay", "visa",
    "mastercard", "net banking", "internet banking", "cvv", "branch",
    "manager", "cash", "funds", "deposit", "withdrawal",
    "balance", "cheque", "dd", "overdraft", "savings",
    "current account", "fixed deposit", "fd", "rd", "mutual fund",
    "stocks", "trading", "crypto", "bitcoin", "investment",
    "returns", "profit", "loss", "tax", "income tax",
    "tds", "gst", "billing", "invoice", "receipt",
    "credt", "debt", "cr", "dr", "credited",
    "debited", "amount", "rs", "inr", "rupees",
    "lakh", "crore", "thousand", "hundred", "paisa",
    "paise", "paise bhejo", "paise transfer", "bank khata", "khata",
    "bima", "insurance", "premium", "policy", "claim",
    "settlement", "refund processed", "cashback received", "reward points", "loyalty points",
    "redeem points", "encash", "vpa", "upi id", "upi pin",
    "mpin", "tpin", "beneficiary", "payee", "remittance",
    "wire transfer", "neft", "rtgs", "imps", "swift",
    "forex", "loan approved", "pre-approved loan", "personal loan", "home loan",
    "car loan", "business loan", "instant loan", "micro loan", "payday loan",
    "cash advance", "salary advance", "credit limit", "limit increase", "card upgrade",
    "lifetime free", "no annual fee", "zero balance", "minimum balance", "penalty fee",
}

IMPERSONATION_WORDS = {
    "rbi", "reserve bank", "sbi", "government", "police",
    "court", "income tax", "customs", "cbi", "ministry",
    "official", "govt", "department", "authority", "officer",
    "inspector", "magistrate", "judge", "lawyer", "advocate",
    "supreme court", "high court", "cyber cell", "cyber police", "crime branch",
    "cid", "ed", "enforcement directorate", "nia", "ncb",
    "raw", "trai", "irda", "sebi", "epfo",
    "uidai", "aadhar center", "pan office", "passport office", "rto",
    "traffic police", "challan department", "municipality", "bmc", "ndmc",
    "mcd", "collector", "dm", "sp", "dsp",
    "acp", "dcp", "commissioner", "dg", "ig",
    "sho", "constable", "head constable", "sub inspector", "si",
    "asi", "army", "navy", "air force", "military",
    "paramilitary", "crpf", "bsf", "cisf", "itbp",
    "niti aayog", "pmo", "cmo", "minister", "mp",
    "mla", "sarpanch", "mayor", "governor", "president",
    "indian post", "bharatiya dak", "irctc", "indian railways", "nhai",
    "fastag authority", "telecom ministry", "dot", "department of telecommunications", "npci",
    "national payments", "sarkari", "karyalay", "adhikari", "pradhikaran",
    "vibhaag", "mantralaya", "nyayalaya", "police station", "thana",
    "chowki", "control room", "helpline", "customer care", "support team",
    "resolution center", "grievance cell", "ombudsman", "nodal officer", "appellate authority",
    "vigilance", "anti-corruption", "lokpal", "lokayukta", "cag",
    "election commission", "eci",
}

THREAT_WORDS = {
    "arrest", "jail", "legal action", "case filed", "warrant",
    "fine", "penalty", "blacklisted", "terminate", "seize",
    "freeze", "suspend", "cancel", "account freeze", "sim blocked",
    "fir", "complaint", "summon", "subpoena", "court notice",
    "legal notice", "lawsuit", "sue", "prosecute", "imprisonment",
    "detention", "custody", "interrogation", "investigation", "raid",
    "search warrant", "confiscate", "attach property", "auction", "defaulter",
    "absconder", "fugitive", "criminal", "fraudulent", "illegal",
    "unlawful", "banned", "restricted", "prohibited", "violation",
    "breach", "non-compliance", "defamation", "harassment", "extortion",
    "blackmail", "threat", "danger", "risk", "severe consequences",
    "strict action", "punitive action", "disciplinary action", "police complaint", "cyber complaint",
    "report filed", "dossier", "chargesheet", "conviction", "girgtaar",
    "girftari", "jail hogi", "fine lagega", "jurmana", "karwai",
    "kanooni karwai", "mukadama", "notice bheja", "court jana padega", "police aayegi",
    "ghar pe police", "raid padegi", "khatra", "saza", "dand",
    "rukawat", "bandi", "zapt", "kroki", "kurki",
    "shikayat", "darj", "khilaf", "virodh", "pratibandh",
    "nishedh", "dhamki", "warning issued", "final warning issued", "account deletion",
    "permanent ban", "lifetime ban", "service termination", "contract cancellation", "agreement failure",
    "breach of trust", "fraud detected", "suspicious activity detected", "money laundering", "terror financing",
    "illegal transaction", "unauthorized access", "hacked",
}

REWARD_WORDS = {
    "congratulations", "you won", "prize", "reward", "gift",
    "cashback", "rupees", "lakh", "crore", "won",
    "winner", "lottery", "jackpot", "lucky draw", "sweepstakes",
    "giveaway", "free", "bonus", "surprise", "special offer",
    "exclusive offer", "mega offer", "bumper prize", "grand prize", "first prize",
    "cash prize", "voucher", "coupon", "discount", "promo code",
    "recharge free", "data free", "smartphone won", "iphone won", "car won",
    "bike won", "gold won", "trip to", "holiday package", "vacation",
    "all expenses paid", "sponsored", "selected", "shortlisted", "chosen",
    "lucky winner", "random selection", "computer selection", "mobile number won", "sim card won",
    "email won", "claim now", "claim prize", "redeem now", "redeem prize",
    "collect prize", "grab offer", "avail offer", "limited offer", "festive offer",
    "diwali offer", "new year offer", "anniversary offer", "birthday offer", "celebration",
    "badhai", "badhai ho", "aap jeet chuke hai", "aap winner hai", "inaam",
    "puraskar", "muft", "free gift", "tohfa", "shandaar",
    "dhamaka", "offer", "discount", "chhoot", "cashback mila",
    "paise mile", "kismat", "bhagya", "lucky", "1st prize",
    "2nd prize", "3rd prize", "consolation prize", "mega draw", "lucky number",
    "lucky spin", "wheel of fortune", "scratch card", "scratch and win", "play and win",
    "bet and win", "rummy win", "casino win", "poker win", "fantasy win",
    "dream11 win", "mpl win", "my11circle win", "bcci offer", "ipl offer",
    "t20 offer", "world cup offer",
}

JOB_WORDS = {
    "work from home", "earn", "daily income", "part-time job", "registration fee",
    "pay to start job", "wfh", "full time job", "freelance", "online earning",
    "earn money online", "make money online", "data entry", "copy paste", "typing job",
    "sms sending job", "email reading job", "ad clicking job", "survey job", "review job",
    "youtube like job", "subscribe job", "instagram like job", "follow job", "rating job",
    "amazon review job", "flipkart review job", "google review job", "app installation job", "game playing job",
    "refer and earn", "network marketing", "mlm", "pyramid scheme", "chain system",
    "downline", "upline", "direct selling", "investment plan", "roi plan",
    "doubling money", "guaranteed income", "fixed income", "passive income", "financial freedom",
    "be your own boss", "no investment", "zero investment", "low investment", "high return",
    "quick money", "easy money", "get rich quick", "lakhpati", "crorepati",
    "naukri", "rozgar", "kaam", "ghar baithe", "kamai",
    "paise kamaye", "din ka", "mahine ka", "salary", "wages",
    "stipend", "bonus", "commission", "incentive", "target",
    "target completion", "task completion", "assignment", "project", "recruitment",
    "hiring", "urgent hiring", "vacancy", "openings", "interview",
    "selection", "offer letter", "joining letter", "appointment letter", "training fee",
    "security deposit", "equipment fee", "laptop fee", "uniform fee", "id card fee",
    "processing fee", "agreement fee", "bond fee", "document verification fee", "hr round",
    "manager round", "job guarantee", "100% placement",
}

DELIVERY_WORDS = {
    "parcel", "shipment", "courier", "delivery failed", "customs charge",
    "pay delivery fee", "india post", "speed post", "postal service", "dhl",
    "fedex", "blue dart", "dtpc", "safexpress", "ecom express",
    "delhivery", "shadowfax", "xpressbees", "amazon delivery", "flipkart delivery",
    "myntra delivery", "meesho delivery", "swiggy delivery", "zomato delivery", "blinkit delivery",
    "zepto delivery", "dunzo delivery", "instamart delivery", "bigbasket delivery", "jio mart delivery",
    "package", "dispatch", "dispatched", "in transit", "out for delivery",
    "delivered", "undelivered", "returned", "address not found", "wrong address",
    "update address", "confirm address", "reschedule", "redelivery", "pick up",
    "drop off", "tracking", "track order", "tracking number", "awb",
    "waybill", "customs clearance", "duty fee", "import tax", "clearance fee",
    "holding fee", "storage fee", "demurrage", "penalty fee", "insurance fee",
    "damage fee", "lost package", "damaged package", "delayed package", "held at customs",
    "seized by customs", "pending payment", "payment required for delivery", "pay to receive", "postman",
    "delivery boy", "delivery executive", "delivery partner", "rider", "samaan",
    "bheja", "parsal", "daak", "chitthi", "patra",
    "pata", "pata galat", "pata update", "wapas", "ruk gaya",
    "roka gaya", "shulk", "tax", "fine", "delivery missed",
    "missed delivery", "door locked", "consignee unavailable", "receiver unavaliable",
}

ELECTRICITY_WORDS = {
    "electricity bill", "power disconnected", "bijli cut", "pay bill immediately", "mseb",
    "uppcl", "bescom", "cesc", "tssprdcl", "tsnpdcl",
    "apsprdcl", "apepdcl", "hbvn", "dhbvn", "jbvnl",
    "nbpdcl", "sbpdcl", "cspdcl", "gedcol", "kseb",
    "tangedco", "wbsedcl", "power supply", "power cut", "load shedding",
    "blackout", "electricity board", "electricity department", "electricity officer", "lineman",
    "meter reader", "meter", "smart meter", "unit", "reading",
    "bill due", "due date", "overdue", "late fee", "penalty",
    "disconnection", "disconnection notice", "final notice electricity", "power suspension", "restore power",
    "reconnect power", "reconnection fee", "update bill", "previous month bill", "current month bill",
    "arrears", "outstanding amount", "pay online", "pay via link", "download bill",
    "view bill", "bill receipt", "payment confirmation", "bijli vibhag", "bijli board",
    "bijli meter", "bijli bill", "light bill", "current bill", "line kat",
    "line cut", "connection cut", "connection kat", "bijli gul", "bhuqtan",
    "jama kare", "shulk", "jurmana", "officer se baat kare", "call officer",
    "contact officer", "helpline number", "customer care number", "bill desk", "payment portal",
    "power grid", "state electricity", "national grid", "solar scheme", "free electricity",
    "electricity subsidy", "200 units free", "zero bill", "waiver", "maaf",
    "bill maaf", "meter checking", "vigilance checking", "electricity theft", "fine for theft",
}

GAS_WORDS = {
    "gas subsidy", "lpg update", "gas kyc", "connection suspended", "indane",
    "hp gas", "bharat gas", "reliance gas", "adani gas", "mahanagar gas",
    "igl", "mgl", "png", "cng", "lpg",
    "cylinder", "gas booking", "book cylinder", "refill", "refill booking",
    "delivery agent", "gas agency", "distributor", "gas officer", "gas connection",
    "new connection", "ujjwala", "ujjwala yojana", "subsidy amount", "subsidy credited",
    "subsidy pending", "subsidy stopped", "link aadhar to gas", "gas aadhar link", "biometric update",
    "ekyc for gas", "inspection", "safety inspection", "inspection fee", "hose pipe change",
    "regulator change", "stove checking", "leakage", "blast", "insurance for gas",
    "gas insurance", "mandatory checking", "compulsory inspection", "gas bill", "piped gas",
    "meter reading", "gas meter", "disconnect gas", "stop gas", "gas line",
    "gas vibhag", "gas agency", "cylinder book", "booking number", "subsidy ka paisa",
    "khate me paise", "kyc pending", "aadhar jode", "connection band", "connection cancel",
    "home delivery", "urgent booking", "tatkal booking", "gas leakage", "emergency service",
    "customer care gas", "helpline gas", "toll free", "complaint gas", "resolve gas issue",
    "address update", "transfer connection", "surrender connection", "deposit refund", "security amount",
    "cylinder limit", "quota over", "extra cylinder", "commercial cylinder", "domestic cylinder",
    "14.2 kg", "19 kg",
}

SIM_WORDS = {
    "sim blocked", "sim suspend", "verify sim", "update kyc now", "jio",
    "airtel", "vi", "vodafone", "idea", "bsnl",
    "mtnl", "jiofi", "dongle", "router", "broadband",
    "fiber", "fiber broadband", "telecom", "customer service", "network provider",
    "sim card", "e-sim", "esim", "convert to esim", "upgrade sim",
    "4g to 5g", "sim upgrade", "free 5g", "5g trial", "port number",
    "mnp", "puk code", "sim locked", "unlock sim", "sim registry",
    "telecom verification", "aadhar sim link", "sim aadhar linking", "document missing", "re-verification",
    "document re-verify", "sim deactivation", "sim validity", "validity expired", "recharge now",
    "plan expired", "outgoing blocked", "incoming blocked", "data exhausted", "100% data used",
    "daily limit", "top up", "data loan", "talktime loan", "caller tune",
    "hello tune", "vas", "value added service", "roaming", "international roaming",
    "isd", "std", "sim band", "number block", "number band",
    "chalu kare", "recharge kare", "kyc update kare", "document jama kare", "5g me badle",
    "free data", "free calling", "unlimited plan", "special offer for you", "exclusive plan",
    "company officer", "tower installation", "jio tower", "airtel tower", "tower lagwaye",
    "tower rent", "advance rent", "tower agreement", "noc fee", "site inspection",
    "network issue", "signal problem", "call drop", "complaint resolution", "trai order",
    "trai rule", "dot order", "telecom guidelines", "maximum sim limit", "extra sim",
}

KYC_WORDS = {
    "kyc update", "verify account", "update details immediately", "aadhar", "pan",
    "voter id", "driving license", "passport", "ration card", "identity proof",
    "address proof", "dob proof", "biometric", "fingerprint", "iris scan",
    "face auth", "ekyc", "c-kyc", "video kyc", "v-kyc",
    "offline kyc", "paperless kyc", "kyc suspended", "kyc expired", "kyc rejected",
    "kyc failed", "kyc pending", "kyc mandatory", "kyc required", "complete kyc",
    "finish kyc", "upload document", "submit document", "document verification", "verify identity",
    "authenticate", "link aadhar", "link pan", "pan-aadhar link", "deadline",
    "last date", "fine for not linking", "penalty for kyc", "account freeze due to kyc", "block due to kyc",
    "unblock account", "reinstate account", "reactivate", "activation", "kyc center",
    "cummunity service center", "csc", "e-mitra", "maha e-seva", "agent",
    "kyc officer", "field visit", "home visit", "verification call", "verification sms",
    "confirmation code", "kyc otp", "kyc pin", "kyc link", "click to update",
    "update online", "self service", "kyc portal", "uidai portal", "income tax portal",
    "nsdl", "utiitsl", "kyc form", "fatca", "crs",
    "pep", "politically exposed person", "kyc compliance", "regulatory requirement", "rbi mandate",
    "sebi guideline", "aml", "anti money laundering", "kyc jama", "kyc kare",
    "document de", "pehchan patra", "praman patra", "nambhar link", "khata link",
    "bank me aadhar", "aadhar jorna", "aadhar updation", "name change", "dob change",
    "address change", "mobile number update", "email update", "profile update", "details mismatch",
    "error in kyc", "re-submit",
}

# Regex for finding numerical OTPs
OTP_PATTERN = re.compile(r'\b\d{4,8}\b')
OTP_WORDS = {"otp", "one time password", "do not share", "never share"}

LINK_PATTERN = re.compile(
    r"https?://[^\s]+|www\.[^\s]+|bit\.ly/[^\s]+|t\.co/[^\s]+|"
    r"[a-zA-Z0-9.-]+\.(tk|ml|ga|cf|gq|xyz|top|buzz|click|link|fun|icu|cam|cc|pw|ws)/[^\s]*",
    re.IGNORECASE,
)

SUSPICIOUS_DOMAINS = {".xyz", ".top", ".tk", ".click", "bit.ly", "tinyurl", "t.co"}
BRAND_MIMIC_PATTERN = re.compile(r'(sbi|hdfc|icici|axis|airtel|jio|paytm|phonepe|gpay)-?[a-z0-9]+\.(com|in|net|xyz|top)', re.IGNORECASE)

TRUSTED_WORDS = {
    "balance", "credited", "debited", "transaction alert",
    "recharge successful", "data balance",
}


# ── Core Analysis ─────────────────────────────────────

def _analyze_text(text: str, metadata: dict = None) -> AnalysisResult:
    """Shared analysis logic for both SMS and voice transcripts."""
    metadata = metadata or {}
    text_lower = text.lower()
    words = set(text_lower.split())

    # Replace newlines with spaces for easier phrase matching
    clean_text = " ".join(text_lower.split())

    links = LINK_PATTERN.findall(text)
    has_links = bool(links)

    # 1. STEP 1: HARD SAFE OVERRIDE
    has_otp_code = bool(OTP_PATTERN.search(clean_text))
    has_otp_words = any(w in clean_text for w in OTP_WORDS)
    
    if has_otp_code and has_otp_words and not has_links:
        return AnalysisResult(
            is_scam=False,
            confidence=0,
            category="OTP / Authentication",
            explanation="Standard OTP message with no malicious intent.",
        )

    # Dictionary Matching Helper
    def _get_hits(word_set):
        return {w for w in word_set if w in clean_text}

    urgency_hits = _get_hits(URGENCY_WORDS)
    financial_hits = _get_hits(FINANCIAL_WORDS)
    impersonation_hits = _get_hits(IMPERSONATION_WORDS)
    threat_hits = _get_hits(THREAT_WORDS)
    reward_hits = _get_hits(REWARD_WORDS)
    job_hits = _get_hits(JOB_WORDS)
    delivery_hits = _get_hits(DELIVERY_WORDS)
    electricity_hits = _get_hits(ELECTRICITY_WORDS)
    gas_hits = _get_hits(GAS_WORDS)
    sim_hits = _get_hits(SIM_WORDS)
    kyc_hits = _get_hits(KYC_WORDS)

    score = 0
    reasons = []

    # --- ADVANCED BEHAVIORAL CHECKS ---
    sender = metadata.get("sender", "")
    timestamp = metadata.get("timestamp")
    is_repeated = metadata.get("is_repeated", False)

    # 1. Sender Intelligence
    if sender:
        if re.match(r'^\+?[0-9]{10,12}$', sender):
            score += 20
            reasons.append("Sender appears to be a random mobile number (+20)")
        elif re.match(r'^[A-Z]{2}-[A-Z0-9]{5,6}$', sender) and not any(trusted in sender.lower() for trusted in ["hdfc", "sbi", "airtel", "jio", "paytm"]):
            score += 15
            reasons.append("Sender ID is unknown/unusual format (+15)")
        elif any(trusted in sender.lower() for trusted in ["hdfc", "sbi", "airtel", "jio", "paytm", "icici"]):
            score -= 40
            reasons.append("Trusted sender pattern (-40)")

    # 2. Frequency Detection
    if is_repeated:
        score += 30
        reasons.append("High frequency: similar message repeated (+30)")

    # 3. Personalization Check
    if "dear user" in clean_text or "dear customer" in clean_text:
        score += 10
        reasons.append("Generic greeting used (+10)")

    # 4. Language Pattern Detection
    all_caps_ratio = sum(1 for c in text if c.isupper()) / len(text) if len(text) > 0 else 0
    if all_caps_ratio > 0.4 or "!!!" in text:
        score += 15
        reasons.append("Unnatural language/ALL CAPS/punctuation (+15)")

    # 6. Action Intent Detection
    action_words = {"click", "verify", "update", "pay", "login", "download"}
    if any(aw in clean_text for aw in action_words):
        score += 25
        reasons.append("Action intended (click/verify/pay) (+25)")

    # 7. Emotional Manipulation Detection
    # 10. Multi-Language Detection
    manipulative_phrases = ["turant verify karo", "account band ho jayega", "paise jeete ho", "block ho jayega"]
    if any(mp in clean_text for mp in manipulative_phrases):
        score += 20
        reasons.append("Manipulative multi-language phrase detected (+20)")

    # 8. Time-based pattern
    if timestamp:
        try:
            from dateutil.parser import parse
            if isinstance(timestamp, str):
                timestamp = parse(timestamp)
            hour = timestamp.hour
            if hour >= 23 or hour <= 6:
                score += 10
                reasons.append("Arrived at unusual hour (+10)")
        except Exception:
            pass

    # 2. STEP 2: TRUSTED MESSAGE DETECTION
    is_informational = any(w in clean_text for w in TRUSTED_WORDS)
    if is_informational and not has_links and not urgency_hits and not threat_hits:
        score -= 40
        reasons.append("Message appears to be an informational/transactional alert.")
        if score < 0: score = 0

    # 3. STEP 3: SCAM SIGNAL DETECTION
    if urgency_hits:
        score += 20
        reasons.append(f"Urgency: {', '.join(list(urgency_hits)[:2])}")

    if financial_hits and (urgency_hits or threat_hits or has_links or has_otp_words):
        score += 20
        reasons.append(f"Financial: {', '.join(list(financial_hits)[:2])}")

    if impersonation_hits:
        score += 25
        reasons.append(f"Authority Impersonation: {', '.join(list(impersonation_hits)[:2])}")

    if threat_hits:
        score += 25
        reasons.append(f"Threat/Fear: {', '.join(list(threat_hits)[:2])}")

    if reward_hits:
        score += 25
        reasons.append(f"Reward/Lottery: {', '.join(list(reward_hits)[:2])}")

    if job_hits:
        score += 30
        reasons.append(f"Job Scam: {', '.join(list(job_hits)[:2])}")

    if delivery_hits:
        score += 25
        reasons.append(f"Delivery Scam: {', '.join(list(delivery_hits)[:2])}")

    if electricity_hits:
        score += 30
        reasons.append(f"Electricity Scam: {', '.join(list(electricity_hits)[:2])}")
        
    if gas_hits:
        score += 25
        reasons.append(f"Gas/Utility Scam: {', '.join(list(gas_hits)[:2])}")

    if sim_hits:
        score += 25
        reasons.append(f"SIM/Telecom Scam: {', '.join(list(sim_hits)[:2])}")

    if kyc_hits:
        score += 25
        reasons.append(f"KYC Scam: {', '.join(list(kyc_hits)[:2])}")

    # 4. STEP 4: LINK ANALYSIS & 5. URL BEHAVIOR SIMULATION
    if has_links:
        score += 20
        reasons.append("Contains link.")
        
        # Check suspicious TLDs
        for link in links:
            link_str = link if isinstance(link, str) else link[0]
            link_lower = link_str.lower()
            if any(tld in link_lower for tld in SUSPICIOUS_DOMAINS):
                score += 40
                reasons.append(f"Suspicious domain detected.")
            
            # URL Behavior Simulation
            if bool(re.search(r'[a-z]+\d+[a-z]+', link_lower)):
                score += 20
                reasons.append("Numbers inside domain (+20)")
            if link_lower.count('-') >= 2:
                score += 20
                reasons.append("Multiple hyphens in domain (+20)")
            if link_lower.count('/') > 4:
                score += 20
                reasons.append("Long suspicious path (+20)")

            # Check brand hijacking
            if BRAND_MIMIC_PATTERN.search(link_lower):
                score += 50
                reasons.append(f"Domain mimicking real brand detected.")

    # 5. STEP 5: COMBINATION BOOST
    if urgency_hits and has_links:
        score += 30
        reasons.append("Combo: Urgency + Link")
    elif impersonation_hits and threat_hits:
        score += 30
        reasons.append("Combo: Authority + Threat")
    elif reward_hits and has_links:
        score += 30
        reasons.append("Combo: Reward + Link")
    elif financial_hits and has_links:
        score += 30
        reasons.append("Combo: Payment request + Link")

    # Limit rule-based score to 100
    score = max(0, min(score, 100))

    # Determine Category
    category = "safe"
    if job_hits: category = "job_scam"
    elif electricity_hits: category = "electricity_scam"
    elif delivery_hits: category = "delivery_scam"
    elif kyc_hits: category = "kyc_fraud"
    elif impersonation_hits: category = "impersonation"
    elif threat_hits: category = "threat_scam"
    elif reward_hits: category = "reward_scam"
    elif has_links and urgency_hits: category = "phishing"
    elif has_links and score >= 25: category = "suspicious_link"
    elif score >= 25: category = "suspicious"

    # ── ML Analysis Integration ───────────────────────────
    ml_result = classifier.predict(text)
    ml_confidence = ml_result["confidence"]
    
    # Weight: 60% Rule-based, 40% ML
    final_score = int((score * 0.6) + (ml_confidence * 0.4))

    # 6. STEP 8: FINAL CONFLICT RESOLUTION
    if has_otp_words and not has_links and final_score < 50:
        final_score = 0
        category = "OTP / Authentication"
        reasons.insert(0, "Resolved as Safe OTP.")

    # 7. STEP 7: FINAL SCORING
    is_scam = False
    if final_score >= 50:
        verdict = "SCAM"
        is_scam = True
    elif final_score >= 25:
        verdict = "SUSPICIOUS"
        is_scam = True
    else:
        verdict = "SAFE"
        is_scam = False

    if ml_result["is_scam"] and final_score < 50:
        reasons.append(f"ML Model flagged but overriding due to score: ({ml_confidence}% conf)")
    elif ml_result["is_scam"]:
        reasons.append(f"ML Model detected scam pattern ({ml_confidence}% conf)")

    if not reasons:
        reasons.append("No suspicious patterns detected. Message appears safe.")

    explanation = " | ".join(reasons)
    
    return AnalysisResult(
        is_scam=is_scam,
        confidence=final_score,
        category=category,
        explanation=f"[{verdict}] {explanation}",
    )


def analyze_sms(message: str, metadata: dict = None) -> AnalysisResult:
    """
    Hybrid SMS analysis: Rule-based first, then AI for suspicious messages.
    
    Flow:
      1. Rule-based analysis (instant)
      2. If SUSPICIOUS (score 25-60) → enhance with Gemini AI
      3. AI verdict overrides rule-based if confidence is higher
    """
    # Step 1: Fast rule-based analysis
    rule_result = _analyze_text(message, metadata)
    
    # Step 2: If clearly SAFE or clearly SCAM, return immediately
    if rule_result.confidence < 20 or rule_result.confidence >= 70:
        return rule_result
    
    # Step 3: For SUSPICIOUS range (20-69), use AI for deeper analysis
    try:
        from services.ai_sms_analyzer import analyze_with_ai
        sender = (metadata or {}).get("sender", "")
        ai_verdict = analyze_with_ai(message, sender)
        
        if ai_verdict is not None:
            # AI successfully analyzed — use its verdict
            is_scam = ai_verdict.verdict == "SCAM"
            category = rule_result.category  # Keep rule-based category
            
            if ai_verdict.verdict == "SAFE" and ai_verdict.confidence >= 70:
                # AI says SAFE with high confidence — override
                return AnalysisResult(
                    is_scam=False,
                    confidence=max(0, 100 - ai_verdict.confidence),
                    category=category,
                    explanation=f"[AI SAFE] {ai_verdict.reason}",
                )
            elif ai_verdict.verdict == "SCAM" and ai_verdict.confidence >= 75:
                # AI says SCAM with high confidence — override
                return AnalysisResult(
                    is_scam=True,
                    confidence=ai_verdict.confidence,
                    category=category,
                    explanation=f"[AI SCAM] {ai_verdict.reason} | Signals: {', '.join(ai_verdict.triggered_signals[:3])}",
                )
            else:
                # AI says SUSPICIOUS or low confidence — blend with rule-based
                blended_confidence = (rule_result.confidence + ai_verdict.confidence) // 2
                return AnalysisResult(
                    is_scam=blended_confidence >= 50,
                    confidence=blended_confidence,
                    category=category,
                    explanation=f"[HYBRID] Rule: {rule_result.confidence}% + AI: {ai_verdict.confidence}% → {ai_verdict.reason}",
                )
    except Exception as e:
        import logging
        logging.getLogger("eldercare").warning(f"[AI-SMS] Enhancement failed, using rule-based: {e}")
    
    # Fallback: return rule-based result
    return rule_result


def analyze_call(transcript: str, metadata: dict = None) -> AnalysisResult:
    return _analyze_text(transcript, metadata)

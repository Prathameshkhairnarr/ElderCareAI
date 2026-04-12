import re
import os

# Massive keyword dictionaries (>100 variants each, English + Hinglish + Typos + Phrases)
KEYWORDS = {
    "URGENCY_WORDS": [
        "urgent", "immediately", "act now", "expire", "suspended", "last chance", "hurry", "deadline", 
        "limited time", "warning", "final notice", "right away", "don't delay", "asap", "within 24 hours", 
        "within 12 hours", "today only", "ending soon", "immediate action", "urgent request", "action required", 
        "do it now", "last warning", "critical", "mandatory", "required immediately", "without fail", 
        "time sensitive", "fast", "quick", "soon", "before it expires", "expiring today", "will be blocked",
        "will be suspended", "deactivation", "deactivate soon", "account closed", "closure warning", 
        "immediate attention", "action needed", "respond now", "must reply", "last day", "closing soon",
        "turant", "jaldi", "abhi karein", "aakhri mauka", "khatam ho raha", "aaj hi", "block ho jayega",
        "band ho jayega", "warn kiya jata hai", "antim din", "samay seema", "jald se jald", "tatkal",
        "urgnt", "imediately", "expir", "suspendd", "hurrei", "deadlin", "act fast", "quick reply",
        "reply asap", "urgent update", "critical update", "security update required", "immediate update",
        "mandatory update", "compulsory", "compulsory action", "must act", "failure to do so", "if not done",
        "action pending", "pending action", "resolve now", "fix now", "issue detected", "attention required",
        "please act", "kindly act", "urgent notice", "final reminder", "last reminder", "reminder 1",
        "reminder 2", "reminder 3", "account deletion", "profile suspension", "login immediately", "verify now",
        "verify instantly", "immediate verification", "instant verification", "alert", "security alert"
    ],
    "FINANCIAL_WORDS": [
        "bank", "account", "transfer", "upi", "otp", "pin", "credit card", "debit card", "loan", "emi", 
        "payment", "refund", "kyc", "aadhar", "pan card", "blocked", "verify", "transaction", "wallet", 
        "paytm", "phonepe", "gpay", "bhim", "rupay", "visa", "mastercard", "net banking", "internet banking",
        "cvv", "branch", "manager", "cash", "funds", "deposit", "withdrawal", "balance", "cheque", "dd",
        "overdraft", "savings", "current account", "fixed deposit", "fd", "rd", "mutual fund", "stocks",
        "trading", "crypto", "bitcoin", "investment", "returns", "profit", "loss", "tax", "income tax",
        "tds", "gst", "billing", "invoice", "receipt", "credt", "debt", "cr", "dr", "credited", "debited",
        "amount", "rs", "inr", "rupees", "lakh", "crore", "thousand", "hundred", "paisa", "paise",
        "paise bhejo", "paise transfer", "bank khata", "khata", "bima", "insurance", "premium", "policy",
        "claim", "settlement", "refund processed", "cashback received", "reward points", "loyalty points",
        "redeem points", "encash", "vpa", "upi id", "upi pin", "mpin", "tpin", "beneficiary", "payee",
        "remittance", "wire transfer", "neft", "rtgs", "imps", "swift", "forex", "loan approved", 
        "pre-approved loan", "personal loan", "home loan", "car loan", "business loan", "instant loan",
        "micro loan", "payday loan", "cash advance", "salary advance", "credit limit", "limit increase",
        "card upgrade", "lifetime free", "no annual fee", "zero balance", "minimum balance", "penalty fee"
    ],
    "IMPERSONATION_WORDS": [
        "rbi", "reserve bank", "sbi", "government", "police", "court", "income tax", "customs", "cbi", 
        "ministry", "official", "govt", "department", "authority", "officer", "inspector", "magistrate",
        "judge", "lawyer", "advocate", "supreme court", "high court", "cyber cell", "cyber police", 
        "crime branch", "cid", "ed", "enforcement directorate", "nia", "ncb", "raw", "trai", "irda", 
        "sebi", "epfo", "uidai", "aadhar center", "pan office", "passport office", "rto", "traffic police",
        "challan department", "municipality", "bmc", "ndmc", "mcd", "collector", "dm", "sp", "dsp", "acp",
        "dcp", "commissioner", "dg", "ig", "sho", "constable", "head constable", "sub inspector", "si",
        "asi", "army", "navy", "air force", "military", "paramilitary", "crpf", "bsf", "cisf", "itbp",
        "niti aayog", "pmo", "cmo", "minister", "mp", "mla", "sarpanch", "mayor", "governor", "president",
        "indian post", "bharatiya dak", "irctc", "indian railways", "nhai", "fastag authority", 
        "telecom ministry", "dot", "department of telecommunications", "npci", "national payments", 
        "sarkari", "karyalay", "adhikari", "pradhikaran", "vibhaag", "mantralaya", "nyayalaya", 
        "police station", "thana", "chowki", "control room", "helpline", "customer care", "support team",
        "resolution center", "grievance cell", "ombudsman", "nodal officer", "appellate authority",
        "vigilance", "anti-corruption", "lokpal", "lokayukta", "cag", "election commission", "eci"
    ],
    "THREAT_WORDS": [
        "arrest", "jail", "legal action", "case filed", "warrant", "fine", "penalty", "blacklisted", 
        "terminate", "seize", "freeze", "suspend", "cancel", "account freeze", "sim blocked", "fir", 
        "complaint", "summon", "subpoena", "court notice", "legal notice", "lawsuit", "sue", "prosecute",
        "imprisonment", "detention", "custody", "interrogation", "investigation", "raid", "search warrant",
        "confiscate", "attach property", "auction", "defaulter", "absconder", "fugitive", "criminal", 
        "fraudulent", "illegal", "unlawful", "banned", "restricted", "prohibited", "violation", "breach",
        "non-compliance", "defamation", "harassment", "extortion", "blackmail", "threat", "danger",
        "risk", "severe consequences", "strict action", "punitive action", "disciplinary action",
        "police complaint", "cyber complaint", "report filed", "dossier", "chargesheet", "conviction",
        "girgtaar", "girftari", "jail hogi", "fine lagega", "jurmana", "karwai", "kanooni karwai",
        "mukadama", "notice bheja", "court jana padega", "police aayegi", "ghar pe police", "raid padegi",
        "khatra", "saza", "dand", "rukawat", "bandi", "zapt", "kroki", "kurki", "shikayat", "darj",
        "khilaf", "virodh", "pratibandh", "nishedh", "dhamki", "warning issued", "final warning issued",
        "account deletion", "permanent ban", "lifetime ban", "service termination", "contract cancellation",
        "agreement failure", "breach of trust", "fraud detected", "suspicious activity detected",
        "money laundering", "terror financing", "illegal transaction", "unauthorized access", "hacked"
    ],
    "REWARD_WORDS": [
        "congratulations", "you won", "prize", "reward", "gift", "cashback", "rupees", "lakh", "crore", 
        "won", "winner", "lottery", "jackpot", "lucky draw", "sweepstakes", "giveaway", "free", "bonus",
        "surprise", "special offer", "exclusive offer", "mega offer", "bumper prize", "grand prize",
        "first prize", "cash prize", "voucher", "coupon", "discount", "promo code", "recharge free",
        "data free", "smartphone won", "iphone won", "car won", "bike won", "gold won", "trip to",
        "holiday package", "vacation", "all expenses paid", "sponsored", "selected", "shortlisted",
        "chosen", "lucky winner", "random selection", "computer selection", "mobile number won",
        "sim card won", "email won", "claim now", "claim prize", "redeem now", "redeem prize",
        "collect prize", "grab offer", "avail offer", "limited offer", "festive offer", "diwali offer",
        "new year offer", "anniversary offer", "birthday offer", "celebration", "badhai", "badhai ho",
        "aap jeet chuke hai", "aap winner hai", "inaam", "puraskar", "muft", "free gift", "tohfa",
        "shandaar", "dhamaka", "offer", "discount", "chhoot", "cashback mila", "paise mile",
        "kismat", "bhagya", "lucky", "1st prize", "2nd prize", "3rd prize", "consolation prize",
        "mega draw", "lucky number", "lucky spin", "wheel of fortune", "scratch card", "scratch and win",
        "play and win", "bet and win", "rummy win", "casino win", "poker win", "fantasy win", "dream11 win",
        "mpl win", "my11circle win", "bcci offer", "ipl offer", "t20 offer", "world cup offer"
    ],
    "JOB_WORDS": [
        "work from home", "earn", "daily income", "part-time job", "registration fee", "pay to start job",
        "wfh", "full time job", "freelance", "online earning", "earn money online", "make money online",
        "data entry", "copy paste", "typing job", "sms sending job", "email reading job", "ad clicking job",
        "survey job", "review job", "youtube like job", "subscribe job", "instagram like job", "follow job",
        "rating job", "amazon review job", "flipkart review job", "google review job", "app installation job",
        "game playing job", "refer and earn", "network marketing", "mlm", "pyramid scheme", "chain system",
        "downline", "upline", "direct selling", "investment plan", "roi plan", "doubling money",
        "guaranteed income", "fixed income", "passive income", "financial freedom", "be your own boss",
        "no investment", "zero investment", "low investment", "high return", "quick money", "easy money",
        "get rich quick", "lakhpati", "crorepati", "naukri", "rozgar", "kaam", "ghar baithe", "kamai",
        "paise kamaye", "din ka", "mahine ka", "salary", "wages", "stipend", "bonus", "commission",
        "incentive", "target", "target completion", "task completion", "assignment", "project", 
        "recruitment", "hiring", "urgent hiring", "vacancy", "openings", "interview", "selection",
        "offer letter", "joining letter", "appointment letter", "training fee", "security deposit",
        "equipment fee", "laptop fee", "uniform fee", "id card fee", "processing fee", "agreement fee",
        "bond fee", "document verification fee", "hr round", "manager round", "job guarantee", "100% placement"
    ],
    "DELIVERY_WORDS": [
        "parcel", "shipment", "courier", "delivery failed", "customs charge", "pay delivery fee", 
        "india post", "speed post", "postal service", "dhl", "fedex", "blue dart", "dtpc", "safexpress",
        "ecom express", "delhivery", "shadowfax", "xpressbees", "amazon delivery", "flipkart delivery",
        "myntra delivery", "meesho delivery", "swiggy delivery", "zomato delivery", "blinkit delivery",
        "zepto delivery", "dunzo delivery", "instamart delivery", "bigbasket delivery", "jio mart delivery",
        "package", "dispatch", "dispatched", "in transit", "out for delivery", "delivered", "undelivered",
        "returned", "address not found", "wrong address", "update address", "confirm address", "reschedule",
        "redelivery", "pick up", "drop off", "tracking", "track order", "tracking number", "awb", 
        "waybill", "customs clearance", "duty fee", "import tax", "clearance fee", "holding fee", 
        "storage fee", "demurrage", "penalty fee", "insurance fee", "damage fee", "lost package",
        "damaged package", "delayed package", "held at customs", "seized by customs", "pending payment",
        "payment required for delivery", "pay to receive", "postman", "delivery boy", "delivery executive",
        "delivery partner", "rider", "samaan", "bheja", "parsal", "daak", "chitthi", "patra", "pata",
        "pata galat", "pata update", "wapas", "ruk gaya", "roka gaya", "shulk", "tax", "fine",
        "delivery missed", "missed delivery", "door locked", "consignee unavailable", "receiver unavaliable"
    ],
    "ELECTRICITY_WORDS": [
        "electricity bill", "power disconnected", "bijli cut", "pay bill immediately", "mseb", "uppcl",
        "bescom", "cesc", "tssprdcl", "tsnpdcl", "apsprdcl", "apepdcl", "hbvn", "dhbvn", "jbvnl", 
        "nbpdcl", "sbpdcl", "cspdcl", "gedcol", "kseb", "tangedco", "wbsedcl", "power supply", "power cut",
        "load shedding", "blackout", "electricity board", "electricity department", "electricity officer",
        "lineman", "meter reader", "meter", "smart meter", "unit", "reading", "bill due", "due date",
        "overdue", "late fee", "penalty", "disconnection", "disconnection notice", "final notice electricity",
        "power suspension", "restore power", "reconnect power", "reconnection fee", "update bill",
        "previous month bill", "current month bill", "arrears", "outstanding amount", "pay online",
        "pay via link", "download bill", "view bill", "bill receipt", "payment confirmation", "bijli vibhag",
        "bijli board", "bijli meter", "bijli bill", "light bill", "current bill", "line kat", "line cut",
        "connection cut", "connection kat", "bijli gul", "bhuqtan", "jama kare", "shulk", "jurmana",
        "officer se baat kare", "call officer", "contact officer", "helpline number", "customer care number",
        "bill desk", "payment portal", "power grid", "state electricity", "national grid", "solar scheme",
        "free electricity", "electricity subsidy", "200 units free", "zero bill", "waiver", "maaf",
        "bill maaf", "meter checking", "vigilance checking", "electricity theft", "fine for theft"
    ],
    "GAS_WORDS": [
        "gas subsidy", "lpg update", "gas kyc", "connection suspended", "indane", "hp gas", "bharat gas",
        "reliance gas", "adani gas", "mahanagar gas", "igl", "mgl", "png", "cng", "lpg", "cylinder",
        "gas booking", "book cylinder", "refill", "refill booking", "delivery agent", "gas agency",
        "distributor", "gas officer", "gas connection", "new connection", "ujjwala", "ujjwala yojana",
        "subsidy amount", "subsidy credited", "subsidy pending", "subsidy stopped", "link aadhar to gas",
        "gas aadhar link", "biometric update", "ekyc for gas", "inspection", "safety inspection", 
        "inspection fee", "hose pipe change", "regulator change", "stove checking", "leakage", "blast",
        "insurance for gas", "gas insurance", "mandatory checking", "compulsory inspection", "gas bill",
        "piped gas", "meter reading", "gas meter", "disconnect gas", "stop gas", "gas line",
        "gas vibhag", "gas agency", "cylinder book", "booking number", "subsidy ka paisa", "khate me paise",
        "kyc pending", "aadhar jode", "connection band", "connection cancel", "home delivery",
        "urgent booking", "tatkal booking", "gas leakage", "emergency service", "customer care gas",
        "helpline gas", "toll free", "complaint gas", "resolve gas issue", "address update",
        "transfer connection", "surrender connection", "deposit refund", "security amount", "cylinder limit",
        "quota over", "extra cylinder", "commercial cylinder", "domestic cylinder", "14.2 kg", "19 kg"
    ],
    "SIM_WORDS": [
        "sim blocked", "sim suspend", "verify sim", "update kyc now", "jio", "airtel", "vi", "vodafone",
        "idea", "bsnl", "mtnl", "jiofi", "dongle", "router", "broadband", "fiber", "fiber broadband",
        "telecom", "customer service", "network provider", "sim card", "e-sim", "esim", "convert to esim",
        "upgrade sim", "4g to 5g", "sim upgrade", "free 5g", "5g trial", "port number", "mnp", "puk code",
        "sim locked", "unlock sim", "sim registry", "telecom verification", "aadhar sim link",
        "sim aadhar linking", "document missing", "re-verification", "document re-verify", "sim deactivation",
        "sim validity", "validity expired", "recharge now", "plan expired", "outgoing blocked", 
        "incoming blocked", "data exhausted", "100% data used", "daily limit", "top up", "data loan",
        "talktime loan", "caller tune", "hello tune", "vas", "value added service", "roaming",
        "international roaming", "isd", "std", "sim band", "number block", "number band", "chalu kare",
        "recharge kare", "kyc update kare", "document jama kare", "5g me badle", "free data", "free calling",
        "unlimited plan", "special offer for you", "exclusive plan", "company officer", "tower installation",
        "jio tower", "airtel tower", "tower lagwaye", "tower rent", "advance rent", "tower agreement",
        "noc fee", "site inspection", "network issue", "signal problem", "call drop", "complaint resolution",
        "trai order", "trai rule", "dot order", "telecom guidelines", "maximum sim limit", "extra sim"
    ],
    "KYC_WORDS": [
        "kyc update", "verify account", "update details immediately", "aadhar", "pan", "voter id", "driving license",
        "passport", "ration card", "identity proof", "address proof", "dob proof", "biometric", "fingerprint",
        "iris scan", "face auth", "ekyc", "c-kyc", "video kyc", "v-kyc", "offline kyc", "paperless kyc",
        "kyc suspended", "kyc expired", "kyc rejected", "kyc failed", "kyc pending", "kyc mandatory",
        "kyc required", "complete kyc", "finish kyc", "upload document", "submit document", "document verification",
        "verify identity", "authenticate", "link aadhar", "link pan", "pan-aadhar link", "deadline",
        "last date", "fine for not linking", "penalty for kyc", "account freeze due to kyc", "block due to kyc",
        "unblock account", "reinstate account", "reactivate", "activation", "kyc center", "cummunity service center",
        "csc", "e-mitra", "maha e-seva", "agent", "kyc officer", "field visit", "home visit", "verification call",
        "verification sms", "confirmation code", "kyc otp", "kyc pin", "kyc link", "click to update",
        "update online", "self service", "kyc portal", "uidai portal", "income tax portal", "nsdl", "utiitsl",
        "kyc form", "fatca", "crs", "pep", "politically exposed person", "kyc compliance", "regulatory requirement",
        "rbi mandate", "sebi guideline", "aml", "anti money laundering", "kyc jama", "kyc kare", "document de",
        "pehchan patra", "praman patra", "nambhar link", "khata link", "bank me aadhar", "aadhar jorna",
        "aadhar updation", "name change", "dob change", "address change", "mobile number update",
        "email update", "profile update", "details mismatch", "error in kyc", "re-submit"
    ]
}

def format_python_set(name, words):
    res = f"{name} = {{\n"
    for i in range(0, len(words), 5):
        chunk = words[i:i+5]
        res += "    " + ", ".join(f'"{w}"' for w in chunk) + ",\n"
    res += "}\n"
    return res

def format_dart_set(name, words):
    res = f"  static const {name} = <String>{{\n"
    for w in words:
        res += f"    '{w}',\n"
    res += "  };\n"
    return res

def update_python_file():
    path = r"d:\3d design\ElderCareAI\backend\services\analysis_service.py"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Simple regex to replace the blocks
    for key, words in KEYWORDS.items():
        pattern = re.compile(rf"{key}\s*=\s*\{{[^}}]*\}}", re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(format_python_set(key, words).strip(), content)
        else:
            print(f"Could not find {key} in python file")

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Updated Python Backend!")

def update_dart_file():
    path = r"d:\3d design\ElderCareAI\lib\services\sms_classifier.dart"
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    # Mapping Python constants to Dart constants
    mapping = {
        "URGENCY_WORDS": "_urgencyWords",
        "FINANCIAL_WORDS": "_financialWords",
        "IMPERSONATION_WORDS": "_impersonationWords",
        "THREAT_WORDS": "_threatWords",
        "REWARD_WORDS": "_rewardWords",
        "JOB_WORDS": "_jobWords",
        "DELIVERY_WORDS": "_deliveryWords",
        "ELECTRICITY_WORDS": "_electricityWords",
        "GAS_WORDS": "_gasWords",
        "SIM_WORDS": "_simWords",
        "KYC_WORDS": "_kycWords"
    }

    for py_key, dart_key in mapping.items():
        words = KEYWORDS[py_key]
        pattern = re.compile(rf"static const {dart_key}\s*=\s*<String>\{{[^}}]*\}};", re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(format_dart_set(dart_key, words).strip(), content)
        else:
            print(f"Could not find {dart_key} in dart file")

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print("Updated Dart Frontend!")

if __name__ == "__main__":
    update_python_file()
    update_dart_file()

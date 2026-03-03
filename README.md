# 🛡️ ElderCare AI — Scam & Safety Assistant  
### Smart Protection for Your Loved Ones

**ElderCare AI** is a voice‑first, privacy‑focused digital guardian designed to protect elderly users from scam SMS, fraud calls, and suspicious digital activity.

The platform combines a **Flutter mobile app** with a **FastAPI backend**, enhanced with a **real‑time SMS intelligence pipeline**, **background protection service**, and **dynamic risk engine**.

---

# 🚀 Key Features

## 📩 Real‑Time SMS Intelligence (UPDATED ✅)
- Foreground + background SMS detection  
- another_telephony dual‑isolate support  
- OTP & system message filtering  
- Duplicate suppression (hash‑based)  
- Confidence scoring (0–100)  
- Automatic threat classification  

### Supported Categories
- `financial_scam`  
- `impersonation`  
- `phishing`  
- `threat_scam`  
- `safe`  

---

## 🎙️ Voice Fraud Detection
- Call transcript analysis  
- Shared intelligence engine  
- Fraud pattern detection  
- Extensible for live monitoring  

---

## 🚨 Smart Alerts System (Hardened ✅)
- Auto‑generated on scam detection  
- Severity levels: `high`, `medium`  
- Elder‑friendly warning UI  
- Policy‑based alert suppression  
- Notification channel hardening  

---

## 🧠 Risk Engine (Improved ✅)
- Unified scoring core  
- Dynamic risk updates  
- Smooth score progression  
- Duplicate‑safe events  
- Explainable AI output  
- Backend sync throttling  

---

## 🚨 Emergency SOS
- Shake‑to‑SOS trigger  
- False‑trigger protection (debounce)  
- Emergency service integration  
- Elder‑friendly activation  

---

## 🔄 Background Protection Service (CRITICAL UPDATE ✅)
- Foreground service mode  
- Early boot initialization  
- Android 12/13/14 compatible  
- Battery optimization handling  
- Service survival improvements  

---

## 🔐 Authentication
- Phone + PIN login  
- JWT secure sessions  
- Role support (Elder, Guardian)  
- Secure token storage  

---

## ❤️ Health & System Monitoring
- Backend health endpoint  
- App readiness checks  
- Service lifecycle logging  
- Background watchdog logs  

---

# 🏗️ Tech Stack

## 📱 Frontend (Flutter)
- Flutter (Material UI)  
- Provider state management  
- another_telephony  
- Flutter Background Service  
- Local Notifications  
- Elder‑friendly responsive UI  

---

## ⚡ Backend (FastAPI)
- FastAPI  
- SQLAlchemy  
- Pydantic v2  
- JWT Authentication  
- Uvicorn  

---

## 🗄️ Database
- SQLite (dev)  
- PostgreSQL (production ready)  

---

# 📂 Project Structure

```
ElderCareAI/
│
├── backend/
│   ├── routers/
│   ├── services/
│   ├── database/
│   ├── schemas/
│   └── main.py
│
└── lib/
    ├── screens/
    ├── widgets/
    ├── services/
    └── main.dart
```

---

# ⚙️ Backend Setup

```bash
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload --port 8001
```

Swagger:
```
http://127.0.0.1:8001/docs
```

---

# 📱 Flutter Setup

```bash
flutter pub get
flutter run
```

### ✅ Supported Targets
- Android emulator  
- Physical device  
- Windows  
- Web  

---

# 🔐 Required Permissions

- RECEIVE_SMS  
- READ_SMS  
- FOREGROUND_SERVICE  
- POST_NOTIFICATIONS  
- Ignore Battery Optimization (recommended)  

Permissions are used strictly for user safety features.

---

# 🧪 Verification Checklist (NEW ✅)

After running the app, you should see:

```
Main isolate SMS listener initialized
🚨 BACKGROUND SERVICE STARTED
📱 [SMS RECEIVED]
```

If these appear → system fully operational.

---

# 📊 Current Status

- ✅ SMS dual‑isolate listener  
- ✅ Background service hardened  
- ✅ Risk scoring engine  
- ✅ Smart alert pipeline  
- ✅ Duplicate & OTP filtering  
- 🚧 Play Store compliance pending  
- 🚧 Final production hardening  

---

# 🚀 Future Roadmap

- 🔔 Real OTP verification  
- 📞 Live call monitoring  
- 🧠 ML‑based scam detection  
- 👨‍👩‍👧 Guardian dashboard  
- ☁️ Cloud deployment  
- 🔐 Biometric login  
- 📊 Advanced risk analytics  

---

# 🔐 Security Notes

- Passwords hashed with bcrypt  
- JWT signed tokens  
- No sensitive plaintext storage  
- Permission‑gated SMS access  
- Defensive background handling  

---

# 🤝 Contributing

1. Fork the repo  
2. Create feature branch  
3. Commit changes  
4. Open PR  

---

# 📜 License

MIT License

---

# 👨‍💻 Author

**Prathamesh Khairnar**  
Built with ❤️ for elder safety.

---

# ⭐ Support

If this project helped you:

⭐ Star the repo  
🍴 Fork it  
🧠 Share feedback  

---

**ElderCare AI — Because every elder deserves digital protection.**

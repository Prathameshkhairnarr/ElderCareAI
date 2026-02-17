# 🛡️ ElderCare AI — Scam & Safety Assistant

**Smart Protection for Your Loved Ones**

ElderCare AI is a voice-first, privacy-focused digital guardian designed to protect elderly users from scam calls, fraud SMS, and suspicious activities. The system combines a FastAPI backend with a Flutter mobile app to deliver real-time scam detection and safety alerts.

---

## 🚀 Key Features

### 🔐 Authentication

* Phone + PIN login
* JWT-based secure sessions
* Role support (`elder`, `guardian`)
* Swagger OAuth2 support

### 📩 SMS Scam Detection

* Keyword + pattern based analysis
* Confidence scoring (0–100)
* Category classification:

  * financial_scam
  * impersonation
  * phishing
  * threat_scam
  * safe
* Automatic alert generation for risky messages

### 🎙️ Voice Fraud Detection

* Call transcript analysis
* Same intelligence engine as SMS
* Real-time fraud pattern detection

### 🚨 Smart Alerts System

* Auto-generated when scam detected
* Severity levels:

  * high
  * medium
* Alert history with pagination

### 🧠 Risk Engine

* Unified analysis core
* Extensible scoring logic
* Explainable AI output

### ❤️ Health & System Monitoring

* Backend health endpoint
* App health status
* Service readiness checks

### ⚙️ Settings & Profile

* User-centric design
* Elder-friendly UI
* Secure session handling

---

## 🏗️ Tech Stack

### Frontend (Flutter)

* Flutter (Material UI)
* Provider / setState state management
* Responsive elder-friendly design
* Dark premium theme

### Backend (FastAPI)

* FastAPI
* SQLAlchemy
* Pydantic v2
* JWT Authentication
* Uvicorn

### Database

* SQLite (dev)
* PostgreSQL ready (prod)

---

## 📂 Project Structure

```
ElderCareAI/
│
├── backend/
│   ├── routers/
│   │   ├── auth.py
│   │   ├── sms.py
│   │   ├── voice.py
│   │   ├── alerts.py
│   │   ├── risk.py
│   │   └── sos.py
│   │
│   ├── services/
│   │   ├── auth_service.py
│   │   └── analysis_service.py
│   │
│   ├── database/
│   │   ├── engine.py
│   │   └── models.py
│   │
│   ├── schemas/
│   │   └── schemas.py
│   │
│   └── main.py
│
└── lib/
    ├── screens/
    ├── widgets/
    └── main.dart
```

---

## ⚙️ Backend Setup

### 1️⃣ Create virtual environment

```bash
python -m venv venv
venv\Scripts\activate
```

### 2️⃣ Install dependencies

```bash
python -m pip install -r requirements.txt
```

### 3️⃣ Run server

```bash
python -m uvicorn main:app --reload --port 8001
```

### 4️⃣ Open Swagger

```
http://127.0.0.1:8001/docs
```

---

## 📱 Flutter Setup

### 1️⃣ Get packages

```bash
flutter pub get
```

### 2️⃣ Run app

```bash
flutter run
```

### 3️⃣ Supported targets

* ✅ Android emulator
* ✅ Physical device
* ✅ Windows
* ✅ Web

---

## 🔄 API Flow

```
Register → Login → Get JWT → Analyze SMS/Call → Generate Alerts → View History
```

---

## 🧪 Testing Guide

### ✅ Register

POST `/auth/register`

```json
{
  "name": "Rajesh Kumar",
  "phone": "9876543210",
  "password": "1234",
  "role": "elder"
}
```

---

### ✅ Login (OAuth2 form)

POST `/auth/login`

Form fields:

```
username = phone number
password = pin
grant_type = password
```

---

### ✅ Analyze SMS

POST `/analyze-sms`

```json
{
  "message": "Congratulations! You won 50 lakhs. Send OTP now."
}
```

---

### ✅ Analyze Voice

POST `/analyze-call`

```json
{
  "transcript": "I am from bank. Share your OTP immediately."
}
```

---

### ✅ Get Alerts

GET `/alerts`

Query params:

```
limit
offset
```

---

### ✅ Health Check

GET `/health`

---

## 🔐 Security Notes

* Passwords hashed with bcrypt
* JWT signed tokens
* Protected endpoints via dependency injection
* No sensitive data stored in plaintext
* CORS enabled

---

## 🧠 Scam Detection Logic

The engine evaluates:

* urgency language
* financial keywords
* impersonation patterns
* threat language
* suspicious links

Each signal contributes to a confidence score (0–100).

---

## 🚀 Future Roadmap

* 🔔 Real OTP verification
* 📞 Live call monitoring
* 🧠 ML-based scam detection
* 👨‍👩‍👧 Guardian dashboard
* ☁️ Cloud deployment
* 🔐 Biometric login
* 📊 Risk analytics

---

## 🤝 Contributing

Pull requests are welcome. For major changes:

1. Fork repo
2. Create feature branch
3. Commit changes
4. Open PR

---

## 📜 License

MIT License

---

## 👨‍💻 Author

**Prathamesh Khairnar**

Built with ❤️ for elder safety.

---

## ⭐ Support

If this project helped you:

* ⭐ Star the repo
* 🍴 Fork it
* 🧠 Share feedback

---

**ElderCare AI — Because every elder deserves digital protection.**

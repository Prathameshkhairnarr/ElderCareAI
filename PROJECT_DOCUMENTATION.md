# ElderCare AI — Smart Elder Care Companion

> An AI-powered mobile application designed to protect elderly users from digital fraud, monitor their health, and keep their families connected — all through a natural Hindi voice interface.

---

## 📋 Project Overview

| Field | Details |
|-------|---------|
| **Project Name** | ElderCare AI (ElderSaathi) |
| **Platform** | Android (Flutter) |
| **Backend** | Python FastAPI (Render) |
| **AI Models** | GPT-4o, Gemini 2.0 Flash, Scikit-learn ML |
| **Voice Engine** | Microsoft Edge TTS (Neural Voices) |
| **Target Users** | Elderly (60+), Guardians, Children |
| **Status** | Production-ready, PlayStore deployment |

---

## 🎯 Problem Statement

India has 140M+ senior citizens, many of whom:
- Receive 5-10 scam SMS/calls daily targeting their savings
- Cannot easily navigate complex health apps
- Live alone without immediate family support
- Need a simple, voice-first interface in their native language

**ElderCare AI solves this** by providing an AI doctor, fraud protection, and family connectivity — all accessible through natural Hindi voice conversation.

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    FLUTTER MOBILE APP                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Voice AI │  │ SMS Scam │  │  Health  │  │ Guardian │   │
│  │ Doctor   │  │ Detector │  │ Monitor  │  │Dashboard │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │              │              │              │          │
│  ┌────┴──────────────┴──────────────┴──────────────┴────┐   │
│  │              SERVICE LAYER (Dart)                      │   │
│  │  • Edge TTS  • SmsClassifier  • HealthService        │   │
│  │  • STT       • RiskEngine     • EmergencyService     │   │
│  └──────────────────────┬───────────────────────────────┘   │
└─────────────────────────┼───────────────────────────────────┘
                          │ HTTPS/REST
┌─────────────────────────┼───────────────────────────────────┐
│              FASTAPI BACKEND (Render)                         │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ SMS API  │  │ Risk API │  │Health API│  │Guardian  │   │
│  │ /sms/*   │  │ /risk/*  │  │/health/* │  │ API      │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │              │              │              │          │
│  ┌────┴──────────────┴──────────────┴──────────────┴────┐   │
│  │              AI & ML SERVICES                         │   │
│  │  • Gemini AI SMS Analyzer  • Trained ML Model        │   │
│  │  • Edge TTS Synthesizer    • Risk Intelligence       │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                          │                                    │
│  ┌───────────────────────┴──────────────────────────────┐   │
│  │              SQLite DATABASE                           │   │
│  │  Users • RiskState • Alerts • SmsAnalysis • Meds     │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Key Features

### 1. AI Voice Doctor (Veda)
- **Natural Hindi conversation** — speaks like a real doctor
- **Edge TTS Neural Voice** — hi-IN-SwaraNeural (warm, female, elder-friendly)
- **Continuous conversation mode** — auto-listens after speaking
- **Emotion-aware responses** — adjusts tone based on context
- **Health context integration** — knows user's vitals, medications, conditions
- **Voice OS commands** — change theme, trigger SOS, navigate app via voice

**Tech Stack:** Speech-to-Text → GPT-4o/Gemini → Edge TTS → just_audio playback

### 2. SMS Scam Detection (Hybrid AI)
- **On-device instant classification** (0ms, no network needed)
- **DLT Sender Whitelist** — 100+ TRAI-regulated Indian sender IDs
- **11 scam signal categories** — urgency, financial, impersonation, threats, etc.
- **India-specific patterns** — "bijli kategi", "KYC expire", "PM Kisan" scams
- **Template memory system** — remembers scam fingerprints (DJB2 hash)
- **Backend AI enhancement** — Gemini analyzes suspicious messages
- **Trained ML model** — TF-IDF + Logistic Regression (97%+ accuracy, 5500+ samples)
- **Smart alert policy** — only notifies for genuine threats

**Detection Flow:**
```
SMS → DLT Check → Contact Check → OTP/Transaction Check → Scoring Engine → AI (if suspicious)
```

### 3. Dynamic Risk Intelligence
- **Real-time risk score** (0-100) with smooth hourly decay
- **Multi-signal scoring** — SMS scam (+15), SOS (+25), Call scam (+20)
- **Spike detection** — 3+ scams in 10 min triggers 1.5x multiplier
- **Health vulnerability bonus** — elderly/medical conditions increase sensitivity
- **Auto-resolve** — full reset after 7 clean days

### 4. Emergency SOS System
- **One-tap SOS** with GPS location
- **Shake-to-SOS** — hands-free emergency trigger
- **SMS delivery** to emergency contacts (native Android)
- **Backend sync** with idempotency key
- **Offline queue** — retries when network returns
- **60-second cooldown** — prevents accidental triggers
- **Voice confirmation** — "SOS bhej diya gaya hai"

### 5. Health Monitoring
- **Live vitals** — steps, heart rate, SpO2, blood pressure, temperature
- **Google Fit / Health Connect** integration
- **Pedometer fallback** via accelerometer
- **Health profile** — age, weight, blood group, conditions
- **Medication management** — search 10,000+ Indian medicines, set reminders
- **Prescription Reader** — AI-powered Rx scanner (Gemini Vision)
- **Prescription history** — auto-saved, searchable

### 6. Guardian Dashboard
- **Multi-elder monitoring** — risk scores, vitals, alerts
- **Children tab** — screen time, location, digital safety
- **Real-time alerts** — scam detected, SOS triggered, health anomaly
- **Remote actions** — call elder, view medications, send reminders
- **Threat console** — view and block detected scam attempts
- **AI Weekly Synopsis** — auto-generated from real data
- **Elder Detail Screen** — full management (meds, health profile, timeline)

### 7. Call Protection
- **Phone number reputation** — community-reported scam numbers
- **Carrier/location lookup** — verify caller identity
- **Scam reporting** — contribute to community database

---

## 🛠️ Technology Stack

### Frontend (Flutter/Dart)
| Component | Technology |
|-----------|-----------|
| Framework | Flutter 3.32 (Dart 3.8) |
| Voice STT | speech_to_text |
| Voice TTS | Edge TTS (WebSocket → Backend HTTP) |
| Audio | just_audio |
| Health | health package + sensors_plus |
| SMS | another_telephony |
| Location | geolocator + geocoding |
| Storage | shared_preferences |
| HTTP | http package + custom ResilientHttp |
| Notifications | flutter_local_notifications |
| Background | flutter_background_service |

### Backend (Python)
| Component | Technology |
|-----------|-----------|
| Framework | FastAPI + Uvicorn |
| Database | SQLAlchemy + SQLite |
| ML Model | Scikit-learn (TF-IDF + LogisticRegression) |
| AI | Gemini 2.0 Flash API |
| TTS | edge-tts 7.0+ (Sec-MS-GEC token) |
| Auth | JWT (python-jose) + bcrypt |
| Deployment | Render (auto-deploy from Git) |

### AI/ML Pipeline
| Model | Purpose | Accuracy |
|-------|---------|----------|
| GPT-4o (Azure/GitHub) | Voice AI Doctor conversations | — |
| Gemini 2.0 Flash | SMS deep analysis, Prescription reading | — |
| TF-IDF + LogisticRegression | SMS spam classification | 97%+ |
| Naive Bayes (fallback) | Lightweight SMS classification | ~85% |
| Rule-based engine | On-device instant classification | ~92% |

---

## 📊 SMS Detection — Technical Deep Dive

### On-Device Classifier (2000+ lines Dart)

**Signal Categories & Weights:**
```
Urgency words         → +20 points
Financial keywords    → +20 points
Authority impersonation → +25 points
Threat/Fear tactics   → +25 points
Reward/Lottery        → +25 points
Job scam patterns     → +30 points
Delivery scam         → +25 points
Electricity scam      → +30 points
KYC fraud             → +25 points
Suspicious links      → +20-50 points
Combination boosts    → +30 points
```

**Behavioral Analysis:**
- Sender intelligence (DLT format, mobile number, trusted whitelist)
- Time-of-day analysis (late night = +10)
- Language pattern detection (ALL CAPS, Hindi manipulation phrases)
- URL domain analysis (shorteners, brand mimicking, path depth)
- Template fingerprint matching (DJB2 hash, 100-entry circular buffer)

**Verdict Bands:**
- 0-24: SAFE ✅
- 25-49: SUSPICIOUS ⚠️
- 50-100: SCAM 🚨

### Backend AI Enhancement
- Only triggered for SUSPICIOUS messages (saves API costs)
- Uses Gemini with comprehensive India-specific DLT-aware prompt
- Returns structured JSON verdict with confidence score
- Hybrid blending: 60% rule-based + 40% AI

---

## 🔐 Security Features

- JWT token authentication with refresh mechanism
- PIN-based login (elder-friendly, no password)
- Input sanitization (PII redaction before AI calls)
- Rate limiting on API endpoints
- Idempotent operations (SOS, SMS analysis)
- No raw stack traces in production responses
- Request ID tracking for debugging

---

## 📱 User Roles & Flows

### Elder (Primary User)
```
Login → Dashboard → [AI Doctor | SMS Check | Health | SOS]
                         ↓
              Voice conversation with Veda
              (Hindi, continuous, emotion-aware)
```

### Guardian (Family Member)
```
Login → Guardian Dashboard → [Elders Tab | Children Tab | Alerts]
                                    ↓
                    Elder Detail → [Meds | Health | Timeline | Threats]
```

### Child (Young Family Member)
```
Login → Child Dashboard → [Home | Safety | Buddy | Focus | Insights]
                                    ↓
                    My Buddy (AI voice assistant with Siri-like orb UI)
```

---

## 📈 Performance Metrics

| Metric | Value |
|--------|-------|
| SMS Classification Speed (on-device) | < 5ms |
| Voice Response Latency (Edge TTS) | 1-3 seconds |
| AI Doctor Response (GPT-4o) | 2-4 seconds |
| App Cold Start | < 3 seconds |
| Background SMS Processing | < 100ms |
| Risk Score Update | Real-time |
| Model Size (trained) | ~2 MB |
| APK Size | ~45 MB |

---

## 🗂️ Project Structure

```
ElderCareAI/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/api_config.dart       # API keys & endpoints
│   ├── models/                      # Data models
│   ├── screens/                     # UI screens (15+)
│   │   ├── dashboard_screen.dart    # Elder main dashboard
│   │   ├── guardian_dashboard_screen.dart  # Guardian view
│   │   ├── elder_detail_screen.dart # Full elder management
│   │   ├── ai_doctor_screen.dart    # Voice AI interface
│   │   ├── sms_analyzer_screen.dart # SMS safety check
│   │   └── child_dashboard/         # Child monitoring
│   ├── services/                    # Business logic
│   │   ├── sms_classifier.dart      # On-device ML (2000 lines)
│   │   ├── sms_listener_service.dart # Background SMS listener
│   │   ├── background_service.dart  # Full processing pipeline
│   │   ├── health_service.dart      # Vitals & Health Connect
│   │   └── emergency_service.dart   # SOS system
│   ├── voice/                       # Voice AI system
│   │   ├── voice_engine.dart        # TTS orchestrator
│   │   ├── edge_tts_service.dart    # Microsoft Neural TTS
│   │   ├── ai_brain_service.dart    # GPT-4o/Gemini brain
│   │   ├── voice_controller.dart    # Full voice pipeline
│   │   └── sms_classifier.dart      # Text cleaning & SSML
│   └── widgets/                     # Reusable UI components
├── backend/
│   ├── main.py                      # FastAPI app
│   ├── routers/                     # API endpoints
│   │   ├── sms.py                   # SMS analysis
│   │   ├── health.py                # Health data
│   │   ├── guardian.py              # Guardian features
│   │   └── edge_tts_router.py      # TTS synthesis
│   ├── services/
│   │   ├── analysis_service.py      # Hybrid SMS analysis
│   │   ├── ai_sms_analyzer.py      # Gemini AI analyzer
│   │   ├── ml_model.py             # ML classifier
│   │   └── risk_service.py         # Risk intelligence
│   ├── train_pipeline.py           # ML training script
│   └── sms_model.pkl               # Trained model (97%+)
└── android/                         # Native Android config
```

---

## 🎓 What I Learned

- **Voice-first UX design** for elderly users (Hindi, simple, patient)
- **Hybrid AI architecture** — on-device speed + cloud intelligence
- **Indian DLT/TRAI ecosystem** — sender ID verification system
- **Real-time risk scoring** with decay algorithms
- **Production ML pipeline** — training, evaluation, deployment
- **Flutter background services** — SMS interception, health monitoring
- **WebSocket protocols** — Edge TTS binary frame handling
- **Multi-role app architecture** — Elder, Guardian, Child with shared backend

---

## 🔮 Future Roadmap

- [ ] Firebase Cloud Messaging (push notifications)
- [ ] Real-time location sharing (elder → guardian)
- [ ] Geofencing for child safety zones
- [ ] WhatsApp message scanning
- [ ] Fall detection via accelerometer
- [ ] Multi-language support (Tamil, Telugu, Bengali)
- [ ] Wearable integration (smartwatch vitals)
- [ ] Community scam database (crowdsourced)

---

## 👨‍💻 Developer

**Built as a solo full-stack project** — from concept to PlayStore-ready app.

Covers: Mobile Development, Backend Engineering, AI/ML, Voice Technology, Security, and UX Design for accessibility.

---

*Last updated: June 2026*

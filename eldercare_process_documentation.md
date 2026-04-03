# 🛡️ ElderCare AI - Detailed Process & App Documentation
*Complete Summary of Development Status as of Current Build*

---

## 1. Project Overview
**ElderCare AI** is a comprehensive, voice-first, privacy-focused digital ecosystem designed to protect elderly individuals from digital frauds, track their health, and provide quick emergency assistance. The system relies heavily on proactive monitoring (SMS, calls, sensors) combined with AI-based decision making.

**Roles Supported:**
- **Elder:** The primary beneficiary being monitored.
- **Guardian:** A secondary user who oversees the elder's status, receives emergency pings, and manages app settings.

---

## 2. Tech Stack Architecture
- **Frontend (Mobile App):** Built using **Flutter**. Includes support for background processes via isolates. State management is handled through Providers/Services paradigm.
- **Backend (API Server):** Built using **FastAPI (Python)**. 
- **Database:** Local/dev environment uses **SQLite** (`eldercare.db`), managed via SQLAlchemy. Future-proofed for PostgreSQL.
- **AI/Voice Integration:** ElevenLabs and Azure TTS services, along with an Offline Command Handler and Natural Language Processing algorithms for voice commands.

---

## 3. Detailed Feature Breakdown (Frontend / Mobile)

### A. Core Security & Fraud Prevention
1. **Real-time SMS Intelligence:** 
   - A dual-isolate architecture allows SMS tracking both in the foreground and the background.
   - Filters out general OTPs and categorizes messages: `financial_scam`, `impersonation`, `phishing`, `threat_scam`, or `safe`.
   - Dedicated `SMS Analyzer Screen` to review text history.
2. **Dynamic Risk Engine:** 
   - Calculates a live risk score based on intercepted threats. Includes "score decay" (scores cool down over time if no new threats are found).
   - Generates automated smart alerts to both the Elder and connected Guardian.
3. **Call Protection & Reputation Check:** 
   - Uses `another_telephony` integration.
   - Cross-checks unknown incoming numbers against a reputation service.

### B. Emergency & Safety (SOS System)
1. **Shake-to-SOS:** 
   - `ShakeDetectorService` utilizes sensor data so the elder can simply shake their phone to trigger a distress ping.
   - Includes False-trigger debounce mechanisms.
2. **Emergency Hotlines:** 
   - Dedicated `SOS Screen` and quick-access SOS widgets.

### C. Proactive Health & Medical Tracking
1. **Health Monitor (Google Fit Integration):** 
   - Connects to sensors/pedometers and Google Fit APIs to check vitals, steps, and activity.
   - `My Health Screen` and `Health Profile View Screen` keep records of conditions.
2. **AI Doctor Assistant:** 
   - An intelligent chat interface (`ai_doctor_screen`) equipped with medical response parsers.
   - Discusses symptoms and schedules check-ups using AI capability.
3. **Advanced Medication Management:** 
   - Auto-seeded A-Z medicines dataset handles medicine lookups.
   - Reminders integrated via `medicine_reminder_service` with specific voice alerts (`medication_voice_alert`).

### D. Intelligent Voice Mechanics (Hands-Free Control)
Extensive custom-built voice service mapping:
1. **Wake Word Detection:** The app listens continuously (when active) for specific trigger words.
2. **Intent Routing & Parsing:** Extracts the exact intent of the spoken string using NLP helpers (`speech_naturalizer`, `emotion_tagger`, `language_detector`).
3. **Offline Command Handler:** Basic actions don't require internet, significantly enhancing speed and security.
4. **Text-To-Speech (TTS):** Responses are delivered audibly using premium TTS (Azure/ElevenLabs).

---

## 4. Detailed Backend Breakdown (FastAPI)

### A. Scalable Application Structure
The server routes are cleanly modularized:
- `/auth`: Login/JWT/Registration.
- `/sms` & `/call`: Handlers for syncing local device threats to the global intelligence DB.
- `/health` & `/medications`: Endpoints to sync vitals and prescriptions.
- `/sos` & `/contacts`: Emergency route triggers and Guardian management. 

### B. Production Grade Handling
1. **Middleware Pipeline:** Features UUID generation per-request and latency tracking.
2. **Robust Data Seeding:** Upon initial boot (`lifespan` hook), the database auto-seeds a huge repository of Indian medicines (`A_Z_medicines_dataset_of_India.csv`).
3. **Background Services:** Contains a persistent `decay_all_scores` scheduler running asynchronously every hour to normalize the threat levels.
4. **Fault Tolerance:** Global exception handlers are set so stacking errors don't crash the server.

---

## 5. Security & System Requirements

**Cryptographic Security:**
- JWTs for authenticated mobile sessions.
- Biometric-ready architecture implementation placeholders.
- Passwords (if managed) hashed tightly.

**Heavy App Permissions Required (Flutter):**
Because it's a security app, the core relies heavily on permissions granted at startup:
- `RECEIVE_SMS`, `READ_SMS`, `phone`, `notification`
- `FOREGROUND_SERVICE`
- `activityRecognition` (health tracker)
- `ignoreBatteryOptimizations` (critical for keeping the background isolate alive indefinitely)

---

## 6. Development Progress Summary
* **What is 100% Done:** Backend API structures, SQLite mappings, Real-time background SMS interception, Scam classification pipelines, Health module, Basic UI dashboards, Guardian sync mechanisms, and Core routing.
* **What requires Polish / Pending:** Thorough Play Store compliance (Getting persistent SMS permission approved by Google Play is typically difficult), live phone call wire-tapping features (due to OS limitations), and comprehensive cloud deployments.

# ElderCare AI — Real-World Stress Test Checklist

Run all tests on a **real Android device** (not emulator) with the production APK.

---

## 🔴 Critical Path Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 1 | **Airplane mode SOS** | Enable airplane → Tap SOS → Restore network | SMS sent, SOS queued, flushed on reconnect | App crash, SOS lost |
| 2 | **Rapid SOS taps** | Tap SOS 5× in 2 seconds | Only 1 SOS sent, cooldown shows for rest | Multiple SOS, ANR, freeze |
| 3 | **Slow GPS + SOS** | Mock slow GPS (indoors), trigger SOS | Completes within 8s with "GPS Unavailable" | Hangs >10s, ANR |
| 4 | **No GPS + SOS** | Disable location services, trigger SOS | SOS sends with "Location Unknown" | Crash, infinite spinner |
| 5 | **Backend down + SOS** | Stop backend server, trigger SOS | SMS sent, "Server sync queued" shown | Crash, silent failure |

## 🟡 SMS Intelligence Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 6 | **Malformed SMS** | Send empty/null-body SMS to device | Ignored silently, no crash | Crash, ANR |
| 7 | **OTP filtering** | Receive OTP SMS (e.g., "Your OTP is 123456") | Classified as OTP, not processed | Alert fires for OTP |
| 8 | **Scam SMS detected** | Send known scam message | Alert shown, risk score +15 | No alert, wrong score |
| 9 | **Message flood** | Send 20 SMS in 30 seconds | All processed, no duplicates, no ANR | Duplicates, crash, memory spike |
| 10 | **Long SMS** | Send 2000+ char message | Truncated to 2000, classified normally | OOM, crash |
| 11 | **Background SMS** | Kill app from recents, send SMS | Background handler processes, alert shown | SMS missed, crash |
| 12 | **Duplicate SMS** | Send identical message 3× | Only 1st processed, rest deduped | Triplicate processing |

## 🟡 Shake SOS Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 13 | **Valid shake** | Shake phone vigorously 4× in 2s | SOS triggered, vibration feedback | No trigger, or false trigger |
| 14 | **Vehicle driving** | Drive on bumpy road for 5 min | No false SOS triggers | SOS triggered by road bumps |
| 15 | **Walking/running** | Walk briskly for 5 min | No false SOS triggers | SOS triggered by walking |
| 16 | **Phone drop** | Drop phone on soft surface | No SOS trigger (sensor noise filtered) | SOS triggered by drop |
| 17 | **Shake cooldown** | Shake once → wait 30s → shake again | 2nd shake blocked by 60s cooldown | 2nd SOS sent within cooldown |

## 🟡 Network Resilience Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 18 | **Poor network** | Enable network throttling (2G) | All API calls complete with retry | Timeouts, ANR |
| 19 | **Network loss mid-request** | Start SMS analysis → disable wifi | Timeout + graceful error shown | Infinite spinner, ANR |
| 20 | **Backend 500 error** | Force backend 500 on /risk | Retry 3×, then show cached data | Crash, infinite retry |
| 21 | **Token expired** | Wait for token expiry, use app | "Token expired" message, redirect to login | Crash, blank screen |

## 🟡 Lifecycle Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 22 | **Long background** | Leave app in background 30 min | Resumes normally, SMS listener alive | Crash on resume, listener dead |
| 23 | **Battery saver mode** | Enable battery saver, use app | App functions, background SMS works | Background killed, SMS missed |
| 24 | **Low memory** | Open 20+ apps, return to ElderCare | No crash, data preserved | Crash, data lost |
| 25 | **Screen rotation** | Rotate during SOS sending | UI stable, SOS completes | Crash, duplicate SOS |

## 🟢 Performance Tests

| # | Scenario | Steps | PASS Criteria | FAIL Criteria |
|---|----------|-------|---------------|---------------|
| 26 | **Startup time** | Cold start app | Login/Dashboard in <3s | ANR, >5s white screen |
| 27 | **Battery drain** | Use app passively for 1 hour | <5% battery drain | >10% battery drain |
| 28 | **Memory stable** | Use app for 30 min continuous | Memory flat, no growth | Memory growing unbounded |

---

## Summary

| Category | Tests | Min Pass Required |
|----------|-------|-------------------|
| Critical Path | 5 | **5/5** |
| SMS Intelligence | 7 | **6/7** |
| Shake SOS | 5 | **5/5** |
| Network Resilience | 4 | **3/4** |
| Lifecycle | 4 | **3/4** |
| Performance | 3 | **2/3** |
| **TOTAL** | **28** | **24/28 (86%)** |

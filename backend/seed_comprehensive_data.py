import sqlite3
import hashlib
from datetime import datetime, timedelta, timezone

def hash_phone(phone, salt="ElderCareAI_v1_privacy_salt_2026"):
    # Simple normalization: keep only digits
    digits = "".join(filter(str.isdigit, phone))
    if digits.startswith("91") and len(digits) == 12:
        digits = digits[2:]
    salted = digits + salt
    return hashlib.sha256(salted.encode()).hexdigest()

def seed():
    conn = sqlite3.connect('eldercare.db')
    cursor = conn.cursor()
    
    user_id = 1
    now = datetime.now(timezone.utc)
    
    print("Clearing old data for a fresh seed...")
    cursor.execute("DELETE FROM sms_analyses WHERE user_id = ?", (user_id,))
    cursor.execute("DELETE FROM alerts WHERE user_id = ?", (user_id,))
    cursor.execute("DELETE FROM risk_entries WHERE user_id = ?", (user_id,))
    cursor.execute("DELETE FROM risk_states WHERE user_id = ?", (user_id,))
    cursor.execute("DELETE FROM health_vitals WHERE user_id = ?", (user_id,))
    cursor.execute("DELETE FROM sos_logs WHERE user_id = ?", (user_id,))
    
    print("Seeding SMS History...")
    sms_scams = [
        ("URGENT: Your bank account has been suspended. Click here to verify: http://bit.ly/bank-verify-2026", "financial_impersonation", 85),
        ("Congratulations! You won a cash prize of ₹1,00,000. Send ₹5,000 processing fee to claim.", "lottery_scam", 92),
        ("Your electricity bill is overdue. Pay immediately to avoid disconnection: https://power-pay.ga/bill", "phishing", 78)
    ]
    
    for body, category, confidence in sms_scams:
        cursor.execute("""
            INSERT INTO sms_analyses (user_id, message, is_scam, confidence, category, explanation, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (user_id, body, 1, confidence, category, f"Detected {category} with high confidence.", (now - timedelta(hours=12)).isoformat()))
        sms_id = cursor.lastrowid
        
        # Add to risk entries
        cursor.execute("""
            INSERT INTO risk_entries (user_id, source_type, source_id, status, risk_score_contribution, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (user_id, "sms", str(sms_id), "ACTIVE", 15, (now - timedelta(hours=12)).isoformat()))

    print("Seeding Alerts...")
    alerts = [
        ("sms_fraud", "Urgent Bank Scam Detected", "Suspicious link found in message from unknown sender.", "high"),
        ("call_fraud", "Voice Phishing Attempt", "Call transcript indicates impersonation of government official.", "critical"),
        ("health_warning", "Irregular Heart Rate", "Heart rate peaked at 110 bpm during rest period.", "medium"),
        ("sos", "Emergency SOS Triggered", "SOS was triggered. Contacts have been notified.", "critical")
    ]
    
    for a_type, title, details, severity in alerts:
        cursor.execute("""
            INSERT INTO alerts (user_id, alert_type, title, details, severity, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (user_id, a_type, title, details, severity, (now - timedelta(days=1)).isoformat()))

    print("Seeding Phone Reputation...")
    phones = [
        ("9876543210", 95, "loan_scam", 142),
        ("8888888888", 88, "bank_fraud", 56),
        ("7777777777", 45, "suspicious", 12),
        ("9123456789", 10, "safe", 0)
    ]
    
    for phone, score, category, count in phones:
        p_hash = hash_phone(phone)
        cursor.execute("""
            INSERT OR REPLACE INTO phone_reputation (phone_hash, risk_score, category, report_count, last_updated)
            VALUES (?, ?, ?, ?, ?)
        """, (p_hash, score, category, count, now.isoformat()))

    print("Seeding Health Vitals...")
    vitals = [
        ('heart_rate', 72.0, 'bpm'),
        ('steps', 4500.0, 'steps'),
        ('spo2', 98.0, '%'),
        ('sleep', 7.5, 'hrs'),
        ('temperature', 98.6, '°F'),
        ('bp', 120.0, 'mmHg')
    ]
    
    for v_type, value, unit in vitals:
        for i in range(5):
            recorded_at = now - timedelta(days=i, hours=2)
            cursor.execute("""
                INSERT INTO health_vitals (user_id, type, value, unit, recorded_at)
                VALUES (?, ?, ?, ?, ?)
            """, (user_id, v_type, value + (i * 0.5), unit, recorded_at.isoformat()))

    print("Setting Risk State...")
    # Seed specific risk score of 24 as requested previously by match screenshot
    cursor.execute("""
        INSERT INTO risk_states (user_id, current_score, last_scam_at, updated_at)
        VALUES (?, ?, ?, ?)
    """, (user_id, 24, now.isoformat(), now.isoformat()))

    conn.commit()
    conn.close()
    print("Comprehensive seeding completed successfully!")

if __name__ == "__main__":
    seed()


import sqlite3
import hashlib
from datetime import datetime, timedelta

def restore_data():
    conn = sqlite3.connect('eldercare.db')
    cursor = conn.cursor()
    
    # Tables are already created by the app (diagnose_engine.py did this)
    # We just insert data into: sms_analyses, risk_entries, risk_states
    
    user_id = 1
    
    # 1. Restore SMS History (table: sms_analyses)
    sms_data = [
        # (body, category, risk_score, is_fraud, explanation)
        ("Your bank account is locked. Click http://bit.ly/scam to verify.", "financial_scam", 85, 1, "Urgency + suspicious link detected.", datetime.now()),
        ("Grandma, I lost my phone. Send money to this number urgently.", "impersonation", 92, 1, "Impersonation pattern detected.", datetime.now() - timedelta(hours=2)),
        ("Your electricity bill is due due. Pay now to avoid disconnection.", "threat_scam", 75, 1, "Threat language detected.", datetime.now() - timedelta(days=1)),
        ("Hey mom, creating a new group for the family dinner.", "safe", 10, 0, "Normal conversation.", datetime.now() - timedelta(days=2)),
        ("OTP for transaction 1234 is 5678. Do not share.", "safe", 5, 0, "Transactional message.", datetime.now() - timedelta(days=3))
    ]
    
    print("Restore SMS Analyses...")
    for body, category, score, is_fraud, explanation, ts in sms_data:
        content_hash = hashlib.sha256(" ".join(body.lower().strip().split()).encode("utf-8")).hexdigest()
        
        try:
            # Check if exists
            cursor.execute("SELECT id FROM sms_analyses WHERE content_hash = ?", (content_hash,))
            if cursor.fetchone():
                continue

            cursor.execute("""
                INSERT INTO sms_analyses (user_id, message, content_hash, is_scam, confidence, category, explanation, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """, (user_id, body, content_hash, is_fraud, score, category, explanation, ts))
            
            # If scam, add to risk_entries
            if is_fraud:
                cursor.execute("""
                    INSERT INTO risk_entries (user_id, source_type, source_id, risk_score_contribution, status, created_at)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, (user_id, "sms", content_hash, score, "ACTIVE", ts))
                
        except Exception as e:
            print(f"Error inserting SMS: {e}")

    # 2. Restore Risk State (table: risk_states)
    print("Restore Risk State...")
    try:
        # Calculate aggregate score (simple avg of active scams)
        cursor.execute("SELECT AVG(risk_score_contribution) FROM risk_entries WHERE user_id = ? AND status='ACTIVE'", (user_id,))
        avg_score = cursor.fetchone()[0]
        current_score = int(avg_score) if avg_score else 0
        
        # Override for demo impact if low
        if current_score < 40: current_score = 65
        
        cursor.execute("""
            INSERT OR REPLACE INTO risk_states (user_id, current_score, last_scam_at, updated_at)
            VALUES (?, ?, ?, ?)
        """, (user_id, current_score, datetime.now(), datetime.now()))
    except Exception as e:
         print(f"Error restoring risk state: {e}")

    conn.commit()
    conn.close()
    print("✅ Data restoration complete (Correct Schema)!")

if __name__ == "__main__":
    restore_data()

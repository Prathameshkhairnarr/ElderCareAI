
import sqlite3
from datetime import datetime
from database.engine import engine, Base
from database.models import User, RiskScore, SMSLog

# Ensure tables exist
Base.metadata.create_all(bind=engine)

def restore_data():
    conn = sqlite3.connect('eldercare.db')
    cursor = conn.cursor()
    
    user_id = 1
    
    # 1. Restore SMS History
    sms_data = [
        (user_id, "Your bank account is locked. Click http://bit.ly/scam to verify.", "financial_scam", 85.0, 1, "Urgency + suspicious link detected.", datetime.now()),
        (user_id, "Grandma, I lost my phone. Send money to this number urgently.", "impersonation", 92.0, 1, "Impersonation pattern detected.", datetime.now()),
        (user_id, "Your electricity bill is due due. Pay now to avoid disconnection.", "threat_scam", 75.0, 1, "Threat language detected.", datetime.now()),
        (user_id, "Hey mom, creating a new group for the family dinner.", "safe", 10.0, 0, "Normal conversation.", datetime.now()),
        (user_id, "OTP for transaction 1234 is 5678. Do not share.", "safe", 5.0, 0, "Transactional message.", datetime.now())
    ]
    
    print("Restore SMS...")
    for sms in sms_data:
        try:
            cursor.execute("""
                INSERT INTO sms_logs (user_id, body, category, risk_score, is_fraud, explanation, timestamp)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, sms)
        except Exception as e:
            print(f"Skipping duplicate/error SMS: {e}")

    # 2. Restore Risk Score
    print("Restore Risk Score...")
    try:
        cursor.execute("""
            INSERT OR REPLACE INTO risk_scores (user_id, score, level, details, last_updated)
            VALUES (?, ?, ?, ?, ?)
        """, (user_id, 65.0, "Medium", "Recent scam attempts detected.", datetime.now()))
    except Exception as e:
         print(f"Error restoring risk score: {e}")

    conn.commit()
    conn.close()
    print("✅ Data restoration complete!")

if __name__ == "__main__":
    restore_data()

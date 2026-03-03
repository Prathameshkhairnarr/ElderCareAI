import sqlite3

def verify_restore():
    db_path = 'eldercare.db'
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        checks = {
            "sms_analyses": "SELECT count(*) FROM sms_analyses",
            "risk_entries": "SELECT count(*) FROM risk_entries",
            "emergency_contacts": "SELECT count(*) FROM emergency_contacts",
            "risk_states": "SELECT current_score FROM risk_states WHERE user_id=1"
        }
        
        print(f"--- Verification for {db_path} ---")
        for name, query in checks.items():
            cursor.execute(query)
            res = cursor.fetchone()
            print(f"{name}: {res[0] if res else 'N/A'}")
            
        print("\n--- Recent Restored SMS ---")
        cursor.execute("SELECT message, category, is_scam FROM sms_analyses LIMIT 5")
        for row in cursor.fetchall():
            print(row)

        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    verify_restore()

import sqlite3
import os
from datetime import datetime, timezone

def restore_real_data():
    source_db = 'eldercare_corrupt.db'
    dest_db = 'eldercare.db'
    
    if not os.path.exists(source_db):
        print(f"Error: {source_db} not found. Cannot restore real data.")
        return

    try:
        source_conn = sqlite3.connect(source_db)
        dest_conn = sqlite3.connect(dest_db)
        
        source_cursor = source_conn.cursor()
        dest_cursor = dest_conn.cursor()
        
        user_id = 1
        
        print("--- STARTING REAL DATA RESTORATION ---")
        
        # 1. Clear ALL existing data (except users) to remove demo/mock entries
        print("Clearing demo/mock data...")
        tables_to_clear = [
            "sms_analyses", "risk_entries", "risk_states", 
            "alerts", "sos_logs", "health_vitals"
        ]
        for table in tables_to_clear:
            dest_cursor.execute(f"DELETE FROM {table} WHERE user_id = ?", (user_id,))
        
        # 2. Restore SMS Analyses
        print("Restoring real SMS Analyser data...")
        try:
            source_cursor.execute("""
                SELECT message, content_hash, is_scam, confidence, category, explanation, created_at 
                FROM sms_analyses WHERE user_id = ?
            """, (user_id,))
            sms_rows = source_cursor.fetchall()
            
            if sms_rows:
                print(f"Found {len(sms_rows)} real SMS messages in backup.")
                dest_cursor.executemany("""
                    INSERT INTO sms_analyses (user_id, message, content_hash, is_scam, confidence, category, explanation, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, [(user_id, *r) for r in sms_rows])
            else:
                print("No SMS history found in backup.")
        except Exception as e:
            print(f"Error restoring SMS: {e}")

        # 3. Restore Emergency Contacts
        print("Restoring real Emergency Contacts...")
        try:
            # First clean any demo contacts
            dest_cursor.execute("DELETE FROM emergency_contacts WHERE user_id = ?", (user_id,))
            
            # Check schema of source emergency_contacts
            source_cursor.execute("PRAGMA table_info(emergency_contacts)")
            cols = [c[1] for c in source_cursor.fetchall()]
            
            if "id" in cols:
                query = "SELECT id, name, phone, relationship, colorIndex, is_active FROM emergency_contacts WHERE user_id = ?"
                source_cursor.execute(query, (user_id,))
                contacts = source_cursor.fetchall()
                if contacts:
                    print(f"Found {len(contacts)} real contacts.")
                    dest_cursor.executemany("""
                        INSERT INTO emergency_contacts (id, user_id, name, phone, relationship, colorIndex, is_active)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                    """, [(c[0], user_id, c[1], c[2], c[3], c[4], c[5]) for c in contacts])
            else:
                # Older schema?
                source_cursor.execute("SELECT name, phone, relationship FROM emergency_contacts WHERE user_id = ?", (user_id,))
                contacts = source_cursor.fetchall()
                if contacts:
                    print(f"Found {len(contacts)} contacts (old schema).")
                    from uuid import uuid4
                    dest_cursor.executemany("""
                        INSERT INTO emergency_contacts (id, user_id, name, phone, relationship, colorIndex)
                        VALUES (?, ?, ?, ?, ?, ?)
                    """, [(str(uuid4()), user_id, c[0], c[1], c[2], 0) for c in contacts])

        except Exception as e:
            print(f"Error restoring contacts: {e}")

        # 4. Finalizing Risk State
        # Instead of hardcoding 24, we initialize a clean state.
        # The backend risk_service will recalculate the score correctly next time the app fetches it.
        print("Initializing clean Risk State...")
        dest_cursor.execute("""
            INSERT INTO risk_states (user_id, current_score, last_scam_at, updated_at)
            VALUES (?, 0, NULL, ?)
        """, (user_id, datetime.now(timezone.utc).isoformat()))

        # 5. Populate risk_entries for restored scams so the calculation works
        print("Re-indexing real scams into risk tracker...")
        dest_cursor.execute("SELECT id, is_scam, created_at FROM sms_analyses WHERE user_id = ? AND is_scam = 1", (user_id,))
        scams = dest_cursor.fetchall()
        for s_id, is_scam, created_at in scams:
            dest_cursor.execute("""
                INSERT INTO risk_entries (user_id, source_type, source_id, status, risk_score_contribution, created_at)
                VALUES (?, 'sms', ?, 'ACTIVE', 15, ?)
            """, (user_id, str(s_id), created_at))

        dest_conn.commit()
        source_conn.close()
        dest_conn.close()
        print("✅ AUTHENTIC DATA RESTORED. Demo data removed.")
        
    except Exception as e:
        print(f"Global restore error: {e}")

if __name__ == "__main__":
    restore_real_data()


import sqlite3

def clean_restore():
    try:
        source_conn = sqlite3.connect('eldercare_corrupt.db')
        dest_conn = sqlite3.connect('eldercare.db')
        dest_cursor = dest_conn.cursor()
        
        user_id = 1
        
        # 1. Try to restore SMS if table exists in source
        try:
            source_cursor = source_conn.cursor()
            source_cursor.execute("SELECT message, is_scam, confidence, category, explanation, created_at FROM sms_analyses WHERE user_id = ?", (user_id,))
            rows = source_cursor.fetchall()
            
            if rows:
                print(f"Recovered {len(rows)} real SMS messages.")
                dest_cursor.executemany("""
                    INSERT INTO sms_analyses (user_id, message, is_scam, confidence, category, explanation, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                """, [(user_id, *r) for r in rows])
            else:
                print("No SMS history found in backup.")
                
        except Exception as e:
            print(f"Skipping SMS restore (likely table missing): {e}")

        # 2. Try to restore Contacts if table exists
        try:
            source_cursor.execute("SELECT id, name, phone, relationship, is_active FROM emergency_contacts WHERE user_id = ?", (user_id,))
            contacts = source_cursor.fetchall()
            
            if contacts:
                print(f"Recovered {len(contacts)} contacts.")
                dest_cursor.executemany("""
                    INSERT OR IGNORE INTO emergency_contacts (id, user_id, name, phone, relationship, is_active)
                    VALUES (?, ?, ?, ?, ?, ?)
                """, [(c[0], user_id, c[1], c[2], c[3], c[4]) for c in contacts])
            else:
                 print("No contacts found in backup.")
                 
        except Exception as e:
            print(f"Skipping Contacts restore: {e}")

        dest_conn.commit()
        source_conn.close()
        dest_conn.close()
        print("✅ Clean restore complete.")
        
    except Exception as e:
        print(f"Global restore error: {e}")

if __name__ == "__main__":
    clean_restore()

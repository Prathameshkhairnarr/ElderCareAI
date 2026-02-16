import sqlite3

def restore_user():
    try:
        old_conn = sqlite3.connect('eldercare_corrupt.db')
        new_conn = sqlite3.connect('eldercare.db')
        
        # Get old hash
        phone = "0987654321"
        cursor = old_conn.execute("SELECT password_hash FROM users WHERE phone = ?", (phone,))
        row = cursor.fetchone()
        
        if row:
            old_hash = row[0]
            print(f"Found old hash for {phone}: {old_hash}")
            
            # Update in new DB
            new_conn.execute("UPDATE users SET password_hash = ? WHERE phone = ?", (old_hash, phone))
            new_conn.commit()
            print("Successfully restored original password to new database.")
        else:
            print(f"User {phone} not found in old database.")
            
        old_conn.close()
        new_conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    restore_user()

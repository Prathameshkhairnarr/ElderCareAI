import sqlite3

def list_data():
    try:
        conn = sqlite3.connect('eldercare_corrupt.db')
        cursor = conn.cursor()
        
        print("--- SMS ANALYSES ---")
        try:
            cursor.execute("SELECT * FROM sms_analyses LIMIT 10")
            for row in cursor.fetchall():
                print(row)
        except Exception as e:
            print(f"Error reading sms_analyses: {e}")
            
        print("\n--- EMERGENCY CONTACTS ---")
        try:
            cursor.execute("SELECT * FROM emergency_contacts LIMIT 10")
            for row in cursor.fetchall():
                print(row)
        except Exception as e:
            print(f"Error reading emergency_contacts: {e}")
            
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    list_data()

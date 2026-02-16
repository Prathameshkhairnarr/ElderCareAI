import sqlite3
try:
    conn = sqlite3.connect("eldercare.db")
    cursor = conn.execute("PRAGMA integrity_check")
    result = cursor.fetchone()
    print(f"Integrity check for eldercare.db: {result[0]}")
    
    # Try the backup too
    conn2 = sqlite3.connect("eldercare_bak.db")
    cursor2 = conn2.execute("PRAGMA integrity_check")
    result2 = cursor2.fetchone()
    print(f"Integrity check for eldercare_bak.db: {result2[0]}")
    
    conn.close()
    conn2.close()
except Exception as e:
    print(f"Integrity check failed: {e}")

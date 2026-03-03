import sqlite3
import json

conn = sqlite3.connect("eldercare.db")
cursor = conn.execute("PRAGMA table_info(users)")
cols = cursor.fetchall()

cursor = conn.execute("SELECT * FROM users WHERE phone='0987654321'")
row = cursor.fetchone()

with open("debug_log.txt", "w") as f:
    f.write("--- Schema ---\n")
    for c in cols:
        f.write(str(c) + "\n")
    
    f.write("\n--- Data ---\n")
    if row:
        d = dict(zip([c[1] for c in cursor.description], row))
        if 'password_hash' in d: d['password_hash'] = '***'
        f.write(str(d) + "\n")
    else:
        f.write("User not found\n")

conn.close()

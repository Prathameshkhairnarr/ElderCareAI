import sqlite3
conn = sqlite3.connect("eldercare.db")
cursor = conn.execute("SELECT * FROM users WHERE id=3")
row = cursor.fetchone()
with open("raw_data.txt", "w") as f:
    if row:
        f.write(str(list(row)) + "\n")
        f.write(str([c[0] for c in cursor.description]) + "\n")
    else:
        f.write("Row not found\n")
conn.close()

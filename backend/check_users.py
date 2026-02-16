import sqlite3, json

try:
    conn = sqlite3.connect("eldercare.db")
    cursor = conn.execute("SELECT id, name, phone, role, created_at FROM users")
    rows = cursor.fetchall()
    result = []
    for r in rows:
        result.append({"id": r[0], "name": r[1], "phone": r[2], "role": r[3], "created_at": r[4]})
    with open("users_dump.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, default=str)
    print(f"Found {len(result)} users. Saved to users_dump.json")
    conn.close()
except Exception as e:
    print(f"Error: {e}")

import sqlite3

DB_PATH = "eldercare.db"

def migrate_roles():
    print(f"🔵 Connecting to {DB_PATH}...")
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # Check existing roles
        cursor.execute("SELECT COUNT(*) FROM users WHERE role = 'caregiver'")
        count = cursor.fetchone()[0]
        print(f"🧐 Found {count} users with 'caregiver' role.")

        if count > 0:
            print("🚀 Migrating 'caregiver' -> 'guardian'...")
            cursor.execute("UPDATE users SET role = 'guardian' WHERE role = 'caregiver'")
            conn.commit()
            print("✅ Migration complete.")
        else:
            print("✅ No migration needed.")

        conn.close()

    except Exception as e:
        print(f"❌ Migration failed: {e}")

if __name__ == "__main__":
    migrate_roles()

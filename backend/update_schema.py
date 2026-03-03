"""
Update database schema.
Adds is_read column to alerts table if missing.
Creates guardians table.
"""
from sqlalchemy import text
from database.engine import engine, Base
from database.models import Guardian

def update_schema():
    print("Checking database schema...")
    with engine.connect() as conn:
        # 1. Check if 'is_read' exists in 'alerts'
        # SQLite pragma
        result = conn.execute(text("PRAGMA table_info(alerts)"))
        columns = [row[1] for row in result.fetchall()]
        
        if "is_read" not in columns:
            print("Adding 'is_read' column to 'alerts' table...")
            try:
                conn.execute(text("ALTER TABLE alerts ADD COLUMN is_read BOOLEAN DEFAULT 0"))
                conn.commit()
                print("Column added successfully.")
            except Exception as e:
                print(f"Error adding column: {e}")
        else:
            print("'is_read' column already exists in 'alerts'.")

    # 2. Create new tables (Guardians)
    print("Creating new tables if missing...")
    Base.metadata.create_all(bind=engine)
    print("Schema update complete.")

if __name__ == "__main__":
    update_schema()

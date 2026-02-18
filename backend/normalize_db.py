from sqlalchemy.orm import Session
from database.engine import SessionLocal
from database.models import User, Guardian
from utils.phone_utils import normalize_phone

def normalize_database():
    # Force use of backend/eldercare.db if it exists relative to root
    import os
    if os.path.exists("backend/eldercare.db"):
        os.environ["DATABASE_URL"] = "sqlite:///backend/eldercare.db"
        print("📍 Using backend/eldercare.db")
    
    # Re-import SessionLocal after setting env var might not work if already imported,
    # so we'll just manually engine it here for the migration script to be safe.
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    db_url = os.environ.get("DATABASE_URL", "sqlite:///./eldercare.db")
    engine = create_engine(db_url)
    SessionLocalMigration = sessionmaker(bind=engine)
    db = SessionLocalMigration()

    try:
        # 1. Normalize User phones
        users = db.query(User).all()
        print(f"🧐 Checking {len(users)} users...")
        user_fixed = 0
        for user in users:
            original = user.phone
            normalized = normalize_phone(original)
            if original != normalized:
                print(f"  ⚡ Fixing User {user.id} ({user.name}): '{original}' -> '{normalized}'")
                user.phone = normalized
                user_fixed += 1
        
        # 2. Normalize Guardian phones
        guardians = db.query(Guardian).all()
        print(f"🧐 Checking {len(guardians)} guardian entries...")
        guardian_fixed = 0
        for g in guardians:
            original = g.phone
            normalized = normalize_phone(original)
            if original != normalized:
                print(f"  ⚡ Fixing Guardian {g.id} (linked to user {g.user_id}): '{original}' -> '{normalized}'")
                g.phone = normalized
                guardian_fixed += 1
        
        if user_fixed > 0 or guardian_fixed > 0:
            db.commit()
            print(f"✅ Migration complete. Fixed {user_fixed} users and {guardian_fixed} guardians.")
        else:
            print("✅ No records needed normalization.")
            
    except Exception as e:
        print(f"❌ Migration failed: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    normalize_database()

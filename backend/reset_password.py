from database.engine import get_db, SessionLocal
from database.models import User
from services.auth_service import hash_password

db = SessionLocal()
try:
    user = db.query(User).filter(User.phone == "0987654321").first()
    if user:
        print(f"Resetting password for {user.name} ({user.phone}) to 1234")
        user.password_hash = hash_password("1234")
        db.commit()
        print("✅ Password reset successful.")
    else:
        print("❌ User not found.")
except Exception as e:
    print(f"Error: {e}")
finally:
    db.close()

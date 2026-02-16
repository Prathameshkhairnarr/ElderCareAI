from sqlalchemy.orm import Session
from database.engine import SessionLocal
from database.models import User
import re

def normalize_phone(phone):
    # Remove non-digits
    digits = re.sub(r'[^\d]', '', phone)
    # Take last 10
    if len(digits) > 10:
        return digits[-10:]
    return digits

def fix_phones():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        print(f"Checking {len(users)} users...")
        fixed_count = 0
        for user in users:
            original = user.phone
            normalized = normalize_phone(original)
            
            if original != normalized:
                print(f"Fixing User {user.id} ({user.name}): '{original}' -> '{normalized}'")
                user.phone = normalized
                fixed_count += 1
        
        if fixed_count > 0:
            db.commit()
            print(f"Fixed {fixed_count} phone numbers.")
        else:
            print("No users needed fixing.")
            
    except Exception as e:
        print(f"Error: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    fix_phones()

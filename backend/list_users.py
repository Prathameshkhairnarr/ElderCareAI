from sqlalchemy.orm import Session
from database.engine import SessionLocal
from database.models import User

def list_users():
    db = SessionLocal()
    try:
        users = db.query(User).all()
        with open("users_list.txt", "w", encoding="utf-8") as f:
            f.write(f"Found {len(users)} users:\n")
            for user in users:
                f.write(f"ID: {user.id} | Name: {user.name} | Phone: '{user.phone}' | Role: {user.role}\n")
        print("User list written to users_list.txt")
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    list_users()

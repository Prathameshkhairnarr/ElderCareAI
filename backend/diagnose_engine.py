from database.engine import engine, Base
from sqlalchemy import text
import database.models  # Import models to register them with Base

output = []
output.append(f"Engine URL: {engine.url}")

# Create tables
Base.metadata.create_all(bind=engine)
output.append("Called Base.metadata.create_all")

try:
    with engine.connect() as conn:
        result = conn.execute(text("PRAGMA table_info(users)"))
        output.append("Columns in 'users' table:")
        for row in result:
            output.append(str(row))
except Exception as e:
    output.append(f"Error checking schema: {e}")

with open("diagnose_output.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(output))
print("Results saved to diagnose_output.txt")

import os
import csv
import sys
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# Appending the current directory so modules can be imported
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database.engine import Base
from database.models import Medicine

# Hardcode the DB URL for local SQLITE for ElderCareAI (Check environment)
# Wait, ElderCareAI uses PostgreSQL in production, but let's check database.engine to be sure.
# I'll import engine and create a session.
from database.engine import engine, SessionLocal

CSV_FILE_PATH = r"d:\3d design\ElderCareAI\A_Z_medicines_dataset_of_India.csv"

def parse_price(price_str):
    try:
        return float(price_str)
    except (ValueError, TypeError):
        return None

def seed_medicines():
    print("Creating tables if they don't exist...")
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    # Check if we already have medicines
    count = db.query(Medicine).count()
    if count > 0:
        print(f"Database already contains {count} medicines. Skipping seed to prevent duplicates.")
        db.close()
        return

    print(f"Reading CSV from {CSV_FILE_PATH}...")
    
    if not os.path.exists(CSV_FILE_PATH):
        print(f"File not found: {CSV_FILE_PATH}")
        db.close()
        return

    medicines_to_insert = []
    
    # id,name,price(₹),Is_discontinued,manufacturer_name,type,pack_size_label,short_composition1,short_composition2
    with open(CSV_FILE_PATH, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get('Is_discontinued', '').upper() == 'TRUE':
                continue # Skip discontinued medicines
                
            comp1 = row.get('short_composition1', '').strip()
            comp2 = row.get('short_composition2', '').strip()
            composition = comp1
            if comp2:
                composition = f"{comp1} + {comp2}"
                
            med = {
                "name": row.get('name', '').strip(),
                "composition": composition,
                "manufacturer": row.get('manufacturer_name', '').strip(),
                "price": parse_price(row.get('price(₹)')),
                "type": row.get('type', '').strip(),
                "pack_size": row.get('pack_size_label', '').strip(),
            }
            # Only add if it has a valid name
            if med["name"]:
                medicines_to_insert.append(med)
            
            # Batch print to show progress
            if len(medicines_to_insert) % 50000 == 0:
                print(f"Parsed {len(medicines_to_insert)} records...")

    print(f"Starting bulk insert of {len(medicines_to_insert)} medicines...")
    
    # Bulk insert for speed
    # We chunk the insert to avoid memory issues
    CHUNK_SIZE = 10000
    for i in range(0, len(medicines_to_insert), CHUNK_SIZE):
        chunk = medicines_to_insert[i:i + CHUNK_SIZE]
        db.bulk_insert_mappings(Medicine, chunk)
        db.commit()
        print(f"Inserted {i + len(chunk)} / {len(medicines_to_insert)}")
        
    print("Seed completed successfully!")
    db.close()

if __name__ == "__main__":
    seed_medicines()

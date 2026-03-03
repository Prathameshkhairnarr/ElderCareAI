import sqlite3
import os

def inspect_db(db_path):
    if not os.path.exists(db_path):
        print(f"Error: {db_path} does not exist.")
        return

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        print(f"--- Inspecting {db_path} ---")
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        print(f"Tables: {[t[0] for t in tables]}")
        
        for table in tables:
            t_name = table[0]
            print(f"\nSchema for {t_name}:")
            cursor.execute(f"PRAGMA table_info({t_name});")
            for col in cursor.fetchall():
                print(col)
            
            cursor.execute(f"SELECT COUNT(*) FROM {t_name};")
            count = cursor.fetchone()[0]
            print(f"Row count: {count}")
            
            if count > 0:
                print(f"Sample rows from {t_name}:")
                cursor.execute(f"SELECT * FROM {t_name} LIMIT 3;")
                for row in cursor.fetchall():
                    print(row)
        
        conn.close()
    except Exception as e:
        print(f"Error inspecting {db_path}: {e}")

if __name__ == "__main__":
    inspect_db('eldercare_corrupt.db')


import sqlite3
from datetime import datetime, timedelta

def seed_health():
    conn = sqlite3.connect('eldercare.db')
    cursor = conn.cursor()
    
    user_id = 1
    now = datetime.now()
    
    vitals = [
        ('heart_rate', 72.0, 'bpm'),
        ('steps', 4500.0, 'steps'),
        ('spo2', 98.0, '%'),
        ('sleep', 7.5, 'hrs'),
        ('temperature', 98.6, '°F'),
        ('bp', 120.0, 'mmHg')
    ]
    
    print("Seeding health vitals...")
    for v_type, value, unit in vitals:
        # Seed 5 entries for each type over last 5 days
        for i in range(5):
            recorded_at = now - timedelta(days=i)
            # Add some variance
            import random
            val = value + (random.random() * 5 - 2.5)
            if v_type == 'steps': val = value - (i * 500)
            
            cursor.execute("""
                INSERT INTO health_vitals (user_id, type, value, unit, recorded_at)
                VALUES (?, ?, ?, ?, ?)
            """, (user_id, v_type, val, unit, recorded_at))
            
    conn.commit()
    conn.close()
    print("✅ Health data seeded!")

if __name__ == "__main__":
    seed_health()

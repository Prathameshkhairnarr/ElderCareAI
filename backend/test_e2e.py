import requests
import json

base_url = "http://127.0.0.1:8001"

# 1. Register
reg_data = {
    "name": "Investor Demo User",
    "phone": "0987654321",
    "password": "1234",
    "role": "elder"
}

results = []

try:
    print("🔵 Registering...")
    r = requests.post(f"{base_url}/auth/register", json=reg_data)
    results.append({"step": "register", "status": r.status_code, "body": r.json()})
    print(f"Registration Status: {r.status_code}")
    
    # 2. Login
    login_data = {"username": "0987654321", "password": "1234"}
    print("🔵 Logging in...")
    l = requests.post(f"{base_url}/auth/login", data=login_data)
    results.append({"step": "login", "status": l.status_code, "body": l.json()})
    print(f"Login Status: {l.status_code}")

except Exception as e:
    results.append({"step": "error", "detail": str(e)})
    print(f"Test failed: {e}")

with open("e2e_result.json", "w", encoding="utf-8") as f:
    json.dump(results, f, indent=2, default=str)
print("Saved to e2e_result.json")

import requests
import json

url = "http://127.0.0.1:8001/auth/login"
data = {
    "username": "0987654321",
    "password": "1234"
}

try:
    response = requests.post(url, data=data)
    result = {
        "status": response.status_code,
        "content": response.json()
    }
    with open("login_result.json", "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2)
    print("Result saved to login_result.json")
except Exception as e:
    print(f"Request failed: {e}")

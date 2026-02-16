import requests
import json

url = "http://localhost:8000/auth/register"
headers = {"Content-Type": "application/json"}
data = {
    "name": "Debug User",
    "phone": "9998887776",
    "password": "password123",
    "role": "elder",
    "firebase_token": None
}

try:
    print(f"Sending request to {url}...")
    response = requests.post(url, json=data, headers=headers)
    print(f"Status Code: {response.status_code}")
    print("Response Body:")
    print(response.text)
except Exception as e:
    print(f"Request failed: {e}")

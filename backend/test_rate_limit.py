import requests
import time

BASE_URL = "http://127.0.0.1:8000"
LOGIN_URL = f"{BASE_URL}/auth/login"

# Dummy credentials
data = {
    "username": "1234567890",
    "password": "wrongpassword"
}

print("Testing Rate Limiting on Login (Limit: 5/min)")

for i in range(1, 8):
    response = requests.post(LOGIN_URL, data=data) # Send form data
    print(f"Attempt {i}: Status Code: {response.status_code}")
    
    if response.status_code == 429:
        print("\nSUCCESS: Rate limit triggered!")
        break
    
    # Small delay
    time.sleep(0.5)

else:
    print("\nFAIL: Rate limit NOT triggered after 7 attempts.")

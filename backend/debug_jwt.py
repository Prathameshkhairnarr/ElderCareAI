import os
from datetime import datetime, timedelta, timezone
from jose import jwt, JWTError
from typing import Optional

# Setup from .env (simulated loaded values)
SECRET_KEY = "eldercare-dev-secret-key-2026"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 1440

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str) -> dict:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except JWTError as e:
        print(f"JWTError: {e}")
        raise

# Simulate flow
user_id = 1
role = "elder"
data = {"sub": str(user_id), "role": role}  # Note: sub converted to string here

print(f"Creating token with data: {data}")
try:
    token = create_access_token(data)
    print(f"Generated Token: {token}")
except Exception as e:
    print(f"Error creating token: {e}")
    exit(1)

print("\nDecoding token...")
try:
    payload = decode_token(token)
    print(f"Decoded Payload: {payload}")
    
    extracted_user_id = payload.get("sub")
    print(f"Extracted sub: {extracted_user_id} (Type: {type(extracted_user_id)})")
    
    if extracted_user_id is None:
        print("Error: sub claim is missing!")
except Exception as e:
    print(f"Error decoding token: {e}")

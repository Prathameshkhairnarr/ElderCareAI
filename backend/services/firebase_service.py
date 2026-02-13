
import firebase_admin
from firebase_admin import auth, credentials
import os

# Initialize Firebase Admin
# For production, utilize environment variable GOOGLE_APPLICATION_CREDENTIALS
# or explicitly pass certificate path.
try:
    if not firebase_admin._apps:
        # Check for service-account.json in current directory (for local dev)
        cred = None
        service_account_path = "service-account.json"
        
        if os.path.exists(service_account_path):
             cred = credentials.Certificate(service_account_path)
        
        # Initialize app with credential (if found) or default (env var)
        if cred:
            firebase_admin.initialize_app(cred)
            print(f"Firebase Admin initialized with {service_account_path}")
        else:
            firebase_admin.initialize_app()
            print("Firebase Admin initialized with default credentials")
            
except Exception as e:
    print(f"Warning: Firebase Admin init failed (might be expected in dev without creds): {e}")

def verify_firebase_token(token: str) -> str | None:
    """
    Verifies a Firebase ID token and returns the phone number if valid.
    """
    try:
        decoded_token = auth.verify_id_token(token)
        phone = decoded_token.get("phone_number")
        return phone
    except Exception as e:
        print(f"Error verifying Firebase token: {e}")
        return None

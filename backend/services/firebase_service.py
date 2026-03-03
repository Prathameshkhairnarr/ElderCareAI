
import firebase_admin
from firebase_admin import auth, credentials
import os

# Initialize Firebase Admin
# For production, utilize environment variable GOOGLE_APPLICATION_CREDENTIALS
# or explicitly pass certificate path.
_initialized_with_creds = False

try:
    if not firebase_admin._apps:
        # Check for service-account.json in current directory (for local dev)
        cred = None
        service_account_path = "service-account.json"
        
        if os.path.exists(service_account_path):
             cred = credentials.Certificate(service_account_path)
             _initialized_with_creds = True
        
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
    If backend is not configured with creds, it returns None/Skips to avoid hanging.
    """
    if not _initialized_with_creds:
        print("⚠️ Firebase Admin has no creds. Skipping strict verification to prevent hang.")
        # For dev/demo: We return None to signal "cannot verify", 
        # BUT the auth router should handle this gracefully if we want to bypass.
        # Alternatively, we can Decode the token without verify to get the phone number (insecure but works for dev)
        # Let's return a special signal or just return None.
        return None 

    print(f"🔥 Verifying Firebase token: {token[:10]}...")
    try:
        # TIMEOUT workaround: Firebase admin doesn't support timeout arg directly here, 
        # but we hope it doesn't hang if creds are present.
        decoded_token = auth.verify_id_token(token)
        phone = decoded_token.get("phone_number")
        print(f"✅ Firebase token verified. Phone: {phone}")
        return phone
    except Exception as e:
        print(f"Error verifying Firebase token: {e}")
        return None

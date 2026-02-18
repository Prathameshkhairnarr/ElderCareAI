import re

def normalize_phone(phone: str) -> str:
    """
    Normalizes a phone number by removing all non-digits and taking the last 10 digits.
    This ensures consistency across registration, login, and guardian linking.
    """
    if not phone:
        return ""
    # Remove non-digits
    digits = re.sub(r'[^\d]', '', phone)
    # Take last 10 (standard 10-digit mobile format without country code)
    if len(digits) > 10:
        return digits[-10:]
    return digits

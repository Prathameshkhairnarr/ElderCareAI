import sys
import os

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), "backend"))

try:
    from services.analysis_service import analyze_sms
    print("Successfully imported analyze_sms")
except ImportError as e:
    print(f"ImportError: {e}")
    print("Make sure scikit-learn is installed: pip install scikit-learn")
    sys.exit(1)

# Test Cases
scam_msg = "Your bank account is locked. Click here to verify identity immediately."
safe_msg = "Hey, let's meet for coffee tomorrow at 10 AM."

print(f"\nAnalyzing Scam Message: '{scam_msg}'")
result_scam = analyze_sms(scam_msg)
print(f"Is Scam: {result_scam.is_scam}")
print(f"Confidence: {result_scam.confidence}")
print(f"Explanation: {result_scam.explanation}")

print(f"\nAnalyzing Safe Message: '{safe_msg}'")
result_safe = analyze_sms(safe_msg)
print(f"Is Scam: {result_safe.is_scam}")
print(f"Confidence: {result_safe.confidence}")
print(f"Explanation: {result_safe.explanation}")

if result_scam.is_scam and not result_safe.is_scam:
    print("\nSUCCESS: Model correctly identified scam and safe messages.")
else:
    print("\nFAIL: Model failed to distinguish correctly.")

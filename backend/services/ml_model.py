"""
SMS Scam ML Classifier — Production-ready with trained model support.

Loads a pre-trained model (sms_model.pkl) if available.
Falls back to a small in-memory model if no trained model exists.
"""
import os
import logging

logger = logging.getLogger("eldercare_ai")

# Try to load the production trained model
_MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sms_model.pkl")


class ScamClassifier:
    def __init__(self):
        self.model = None
        self._using_trained = False
        self._load_model()

    def _load_model(self):
        """Try to load trained model, fall back to toy model."""
        # Try production model first
        if os.path.exists(_MODEL_PATH):
            try:
                import joblib
                self.model = joblib.load(_MODEL_PATH)
                self._using_trained = True
                logger.info(f"ScamClassifier loaded TRAINED model from {_MODEL_PATH}")
                return
            except Exception as e:
                logger.warning(f"Failed to load trained model: {e}. Using fallback.")

        # Fallback: small in-memory model
        self._train_fallback()

    def _train_fallback(self):
        """Train a small fallback model for when no trained model exists."""
        from sklearn.feature_extraction.text import CountVectorizer
        from sklearn.naive_bayes import MultinomialNB
        from sklearn.pipeline import make_pipeline

        self.model = make_pipeline(CountVectorizer(), MultinomialNB())

        X_train = [
            # Scam samples
            "Your bank account is locked due to suspicious activity.",
            "Click here to claim your lottery prize now!",
            "Urgent: Update your KYC to avoid account handling charges.",
            "Verify your identity immediately or face legal action.",
            "Congratulations! You won a $1000 gift card.",
            "IRS detected tax fraud. Call us back immediately.",
            "Hi grandma, I'm in trouble and need money strictly.",
            "Family emergency, please send cash via Western Union.",
            "Your SIM will be blocked in 24 hours. Click to verify.",
            "Earn Rs 50000 daily from home. Part time job. WhatsApp now.",
            "Your electricity will be disconnected today. Pay now.",
            "PM Kisan Yojana: Click link to get Rs 6000 in your account.",
            "Dear customer your account has been suspended click here to reactivate.",
            "You have won iPhone 15 in lucky draw. Claim now before expiry.",
            "KYC update mandatory. Your Paytm wallet will be blocked.",
            "Loan approved Rs 5 lakh. No documents needed. Apply now.",
            # Safe samples
            "Hey, are we still meeting for lunch today?",
            "Your appointment is confirmed for tomorrow at 2 PM.",
            "Happy birthday! Hope you have a great day.",
            "Can you pick up some milk on your way home?",
            "The package has been delivered to your front door.",
            "Reminder: Take your medication after dinner.",
            "Call me when you get a chance.",
            "Your OTP for login is 123456. Do not share it.",
            "Rs 500 debited from A/c XX1234. UPI ref 123456789.",
            "Your recharge of Rs 299 is successful. Validity 28 days.",
            "Order #12345 shipped. Arriving by tomorrow.",
            "Your Aadhaar has been successfully linked to your mobile.",
            "Bill generated for Rs 1200. Due date: 15 Jan. Pay via app.",
            "Flight PNR confirmed: ABC123. Departure 10:30 AM.",
            "Your SBI balance is Rs 25,430. Last txn: Rs 500 debit.",
            "Appointment with Dr. Sharma confirmed for 3 PM today.",
        ]
        y_train = [
            1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  # Scam
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  # Safe
        ]

        self.model.fit(X_train, y_train)
        self._using_trained = False
        logger.info("ScamClassifier using FALLBACK model (32 samples). Run train_pipeline.py for better accuracy.")

    def predict(self, text: str) -> dict:
        """Predict if text is scam and return probability."""
        prediction = self.model.predict([text])[0]
        proba = self.model.predict_proba([text])[0]

        # scam_probability is for class 1 (Scam)
        scam_probability = proba[1] * 100 if len(proba) > 1 else 50

        return {
            "is_scam": bool(prediction == 1),
            "confidence": int(scam_probability),
            "model_type": "trained" if self._using_trained else "fallback",
        }


# Singleton instance
classifier = ScamClassifier()

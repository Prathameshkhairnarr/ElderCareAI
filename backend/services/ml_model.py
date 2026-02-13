from sklearn.feature_extraction.text import CountVectorizer
from sklearn.naive_bayes import MultinomialNB
from sklearn.pipeline import make_pipeline
import logging

logger = logging.getLogger("eldercare_ai")

class ScamClassifier:
    def __init__(self):
        self.model = make_pipeline(CountVectorizer(), MultinomialNB())
        self._train()

    def _train(self):
        """Train on a small, hardcoded dataset for demonstration."""
        # TODO: Load from a larger dataset or file in production.
        X_train = [
            "Your bank account is locked due to suspicious activity.",
            "Click here to claim your lottery prize now!",
            "Urgent: Update your KY to avoid account handling charges.",
            "Verify your identity immediately or face legal action.",
            "Congratulations! You won a $1000 gift card.",
            "IRS detected tax fraud. Call us back immediately.",
            "Hi grandma, I'm in trouble and need money strictly.",
            "Family emergency, please send cash via Western Union.",
            
            # Non-scam / Normal messages
            "Hey, are we still meeting for lunch today?",
            "Your appointment is confirmed for tomorrow at 2 PM.",
            "Happy birthday! Hope you have a great day.",
            "Can you pick up some milk on your way home?",
            "The package has been delivered to your front door.",
            "Reminder: Take your medication after dinner.",
            "Call me when you get a chance.",
            "Your OTP for login is 123456. Do not share it."
        ]
        y_train = [
            1, 1, 1, 1, 1, 1, 1, 1,  # 1 = Scam
            0, 0, 0, 0, 0, 0, 0, 0   # 0 = Safe
        ]
        
        self.model.fit(X_train, y_train)
        logger.info("ScamClassifier trained on initial dataset.")

    def predict(self, text: str) -> dict:
        """Predict if text is scam and return probability."""
        prediction = self.model.predict([text])[0]
        proba = self.model.predict_proba([text])[0]
        
        # prohibited_proba is for class 1 (Scam)
        scam_probability = proba[1] * 100
        
        return {
            "is_scam": bool(prediction == 1),
            "confidence": int(scam_probability)
        }

# Singleton instance
classifier = ScamClassifier()

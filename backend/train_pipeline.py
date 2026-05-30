"""
ElderCare AI — SMS Scam Model Training Pipeline

Downloads UCI SMS Spam Collection, optionally combines with app-collected data,
trains a production-grade classifier, evaluates it, and saves the model.

Usage:
    python train_pipeline.py

Requirements:
    pip install scikit-learn pandas joblib requests
"""

import os
import sys
import zipfile
import requests
import pandas as pd
import numpy as np
from pathlib import Path

# ── Constants ──
UCI_URL = "https://archive.ics.uci.edu/ml/machine-learning-databases/00228/smsspamcollection.zip"
UCI_ZIP = "smsspamcollection.zip"
UCI_FILE = "SMSSpamCollection"
APP_DATA_FILE = "app_collected_sms.csv"
MODEL_OUTPUT = "sms_model.pkl"


def print_header():
    print("\n" + "=" * 60)
    print("  ElderCare AI — SMS Scam Model Training Pipeline")
    print("=" * 60 + "\n")


def download_uci_dataset():
    """Download and extract UCI SMS Spam Collection."""
    if os.path.exists(UCI_FILE):
        print(f"[✓] UCI dataset already exists: {UCI_FILE}")
        return True

    print(f"[↓] Downloading UCI SMS Spam Collection...")
    print(f"    URL: {UCI_URL}")

    try:
        response = requests.get(UCI_URL, timeout=30, stream=True)
        response.raise_for_status()

        with open(UCI_ZIP, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        print(f"[✓] Downloaded: {UCI_ZIP} ({os.path.getsize(UCI_ZIP) / 1024:.1f} KB)")

        # Extract
        with zipfile.ZipFile(UCI_ZIP, "r") as z:
            z.extractall(".")

        # Clean up zip
        os.remove(UCI_ZIP)

        if os.path.exists(UCI_FILE):
            print(f"[✓] Extracted: {UCI_FILE}")
            return True
        else:
            print(f"[✗] Extraction failed — {UCI_FILE} not found")
            return False

    except requests.exceptions.RequestException as e:
        print(f"[✗] Download failed: {e}")
        return False
    except zipfile.BadZipFile:
        print("[✗] Downloaded file is not a valid ZIP")
        if os.path.exists(UCI_ZIP):
            os.remove(UCI_ZIP)
        return False
    except Exception as e:
        print(f"[✗] Unexpected error: {e}")
        return False


def load_uci_data():
    """Load UCI SMS Spam Collection into a DataFrame."""
    print(f"\n[→] Loading UCI dataset: {UCI_FILE}")

    try:
        df = pd.read_csv(
            UCI_FILE,
            sep="\t",
            header=None,
            names=["label", "message"],
            encoding="latin-1",
        )

        # Convert labels: ham=0, spam=1
        df["label"] = df["label"].map({"ham": 0, "spam": 1})
        df = df.dropna(subset=["label", "message"])
        df["label"] = df["label"].astype(int)

        spam_count = df["label"].sum()
        ham_count = len(df) - spam_count

        print(f"    Total: {len(df)} messages")
        print(f"    Ham (safe): {ham_count} ({ham_count/len(df)*100:.1f}%)")
        print(f"    Spam (scam): {spam_count} ({spam_count/len(df)*100:.1f}%)")

        return df

    except Exception as e:
        print(f"[✗] Failed to load UCI data: {e}")
        return None


def load_app_data():
    """Load app-collected SMS data if available."""
    if not os.path.exists(APP_DATA_FILE):
        print(f"\n[⚠] App-collected data not found: {APP_DATA_FILE}")
        print(f"    Training on UCI data only.")
        print(f"    To improve accuracy, create {APP_DATA_FILE} with columns: message,label")
        print(f"    (label: 0=safe, 1=scam)")
        return None

    print(f"\n[→] Loading app-collected data: {APP_DATA_FILE}")

    try:
        df = pd.read_csv(APP_DATA_FILE)

        if "message" not in df.columns or "label" not in df.columns:
            print(f"[⚠] {APP_DATA_FILE} must have 'message' and 'label' columns. Skipping.")
            return None

        df = df.dropna(subset=["message", "label"])
        df["label"] = df["label"].astype(int)

        spam_count = df["label"].sum()
        ham_count = len(df) - spam_count

        print(f"    Total: {len(df)} messages")
        print(f"    Safe: {ham_count} | Scam: {spam_count}")

        return df

    except Exception as e:
        print(f"[⚠] Failed to load app data: {e}")
        return None


def train_model(df):
    """Train the SMS scam classifier and evaluate it."""
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import train_test_split, cross_val_score
    from sklearn.metrics import (
        accuracy_score,
        f1_score,
        precision_score,
        recall_score,
        confusion_matrix,
        classification_report,
    )
    from sklearn.pipeline import make_pipeline
    import joblib

    print("\n" + "-" * 60)
    print("  TRAINING MODEL")
    print("-" * 60)

    X = df["message"].values
    y = df["label"].values

    # Split: 80% train, 20% test
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    print(f"\n    Train set: {len(X_train)} samples")
    print(f"    Test set:  {len(X_test)} samples")

    # Build pipeline: TF-IDF + Logistic Regression
    # TF-IDF with bigrams captures phrases like "click here", "act now"
    pipeline = make_pipeline(
        TfidfVectorizer(
            max_features=15000,
            ngram_range=(1, 2),
            min_df=2,
            max_df=0.95,
            strip_accents="unicode",
            lowercase=True,
        ),
        LogisticRegression(
            C=5.0,
            max_iter=1000,
            solver="lbfgs",
            class_weight="balanced",  # Handle imbalanced data
            random_state=42,
        ),
    )

    print("\n    Training TF-IDF + Logistic Regression...")
    pipeline.fit(X_train, y_train)

    # Evaluate
    y_pred = pipeline.predict(X_test)

    accuracy = accuracy_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)

    # Confusion matrix for false positive rate
    tn, fp, fn, tp = confusion_matrix(y_test, y_pred).ravel()
    fpr = fp / (fp + tn) if (fp + tn) > 0 else 0

    # Cross-validation
    cv_scores = cross_val_score(pipeline, X, y, cv=5, scoring="f1")

    print("\n" + "-" * 60)
    print("  EVALUATION RESULTS")
    print("-" * 60)
    print(f"\n    Accuracy:           {accuracy * 100:.2f}%")
    print(f"    F1 Score:           {f1 * 100:.2f}%")
    print(f"    Precision:          {precision * 100:.2f}%")
    print(f"    Recall:             {recall * 100:.2f}%")
    print(f"    False Positive Rate: {fpr * 100:.3f}%")
    print(f"    Cross-Val F1 (5-fold): {cv_scores.mean() * 100:.2f}% ± {cv_scores.std() * 100:.2f}%")
    print(f"\n    Confusion Matrix:")
    print(f"      True Negatives:  {tn} (safe correctly identified)")
    print(f"      False Positives: {fp} (safe wrongly flagged as scam)")
    print(f"      False Negatives: {fn} (scam missed)")
    print(f"      True Positives:  {tp} (scam correctly caught)")

    # Save model
    model_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), MODEL_OUTPUT)
    joblib.dump(pipeline, model_path)
    model_size = os.path.getsize(model_path) / (1024 * 1024)

    print(f"\n    Model saved: {model_path}")
    print(f"    Model size:  {model_size:.2f} MB")

    return {
        "accuracy": accuracy,
        "f1": f1,
        "precision": precision,
        "recall": recall,
        "fpr": fpr,
        "total_samples": len(df),
        "model_path": model_path,
    }


def print_summary(stats):
    """Print final summary and instructions."""
    print("\n" + "=" * 60)
    print("  TRAINING COMPLETE — SUMMARY")
    print("=" * 60)
    print(f"""
    Total Training Samples: {stats['total_samples']}
    Model Accuracy:         {stats['accuracy'] * 100:.2f}%
    F1 Score:               {stats['f1'] * 100:.2f}%
    False Positive Rate:    {stats['fpr'] * 100:.3f}%
    Model Location:         {stats['model_path']}
    """)

    print("-" * 60)
    print("  NEXT STEPS")
    print("-" * 60)
    print("""
    1. Copy sms_model.pkl to your backend folder:
       cp sms_model.pkl /path/to/backend/

    2. Update ml_model.py to load the trained model:
       model = joblib.load('sms_model.pkl')

    3. Restart your backend server:
       uvicorn main:app --reload

    4. (Optional) Add Indian scam SMS to app_collected_sms.csv
       and re-run this script to improve accuracy.
    """)
    print("=" * 60 + "\n")


def main():
    print_header()

    # Step 1: Download UCI dataset
    if not download_uci_dataset():
        print("\n[✗] Cannot proceed without UCI dataset. Exiting.")
        sys.exit(1)

    # Step 2: Load UCI data
    uci_df = load_uci_data()
    if uci_df is None:
        print("\n[✗] Failed to load UCI data. Exiting.")
        sys.exit(1)

    # Step 3: Load app-collected data (optional)
    app_df = load_app_data()

    # Step 4: Combine datasets
    if app_df is not None:
        combined_df = pd.concat([uci_df, app_df], ignore_index=True)
        print(f"\n[✓] Combined dataset: {len(combined_df)} total messages")
    else:
        combined_df = uci_df

    # Step 5: Train model
    try:
        stats = train_model(combined_df)
    except ImportError as e:
        print(f"\n[✗] Missing dependency: {e}")
        print("    Install with: pip install scikit-learn pandas joblib")
        sys.exit(1)
    except Exception as e:
        print(f"\n[✗] Training failed: {e}")
        sys.exit(1)

    # Step 6: Print summary
    print_summary(stats)


if __name__ == "__main__":
    main()

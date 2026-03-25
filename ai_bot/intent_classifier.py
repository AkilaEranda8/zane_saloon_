"""
Intent classifier with:
- TF-IDF + LinearSVC (character n-grams + word n-grams combined)
- Confidence scoring
- Low-confidence clarification threshold
- Context-aware re-scoring using previous intent
"""
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import LinearSVC
from sklearn.pipeline import Pipeline, FeatureUnion
from sklearn.base import BaseEstimator, TransformerMixin
from training_data import TRAINING_DATA

CLARIFY_THRESHOLD = 0.18   # below this → ask clarifying question


def _preprocess(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text


class TextSelector(BaseEstimator, TransformerMixin):
    def fit(self, X, y=None): return self
    def transform(self, X): return X


class IntentClassifier:
    def __init__(self):
        # Combine char-level and word-level features for better accuracy
        self._pipeline = Pipeline([
            ("features", FeatureUnion([
                ("char", TfidfVectorizer(
                    analyzer="char_wb",
                    ngram_range=(2, 5),
                    max_features=12000,
                    sublinear_tf=True,
                )),
                ("word", TfidfVectorizer(
                    analyzer="word",
                    ngram_range=(1, 3),
                    max_features=8000,
                    sublinear_tf=True,
                )),
            ])),
            ("clf", LinearSVC(C=1.5, max_iter=3000)),
        ])
        self._train()

    def _train(self):
        X, y = [], []
        for intent, phrases in TRAINING_DATA.items():
            for phrase in phrases:
                X.append(_preprocess(phrase))
                y.append(intent)
        self._pipeline.fit(X, y)

    def predict(self, text: str, prev_intent: str | None = None) -> dict:
        clean = _preprocess(text)
        intent = self._pipeline.predict([clean])[0]
        scores = self._pipeline.decision_function([clean])[0]
        classes = list(self._pipeline.classes_)

        # Normalize scores to 0–1 range
        min_s, max_s = min(scores), max(scores)
        span = max_s - min_s if max_s != min_s else 1.0
        norm = [(s - min_s) / span for s in scores]
        confidence = round(norm[classes.index(intent)], 2)

        # Context boost: if previous intent is booking flow, bias toward booking intents
        if prev_intent and confidence < 0.5:
            booking_intents = {"book_appointment", "check_services", "check_staff",
                               "check_availability", "check_prices"}
            if prev_intent in booking_intents and intent not in booking_intents:
                # Re-check if any booking intent has decent score
                for i, cls in enumerate(classes):
                    if cls in booking_intents and norm[i] > confidence * 0.8:
                        intent = cls
                        confidence = round(norm[i], 2)
                        break

        # Low confidence → signal for clarification
        needs_clarify = confidence < CLARIFY_THRESHOLD

        return {
            "intent":         intent,
            "confidence":     confidence,
            "needs_clarify":  needs_clarify,
        }


# Singleton — loaded once at startup
classifier = IntentClassifier()

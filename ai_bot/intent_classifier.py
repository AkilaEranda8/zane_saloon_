"""
Custom intent classifier — trained on salon-specific phrases.
Uses TF-IDF + LinearSVC (no external AI API needed).
"""
import re
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import LinearSVC
from sklearn.pipeline import Pipeline
from training_data import TRAINING_DATA


def _preprocess(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^\w\s]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text


class IntentClassifier:
    def __init__(self):
        self._pipeline = Pipeline([
            ("tfidf", TfidfVectorizer(
                analyzer="char_wb",
                ngram_range=(2, 4),
                max_features=8000,
                sublinear_tf=True,
            )),
            ("clf", LinearSVC(C=1.0, max_iter=2000)),
        ])
        self._train()

    def _train(self):
        X, y = [], []
        for intent, phrases in TRAINING_DATA.items():
            for phrase in phrases:
                X.append(_preprocess(phrase))
                y.append(intent)
        self._pipeline.fit(X, y)

    def predict(self, text: str) -> dict:
        clean = _preprocess(text)
        intent = self._pipeline.predict([clean])[0]
        scores = self._pipeline.decision_function([clean])[0]
        classes = self._pipeline.classes_
        # Confidence: distance from decision boundary (higher = more confident)
        max_score = float(max(scores))
        confidence = round(min(max(max_score / 3.0, 0.0), 1.0), 2)
        return {"intent": intent, "confidence": confidence}


# Singleton — loaded once at startup
classifier = IntentClassifier()

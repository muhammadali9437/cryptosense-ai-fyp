"""Loads the trained models and combines them into one signal.

Ensemble = weighted soft voting: each model's class probabilities are averaged, weighted
by that model's macro-F1 on the validation set (better models get a bigger say).
"""
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

from .deep import GRUModel
from .features import FEATURES, LABELS

MODEL_DIR = Path(__file__).resolve().parents[2] / "ml" / "models"
MODEL_NAMES = {"xgb": "XGBoost", "lgbm": "LightGBM", "gru": "GRU (deep learning)"}


class Predictor:
    def __init__(self, model_dir: Path = MODEL_DIR):
        self.model_dir = model_dir
        self.tabular: dict = {}
        self.gru: GRUModel | None = None
        self.metrics: dict = {}
        self.weights: dict = {}
        self.reload()

    def reload(self) -> None:
        self.tabular = {}
        for key in ("xgb", "lgbm"):
            p = self.model_dir / f"{key}.joblib"
            if p.exists():
                self.tabular[key] = joblib.load(p)
        try:
            self.gru = GRUModel.load(self.model_dir / "gru.pt")
        except Exception:
            self.gru = None
        mp = self.model_dir / "metrics.json"
        self.metrics = json.loads(mp.read_text()) if mp.exists() else {}
        self.weights = self.metrics.get("ensemble_weights", {})

    @property
    def models(self) -> list[str]:
        return list(self.tabular) + (["gru"] if self.gru else [])

    @property
    def ready(self) -> bool:
        return bool(self.models)

    def predict(self, feats: pd.DataFrame) -> dict:
        """feats = feature rows in time order (the last row is 'now')."""
        if not self.ready:
            return self._rules(feats.iloc[-1])

        probs: dict[str, np.ndarray] = {}
        last = feats.iloc[[-1]][FEATURES]
        for key, model in self.tabular.items():
            probs[key] = model.predict_proba(last)[0]
        if self.gru is not None:
            p = self.gru.predict_proba_window(feats)
            if p is not None:
                probs["gru"] = p

        total, wsum = np.zeros(3), 0.0
        for key, p in probs.items():
            w = float(self.weights.get(key, 1.0))
            total += w * p
            wsum += w
        avg = total / wsum
        cls = int(np.argmax(avg))
        trend = LABELS[cls]

        votes = {k: {"trend": LABELS[int(np.argmax(p))], "confidence": round(float(p.max()), 3)} for k, p in probs.items()}
        agreeing = [k for k, v in votes.items() if v["trend"] == trend] or list(votes)
        best = max(agreeing, key=lambda k: votes[k]["confidence"])
        return {
            "trend": trend,
            "confidence": round(float(avg[cls]), 3),
            "model": f"Ensemble (led by {MODEL_NAMES[best]})",
            "votes": {MODEL_NAMES[k]: v for k, v in votes.items()},
            "probabilities": {LABELS[i]: round(float(x), 3) for i, x in enumerate(avg)},
        }

    @staticmethod
    def _rules(row: pd.Series) -> dict:
        """Used only until `python -m ml.train` has been run."""
        score = (np.sign(row["sma20_dist"]) + np.sign(row["sma50_dist"]) + row["macd_cross"]
                 + (1 if row["rsi_14"] > 55 else -1 if row["rsi_14"] < 45 else 0))
        trend = "bullish" if score >= 2 else "bearish" if score <= -2 else "neutral"
        conf = round(min(0.5 + 0.1 * abs(float(score)), 0.9), 3)
        return {"trend": trend, "confidence": conf, "model": "Rule-based (run ml.train to enable AI)",
                "votes": {}, "probabilities": {}}


predictor = Predictor()
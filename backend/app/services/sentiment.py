"""News sentiment.

1st choice: FinBERT (ProsusAI/finbert), a BERT model trained on financial news.
Fallback: VADER + a crypto word list (used when transformers/torch are not installed).
"""
import logging
import threading

from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

from ..config import settings

log = logging.getLogger("cryptosense.sentiment")

CRYPTO_LEXICON = {
    "surge": 2.5, "surges": 2.5, "rally": 2.3, "rallies": 2.3, "soar": 2.6, "soars": 2.6,
    "bullish": 2.5, "inflows": 1.8, "adoption": 1.6, "approval": 2.0, "approves": 2.0,
    "record": 1.5, "breakout": 2.0, "upgrade": 1.5, "partnership": 1.5,
    "plunge": -2.8, "plunges": -2.8, "crash": -3.0, "crashes": -3.0, "dump": -2.4,
    "bearish": -2.5, "outflows": -1.8, "hack": -3.0, "hacked": -3.0, "exploit": -2.8,
    "ban": -2.5, "bans": -2.5, "lawsuit": -2.2, "sues": -2.2, "fraud": -3.0,
    "liquidations": -2.0, "sell-off": -2.4, "selloff": -2.4, "slump": -2.3,
}

_vader = SentimentIntensityAnalyzer()
_vader.lexicon.update(CRYPTO_LEXICON)

_pipe = None
_tried = False
_lock = threading.Lock()


def _finbert():
    """Load FinBERT once (first call downloads ~400 MB). Returns None if unavailable."""
    global _pipe, _tried
    with _lock:
        if not _tried:
            _tried = True
            try:
                from transformers import pipeline
                _pipe = pipeline("text-classification", model=settings.sentiment_model, top_k=None, truncation=True)
                log.info("FinBERT loaded: %s", settings.sentiment_model)
            except Exception as e:
                log.info("FinBERT not available (%s); using VADER", e.__class__.__name__)
                _pipe = None
    return _pipe


def _label(score: float) -> str:
    return "bullish" if score > 0.15 else "bearish" if score < -0.15 else "neutral"


def analyze(texts: list[str]) -> list[dict]:
    """Returns one {label, score (-1..1), model} per text."""
    if not texts:
        return []
    pipe = _finbert()
    if pipe is not None:
        try:
            out = []
            for scores in pipe(texts, batch_size=16):
                d = {s["label"].lower(): s["score"] for s in scores}
                score = d.get("positive", 0.0) - d.get("negative", 0.0)
                out.append({"label": _label(score), "score": round(score, 3), "model": "FinBERT"})
            return out
        except Exception as e:
            log.warning("FinBERT failed, falling back to VADER: %s", e)
    res = []
    for t in texts:
        score = _vader.polarity_scores(t)["compound"]
        res.append({"label": _label(score), "score": round(score, 3), "model": "VADER"})
    return res


def engine() -> str:
    return "FinBERT" if _finbert() is not None else "VADER"
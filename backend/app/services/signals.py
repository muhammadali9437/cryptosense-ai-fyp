"""Builds each coin's AI signal from live data: candles + funding + Fear & Greed + BTC trend."""
import asyncio
from datetime import datetime, timezone

from ..config import settings
from . import binance, demo
from .cache import cached
from .features import FEATURES, add_features, explain, merge_context
from .predictor import predictor
from .sentiment_index import fear_greed, fng_frame


async def _candles(symbol: str):
    async def build():
        try:
            return binance.to_frame(await binance.klines(symbol, "1h", 250)), True
        except Exception:
            return demo.candles(symbol, 250), False
    return await cached(f"candles:{symbol}", 60, build)


async def _funding(symbol: str):
    try:
        return binance.funding_frame(await binance.funding_rates(symbol, 30))
    except Exception:
        return None


async def _fng():
    try:
        return fng_frame(await fear_greed(30))
    except Exception:
        return None


async def signal_for(symbol: str) -> dict:
    (df, live), (btc, _), funding, fng = await asyncio.gather(
        _candles(symbol), _candles("BTCUSDT"), _funding(symbol), _fng()
    )
    merged = merge_context(df, funding, fng, btc)
    feats = add_features(merged).dropna(subset=FEATURES).reset_index(drop=True)
    row = feats.iloc[-1]
    pred = predictor.predict(feats)
    horizon = predictor.metrics.get("horizon_hours", 24)

    return {
        "symbol": symbol,
        "trend": pred["trend"],
        "model": pred["model"],
        "confidence": pred["confidence"],
        "horizon": f"Next {horizon} hours",
        "reasons": explain(row, pred["trend"]),
        "votes": pred["votes"],
        "probabilities": pred["probabilities"],
        "price": round(float(row["close"]), 8),
        "indicators": {k: round(float(row[k]), 4) for k in FEATURES},
        "live": live,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }


async def all_signals() -> list[dict]:
    async def build():
        out = []
        for s in settings.symbol_list:
            out.append(await signal_for(s))
        try:  # keep the chatbot's knowledge base up to date
            from .rag import kb
            await asyncio.to_thread(kb.upsert_signals, out)
        except Exception:
            pass
        return out
    return await cached("signals", 300, build)
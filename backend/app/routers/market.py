"""Market data: prices, candles, and market sentiment (Fear & Greed, funding, open interest)."""
import asyncio

from fastapi import APIRouter, HTTPException, Query

from ..config import settings
from ..services import binance
from ..services.cache import cached
from ..services.market import NAMES, prices
from ..services.sentiment_index import fear_greed

router = APIRouter(prefix="/api/market", tags=["Market"])
INTERVALS = {"1m", "5m", "15m", "30m", "1h", "4h", "1d", "1w"}


@router.get("/tickers")
async def tickers():
    data = await prices()
    return [{**t, "name": NAMES.get(s, s.replace("USDT", ""))} for s, t in data.items()]


@router.get("/klines")
async def klines(symbol: str = "BTCUSDT", interval: str = "1h", limit: int = Query(90, ge=10, le=1000)):
    if interval not in INTERVALS:
        raise HTTPException(400, f"interval must be one of {sorted(INTERVALS)}")
    try:
        rows = await binance.klines(symbol.upper(), interval, limit)
    except Exception:
        raise HTTPException(503, "Binance is not reachable right now.")
    return [{"time": r[0], "open": float(r[1]), "high": float(r[2]), "low": float(r[3]),
             "close": float(r[4]), "volume": float(r[5])} for r in rows]


@router.get("/sentiment")
async def market_sentiment():
    """Feeds the 'Market mood' gauge: Fear & Greed (7 days) + futures funding and open interest per coin."""
    async def build():
        try:
            fng = await fear_greed(7)
        except Exception:
            fng = []

        async def one(symbol: str):
            try:
                rates, oi = await asyncio.gather(binance.funding_rates(symbol, 1), binance.open_interest(symbol))
                return {"symbol": symbol, "funding_rate_pct": float(rates[-1]["fundingRate"]) * 100, "open_interest": oi}
            except Exception:
                return {"symbol": symbol, "funding_rate_pct": None, "open_interest": None}

        futures = await asyncio.gather(*(one(s) for s in settings.symbol_list))
        return {
            "fear_greed": [{"value": int(f["value"]), "label": f["value_classification"], "timestamp": int(f["timestamp"])}
                           for f in fng],
            "futures": futures,
        }
    return await cached("market_sentiment", 300, build)
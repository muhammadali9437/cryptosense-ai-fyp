"""Live prices for the tracked coins (cached a few seconds), with a demo fallback."""
from ..config import settings
from . import binance, demo
from .cache import cached
NAMES = {
    "BTCUSDT": "Bitcoin", "ETHUSDT": "Ethereum", "BNBUSDT": "BNB",
    "SOLUSDT": "Solana", "XRPUSDT": "XRP", "ADAUSDT": "Cardano",
}
async def prices() -> dict[str, dict]:
    """{symbol: ticker} for every tracked coin. Adds live=True/False."""
    async def build():
        try:
            rows = await binance.tickers(settings.symbol_list)
            return {r["symbol"]: {**binance.simple_ticker(r), "live": True} for r in rows}
        except Exception:
            out = {}
            for s in settings.symbol_list:
                p = demo.SEED_PRICES.get(s, 100.0)
                out[s] = {"symbol": s, "price": p, "change_pct": 0.0, "high": p * 1.02,
                          "low": p * 0.98, "quote_volume": 0.0, "live": False}
            return out
    return await cached("prices", 5, build)
async def price_of(symbol: str) -> float | None:
    p = (await prices()).get(symbol)
    if p:
        return p["price"]
    try:
        rows = await binance.tickers([symbol])
        return float(rows[0]["lastPrice"])
    except Exception:
        return None

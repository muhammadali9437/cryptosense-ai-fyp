"""New coin listings on Binance, found for free:
1. exchangeInfo lists every USDT pair that is trading.
2. The first daily candle of a pair (klines with startTime=0) = its listing date.
3. Pairs listed in the last LISTINGS_WINDOW_DAYS days are "new". Risk comes from
   daily volatility and 24h volume. Results are stored in the `listings` table.
"""
import asyncio
from datetime import datetime, timedelta, timezone
import numpy as np
from sqlalchemy import select
from ..config import settings
from ..database import SessionLocal
from ..models import Listing
from . import binance
SKIP_SUFFIXES = ("UPUSDT", "DOWNUSDT", "BULLUSDT", "BEARUSDT")
STABLES = {"USDC", "FDUSD", "TUSD", "BUSD", "DAI", "USDP", "EUR", "EURI", "AEUR", "USDE", "XUSD", "PAXG"}
def risk_level(volatility: float, volume: float) -> int:
    if volatility > 8 or volume < 5e6:
        return 2
    if volatility > 4 or volume < 3e7:
        return 1
    return 0
def note_for(risk: int, change: float) -> str:
    move = (f"up {change:.0f}% since listing" if change >= 0 else f"down {abs(change):.0f}% since listing")
    return {
        0: f"Calmer than most new coins and {move}. Still young, so keep positions small.",
        1: f"Moves a lot day to day and is {move}. Use a stop-loss and a small amount.",
        2: f"Very wild or thinly traded, {move}. One large order can swing the price. Treat as a gamble.",
    }[risk]
async def refresh() -> int:
    """Update the listings table. Returns how many new pairs were found."""
    info = await binance.exchange_info()
    pairs = [
        s["symbol"] for s in info.get("symbols", [])
        if s.get("status") == "TRADING" and s.get("quoteAsset") == "USDT"
        and s.get("isSpotTradingAllowed", True)
        and not s["symbol"].endswith(SKIP_SUFFIXES) and s.get("baseAsset") not in STABLES
    ]
    with SessionLocal() as db:
        known = set(db.scalars(select(Listing.symbol)).all())
    missing = [p for p in pairs if p not in known]
    sem = asyncio.Semaphore(5)
    async def first_candle(symbol: str):
        async with sem:
            try:
                rows = await binance.klines(symbol, "1d", 1, start_time=0)
                return symbol, rows[0] if rows else None
            except Exception:
                return symbol, None
    found = await asyncio.gather(*(first_candle(p) for p in missing))
    with SessionLocal() as db:
        for symbol, row in found:
            if row is None:
                continue
            db.add(Listing(
                symbol=symbol,
                base=symbol[:-4],
                listed_at=datetime.fromtimestamp(row[0] / 1000, timezone.utc),
                first_price=float(row[1]),
            ))
        db.commit()
    await _update_recent()
    return sum(1 for _, r in found if r is not None)
async def _update_recent() -> None:
    cutoff = datetime.now(timezone.utc) - timedelta(days=settings.listings_window_days)
    with SessionLocal() as db:
        recent = [l for l in db.scalars(select(Listing)).all() if _aware(l.listed_at) >= cutoff]
    if not recent:
        return
    tickers = {t["symbol"]: t for t in await binance.all_tickers()}
    async def vol(symbol: str) -> float:
        try:
            closes = [float(r[4]) for r in await binance.klines(symbol, "1d", 30)]
            rets = np.diff(closes) / np.array(closes[:-1]) * 100
            return float(np.std(rets)) if len(rets) > 1 else 10.0
        except Exception:
            return 10.0
    vols = await asyncio.gather(*(vol(l.symbol) for l in recent))
    with SessionLocal() as db:
        for l, v in zip(recent, vols):
            row = db.get(Listing, l.symbol)
            t = tickers.get(l.symbol)
            if row is None or t is None:
                continue
            row.last_price = float(t["lastPrice"])
            row.volume_24h = float(t["quoteVolume"])
            row.volatility = v
            row.risk = risk_level(v, row.volume_24h)
            row.updated_at = datetime.now(timezone.utc)
        db.commit()
def _aware(dt: datetime) -> datetime:
    return dt if dt.tzinfo else dt.replace(tzinfo=timezone.utc)
def recent_listings() -> list[dict]:
    cutoff = datetime.now(timezone.utc) - timedelta(days=settings.listings_window_days)
    with SessionLocal() as db:
        rows = [l for l in db.scalars(select(Listing)).all() if _aware(l.listed_at) >= cutoff]
    rows.sort(key=lambda l: _aware(l.listed_at), reverse=True)
    out = []
    for l in rows:
        change = (l.last_price / l.first_price - 1) * 100 if l.first_price and l.last_price else 0.0
        out.append({
            "symbol": l.base,
            "pair": l.symbol,
            "name": l.base,
            "category": "New listing",
            "listed_at": _aware(l.listed_at).isoformat(),
            "price": l.last_price,
            "change_since_listing": round(change, 2),
            "volume_24h": l.volume_24h,
            "volatility": round(l.volatility, 2),
            "risk": l.risk,
            "note": note_for(l.risk, change),
        })
    return out

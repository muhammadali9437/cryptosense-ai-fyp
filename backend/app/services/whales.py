"""Large on-chain transfers ("whales").
Source: Whale Alert API when WHALE_ALERT_KEY is set, otherwise a clearly-marked demo feed.
"""
import random
import time
from datetime import datetime, timedelta, timezone
import httpx
from ..config import settings
from .cache import cached
MEANING = {
    "to_exchange": "Coins sent to an exchange are often being prepared for sale. Several in a row can pressure the price.",
    "from_exchange": "Coins pulled off an exchange usually go into long-term storage, which shrinks the supply for sale.",
    "wallet_to_wallet": "Transfers between private wallets are usually neutral: custody changes or over-the-counter deals.",
}
def classify(from_type: str, to_type: str) -> str:
    if to_type == "exchange" and from_type != "exchange":
        return "to_exchange"
    if from_type == "exchange" and to_type != "exchange":
        return "from_exchange"
    return "wallet_to_wallet"
async def _from_whale_alert() -> list[dict]:
    params = {
        "api_key": settings.whale_alert_key,
        "min_value": settings.whale_min_usd,
        "start": int(time.time()) - 3600,
        "limit": 100,
    }
    async with httpx.AsyncClient(timeout=12) as client:
        r = await client.get("https://api.whale-alert.io/v1/transactions", params=params)
        r.raise_for_status()
    out = []
    for tx in r.json().get("transactions", []):
        f, t = tx.get("from", {}), tx.get("to", {})
        flow = classify(f.get("owner_type", ""), t.get("owner_type", ""))
        out.append({
            "id": tx.get("hash") or str(tx.get("id")),
            "coin": str(tx.get("symbol", "")).upper(),
            "amount": float(tx.get("amount", 0)),
            "usd": float(tx.get("amount_usd", 0)),
            "from": f.get("owner") or "Unknown wallet",
            "to": t.get("owner") or "Unknown wallet",
            "time": datetime.fromtimestamp(tx.get("timestamp", time.time()), timezone.utc).isoformat(),
            "flow": flow,
            "meaning": MEANING[flow],
        })
    return out
def _demo(n: int = 15) -> list[dict]:
    rng = random.Random(int(time.time() // 60))
    exchanges = ["Binance", "Coinbase", "Kraken", "OKX", "Bybit"]
    coins = [("BTC", 67000, 120, 950), ("ETH", 3500, 1800, 16000),
             ("SOL", 148, 40000, 260000), ("USDT", 1, 15e6, 120e6)]
    now = datetime.now(timezone.utc)
    out = []
    for i in range(n):
        coin, price, lo, hi = rng.choice(coins)
        amount = rng.uniform(lo, hi)
        flow = rng.choice(list(MEANING))
        ex = rng.choice(exchanges)
        out.append({
            "id": f"demo-{int(time.time() // 60)}-{i}",
            "coin": coin, "amount": amount, "usd": amount * price,
            "from": ex if flow == "from_exchange" else "Unknown wallet",
            "to": ex if flow == "to_exchange" else "Unknown wallet",
            "time": (now - timedelta(minutes=3 + i * 4)).isoformat(),
            "flow": flow, "meaning": MEANING[flow],
        })
    return out
def summarize(txs: list[dict]) -> dict:
    inflow = sum(t["usd"] for t in txs if t["flow"] == "to_exchange")
    outflow = sum(t["usd"] for t in txs if t["flow"] == "from_exchange")
    if inflow + outflow == 0:
        read = "No large exchange flows in the last hour."
    elif inflow > outflow * 1.2:
        read = "More money is moving onto exchanges than off. Some big holders may be preparing to sell."
    elif outflow > inflow * 1.2:
        read = "More money is leaving exchanges than arriving. Big holders seem to be moving coins into storage."
    else:
        read = "Money is moving in and out of exchanges in roughly equal amounts."
    return {"inflow_usd": inflow, "outflow_usd": outflow, "read": read}
async def latest_whales() -> dict:
    async def build():
        txs, source = [], "demo"
        if settings.whale_alert_key:
            try:
                txs, source = await _from_whale_alert(), "whale_alert"
            except Exception:
                txs = []
        if not txs:
            txs, source = _demo(), "demo"
        txs.sort(key=lambda t: t["time"], reverse=True)
        return {"source": source, "summary": summarize(txs), "items": txs}
    return await cached("whales", 60, build)

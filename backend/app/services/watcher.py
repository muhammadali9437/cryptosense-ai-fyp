"""Background jobs:
- every ALERT_CHECK_SECONDS: check price alerts and P&L limits, write notifications
- every NEWS_INGEST_MINUTES: fetch news (with FinBERT sentiment) and add it to the RAG knowledge base
- every LISTINGS_REFRESH_HOURS: refresh new Binance listings
"""
import asyncio
import logging
from datetime import datetime, timezone

from sqlalchemy import select

from ..config import settings
from ..database import SessionLocal
from ..models import Alert, Holding, Notification
from . import listings
from .market import prices
from .news import latest_news
from .rag import kb

log = logging.getLogger("cryptosense.watcher")


def _describe(a: Alert) -> str:
    base = a.symbol.replace("USDT", "")
    return {
        "above": f"{base} rose above ${a.value:,.2f}",
        "below": f"{base} fell below ${a.value:,.2f}",
        "move": f"{base} moved more than {a.value:.0f}% in 24h",
    }[a.kind]


async def check_once() -> int:
    """Evaluate every active alert and limit once. Returns notifications created."""
    tickers = await prices()
    if not any(t.get("live") for t in tickers.values()):
        return 0  # never fire alerts on demo prices
    created = 0
    with SessionLocal() as db:
        for a in db.scalars(select(Alert).where(Alert.active.is_(True))).all():
            t = tickers.get(a.symbol)
            if not t:
                continue
            hit = (
                (a.kind == "above" and t["price"] >= a.value)
                or (a.kind == "below" and t["price"] <= a.value)
                or (a.kind == "move" and abs(t["change_pct"]) >= a.value)
            )
            if hit:
                a.active = False
                a.triggered_at = datetime.now(timezone.utc)
                db.add(Notification(user_id=a.user_id, kind="alert",
                                    message=f"Alert: {_describe(a)}. Now ${t['price']:,.2f}."))
                created += 1

        for h in db.scalars(select(Holding).where(Holding.limit_fired.is_(False))).all():
            t = tickers.get(h.symbol)
            if not t or not h.avg_buy:
                continue
            pnl = (t["price"] - h.avg_buy) / h.avg_buy * 100
            base = h.symbol.replace("USDT", "")
            msg = None
            if h.stop_loss_pct is not None and pnl <= -h.stop_loss_pct:
                msg = f"{base} reached your stop-loss ({pnl:+.2f}%). Time to review this position."
            elif h.take_profit_pct is not None and pnl >= h.take_profit_pct:
                msg = f"{base} reached your take-profit target ({pnl:+.2f}%)."
            if msg:
                h.limit_fired = True
                db.add(Notification(user_id=h.user_id, kind="limit", message=msg))
                created += 1
        db.commit()
    return created


async def alert_loop() -> None:
    while True:
        try:
            await check_once()
        except Exception as e:  # keep the loop alive
            log.warning("alert check failed: %s", e)
        await asyncio.sleep(settings.alert_check_seconds)


async def listings_loop() -> None:
    while True:
        try:
            n = await listings.refresh()
            log.info("listings refreshed, %s new pairs stored", n)
        except Exception as e:
            log.warning("listings refresh failed: %s", e)
        await asyncio.sleep(settings.listings_refresh_hours * 3600)


async def news_loop() -> None:
    """Loads the knowledge base once, then keeps adding fresh news to it."""
    try:
        n = await asyncio.to_thread(kb.build_static)
        log.info("knowledge base ready: %s lesson/guide sections", n)
    except Exception as e:
        log.warning("knowledge base build failed: %s", e)
    while True:
        try:
            items = (await latest_news())["items"]
            await asyncio.to_thread(kb.upsert_news, items)
        except Exception as e:
            log.warning("news ingest failed: %s", e)
        await asyncio.sleep(settings.news_ingest_minutes * 60)
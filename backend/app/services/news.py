"""Crypto news with sentiment (FinBERT, or VADER as fallback).

Source: CryptoPanic API when CRYPTOPANIC_KEY is set, otherwise the free
CoinDesk and Cointelegraph RSS feeds. A demo list is used only when offline.
"""
import asyncio
import email.utils
import re
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone

import httpx

from ..config import settings
from .cache import cached
from .sentiment import analyze

RSS_FEEDS = {
    "CoinDesk": "https://www.coindesk.com/arc/outboundfeeds/rss/",
    "Cointelegraph": "https://cointelegraph.com/rss",
}

COIN_WORDS = {
    "BTC": ["bitcoin", "btc"], "ETH": ["ethereum", "ether", "eth"], "BNB": ["bnb", "binance coin"],
    "SOL": ["solana", "sol"], "XRP": ["xrp", "ripple"], "ADA": ["cardano", "ada"],
}


def coins_in(text: str) -> list[str]:
    t = f" {re.sub(r'[^a-z0-9 ]', ' ', text.lower())} "
    found = [c for c, words in COIN_WORDS.items() if any(f" {w} " in t for w in words)]
    return found or ["Market"]


def sage_take(label: str, coins: list[str]) -> str:
    who = "the market" if coins == ["Market"] else ", ".join(coins)
    if label == "bullish":
        return (f"This is good news for {who}, and prices often react quickly. The first jump can fade, "
                "so wait for the chart to confirm before buying, and keep your stop-loss in place.")
    if label == "bearish":
        return (f"This could put pressure on {who}. Headlines like this cause fast drops that sometimes recover. "
                "Check your stop-loss levels rather than selling in a panic.")
    return (f"This is mostly information rather than a price mover for {who}. "
            "Keep it in mind, but let the chart and volume guide you.")


def _strip_html(s: str) -> str:
    return re.sub(r"<[^>]+>", "", s or "").replace("&nbsp;", " ").strip()


def _raw(title: str, summary: str, source: str, url: str, published: datetime) -> dict:
    return {"title": title.strip(), "summary": summary.strip()[:400], "source": source,
            "url": url, "published_at": published.isoformat()}


async def _from_rss(client: httpx.AsyncClient) -> list[dict]:
    items: list[dict] = []
    for source, url in RSS_FEEDS.items():
        try:
            r = await client.get(url, headers={"User-Agent": "CryptoSenseAI/1.0"})
            r.raise_for_status()
            for it in ET.fromstring(r.content).iter("item"):
                date = it.findtext("pubDate")
                try:
                    published = email.utils.parsedate_to_datetime(date) if date else datetime.now(timezone.utc)
                except (TypeError, ValueError):
                    published = datetime.now(timezone.utc)
                if published.tzinfo is None:
                    published = published.replace(tzinfo=timezone.utc)
                items.append(_raw(it.findtext("title") or "", _strip_html(it.findtext("description") or ""),
                                  source, it.findtext("link") or "", published))
        except Exception:
            continue
    return items


async def _from_cryptopanic(client: httpx.AsyncClient) -> list[dict]:
    r = await client.get(settings.cryptopanic_url,
                         params={"auth_token": settings.cryptopanic_key, "public": "true"})
    r.raise_for_status()
    items = []
    for p in r.json().get("results", []):
        pub = p.get("published_at")
        published = datetime.fromisoformat(pub.replace("Z", "+00:00")) if pub else datetime.now(timezone.utc)
        source = (p.get("source") or {}).get("title") or "CryptoPanic"
        items.append(_raw(p.get("title", ""), p.get("description") or "", source, p.get("url") or "", published))
    return items


def _demo() -> list[dict]:
    now = datetime.now(timezone.utc)
    samples = [
        ("Spot Bitcoin funds record a third straight week of inflows", "Funds holding Bitcoin directly took in fresh money again."),
        ("Major exchange pauses withdrawals for emergency maintenance", "Withdrawals are paused while a wallet issue is fixed."),
        ("Regulators publish draft rules for crypto trading platforms", "The draft sets licensing and reporting requirements."),
        ("Ethereum upgrade date confirmed, aiming to lower fees", "Developers agreed on a target date for the next upgrade."),
        ("Solana network slows during a traffic spike", "Transactions slowed for about forty minutes before recovering."),
    ]
    return [_raw(t, d, "Demo feed", "", now - timedelta(hours=i * 2 + 1)) for i, (t, d) in enumerate(samples)]


async def latest_news(limit: int = 40) -> dict:
    async def build():
        async with httpx.AsyncClient(timeout=12, follow_redirects=True) as client:
            items, source = [], "rss"
            if settings.cryptopanic_key:
                try:
                    items, source = await _from_cryptopanic(client), "cryptopanic"
                except Exception:
                    items = []
            if not items:
                items, source = await _from_rss(client), "rss"
        if not items:
            items, source = _demo(), "demo"
        items.sort(key=lambda i: i["published_at"], reverse=True)
        items = items[:limit]

        texts = [f"{i['title']}. {i['summary'][:200]}" for i in items]
        scores = await asyncio.to_thread(analyze, texts)  # FinBERT runs off the event loop
        for item, s in zip(items, scores):
            item["coins"] = coins_in(f"{item['title']} {item['summary']}")
            item["sentiment"], item["score"], item["sentiment_model"] = s["label"], s["score"], s["model"]
            item["sage_take"] = sage_take(s["label"], item["coins"])
        return {"source": source, "items": items}
    return await cached("news", 600, build)
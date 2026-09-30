"""News, whale transfers and new listings."""
from fastapi import APIRouter, Query

from ..services.listings import recent_listings
from ..services.news import latest_news
from ..services.whales import latest_whales

router = APIRouter(prefix="/api", tags=["Discover"])


@router.get("/news")
async def news(sentiment: str | None = Query(None, pattern="^(bullish|bearish|neutral)$"), limit: int = 30):
    data = await latest_news()
    items = [i for i in data["items"] if sentiment is None or i["sentiment"] == sentiment]
    engine = items[0]["sentiment_model"] if items else None
    return {"source": data["source"], "sentiment_engine": engine, "items": items[:limit]}


@router.get("/whales")
async def whales():
    return await latest_whales()


@router.get("/listings")
def listings():
    items = recent_listings()
    return {
        "source": "binance",
        "items": items,
        "note": None if items else "Still scanning Binance for new listings. Try again in a minute.",
    }
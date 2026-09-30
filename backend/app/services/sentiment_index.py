"""Crypto Fear & Greed Index (alternative.me, free, daily since 2018)."""
import httpx
import pandas as pd

from ..config import settings
from .cache import cached


def fng_frame(rows: list[dict]) -> pd.DataFrame:
    if not rows:
        return pd.DataFrame(columns=["time", "fng"])
    df = pd.DataFrame(rows)
    df["time"] = pd.to_datetime(df["timestamp"].astype("int64"), unit="s", utc=True)
    df["fng"] = df["value"].astype(float)
    return df[["time", "fng"]].sort_values("time").reset_index(drop=True)


async def fear_greed(limit: int = 30) -> list[dict]:
    """Newest first. Each row: value, value_classification, timestamp."""
    async def build():
        async with httpx.AsyncClient(timeout=10) as c:
            r = await c.get(settings.fear_greed_url, params={"limit": limit})
            r.raise_for_status()
            return r.json().get("data", [])
    return await cached(f"fng:{limit}", 1800, build)
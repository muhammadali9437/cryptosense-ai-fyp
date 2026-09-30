"""Binance public REST APIs (no key needed): spot prices/candles + futures funding rates."""
import json

import httpx
import pandas as pd

from ..config import settings

KLINE_COLUMNS = [
    "open_time", "open", "high", "low", "close", "volume",
    "close_time", "quote_volume", "trades", "taker_base", "taker_quote", "ignore",
]

_client: httpx.AsyncClient | None = None
_futures: httpx.AsyncClient | None = None


def client() -> httpx.AsyncClient:
    global _client
    if _client is None:
        _client = httpx.AsyncClient(base_url=settings.binance_base, timeout=12)
    return _client


def futures_client() -> httpx.AsyncClient:
    global _futures
    if _futures is None:
        _futures = httpx.AsyncClient(base_url=settings.binance_futures_base, timeout=12)
    return _futures


async def close() -> None:
    global _client, _futures
    for c in (_client, _futures):
        if c is not None:
            await c.aclose()
    _client = _futures = None


def to_frame(rows: list[list]) -> pd.DataFrame:
    """Binance kline rows -> DataFrame. Keeps taker-buy volume (buyer aggression)."""
    df = pd.DataFrame(rows, columns=KLINE_COLUMNS)
    for col in ["open", "high", "low", "close", "volume", "quote_volume", "taker_base"]:
        df[col] = df[col].astype(float)
    df["time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
    return df[["time", "open", "high", "low", "close", "volume", "quote_volume", "taker_base"]].reset_index(drop=True)


def funding_frame(rows: list[dict]) -> pd.DataFrame:
    """Futures funding-rate rows -> DataFrame(time, funding_rate in %)."""
    if not rows:
        return pd.DataFrame(columns=["time", "funding_rate"])
    df = pd.DataFrame(rows)
    df["time"] = pd.to_datetime(df["fundingTime"].astype("int64"), unit="ms", utc=True)
    df["funding_rate"] = df["fundingRate"].astype(float) * 100
    return df[["time", "funding_rate"]].sort_values("time").reset_index(drop=True)


async def klines(symbol: str, interval: str = "1h", limit: int = 200, start_time: int | None = None) -> list[list]:
    params: dict = {"symbol": symbol, "interval": interval, "limit": limit}
    if start_time is not None:
        params["startTime"] = start_time
    r = await client().get("/api/v3/klines", params=params)
    r.raise_for_status()
    return r.json()


async def funding_rates(symbol: str, limit: int = 100) -> list[dict]:
    """Funding rate history (every 8h). Positive = longs pay shorts (market leaning long)."""
    r = await futures_client().get("/fapi/v1/fundingRate", params={"symbol": symbol, "limit": limit})
    r.raise_for_status()
    return r.json()


async def open_interest(symbol: str) -> float:
    """Current open interest. History is only 30 days, so live only."""
    r = await futures_client().get("/fapi/v1/openInterest", params={"symbol": symbol})
    r.raise_for_status()
    return float(r.json()["openInterest"])


async def tickers(symbols: list[str]) -> list[dict]:
    r = await client().get(
        "/api/v3/ticker/24hr", params={"symbols": json.dumps(symbols, separators=(",", ":"))}
    )
    r.raise_for_status()
    return r.json()


async def all_tickers() -> list[dict]:
    r = await client().get("/api/v3/ticker/24hr")
    r.raise_for_status()
    return r.json()


async def exchange_info() -> dict:
    r = await client().get("/api/v3/exchangeInfo")
    r.raise_for_status()
    return r.json()


def simple_ticker(t: dict) -> dict:
    """Binance 24hr ticker -> the fields the frontend uses."""
    return {
        "symbol": t["symbol"],
        "price": float(t["lastPrice"]),
        "change_pct": float(t["priceChangePercent"]),
        "high": float(t["highPrice"]),
        "low": float(t["lowPrice"]),
        "quote_volume": float(t["quoteVolume"]),
    }
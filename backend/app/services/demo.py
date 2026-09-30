"""Synthetic market data for offline use (no internet at the viva) and `train --demo`."""
from datetime import datetime, timedelta, timezone

import numpy as np
import pandas as pd

SEED_PRICES = {
    "BTCUSDT": 67000.0, "ETHUSDT": 3500.0, "BNBUSDT": 590.0,
    "SOLUSDT": 148.0, "XRPUSDT": 0.52, "ADAUSDT": 0.45,
}


def candles(symbol: str, n: int = 500, seed: int | None = None) -> pd.DataFrame:
    """Hourly candles with trending/ranging regimes so models have patterns to learn."""
    rng = np.random.default_rng(seed if seed is not None else sum(map(ord, symbol)))
    price = SEED_PRICES.get(symbol, 100.0)
    closes, buy_share, drift = [], [], 0.0
    for i in range(n):
        if i % 120 == 0:
            drift = rng.choice([-0.0012, 0.0, 0.0, 0.0012])
        price *= 1 + drift + rng.normal(0, 0.006)
        closes.append(price)
        buy_share.append(np.clip(0.5 + drift * 60 + rng.normal(0, 0.04), 0.05, 0.95))
    close = np.array(closes)
    open_ = np.concatenate([[close[0]], close[:-1]])
    spread = np.abs(rng.normal(0, 0.003, n))
    volume = rng.lognormal(6, 0.4, n) * (1 + np.abs(close / open_ - 1) * 50)
    end = datetime.now(timezone.utc).replace(minute=0, second=0, microsecond=0)
    times = [end - timedelta(hours=n - 1 - i) for i in range(n)]
    return pd.DataFrame({
        "time": pd.to_datetime(times, utc=True), "open": open_,
        "high": np.maximum(open_, close) * (1 + spread), "low": np.minimum(open_, close) * (1 - spread),
        "close": close, "volume": volume, "quote_volume": volume * close,
        "taker_base": volume * np.array(buy_share),
    })


def funding(times: pd.Series, seed: int = 1) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    t = pd.date_range(times.min().floor("8h"), times.max(), freq="8h", tz="UTC")
    return pd.DataFrame({"time": t, "funding_rate": 0.01 + rng.normal(0, 0.015, len(t))})


def fear_greed(times: pd.Series, seed: int = 2) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    t = pd.date_range(times.min().floor("D"), times.max(), freq="D", tz="UTC")
    walk = np.clip(50 + np.cumsum(rng.normal(0, 4, len(t))), 5, 95)
    return pd.DataFrame({"time": t, "fng": walk})
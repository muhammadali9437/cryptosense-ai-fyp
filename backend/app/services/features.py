"""Features for the ML/DL models (same code for training and live prediction).
Three groups:
1. Technical indicators from candles: returns, RSI, MACD, Bollinger, ATR, SMA distance, volume.
2. Order-flow: taker-buy ratio (share of volume where buyers were aggressive).
3. Market context: futures funding rate, Fear & Greed Index, and Bitcoin's own trend.
"""
import numpy as np
import pandas as pd
TECHNICAL = [
    "ret_1", "ret_4", "ret_24", "rsi_14", "macd_hist", "macd_cross",
    "bb_pos", "bb_width", "atr_pct", "sma20_dist", "sma50_dist", "vol_ratio",
]
CONTEXT = ["taker_ratio", "funding_rate", "fng", "fng_change_7d", "btc_ret_24", "btc_sma50_dist"]
FEATURES = TECHNICAL + CONTEXT
LABELS = {0: "bearish", 1: "neutral", 2: "bullish"}
DEFAULTS = {"taker_ratio": 0.5, "funding_rate": 0.01, "fng": 50.0, "fng_change_7d": 0.0,
            "btc_ret_24": 0.0, "btc_sma50_dist": 0.0}
def merge_context(
    df: pd.DataFrame,
    funding: pd.DataFrame | None = None,
    fng: pd.DataFrame | None = None,
    btc: pd.DataFrame | None = None,
) -> pd.DataFrame:
    """Attach funding rate, Fear & Greed and BTC candles to a coin's hourly candles.
    merge_asof(direction="backward") only uses values known at that time: no look-ahead."""
    def same_time(frame: pd.DataFrame) -> pd.DataFrame:
        # pandas 3 keeps ms/s units separately; merge_asof needs one unit for every table
        frame = frame.copy()
        frame["time"] = pd.to_datetime(frame["time"], utc=True).astype("datetime64[ns, UTC]")
        return frame.sort_values("time").reset_index(drop=True)
    out = same_time(df)
    if funding is not None and len(funding):
        out = pd.merge_asof(out, same_time(funding), on="time", direction="backward")
    if fng is not None and len(fng):
        f = same_time(fng)
        f["fng_change_7d"] = f["fng"] - f["fng"].shift(7)
        out = pd.merge_asof(out, f, on="time", direction="backward")
    if btc is not None and len(btc):
        b = same_time(btc[["time", "close"]].rename(columns={"close": "btc_close"}))
        out = pd.merge_asof(out, b, on="time", direction="backward")
    return out
def add_features(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    c, h, l, v = df["close"], df["high"], df["low"], df["volume"]
    df["ret_1"] = c.pct_change(1) * 100
    df["ret_4"] = c.pct_change(4) * 100
    df["ret_24"] = c.pct_change(24) * 100
    delta = c.diff()
    gain = delta.clip(lower=0).ewm(alpha=1 / 14, adjust=False).mean()
    loss = (-delta.clip(upper=0)).ewm(alpha=1 / 14, adjust=False).mean()
    rs = gain / loss.replace(0, np.nan)
    df["rsi_14"] = (100 - 100 / (1 + rs)).fillna(100)
    ema12 = c.ewm(span=12, adjust=False).mean()
    ema26 = c.ewm(span=26, adjust=False).mean()
    macd = ema12 - ema26
    signal = macd.ewm(span=9, adjust=False).mean()
    df["macd_hist"] = (macd - signal) / c * 100
    df["macd_cross"] = np.sign(macd - signal)
    sma20 = c.rolling(20).mean()
    std20 = c.rolling(20).std()
    upper, lower = sma20 + 2 * std20, sma20 - 2 * std20
    df["bb_pos"] = (c - lower) / (upper - lower)
    df["bb_width"] = (upper - lower) / sma20 * 100
    prev = c.shift(1)
    tr = pd.concat([h - l, (h - prev).abs(), (l - prev).abs()], axis=1).max(axis=1)
    df["atr_pct"] = tr.ewm(alpha=1 / 14, adjust=False).mean() / c * 100
    df["sma20_dist"] = (c / sma20 - 1) * 100
    df["sma50_dist"] = (c / c.rolling(50).mean() - 1) * 100
    df["vol_ratio"] = v / v.rolling(24).mean()
    if "taker_base" in df:
        df["taker_ratio"] = (df["taker_base"].rolling(6).sum() / v.rolling(6).sum()).clip(0, 1)
    if "btc_close" in df:
        bc = df["btc_close"]
        df["btc_ret_24"] = bc.pct_change(24) * 100
        df["btc_sma50_dist"] = (bc / bc.rolling(50).mean() - 1) * 100
    for col, value in DEFAULTS.items():
        if col not in df:
            df[col] = value
        df[col] = df[col].fillna(value)
    return df.replace([np.inf, -np.inf], np.nan)
def add_labels(df: pd.DataFrame, horizon: int = 24, threshold: float = 1.5) -> pd.DataFrame:
    """Target: price change `horizon` hours later.
    > +threshold% = bullish (2), < -threshold% = bearish (0), otherwise neutral (1)."""
    df = df.copy()
    future = (df["close"].shift(-horizon) / df["close"] - 1) * 100
    df["future_ret"] = future
    df["label"] = np.where(future > threshold, 2, np.where(future < -threshold, 0, 1))
    df.loc[future.isna(), "label"] = np.nan
    return df
def explain(row: pd.Series, trend: str) -> list[str]:
    """Plain-language reasons behind a signal. Facts that agree with the trend come first."""
    facts: list[tuple[int, str]] = []
    s20, s50 = row["sma20_dist"], row["sma50_dist"]
    if s20 > 0 and s50 > 0:
        facts.append((1, "Price is above its 20- and 50-hour moving averages."))
    elif s20 < 0 and s50 < 0:
        facts.append((-1, "Price is below its 20- and 50-hour moving averages."))
    else:
        facts.append((0, "Price is between its 20- and 50-hour averages, so the trend is unclear."))
    if row["macd_cross"] > 0:
        facts.append((1, "MACD is above its signal line, so momentum is pointing up."))
    elif row["macd_cross"] < 0:
        facts.append((-1, "MACD is below its signal line, so momentum is pointing down."))
    rsi = row["rsi_14"]
    if rsi >= 70:
        facts.append((-1, f"RSI is {rsi:.0f}: the rise is stretched and a pullback is common here."))
    elif rsi <= 30:
        facts.append((1, f"RSI is {rsi:.0f}: the fall is stretched and sellers may be tiring."))
    elif rsi >= 55:
        facts.append((1, f"RSI is {rsi:.0f}: buyers are stronger, but not yet stretched."))
    elif rsi <= 45:
        facts.append((-1, f"RSI is {rsi:.0f}: sellers are slightly stronger."))
    tr = row["taker_ratio"]
    if tr > 0.55:
        facts.append((1, f"{tr * 100:.0f}% of recent volume came from aggressive buyers."))
    elif tr < 0.45:
        facts.append((-1, f"Only {tr * 100:.0f}% of recent volume came from buyers; sellers are pushing."))
    fr = row["funding_rate"]
    if fr > 0.05:
        facts.append((-1, f"Futures funding is high ({fr:.3f}%): many traders are betting on a rise, which often ends in a shake-out."))
    elif fr < 0:
        facts.append((1, f"Futures funding is negative ({fr:.3f}%): traders lean short, and short squeezes can push prices up."))
    fng = row["fng"]
    if fng >= 75:
        facts.append((-1, f"Fear & Greed is {fng:.0f} (extreme greed): the market may be overheated."))
    elif fng <= 25:
        facts.append((1, f"Fear & Greed is {fng:.0f} (extreme fear): panic often creates buying chances."))
    b = row["btc_sma50_dist"]
    if b > 1:
        facts.append((1, "Bitcoin itself is trending up, which usually lifts the whole market."))
    elif b < -1:
        facts.append((-1, "Bitcoin itself is trending down, which usually drags the market."))
    vr = row["vol_ratio"]
    if vr > 1.3:
        lean = 1 if row["ret_4"] > 0 else -1
        facts.append((lean, f"Volume is {(vr - 1) * 100:.0f}% above average, so the latest move has conviction."))
    want = {"bullish": 1, "bearish": -1}.get(trend, 0)
    facts.sort(key=lambda f: 0 if f[0] == want else 1)
    return [text for _, text in facts[:4]]

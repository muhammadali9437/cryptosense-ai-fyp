"""Sage, the chatbot, powered by RAG.

1. Retrieve: search the knowledge base (lessons, news, signals) for the question.
2. Augment: put those passages + live prices + the user's portfolio into the prompt.
3. Generate: an LLM (Groq, OpenAI-compatible) writes the answer and cites [1], [2]...
Without an LLM key (or if it fails) Sage answers with rules + live data, and still
returns the most relevant sources.
"""
import asyncio
import json
import re

import httpx

from ..config import settings
from .market import NAMES
from .rag import kb

SYSTEM_PROMPT = """You are Sage, the friendly guide inside CryptoSense AI, a crypto market analytics app.
Explain in plain, simple English that a beginner understands. Keep answers under 170 words.
Use ONLY the numbered sources and the live data provided; never invent prices, news or numbers.
Cite sources inline like [1] or [2] when you use them. If the sources don't contain the answer, say so.
You support decisions but never tell the user to buy or sell a specific coin; mention risk and
stop-losses when relevant."""


async def answer(question: str, context: dict) -> tuple[str, str, list[dict]]:
    """Returns (answer, "llm" | "rules", sources)."""
    try:
        hits = await asyncio.to_thread(kb.search, question)
    except Exception:
        hits = []
    sources = [{"n": i + 1, "title": h["meta"].get("title", ""), "kind": h["meta"].get("kind", ""),
                "url": h["meta"].get("url", ""), "published_at": h["meta"].get("published_at")}
               for i, h in enumerate(hits)]

    if settings.llm_api_key:
        try:
            return await _llm(question, context, hits), "llm", sources
        except Exception:
            pass
    return rules(question, context), "rules", sources[:3]


def _live_summary(ctx: dict) -> str:
    lines = []
    for s, t in ctx.get("prices", {}).items():
        lines.append(f"{s}: ${t['price']:,.4f} ({t['change_pct']:+.2f}% 24h)")
    for s, sig in ctx.get("signals", {}).items():
        lines.append(f"Signal {s}: {sig['trend']} {sig['confidence'] * 100:.0f}% ({sig['model']})")
    if ctx.get("fear_greed"):
        f = ctx["fear_greed"]
        lines.append(f"Fear & Greed: {f['value']} ({f['value_classification']})")
    if ctx.get("portfolio"):
        p = ctx["portfolio"]
        lines.append(f"User portfolio: value ${p['value']:,.2f}, P&L {p['pnl_pct']:+.2f}%, holdings "
                     + json.dumps([{k: h[k] for k in ('symbol', 'amount', 'avg_buy', 'pnl_pct',
                                                      'stop_loss_pct', 'take_profit_pct')} for h in p['holdings']]))
    return "\n".join(lines)


async def _llm(question: str, context: dict, hits: list[dict]) -> str:
    numbered = "\n\n".join(f"[{i + 1}] ({h['meta'].get('kind')}) {h['text'][:900]}" for i, h in enumerate(hits))
    payload = {
        "model": settings.llm_model,
        "temperature": 0.3,
        "max_tokens": 700,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"SOURCES:\n{numbered or '(none)'}\n\nLIVE DATA:\n{_live_summary(context)}"
                                        f"\n\nQUESTION: {question}"},
        ],
    }
    if "gpt-oss" in settings.llm_model:
        payload["reasoning_effort"] = "low"  # faster answers from Groq's gpt-oss models
    async with httpx.AsyncClient(timeout=30) as client:
        r = await client.post(settings.llm_base_url.rstrip("/") + "/chat/completions",
                              headers={"Authorization": f"Bearer {settings.llm_api_key}"}, json=payload)
        r.raise_for_status()
    text = (r.json()["choices"][0]["message"].get("content") or "").strip()
    if not text:
        raise ValueError("empty LLM answer")
    return text


def _usd(v: float) -> str:
    return f"${v:,.0f}" if abs(v) >= 1000 else f"${v:,.2f}" if abs(v) >= 1 else f"${v:.4f}"


def rules(question: str, ctx: dict) -> str:
    q = question.lower()

    def has(*words: str) -> bool:
        return any(w in q for w in words)

    prices: dict = ctx.get("prices", {})
    signals: dict = ctx.get("signals", {})

    if re.match(r"^(hi+|hello|hey|salam|assalam|aoa)\b", q):
        return "Hello! Ask me how a coin is doing, what an indicator means, or how your portfolio looks."

    if has("my portfolio", "my coins", "my holdings", "am i up", "am i down", "my profit", "my loss"):
        p = ctx.get("portfolio")
        if not p:
            return "Log in and add your coins in Portfolio, then I can tell you exactly how you're doing."
        if not p["holdings"]:
            return "Your portfolio is empty. Open Portfolio and tap Add holding first."
        direction = "up" if p["pnl"] >= 0 else "down"
        top = max(p["holdings"], key=lambda h: h["value"])
        share = top["value"] / p["value"] * 100 if p["value"] else 0
        text = (f"Your portfolio is worth {_usd(p['value'])}. You're {direction} {_usd(abs(p['pnl']))} "
                f"({p['pnl_pct']:+.2f}%). {top['symbol'].replace('USDT', '')} is your biggest position at {share:.0f}%.")
        if share > 50:
            text += " That's a lot in one coin; a bad week for it hits your whole portfolio."
        return text

    if has("should i buy", "should i sell", "invest", "buy now", "sell now", "good time"):
        return ("I can't tell you what to buy or sell; CryptoSense supports decisions, it doesn't make them. "
                "Check the trend on the chart, whether RSI is stretched, what the AI signal says and how confident "
                "it is, and any big news or whale moves. Most important: decide your stop-loss and how much you can "
                "afford to lose before you buy.")

    for symbol, name in NAMES.items():
        base = symbol.replace("USDT", "").lower()
        if re.search(rf"\b({base}|{name.lower()})\b", q) and symbol in prices:
            t = prices[symbol]
            s = signals.get(symbol)
            text = (f"{name} is at {_usd(t['price'])}, {'up' if t['change_pct'] >= 0 else 'down'} "
                    f"{abs(t['change_pct']):.2f}% in 24 hours (range {_usd(t['low'])} to {_usd(t['high'])}).")
            if s:
                text += (f" The AI ensemble reads it as {s['trend']} with {s['confidence'] * 100:.0f}% confidence. "
                         f"Main reason: {s['reasons'][0] if s['reasons'] else 'mixed indicators'}")
            return text + " Remember, signals are a second opinion, not an order."

    if has("fear", "greed") and ctx.get("fear_greed"):
        f = ctx["fear_greed"]
        return (f"The Fear & Greed Index is {f['value']} ({f['value_classification']}). Extreme fear often appears "
                "near bottoms, extreme greed near tops. Use it as context, not as a buy or sell button.")
    if has("funding"):
        return ("Funding is a small fee between futures traders every 8 hours. High positive funding means most bet "
                "on a rise, which often ends in a shake-out; negative funding can lead to a short squeeze.")
    if has("rsi", "overbought", "oversold"):
        return ("RSI scores recent moves from 0 to 100. Above 70 the rise is stretched; below 30 the fall is "
                "stretched. In strong trends it can stay high for days, so use it as a warning light.")
    if has("whale"):
        return ("Whales are wallets holding huge amounts. Coins moving onto exchanges often mean selling may follow; "
                "coins moving off exchanges usually mean holding. Look for several moves in the same direction.")
    if has("new coin", "listing", "listed", "new token", "meme"):
        return ("New coins can double in a day and halve the next. Use only money you could lose completely, buy "
                "small, and set a stop-loss straight away. The New listings page rates each one by risk.")
    if has("stop", "take profit", "take-profit", "limit"):
        return ("A stop-loss is where you exit if a trade goes wrong; a take-profit is where you lock in a gain. "
                "Set both in Profit & loss limits and CryptoSense will alert you when either is reached.")
    if has("signal", "model", "xgboost", "lightgbm", "gru", "predict", "accurate", "accuracy") or re.search(r"\bai\b", q):
        return ("Three models, XGBoost, LightGBM and a GRU deep-learning network, read indicators, funding rates, "
                "Fear & Greed and Bitcoin's trend. They label the next 24 hours bullish, bearish or neutral, and their "
                "votes are combined. They don't predict exact prices, and high confidence can still be wrong.")
    if has("up and down", "go up", "go down", "why do", "why does", "why is", "pump", "dump", "crash"):
        return ("A price is just the last deal between a buyer and a seller. More eager buyers push it up; more "
                "eager sellers push it down. News, fear, excitement and whales change how eager each side is.")
    if has("how do i use", "how to use", "help", "guide", "start"):
        return ("Daily routine: read my summary on Overview, check the chart and AI signals, glance at News and "
                "Whale watch, keep your Portfolio protected with stop-losses, and set Alerts. The Academy teaches each step.")
    return ("I'm not sure I understood. Try asking about a coin (\"How is ETH doing?\"), an indicator like RSI, "
            "your portfolio, whales, new listings, or how to use CryptoSense.")
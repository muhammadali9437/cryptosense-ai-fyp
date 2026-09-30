"""Ask Sage (RAG chatbot). Works logged-out; when logged in, Sage also sees your portfolio."""
import asyncio

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from ..database import get_db
from ..models import User
from ..schemas import ChatIn, ChatOut
from ..security import optional_user
from ..services import sage
from ..services.market import prices
from ..services.news import latest_news
from ..services.rag import kb
from ..services.sentiment_index import fear_greed
from ..services.signals import all_signals
from .portfolio import build_portfolio

router = APIRouter(prefix="/api/chat", tags=["Ask Sage (RAG)"])


@router.post("", response_model=ChatOut)
async def chat(body: ChatIn, user: User | None = Depends(optional_user), db: Session = Depends(get_db)):
    try:
        fng = (await fear_greed(1))[0]
    except Exception:
        fng = None
    context = {
        "prices": await prices(),
        "signals": {s["symbol"]: s for s in await all_signals()},
        "fear_greed": fng,
        "portfolio": (await build_portfolio(user, db)).model_dump() if user else None,
    }
    answer, source, sources = await sage.answer(body.question, context)
    return ChatOut(answer=answer, source=source, sources=sources)


@router.get("/knowledge")
async def knowledge_status():
    """Which search engine the RAG uses and how many documents it holds."""
    return await asyncio.to_thread(kb.status)


@router.post("/knowledge/rebuild")
async def rebuild_knowledge():
    """Re-load lessons, latest news and signals into the knowledge base."""
    n = await asyncio.to_thread(kb.build_static)
    news = (await latest_news())["items"]
    await asyncio.to_thread(kb.upsert_news, news)
    await asyncio.to_thread(kb.upsert_signals, await all_signals())
    return {**(await asyncio.to_thread(kb.status)), "static_docs": n, "news_docs": len(news)}
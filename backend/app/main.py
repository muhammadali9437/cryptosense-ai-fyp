"""CryptoSense AI backend. Start with:  uvicorn app.main:app --reload
Interactive API docs: http://127.0.0.1:8000/docs
"""
import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import Base, engine
from .routers import alerts, auth, chat, discover, market, portfolio, signals
from .services import binance
from .services.predictor import predictor
from .services.watcher import alert_loop, listings_loop, news_loop

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    tasks = [asyncio.create_task(t()) for t in (alert_loop, news_loop, listings_loop)]
    logging.getLogger("cryptosense").info(
        "Models loaded: %s", predictor.models or "none (run: python -m ml.train)"
    )
    yield
    for t in tasks:
        t.cancel()
    await binance.close()


app = FastAPI(
    title=settings.app_name,
    version="2.0.0",
    description=(
        "Real-time crypto analytics: live data, ML + deep-learning market signals, portfolio, alerts, "
        "FinBERT news sentiment, whales, new listings and the RAG-powered Sage chatbot."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

for r in (auth, market, signals, portfolio, alerts, discover, chat):
    app.include_router(r.router)


@app.get("/", tags=["Health"])
def root():
    return {"app": settings.app_name, "status": "ok", "docs": "/docs", "models": predictor.models}
"""AI market-state signals (bullish / bearish / neutral + confidence + reasons)."""
from fastapi import APIRouter, HTTPException

from ..config import settings
from ..services.predictor import predictor
from ..services.signals import all_signals, signal_for

router = APIRouter(prefix="/api/signals", tags=["AI signals"])


@router.get("")
async def signals():
    return await all_signals()


@router.get("/model-info")
def model_info():
    """Accuracy, F1, ensemble weights and settings of the trained models (for the report / viva)."""
    return {"trained": predictor.ready, "models": predictor.models, **predictor.metrics}


@router.post("/reload")
def reload_models():
    """Reload models from ml/models after retraining, without restarting the server."""
    predictor.reload()
    return {"trained": predictor.ready, "models": predictor.models}


@router.get("/{symbol}")
async def one_signal(symbol: str):
    symbol = symbol.upper()
    if symbol not in settings.symbol_list:
        raise HTTPException(404, f"Not tracked. Use one of {settings.symbol_list}")
    return await signal_for(symbol)
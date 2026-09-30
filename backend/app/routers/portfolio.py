"""Portfolio with live profit & loss, and per-coin P&L limits."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session
from ..database import get_db
from ..models import Holding, User
from ..schemas import HoldingIn, LimitsIn, PortfolioOut
from ..security import current_user
from ..services.market import price_of, prices
router = APIRouter(prefix="/api/portfolio", tags=["Portfolio & limits"])
async def build_portfolio(user: User, db: Session) -> PortfolioOut:
    live = await prices()
    rows, value, cost = [], 0.0, 0.0
    for h in db.scalars(select(Holding).where(Holding.user_id == user.id)).all():
        price = live.get(h.symbol, {}).get("price") or await price_of(h.symbol) or h.avg_buy
        v, c = h.amount * price, h.amount * h.avg_buy
        value, cost = value + v, cost + c
        rows.append({
            "symbol": h.symbol, "amount": h.amount, "avg_buy": h.avg_buy, "price": price,
            "value": v, "pnl": v - c, "pnl_pct": (price / h.avg_buy - 1) * 100,
            "stop_loss_pct": h.stop_loss_pct, "take_profit_pct": h.take_profit_pct,
        })
    rows.sort(key=lambda r: r["value"], reverse=True)
    pnl = value - cost
    return PortfolioOut(value=value, cost=cost, pnl=pnl,
                        pnl_pct=(pnl / cost * 100) if cost else 0.0, holdings=rows)
def _find(db: Session, user: User, symbol: str) -> Holding | None:
    return db.scalar(select(Holding).where(Holding.user_id == user.id, Holding.symbol == symbol.upper()))
@router.get("", response_model=PortfolioOut)
async def get_portfolio(user: User = Depends(current_user), db: Session = Depends(get_db)):
    return await build_portfolio(user, db)
@router.post("", response_model=PortfolioOut, status_code=201)
async def add_holding(body: HoldingIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    symbol = body.symbol.upper()
    h = _find(db, user, symbol)
    if h:
        total = h.amount + body.amount
        h.avg_buy = (h.avg_buy * h.amount + body.price * body.amount) / total
        h.amount = total
        h.limit_fired = False
    else:
        db.add(Holding(user_id=user.id, symbol=symbol, amount=body.amount, avg_buy=body.price))
    db.commit()
    return await build_portfolio(user, db)
@router.delete("/{symbol}", response_model=PortfolioOut)
async def remove_holding(symbol: str, user: User = Depends(current_user), db: Session = Depends(get_db)):
    h = _find(db, user, symbol)
    if not h:
        raise HTTPException(404, "You don't hold this coin.")
    db.delete(h)
    db.commit()
    return await build_portfolio(user, db)
@router.put("/{symbol}/limits", response_model=PortfolioOut)
async def set_limits(symbol: str, body: LimitsIn, user: User = Depends(current_user), db: Session = Depends(get_db)):
    h = _find(db, user, symbol)
    if not h:
        raise HTTPException(404, "You don't hold this coin.")
    h.stop_loss_pct = body.stop_loss_pct
    h.take_profit_pct = body.take_profit_pct
    h.limit_fired = False
    db.commit()
    return await build_portfolio(user, db)

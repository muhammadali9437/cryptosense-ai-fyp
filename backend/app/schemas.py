"""Request and response shapes (validated by Pydantic)."""
from datetime import datetime
from typing import Literal
from pydantic import BaseModel, Field
class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=80)
    email: str = Field(min_length=5, max_length=160, pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
    password: str = Field(min_length=6, max_length=128)
class LoginIn(BaseModel):
    email: str
    password: str
class UserOut(BaseModel):
    id: int
    name: str
    email: str
class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut
class HoldingIn(BaseModel):
    symbol: str = Field(min_length=5, max_length=20)
    amount: float = Field(gt=0)
    price: float = Field(gt=0, description="Price paid per coin in USD")
class LimitsIn(BaseModel):
    stop_loss_pct: float | None = Field(default=None, ge=1, le=90)
    take_profit_pct: float | None = Field(default=None, ge=1, le=1000)
class HoldingOut(BaseModel):
    symbol: str
    amount: float
    avg_buy: float
    price: float
    value: float
    pnl: float
    pnl_pct: float
    stop_loss_pct: float | None
    take_profit_pct: float | None
class PortfolioOut(BaseModel):
    value: float
    cost: float
    pnl: float
    pnl_pct: float
    holdings: list[HoldingOut]
class AlertIn(BaseModel):
    symbol: str = Field(min_length=5, max_length=20)
    kind: Literal["above", "below", "move"]
    value: float = Field(gt=0)
class AlertOut(BaseModel):
    id: int
    symbol: str
    kind: str
    value: float
    active: bool
    triggered_at: datetime | None
    created_at: datetime
class NotificationOut(BaseModel):
    id: int
    message: str
    kind: str
    seen: bool
    created_at: datetime
class ChatIn(BaseModel):
    question: str = Field(min_length=1, max_length=1000)
class SourceOut(BaseModel):
    n: int
    title: str
    kind: str
    url: str = ""
    published_at: str | None = None
class ChatOut(BaseModel):
    answer: str
    source: Literal["llm", "rules"]
    sources: list[SourceOut] = []

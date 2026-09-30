"""Database tables."""
from datetime import datetime, timezone
from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship
from .database import Base
def now() -> datetime:
    return datetime.now(timezone.utc)
class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    email: Mapped[str] = mapped_column(String(160), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(200))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    holdings: Mapped[list["Holding"]] = relationship(back_populates="user", cascade="all, delete-orphan")
    alerts: Mapped[list["Alert"]] = relationship(back_populates="user", cascade="all, delete-orphan")
class Holding(Base):
    """A coin the user owns, with optional stop-loss / take-profit (in %)."""
    __tablename__ = "holdings"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    symbol: Mapped[str] = mapped_column(String(20))
    amount: Mapped[float] = mapped_column(Float)
    avg_buy: Mapped[float] = mapped_column(Float)
    stop_loss_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    take_profit_pct: Mapped[float | None] = mapped_column(Float, nullable=True)
    limit_fired: Mapped[bool] = mapped_column(Boolean, default=False)
    user: Mapped[User] = relationship(back_populates="holdings")
class Alert(Base):
    """Price alert. kind = above | below | move (24h % move)."""
    __tablename__ = "alerts"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    symbol: Mapped[str] = mapped_column(String(20))
    kind: Mapped[str] = mapped_column(String(10))
    value: Mapped[float] = mapped_column(Float)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    triggered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    user: Mapped[User] = relationship(back_populates="alerts")
class Notification(Base):
    """Message created when an alert or a P&L limit fires."""
    __tablename__ = "notifications"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    message: Mapped[str] = mapped_column(String(300))
    kind: Mapped[str] = mapped_column(String(20), default="alert")
    seen: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
class Listing(Base):
    """Cache of Binance USDT pairs and the date each one was first listed."""
    __tablename__ = "listings"
    symbol: Mapped[str] = mapped_column(String(20), primary_key=True)
    base: Mapped[str] = mapped_column(String(20))
    listed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    first_price: Mapped[float] = mapped_column(Float, default=0)
    last_price: Mapped[float] = mapped_column(Float, default=0)
    volume_24h: Mapped[float] = mapped_column(Float, default=0)
    volatility: Mapped[float] = mapped_column(Float, default=0)
    risk: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)

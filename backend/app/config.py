
"""All settings, read from environment variables or the .env file."""
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[1]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "CryptoSense AI API"
    database_url: str = "sqlite:///./cryptosense.db"
    jwt_secret: str = "change-this-to-a-long-random-string"
    jwt_expire_minutes: int = 60 * 24 * 7
    cors_origins: str = "*"
    symbols: str = "BTCUSDT,ETHUSDT,BNBUSDT,SOLUSDT,XRPUSDT,ADAUSDT"

    # Market data (all free, no key)
    binance_base: str = "https://api.binance.com"
    binance_futures_base: str = "https://fapi.binance.com"
    fear_greed_url: str = "https://api.alternative.me/fng/"

    # Optional outside services
    cryptopanic_key: str = ""
    cryptopanic_url: str = "https://cryptopanic.com/api/developer/v2/posts/"
    whale_alert_key: str = ""
    whale_min_usd: int = 1_000_000

    # Sage chatbot (any OpenAI-compatible API; Groq free tier by default)
    llm_api_key: str = ""
    llm_base_url: str = "https://api.groq.com/openai/v1"
    llm_model: str = "openai/gpt-oss-20b"

    # Deep-learning models (optional, need requirements-ai.txt)
    sentiment_model: str = "ProsusAI/finbert"
    embed_model: str = "sentence-transformers/all-MiniLM-L6-v2"
    rag_dir: str = str(ROOT / "rag_store")
    rag_top_k: int = 5

    # Background jobs
    alert_check_seconds: int = 30
    news_ingest_minutes: int = 15
    listings_refresh_hours: int = 6
    listings_window_days: int = 60

    @property
    def symbol_list(self) -> list[str]:
        return [s.strip().upper() for s in self.symbols.split(",") if s.strip()]

    @property
    def cors_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()
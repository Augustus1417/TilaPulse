from pathlib import Path

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=PROJECT_ROOT / ".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = Field(validation_alias=AliasChoices("DATABASE_URL", "DB_CONNECTION_STRING"))
    admin_api_key: str = ""
    cors_origins: list[str] = ["http://localhost", "http://localhost:3000", "http://localhost:5000", "http://localhost:8080"]
    prediction_alpha: float = 0.7
    prediction_beta: float = 0.3
    prediction_window_size: int = 20
    online_threshold_seconds: int = 30
    lstm_model_path: str = str(PROJECT_ROOT / "models" / "lstm_model.pt")
    timezone: str = "Asia/Manila"


settings = Settings()
from pathlib import Path

from pydantic import AliasChoices, Field
from pydantic_settings import BaseSettings, SettingsConfigDict

from app.core.ai_config import AI_CONFIG

PROJECT_ROOT = Path(__file__).resolve().parents[2]

# Configurable healthy water-quality ranges (assumption, replace with real farm/BFAR data).
TEMP_MIN_C = 24.0
TEMP_MAX_C = 32.0
PH_MIN = 6.5
PH_MAX = 8.5
DO_MIN_MGL = 5.0


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=PROJECT_ROOT / ".env", env_file_encoding="utf-8", extra="ignore")

    database_url: str = Field(validation_alias=AliasChoices("DATABASE_URL", "DB_CONNECTION_STRING"))
    admin_api_key: str = ""
    cors_origins: list[str] = ["http://localhost", "http://localhost:3000", "http://localhost:5000", "http://localhost:8080"]
    prediction_alpha: float = AI_CONFIG.fusion_alpha
    prediction_beta: float = AI_CONFIG.fusion_beta
    prediction_window_size: int = AI_CONFIG.window_size
    prediction_interval_minutes: int = 60
    prediction_min_readings: int = AI_CONFIG.window_size
    scheduler_enabled: bool = True
    prediction_risk_low_threshold: float = AI_CONFIG.risk_low_threshold
    prediction_risk_high_threshold: float = AI_CONFIG.risk_high_threshold
    online_threshold_seconds: int = 30
    lstm_model_path: str = str(PROJECT_ROOT / "models" / "lstm_model.pt")
    timezone: str = "Asia/Manila"


settings = Settings()
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    cors_origins: list[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8080",
    ]
    prediction_alpha: float = 0.7
    prediction_beta: float = 0.3
    prediction_window_size: int = 20
    lstm_model_path: str = "models/lstm_model.pt"


settings = Settings()

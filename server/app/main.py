from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.config import settings
from app.db import Base, engine, migrate_auth_schema
from app.prediction import PredictionService
from app.routers import alerts, devices, health, predict, readings


app = FastAPI(title="TilaPulse Sensor API", version="1.0.0")
app.state.limiter = devices.limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Device-Key", "X-Admin-Key"],
)
app.include_router(health.router)
app.include_router(readings.router)
app.include_router(alerts.router)
app.include_router(devices.router)
app.include_router(devices.admin_router)
app.include_router(predict.router)


@app.on_event("startup")
def initialize_application() -> None:
    migrate_auth_schema()
    Base.metadata.create_all(bind=engine)
    prediction_service = PredictionService(settings.lstm_model_path, settings.prediction_alpha, settings.prediction_beta, settings.prediction_window_size)
    try:
        prediction_service.load_model()
    except RuntimeError:
        prediction_service.model = None
    app.state.prediction_service = prediction_service
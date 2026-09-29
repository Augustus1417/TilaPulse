from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.db import Base, engine
from app.prediction import PredictionService
from app.routers import devices, health, predict, readings


app = FastAPI(title="TilaPulse Sensor API", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "X-Device-Key", "X-Admin-Key"],
)
app.include_router(health.router)
app.include_router(readings.router)
app.include_router(devices.router)
app.include_router(devices.admin_router)
app.include_router(predict.router)


@app.on_event("startup")
def initialize_application() -> None:
    Base.metadata.create_all(bind=engine)
    prediction_service = PredictionService(settings.lstm_model_path, settings.prediction_alpha, settings.prediction_beta, settings.prediction_window_size)
    try:
        prediction_service.load_model()
    except RuntimeError:
        prediction_service.model = None
    app.state.prediction_service = prediction_service
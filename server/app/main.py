from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import devices, mock, predictions, readings
from app.core.config import settings


app = FastAPI(
    title="TilaPulse Sensor API",
    description="HTTP API for tilapia aquaculture sensor readings.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(readings.router)
app.include_router(devices.router)
app.include_router(mock.router)
app.include_router(predictions.router)


@app.get("/", tags=["health"])
def api_information() -> dict[str, str]:
    return {
        "name": "TilaPulse Sensor API",
        "version": "0.1.0",
        "status": "prototype",
        "storage": "in-memory",
    }


@app.get("/api/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok"}

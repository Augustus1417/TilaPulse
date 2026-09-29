from fastapi import APIRouter

from app.db import engine


router = APIRouter(tags=["health"])


@router.get("/")
def api_information() -> dict[str, str]:
    return {"name": "TilaPulse Sensor API", "version": "1.0.0", "status": "ok", "storage": engine.dialect.name}


@router.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok", "storage": engine.dialect.name}
import os

os.environ["DATABASE_URL"] = "sqlite:///./test_tilapulse.db"
os.environ["ADMIN_API_KEY"] = "test-admin-key"

import pytest
from fastapi.testclient import TestClient

from app.db import Base, SessionLocal, engine
from app.main import app
from app.models import AlertModel, DeviceModel, DeviceSessionModel, PredictionModel, ReadingModel
from app.routers.devices import limiter


@pytest.fixture
def client():
    limiter.reset()
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        db.query(DeviceSessionModel).delete()
        db.query(AlertModel).delete()
        db.query(PredictionModel).delete()
        db.query(ReadingModel).delete()
        db.query(DeviceModel).delete()
        db.commit()
    with TestClient(app) as client:
        yield client


def register(client: TestClient, device_id: str, key: str) -> dict[str, object]:
    response = client.post(
        "/api/admin/devices",
        headers={"X-Admin-Key": "test-admin-key"},
        json={"device_id": device_id, "name": device_id, "device_key": key},
    )
    assert response.status_code == 201
    return response.json()


def connect(client: TestClient, device_id: str, key: str) -> str:
    response = client.post(
        "/api/devices/connect", json={"device_id": device_id, "device_key": key}
    )
    assert response.status_code == 200
    return response.json()["token"]


def reading(device_id: str, temperature: float) -> dict[str, object]:
    return {"device_id": device_id, "temperature": temperature, "ph": 7.2, "dissolved_oxygen": 5.5}
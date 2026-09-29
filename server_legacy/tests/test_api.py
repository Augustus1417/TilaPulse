import os

import pytest
from fastapi.testclient import TestClient

os.environ["DB_CONNECTION_STRING"] = "sqlite:///./data/test.db"

from app.db import Base, SessionLocal, engine
from app.main import app
from app.core.config import settings
from app.models import DeviceModel, ReadingModel


client = TestClient(app)


@pytest.fixture(autouse=True)
def clear_readings():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        db.query(ReadingModel).delete()
        db.query(DeviceModel).delete()
        db.commit()
    settings.device_keys = {"pond-a": "secret-a", "pond-b": "secret-b"}
    yield


def reading_payload(device_id: str = "pond-a", temperature: float = 28.4) -> dict:
    return {
        "device_id": device_id,
        "temperature": temperature,
        "ph": 7.2,
        "dissolved_oxygen": 5.8,
    }


def post_reading(device_id: str = "pond-a", temperature: float = 28.4):
    return client.post(
        "/api/readings",
        json=reading_payload(device_id, temperature),
        headers={"X-Device-Key": settings.device_keys[device_id]},
    )


def test_health():
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_describes_persistent_api():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["storage"] == "sqlite"


def test_create_reading_registers_device_and_adds_timestamp():
    response = post_reading()
    assert response.status_code == 201
    body = response.json()
    assert set(body) == {"device_id", "temperature", "ph", "dissolved_oxygen", "timestamp"}
    assert body["device_id"] == "pond-a"
    assert len(body["timestamp"]) == 19

    devices = client.get("/api/devices")
    assert devices.status_code == 200
    assert devices.json()[0]["device_id"] == "pond-a"


def test_bad_or_missing_device_key_returns_401():
    payload = reading_payload()
    assert client.post("/api/readings", json=payload).status_code == 401
    assert client.post("/api/readings", json=payload, headers={"X-Device-Key": "wrong"}).status_code == 401


def test_invalid_reading_is_rejected():
    payload = reading_payload()
    payload["ph"] = 15
    response = client.post("/api/readings", json=payload, headers={"X-Device-Key": "secret-a"})
    assert response.status_code == 422


def test_readings_are_isolated_between_devices():
    post_reading("pond-a", 28.0)
    post_reading("pond-b", 31.0)

    response = client.get("/api/readings", params={"device_id": "pond-a"})
    assert [reading["temperature"] for reading in response.json()] == [28.0]

    response = client.get("/api/readings/pond-b")
    assert [reading["temperature"] for reading in response.json()] == [31.0]


def test_latest_requires_device_and_is_isolated():
    assert client.get("/api/readings/latest").status_code == 422
    post_reading("pond-a", 28.4)
    post_reading("pond-b", 30.4)
    response = client.get("/api/readings/latest", params={"device_id": "pond-a"})
    assert response.status_code == 200
    assert response.json()["temperature"] == 28.4


def test_prediction_does_not_blend_devices(monkeypatch):
    post_reading("pond-a", 28.0)
    post_reading("pond-b", 35.0)
    captured = {}

    def fake_predict(records):
        captured["records"] = records
        return {
            "lstm_probability": 0.2,
            "bocpd_probability": 0.1,
            "risk_score": 0.17,
            "synthetic_model_notice": "test",
        }

    monkeypatch.setattr("app.prediction.prediction_service.predict", fake_predict)
    response = client.post("/api/predict", json={"device_id": "pond-a"})
    assert response.status_code == 200
    assert [record["device_id"] for record in captured["records"]] == ["pond-a"]


def test_prediction_requires_known_device_readings():
    response = client.post("/api/predict", json={"device_id": "pond-a"})
    assert response.status_code == 404


def test_removed_routes_are_not_available():
    paths = client.get("/openapi.json").json()["paths"]
    assert "/api/mock/generate" not in paths
    assert "/api/mock/generate-batch" not in paths

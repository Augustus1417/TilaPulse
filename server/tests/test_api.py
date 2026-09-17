import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.reading_service import reading_service


@pytest.fixture(autouse=True)
def clear_readings():
    reading_service.clear()
    yield
    reading_service.clear()


client = TestClient(app)


def reading_payload(device_id: str = "ESP32-TILAPIA-001") -> dict:
    return {
        "device_id": device_id,
        "temperature": 28.4,
        "ph": 7.2,
        "dissolved_oxygen": 5.8,
    }


def test_health():
    response = client.get("/api/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_root_describes_prototype_api():
    response = client.get("/")

    assert response.status_code == 200
    assert response.json()["storage"] == "in-memory"


def test_create_reading_adds_timestamp():
    response = client.post("/api/readings", json=reading_payload())

    assert response.status_code == 201
    body = response.json()
    assert body["device_id"] == "ESP32-TILAPIA-001"
    assert body["temperature"] == 28.4
    assert len(body["timestamp"]) == 19
    assert body["timestamp"][4] == "-"
    assert body["timestamp"][10] == " "


def test_invalid_reading_is_rejected():
    payload = reading_payload()
    payload["ph"] = 15

    response = client.post("/api/readings", json=payload)

    assert response.status_code == 422


def test_prediction_reports_missing_model_without_crashing():
    response = client.post("/api/predict", json={"readings": [reading_payload()]})

    assert response.status_code == 503
    assert "train_lstm.py" in response.json()["detail"]


def test_latest_reading_returns_404_until_device_submits():
    missing = client.get("/api/readings/latest")
    assert missing.status_code == 404

    client.post("/api/readings", json=reading_payload())
    response = client.get("/api/readings/latest", params={"device_id": "ESP32-TILAPIA-001"})

    assert response.status_code == 200
    assert response.json()["device_id"] == "ESP32-TILAPIA-001"


def test_readings_can_be_filtered_and_limited():
    client.post("/api/readings", json=reading_payload("device-a"))
    client.post("/api/readings", json=reading_payload("device-b"))
    client.post("/api/readings", json=reading_payload("device-a"))

    response = client.get("/api/readings", params={"device_id": "device-a", "limit": 1})

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["device_id"] == "device-a"


def test_devices_returns_last_seen_devices():
    client.post("/api/readings", json=reading_payload("device-a"))
    client.post("/api/readings", json=reading_payload("device-b"))

    response = client.get("/api/devices")

    assert response.status_code == 200
    assert {device["device_id"] for device in response.json()} == {"device-a", "device-b"}
    assert all(device["last_seen"] for device in response.json())


def test_mock_generate_returns_and_stores_reading():
    response = client.post("/api/mock/generate")

    assert response.status_code == 201
    assert response.json()["device_id"] == "ESP32-TILAPIA-001"
    assert client.get("/api/readings").json()


def test_mock_generate_batch_returns_requested_count():
    response = client.post("/api/mock/generate-batch", params={"count": 5})

    assert response.status_code == 201
    readings = response.json()
    assert len(readings) == 5
    assert all(reading["device_id"] == "ESP32-TILAPIA-001" for reading in readings)
    assert len(client.get("/api/readings", params={"limit": 10}).json()) == 5

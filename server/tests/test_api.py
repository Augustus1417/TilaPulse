import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.readings import reading_store


@pytest.fixture(autouse=True)
def clear_readings():
    reading_store.clear()
    yield
    reading_store.clear()


client = TestClient(app)


def reading_payload() -> dict:
    return {
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
    assert set(body) == {"temperature", "ph", "dissolved_oxygen", "timestamp"}
    assert body["temperature"] == 28.4
    assert len(body["timestamp"]) == 19
    assert body["timestamp"][4] == "-"
    assert body["timestamp"][10] == " "


def test_invalid_reading_is_rejected():
    payload = reading_payload()
    payload["ph"] = 15

    response = client.post("/api/readings", json=payload)

    assert response.status_code == 422


def test_prediction_returns_fused_risk_when_model_is_available():
    response = client.post("/api/predict", json={"readings": [reading_payload()]})

    assert response.status_code == 200
    body = response.json()
    assert {"lstm_probability", "bocpd_probability", "risk_score"} <= body.keys()
    assert 0 <= body["risk_score"] <= 1


def test_latest_reading_returns_404_until_device_submits():
    missing = client.get("/api/readings/latest")
    assert missing.status_code == 404

    client.post("/api/readings", json=reading_payload())
    response = client.get("/api/readings/latest")

    assert response.status_code == 200
    assert response.json()["temperature"] == 28.4


def test_readings_are_newest_first_and_limited():
    client.post("/api/readings", json=reading_payload())
    client.post("/api/readings", json={**reading_payload(), "temperature": 29.0})
    client.post("/api/readings", json={**reading_payload(), "temperature": 30.0})

    response = client.get("/api/readings", params={"limit": 1})

    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["temperature"] == 30.0


def test_removed_routes_are_not_available():
    paths = client.get("/openapi.json").json()["paths"]

    assert "/api/devices" not in paths
    assert "/api/mock/generate" not in paths
    assert "/api/mock/generate-batch" not in paths

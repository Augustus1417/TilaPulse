from fastapi.testclient import TestClient

from app.core.config import settings
from app.db import SessionLocal
from app.models import PredictionModel
from app.scheduler import run_scheduled_predictions
from tests.conftest import reading, register


def test_scheduled_job_creates_scheduled_prediction(client: TestClient, monkeypatch) -> None:
    register(client, "pond-a", "secret-a")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    monkeypatch.setattr(settings, "prediction_min_readings", 1)
    monkeypatch.setattr(
        client.app.state.prediction_service,
        "predict",
        lambda records: {"lstm_probability": 0.2, "bocpd_probability": 0.1, "risk_score": 0.17},
    )

    run_scheduled_predictions(client.app)

    with SessionLocal() as db:
        prediction = db.query(PredictionModel).one()
        assert prediction.source == "scheduled"


def test_scheduled_job_continues_after_one_device_fails(client: TestClient, monkeypatch) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    for device_id, key in (("pond-a", "secret-a"), ("pond-b", "secret-b")):
        client.post("/api/readings", json=reading(device_id, 28), headers={"X-Device-Key": key})
    monkeypatch.setattr(settings, "prediction_min_readings", 1)

    def predict(records):
        if records[0]["device_id"] == "pond-a":
            raise RuntimeError("model failure")
        return {"lstm_probability": 0.2, "bocpd_probability": 0.1, "risk_score": 0.17}

    monkeypatch.setattr(client.app.state.prediction_service, "predict", predict)
    run_scheduled_predictions(client.app)

    with SessionLocal() as db:
        predictions = db.query(PredictionModel).all()
        assert len(predictions) == 1
        assert predictions[0].device_id == "pond-b"

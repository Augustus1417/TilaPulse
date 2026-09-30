from fastapi.testclient import TestClient

from tests.conftest import connect, reading, register


def test_prediction_window_never_mixes_devices(client: TestClient, monkeypatch) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    client.post("/api/readings", json=reading("pond-b", 35), headers={"X-Device-Key": "secret-b"})
    captured = {}

    def fake_predict(records):
        captured["records"] = records
        return {"lstm_probability": 0.2, "bocpd_probability": 0.1, "risk_score": 0.17, "synthetic_model_notice": "test"}

    monkeypatch.setattr(client.app.state.prediction_service, "predict", fake_predict)
    token = connect(client, "pond-a", "secret-a")
    response = client.post("/api/predict", json={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert {record["device_id"] for record in captured["records"]} == {"pond-a"}
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
    response = client.post("/api/devices/pond-a/predict", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 201
    assert response.json()["risk_label"] == "low"
    assert {record["device_id"] for record in captured["records"]} == {"pond-a"}


def test_latest_risk_reads_stored_prediction_without_recomputing(client: TestClient, monkeypatch) -> None:
    register(client, "pond-a", "secret-a")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    token = connect(client, "pond-a", "secret-a")
    calls = 0

    def fake_predict(records):
        nonlocal calls
        calls += 1
        return {"lstm_probability": 0.4, "bocpd_probability": 0.2, "risk_score": 0.34}

    monkeypatch.setattr(client.app.state.prediction_service, "predict", fake_predict)
    headers = {"Authorization": f"Bearer {token}"}
    created = client.post("/api/devices/pond-a/predict", headers=headers)
    first = client.get("/api/devices/pond-a/risk/latest", headers=headers)
    second = client.get("/api/devices/pond-a/risk/latest", headers=headers)

    assert created.status_code == 201
    assert first.status_code == 200
    assert second.status_code == 200
    assert first.json() == created.json()
    assert second.json() == first.json()
    assert calls == 1


def test_latest_risk_returns_404_before_first_assessment(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    response = client.get(
        "/api/devices/pond-a/risk/latest",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


def test_prediction_routes_require_matching_session_device(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token_b = connect(client, "pond-b", "secret-b")
    headers = {"Authorization": f"Bearer {token_b}"}

    assert client.post("/api/devices/pond-a/predict", headers=headers).status_code == 403
    assert client.get("/api/devices/pond-a/risk/latest", headers=headers).status_code == 403


def test_each_explicit_assessment_creates_a_new_prediction(client: TestClient, monkeypatch) -> None:
    register(client, "pond-a", "secret-a")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    token = connect(client, "pond-a", "secret-a")
    monkeypatch.setattr(
        client.app.state.prediction_service,
        "predict",
        lambda records: {"lstm_probability": 0.2, "bocpd_probability": 0.1, "risk_score": 0.17},
    )
    headers = {"Authorization": f"Bearer {token}"}
    first = client.post("/api/devices/pond-a/predict", headers=headers).json()
    second = client.post("/api/devices/pond-a/predict", headers=headers).json()

    assert second["id"] != first["id"]
    history = client.get("/api/devices/pond-a/risk/history", headers=headers).json()
    assert [item["id"] for item in history] == [second["id"], first["id"]]
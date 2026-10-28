from fastapi.testclient import TestClient

from tests.conftest import connect, reading, register


def test_unregistered_device_cannot_post(client: TestClient) -> None:
    response = client.post("/api/readings", json=reading("unknown", 28), headers={"X-Device-Key": "secret"})
    assert response.status_code == 404


def test_device_key_is_required_and_reading_is_timestamped(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    token = connect(client, "pond-a", "pond-secret")
    payload = reading("pond-a", 28.4)
    assert client.post("/api/readings", json=payload).status_code == 401
    response = client.post("/api/readings", json=payload, headers={"X-Device-Key": "pond-secret"})
    assert response.status_code == 201
    assert len(response.json()["timestamp"]) == 19


def test_overlong_device_key_is_rejected(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    response = client.post(
        "/api/readings",
        json=reading("pond-a", 28),
        headers={"X-Device-Key": "x" * 73},
    )
    assert response.status_code == 401


def test_readings_are_isolated_between_devices(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    client.post("/api/readings", json=reading("pond-b", 35), headers={"X-Device-Key": "secret-b"})
    token = connect(client, "pond-a", "secret-a")
    response = client.get("/api/readings", params={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {token}"})
    assert [item["temperature"] for item in response.json()] == [28]
    assert client.get("/api/readings/latest", params={"device_id": "pond-b"}, headers={"Authorization": f"Bearer {token}"}).status_code == 403


def test_reading_series_buckets_and_returns_thresholds(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    for temperature in (28.1, 28.4):
        response = client.post(
            "/api/readings",
            json=reading("pond-a", temperature),
            headers={"X-Device-Key": "secret-a"},
        )
        assert response.status_code == 201

    response = client.get(
        "/api/readings/series",
        params={"device_id": "pond-a", "range": "24h"},
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["bucket_seconds"] == 900
    assert body["thresholds"] == {
        "temperature": {"min": 24.0, "max": 32.0},
        "ph": {"min": 6.5, "max": 8.5},
        "dissolved_oxygen": {"min": 5.0, "max": None},
    }
    assert sum(point["count"] for point in body["points"]) == 2
    assert body["points"][0]["temperature"] == {"avg": 28.25, "min": 28.1, "max": 28.4}


def test_reading_series_rejects_invalid_range_and_other_device(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token = connect(client, "pond-a", "secret-a")
    headers = {"Authorization": f"Bearer {token}"}

    assert client.get(
        "/api/readings/series",
        params={"device_id": "pond-a", "range": "2h"},
        headers=headers,
    ).status_code == 422
    assert client.get(
        "/api/readings/series",
        params={"device_id": "pond-b"},
        headers=headers,
    ).status_code == 403


def test_command_returns_reading_state_and_updates_last_seen(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    response = client.get("/api/devices/pond-a/command", headers={"X-Device-Key": "pond-secret"})
    assert response.status_code == 200
    assert response.json() == {"reading_enabled": True}

    devices = client.get("/api/devices").json()
    assert devices[0]["last_seen"] is not None
    assert devices[0]["online"] is True


def test_command_rejects_missing_or_wrong_device_key(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    assert client.get("/api/devices/pond-a/command").status_code == 401
    assert client.get(
        "/api/devices/pond-a/command", headers={"X-Device-Key": "wrong-key"}
    ).status_code == 401
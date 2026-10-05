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
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


def test_readings_are_isolated_between_devices(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    client.post("/api/readings", json=reading("pond-a", 28), headers={"X-Device-Key": "secret-a"})
    client.post("/api/readings", json=reading("pond-b", 35), headers={"X-Device-Key": "secret-b"})
    token = connect(client, "pond-a", "secret-a")
    response = client.get("/api/readings", params={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {token}"})
    assert [item["temperature"] for item in response.json()] == [28]
    assert client.get("/api/readings/latest", params={"device_id": "pond-b"}, headers={"Authorization": f"Bearer {token}"}).status_code == 403
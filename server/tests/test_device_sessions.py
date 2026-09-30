from fastapi.testclient import TestClient

from tests.conftest import connect, register


def test_connect_rejects_invalid_credentials(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    assert client.post("/api/devices/connect", json={"device_id": "pond-a", "device_key": "wrong"}).status_code == 401
    response = client.post("/api/devices/connect", json={"device_id": "unknown", "device_key": "secret-a"})
    assert response.status_code == 401
    assert response.json()["detail"] == "invalid device credentials"


def test_connect_is_rate_limited(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    responses = [client.post("/api/devices/connect", json={"device_id": "pond-a", "device_key": "wrong"}) for _ in range(6)]
    assert responses[-1].status_code == 429


def test_rotation_revokes_existing_sessions(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    response = client.post("/api/admin/devices/pond-a/rotate-key", headers={"X-Admin-Key": "test-admin-key"})
    assert response.status_code == 200
    assert client.get("/api/readings", params={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {token}"}).status_code == 401
    assert connect(client, "pond-a", response.json()["device_key"])


def test_disconnect_only_revokes_its_own_session(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    first = connect(client, "pond-a", "secret-a")
    second = connect(client, "pond-a", "secret-a")
    assert client.delete("/api/devices/disconnect", headers={"Authorization": f"Bearer {first}"}).status_code == 204
    assert client.get("/api/readings", params={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {first}"}).status_code == 401
    assert client.get("/api/readings", params={"device_id": "pond-a"}, headers={"Authorization": f"Bearer {second}"}).status_code == 200
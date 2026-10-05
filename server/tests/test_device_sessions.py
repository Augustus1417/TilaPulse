from fastapi.testclient import TestClient

from app.core import security
from tests.conftest import connect, register


def test_connect_rejects_overlong_device_key(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    response = client.post(
        "/api/devices/connect",
        json={"device_id": "pond-a", "device_key": "x" * 73},
    )
    assert response.status_code == 401


def test_connect_rejects_authentication_backend_failure(
    client: TestClient, monkeypatch
) -> None:
    register(client, "pond-a", "secret-a")

    def fail_verification(device_key: str, device_key_hash: str) -> bool:
        raise RuntimeError("bcrypt backend unavailable")

    monkeypatch.setattr(security.pwd_context, "verify", fail_verification)
    response = client.post(
        "/api/devices/connect",
        json={"device_id": "pond-a", "device_key": "secret-a"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "invalid device credentials"


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


def test_reading_state_requires_a_session_for_the_same_device(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token_a = connect(client, "pond-a", "secret-a")
    token_b = connect(client, "pond-b", "secret-b")

    response = client.patch(
        "/api/devices/pond-a/reading-state",
        json={"enabled": False},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 200
    assert response.json()["reading_enabled"] is False
    assert response.json()["online"] is False
    assert client.patch(
        "/api/devices/pond-a/reading-state",
        json={"enabled": True},
        headers={"Authorization": f"Bearer {token_b}"},
    ).status_code == 403
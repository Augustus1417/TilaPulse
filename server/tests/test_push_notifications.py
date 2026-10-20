from fastapi.testclient import TestClient

from app.db import SessionLocal
from app.models import PushTokenModel
from tests.conftest import connect, register


def auth(token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_push_token_registration_is_idempotent_and_session_scoped(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    first = connect(client, "pond-a", "secret-a")
    second = connect(client, "pond-a", "secret-a")

    response = client.post(
        "/api/devices/pond-a/push-token", json={"token": "fcm-token"}, headers=auth(first)
    )
    assert response.status_code == 200
    assert client.post(
        "/api/devices/pond-a/push-token", json={"token": "fcm-token"}, headers=auth(first)
    ).status_code == 200
    with SessionLocal() as db:
        assert db.query(PushTokenModel).count() == 1

    assert client.delete("/api/devices/pond-a/push-token", headers=auth(second)).status_code == 204
    with SessionLocal() as db:
        assert db.query(PushTokenModel).count() == 1
    assert client.delete("/api/devices/pond-a/push-token", headers=auth(first)).status_code == 204
    with SessionLocal() as db:
        assert db.query(PushTokenModel).count() == 0


def test_push_routes_require_matching_session(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token_a = connect(client, "pond-a", "secret-a")
    token_b = connect(client, "pond-b", "secret-b")

    assert client.post(
        "/api/devices/pond-b/push-token", json={"token": "fcm-token"}, headers=auth(token_a)
    ).status_code == 403
    assert client.post(
        "/api/devices/pond-a/push-token", json={"token": "fcm-token"}, headers=auth(token_b)
    ).status_code == 403
    assert client.post(
        "/api/devices/pond-a/push-token", json={"token": "fcm-token"}
    ).status_code == 401

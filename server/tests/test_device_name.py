from fastapi.testclient import TestClient

from tests.conftest import connect, register


def test_connected_device_can_rename_and_listing_reflects_name(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    headers = {"Authorization": f"Bearer {token}"}

    response = client.patch("/api/devices/pond-a/name", json={"name": "  North Pond  "}, headers=headers)

    assert response.status_code == 200
    assert response.json()["name"] == "North Pond"
    assert client.get("/api/devices").json()[0]["name"] == "North Pond"


def test_device_name_validation_and_session_authorization(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token_a = connect(client, "pond-a", "secret-a")
    token_b = connect(client, "pond-b", "secret-b")

    assert client.patch(
        "/api/devices/pond-a/name",
        json={"name": "   "},
        headers={"Authorization": f"Bearer {token_a}"},
    ).status_code == 422
    assert client.patch(
        "/api/devices/pond-a/name",
        json={"name": "x" * 51},
        headers={"Authorization": f"Bearer {token_a}"},
    ).status_code == 422
    assert client.patch(
        "/api/devices/pond-a/name",
        json={"name": "Other device"},
        headers={"Authorization": f"Bearer {token_b}"},
    ).status_code == 403
    assert client.patch("/api/devices/pond-a/name", json={"name": "No token"}).status_code == 401

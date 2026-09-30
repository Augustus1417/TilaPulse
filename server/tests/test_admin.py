from fastapi.testclient import TestClient

from tests.conftest import register


def test_admin_key_required(client: TestClient) -> None:
    payload = {"device_id": "pond-a", "name": "North Pond", "device_key": "pond-secret"}
    assert client.post("/api/admin/devices", json=payload).status_code == 401
    assert client.post("/api/admin/devices", headers={"X-Admin-Key": "wrong"}, json=payload).status_code == 401
    response = client.post("/api/admin/devices", headers={"X-Admin-Key": "test-admin-key"}, json=payload)
    assert response.status_code == 201
    assert response.json()["device_key"] == "pond-secret"
    assert "non-retrievable" in response.json()["warning"]


def test_public_devices_do_not_expose_keys(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    response = client.get("/api/devices")
    assert response.status_code == 200
    assert "device_key" not in response.json()[0]


def test_admin_listing_never_returns_keys(client: TestClient) -> None:
    register(client, "pond-a", "pond-secret")
    response = client.get("/api/admin/devices", headers={"X-Admin-Key": "test-admin-key"})
    assert response.status_code == 200
    assert "device_key" not in response.json()[0]
    assert "device_key_hash" not in response.json()[0]
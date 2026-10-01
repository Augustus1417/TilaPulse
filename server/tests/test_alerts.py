from fastapi.testclient import TestClient

from tests.conftest import connect, reading, register


def post_reading(client: TestClient, device_id: str, key: str, temperature: float) -> None:
    response = client.post(
        "/api/readings",
        json=reading(device_id, temperature),
        headers={"X-Device-Key": key},
    )
    assert response.status_code == 201


def test_breaching_readings_create_one_alert_without_duplicates(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    post_reading(client, "pond-a", "secret-a", 20)
    post_reading(client, "pond-a", "secret-a", 19)

    response = client.get(
        "/api/devices/pond-a/alerts",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert len(response.json()) == 1
    assert response.json()[0]["parameter"] == "temperature"
    assert response.json()[0]["threshold_breached"] == "below_min"


def test_resolving_alert_allows_a_future_alert(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    post_reading(client, "pond-a", "secret-a", 20)
    headers = {"Authorization": f"Bearer {token}"}

    alert = client.get("/api/devices/pond-a/alerts", headers=headers).json()[0]
    assert client.delete(f"/api/devices/pond-a/alerts/{alert['id']}", headers=headers).status_code == 204
    assert client.get("/api/devices/pond-a/alerts", headers=headers).json() == []

    post_reading(client, "pond-a", "secret-a", 19)
    alerts = client.get("/api/devices/pond-a/alerts", headers=headers).json()
    assert len(alerts) == 1
    assert alerts[0]["id"] != alert["id"]


def test_alert_delete_rejects_another_devices_session(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    register(client, "pond-b", "secret-b")
    token_a = connect(client, "pond-a", "secret-a")
    token_b = connect(client, "pond-b", "secret-b")
    post_reading(client, "pond-a", "secret-a", 20)
    alert = client.get(
        "/api/devices/pond-a/alerts",
        headers={"Authorization": f"Bearer {token_a}"},
    ).json()[0]

    response = client.delete(
        f"/api/devices/pond-a/alerts/{alert['id']}",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 403


def test_alert_delete_returns_not_found_for_unknown_alert(client: TestClient) -> None:
    register(client, "pond-a", "secret-a")
    token = connect(client, "pond-a", "secret-a")
    response = client.delete(
        "/api/devices/pond-a/alerts/999999",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404
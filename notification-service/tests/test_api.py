from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["service"] == "notification"


def test_create_and_list_notifications():
    client.delete("/notifications")

    created = client.post(
        "/notifications",
        json={"message": "Task created", "task_id": 1, "source": "backend"},
    )
    assert created.status_code == 201
    body = created.json()
    assert body["message"] == "Task created"
    assert body["task_id"] == 1

    listed = client.get("/notifications")
    assert listed.status_code == 200
    assert len(listed.json()) == 1


def test_cors_headers():
    response = client.get(
        "/notifications",
        headers={"Origin": "http://localhost:8080"},
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") in ["*", "http://localhost:8080"]


def test_clear_notifications():
    client.post(
        "/notifications",
        json={"message": "To clear", "task_id": 99, "source": "test"},
    )
    delete_res = client.delete("/notifications")
    assert delete_res.status_code == 204

    listed = client.get("/notifications")
    assert listed.status_code == 200
    assert len(listed.json()) == 0

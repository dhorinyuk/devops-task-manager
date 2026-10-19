import os
from unittest.mock import patch

import pytest
from app.database import Base, get_db
from app.main import app
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

# Default to in-memory SQLite for isolated integration tests
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("NOTIFICATION_URL", "http://localhost:9999")


engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture()
def client():
    Base.metadata.create_all(bind=engine)

    def override_get_db():
        db = TestingSessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with (
        patch("app.main.send_notification", return_value=True),
        TestClient(app) as test_client,
    ):
        yield test_client

    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)


def test_health(client):
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["service"] == "backend"


def test_create_and_list_tasks(client):
    create = client.post(
        "/tasks",
        json={"title": "Write Dockerfile", "description": "Backend image"},
    )
    assert create.status_code == 201
    task = create.json()
    assert task["title"] == "Write Dockerfile"
    assert task["completed"] is False

    listed = client.get("/tasks")
    assert listed.status_code == 200
    assert len(listed.json()) == 1


def test_update_and_delete_task(client):
    created = client.post("/tasks", json={"title": "Compose", "description": ""}).json()
    task_id = created["id"]

    updated = client.patch(f"/tasks/{task_id}", json={"completed": True})
    assert updated.status_code == 200
    assert updated.json()["completed"] is True

    deleted = client.delete(f"/tasks/{task_id}")
    assert deleted.status_code == 204

    missing = client.get(f"/tasks/{task_id}")
    assert missing.status_code == 404

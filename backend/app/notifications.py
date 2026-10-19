import httpx

from app.config import NOTIFICATION_URL


def send_notification(message: str, task_id: int | None = None) -> bool:
    """Send a notification event to the notification microservice."""
    payload = {"message": message, "task_id": task_id, "source": "backend"}
    try:
        with httpx.Client(timeout=3.0) as client:
            response = client.post(f"{NOTIFICATION_URL}/notifications", json=payload)
            return response.status_code == 201
    except httpx.HTTPError:
        return False

from datetime import UTC, datetime

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

APP_VERSION = "1.0.0"

app = FastAPI(title="Notification Service", version=APP_VERSION)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# In-memory store (enough for lab demos; can be replaced with DB later)
_notifications: list[dict] = []


class NotificationCreate(BaseModel):
    message: str = Field(..., min_length=1)
    task_id: int | None = None
    source: str = "unknown"


class NotificationResponse(BaseModel):
    id: int
    message: str
    task_id: int | None
    source: str
    created_at: datetime


class HealthResponse(BaseModel):
    status: str
    service: str
    version: str


@app.get("/health", response_model=HealthResponse)
def health():
    return {"status": "ok", "service": "notification", "version": APP_VERSION}


@app.post("/notifications", response_model=NotificationResponse, status_code=201)
def create_notification(payload: NotificationCreate):
    item = {
        "id": len(_notifications) + 1,
        "message": payload.message,
        "task_id": payload.task_id,
        "source": payload.source,
        "created_at": datetime.now(UTC),
    }
    _notifications.append(item)
    return item


@app.get("/notifications", response_model=list[NotificationResponse])
def list_notifications():
    return list(reversed(_notifications))


@app.delete("/notifications", status_code=204)
def clear_notifications():
    _notifications.clear()
    return None

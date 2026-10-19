import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://taskuser:taskpass@localhost:5432/taskdb",
)
NOTIFICATION_URL = os.getenv(
    "NOTIFICATION_URL",
    "http://localhost:8001",
)
APP_NAME = "Task Manager API"
APP_VERSION = "1.0.0"

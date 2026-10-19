from datetime import datetime

from app.models import Task
from app.schemas import TaskCreate, TaskUpdate


def test_task_create_schema():
    task = TaskCreate(title="Learn Docker", description="Lab 1")
    assert task.title == "Learn Docker"
    assert task.description == "Lab 1"


def test_task_create_schema_default_description():
    task = TaskCreate(title="Only title")
    assert task.description == ""


def test_task_update_partial():
    update = TaskUpdate(completed=True)
    data = update.model_dump(exclude_unset=True)
    assert data == {"completed": True}


def test_task_model_defaults():
    task = Task(title="Unit test", description="check defaults")
    assert task.title == "Unit test"
    assert task.completed is False or task.completed is None
    assert isinstance(task.created_at, datetime) or task.created_at is None

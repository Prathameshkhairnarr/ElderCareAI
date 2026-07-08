from typing import List, Optional
from datetime import datetime, timedelta, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func

from database.engine import get_db
from database.models import User, Guardian, Task
from schemas import task_schemas
from services.auth_service import get_current_user
from utils.phone_utils import normalize_phone

router = APIRouter(tags=["Tasks"])

def _utcnow():
    return datetime.now(timezone.utc)

@router.post("/tasks/create", response_model=task_schemas.TaskResponse, status_code=status.HTTP_201_CREATED)
def create_task(
    task: task_schemas.TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Guardian creates a task for their linked elder."""
    # 1. Verify that current_user is a guardian for the specified elder_id
    guardian_entry = (
        db.query(Guardian)
        .filter(Guardian.user_id == task.elder_id, Guardian.phone == normalize_phone(current_user.phone))
        .first()
    )
    if not guardian_entry:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not authorized to assign tasks to this elder.",
        )

    # 2. Critical priority tasks auto-enable voice reminder
    voice_reminder = task.voice_reminder_enabled
    if task.priority == "critical":
        voice_reminder = True

    new_task = Task(
        guardian_id=current_user.id,
        elder_id=task.elder_id,
        title=task.title,
        task_type=task.task_type,
        description=task.description,
        icon_key=task.icon_key,
        scheduled_time=task.scheduled_time,
        recurrence=task.recurrence,
        recurrence_days=task.recurrence_days,
        priority=task.priority,
        voice_reminder_enabled=voice_reminder,
    )

    db.add(new_task)
    db.commit()
    db.refresh(new_task)
    return new_task

@router.get("/tasks/elder/{elder_id}", response_model=List[task_schemas.TaskResponse])
def get_elder_tasks(
    elder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get all tasks for an elder (used by elder's app)."""
    # Verify elder is requesting their own tasks OR a guardian is requesting
    if current_user.id != elder_id:
        guardian_entry = (
            db.query(Guardian)
            .filter(Guardian.user_id == elder_id, Guardian.phone == normalize_phone(current_user.phone))
            .first()
        )
        if not guardian_entry:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized.",
            )

    # Return all for now. In a real scenario, we might filter by today's date.
    now = _utcnow()
    tasks = db.query(Task).filter(Task.elder_id == elder_id).all()
    # Simple filtering: keep pending or today's tasks
    # Full recurrent logic could be implemented here
    return tasks

@router.get("/tasks/guardian/{guardian_id}")
def get_guardian_assigned_tasks(
    guardian_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get all tasks a guardian has assigned."""
    if current_user.id != guardian_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized.",
        )
    
    tasks = db.query(Task).filter(Task.guardian_id == guardian_id).order_by(Task.scheduled_time.asc()).all()
    
    # Calculate completion summary
    total = len(tasks)
    done = sum(1 for t in tasks if t.status == "done")
    pending = sum(1 for t in tasks if t.status == "pending")
    missed = sum(1 for t in tasks if t.status == "missed")

    return {
        "tasks": [task_schemas.TaskResponse.model_validate(t) for t in tasks],
        "completion_summary": {
            "total": total,
            "done": done,
            "pending": pending,
            "missed": missed
        }
    }

@router.patch("/tasks/{task_id}/update", response_model=task_schemas.TaskResponse)
def update_task_status(
    task_id: int,
    update_data: task_schemas.TaskUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Elder (or Guardian) updates task status."""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")

    if update_data.status:
        task.status = update_data.status
        if update_data.status == "done":
            task.completed_at = _utcnow()
        elif update_data.status == "snoozed":
            mins = update_data.snooze_minutes or 30
            task.snooze_until = _utcnow() + timedelta(minutes=mins)
            task.status = "pending" # keep pending but snoozed

    db.commit()
    db.refresh(task)
    return task

@router.delete("/tasks/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Guardian deletes a task."""
    task = db.query(Task).filter(Task.id == task_id, Task.guardian_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")
    
    db.delete(task)
    db.commit()

@router.patch("/tasks/{task_id}/edit", response_model=task_schemas.TaskResponse)
def edit_task(
    task_id: int,
    task_data: task_schemas.TaskCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Guardian edits task details."""
    task = db.query(Task).filter(Task.id == task_id, Task.guardian_id == current_user.id).first()
    if not task:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")
    
    if task.status == "done":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot edit a completed task.")

    task.title = task_data.title
    task.task_type = task_data.task_type
    task.description = task_data.description
    task.icon_key = task_data.icon_key
    task.scheduled_time = task_data.scheduled_time
    task.recurrence = task_data.recurrence
    task.recurrence_days = task_data.recurrence_days
    task.priority = task_data.priority
    task.voice_reminder_enabled = task_data.voice_reminder_enabled

    db.commit()
    db.refresh(task)
    return task

@router.get("/tasks/{elder_id}/pending-reminders", response_model=List[task_schemas.TaskResponse])
def get_pending_reminders(
    elder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Get tasks due for voice reminder right now."""
    if current_user.id != elder_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized.")

    now = _utcnow()
    # Filter: pending, voice_reminder=true, scheduled <= now, and (snooze_until is null or <= now)
    tasks = (
        db.query(Task)
        .filter(Task.elder_id == elder_id)
        .filter(Task.status == "pending")
        .filter(Task.voice_reminder_enabled == True)
        .filter(Task.scheduled_time <= now)
        .filter((Task.snooze_until == None) | (Task.snooze_until <= now))
        .all()
    )
    return tasks

@router.get("/tasks/templates")
def get_task_templates():
    """Static preset templates for quick-add."""
    return [
      {"title": "Dawai lo", "task_type": "medicine", "icon_key": "pill", "priority": "critical"},
      {"title": "Pani piyo", "task_type": "water", "icon_key": "water_glass", "priority": "normal"},
      {"title": "Thodi walk kar lo", "task_type": "walk", "icon_key": "walk", "priority": "normal"},
      {"title": "Ghar pe call karo", "task_type": "call_family", "icon_key": "phone_call", "priority": "normal"},
      {"title": "BP check karo", "task_type": "custom", "icon_key": "heart_pulse", "priority": "important"},
      {"title": "Nashta kar lo", "task_type": "custom", "icon_key": "food", "priority": "normal"}
    ]

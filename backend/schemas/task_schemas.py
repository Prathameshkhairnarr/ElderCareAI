from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class TaskCreate(BaseModel):
    elder_id: int
    title: str
    task_type: str = "custom"
    description: Optional[str] = None
    icon_key: str = "task_default"
    scheduled_time: Optional[datetime] = None
    recurrence: str = "once"          # once | daily | custom_days
    recurrence_days: Optional[str] = None
    priority: str = "normal"          # normal | important | critical
    voice_reminder_enabled: bool = True

class TaskUpdate(BaseModel):
    status: Optional[str] = None      # done | missed | snoozed | pending
    snooze_minutes: Optional[int] = None

class TaskResponse(BaseModel):
    id: int
    guardian_id: int
    elder_id: int
    title: str
    task_type: str
    description: Optional[str]
    icon_key: str
    scheduled_time: Optional[datetime]
    recurrence: str
    status: str
    priority: str
    completed_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True

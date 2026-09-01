from datetime import datetime

from pydantic import BaseModel, ConfigDict


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str | None
    phone: str | None
    email_verified_at: datetime | None
    phone_verified_at: datetime | None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    last_login_at: datetime | None

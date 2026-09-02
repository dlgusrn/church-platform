from datetime import datetime, time as time_of_day
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class WorshipScheduleCreateRequest(BaseModel):
    title: str = Field(min_length=1, max_length=100)
    day_label: str = Field(min_length=1, max_length=100)
    time: time_of_day
    display_order: int = Field(default=0, ge=0)
    is_active: bool = True

    @field_validator("title", "day_label")
    @classmethod
    def normalize_text(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("value must not be blank")
        return normalized


class WorshipScheduleUpdateRequest(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=100)
    day_label: str | None = Field(default=None, min_length=1, max_length=100)
    time: time_of_day | None = None
    display_order: int | None = Field(default=None, ge=0)
    is_active: bool | None = None

    @field_validator("title", "day_label")
    @classmethod
    def normalize_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("value must not be blank")
        return normalized

    @model_validator(mode="after")
    def reject_null_values(self) -> Self:
        for field in self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class WorshipScheduleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    church_id: int
    title: str
    day_label: str
    time: time_of_day
    display_order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

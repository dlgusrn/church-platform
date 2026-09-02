from datetime import date, datetime
from typing import Self
from urllib.parse import urlparse

from pydantic import BaseModel, Field, field_validator, model_validator

from app.models.enums import LiveBroadcastStatus, LiveWorshipType

YOUTUBE_HOSTS = {"youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"}


def validate_youtube_url(value: str) -> str:
    normalized = value.strip()
    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"} or parsed.hostname not in YOUTUBE_HOSTS:
        raise ValueError("youtube_url must be a valid YouTube URL")
    if parsed.hostname == "youtu.be" and not parsed.path.strip("/"):
        raise ValueError("youtube_url must include a video identifier")
    if parsed.hostname != "youtu.be" and parsed.path != "/watch":
        raise ValueError("youtube_url must use a YouTube watch URL")
    if parsed.hostname != "youtu.be" and "v=" not in parsed.query:
        raise ValueError("youtube_url must include a video identifier")
    return normalized


class _LiveWorshipTypeFields(BaseModel):
    worship_type: LiveWorshipType | None = None
    custom_worship_name: str | None = Field(default=None, max_length=100)

    @field_validator("custom_worship_name")
    @classmethod
    def normalize_custom_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            raise ValueError("custom_worship_name must not be blank")
        return normalized


class LiveBroadcastCreateRequest(_LiveWorshipTypeFields):
    worship_type: LiveWorshipType
    broadcast_date: date
    title_override: str | None = Field(default=None, max_length=200)
    youtube_url: str
    status: LiveBroadcastStatus = LiveBroadcastStatus.SCHEDULED
    started_at: datetime | None = None
    ended_at: datetime | None = None

    @field_validator("youtube_url")
    @classmethod
    def validate_url(cls, value: str) -> str:
        return validate_youtube_url(value)

    @field_validator("title_override")
    @classmethod
    def normalize_title(cls, value: str | None) -> str | None:
        return value.strip() if value and value.strip() else None

    @model_validator(mode="after")
    def validate_worship_type_fields(self) -> Self:
        if self.worship_type is LiveWorshipType.CUSTOM:
            if self.custom_worship_name is None:
                raise ValueError("custom_worship_name is required for custom worship_type")
        elif self.custom_worship_name is not None:
            raise ValueError("custom_worship_name is only allowed for custom worship_type")
        return self


class LiveBroadcastUpdateRequest(_LiveWorshipTypeFields):
    broadcast_date: date | None = None
    title_override: str | None = Field(default=None, max_length=200)
    youtube_url: str | None = None
    status: LiveBroadcastStatus | None = None
    started_at: datetime | None = None
    ended_at: datetime | None = None

    @field_validator("youtube_url")
    @classmethod
    def validate_url(cls, value: str | None) -> str | None:
        return None if value is None else validate_youtube_url(value)

    @field_validator("title_override")
    @classmethod
    def normalize_title(cls, value: str | None) -> str | None:
        return value.strip() if value and value.strip() else None

    @model_validator(mode="after")
    def reject_null_required_fields(self) -> Self:
        for field in {"broadcast_date", "youtube_url", "status"} & self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class LiveBroadcastResponse(BaseModel):
    id: int
    church_id: int
    broadcast_date: date
    worship_type: LiveWorshipType
    custom_worship_name: str | None
    title_override: str | None
    display_title: str
    youtube_url: str
    status: LiveBroadcastStatus
    started_at: datetime | None
    ended_at: datetime | None
    created_at: datetime
    updated_at: datetime

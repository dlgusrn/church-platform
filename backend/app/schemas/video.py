from datetime import datetime
from typing import Self

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from app.models.video import VideoSourceType


class _VideoFields(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    source_type: VideoSourceType
    source_ref: str = Field(min_length=1, max_length=500)
    recorded_at: datetime
    duration_seconds: int | None = Field(default=None, ge=0)
    thumbnail_ref: str | None = Field(default=None, max_length=500)
    category_id: int | None = Field(default=None, gt=0)
    collection_id: int | None = Field(default=None, gt=0)
    is_published: bool = True

    @field_validator("title", "source_ref")
    @classmethod
    def normalize_required_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("value must not be blank")
        return value

    @field_validator("description", "thumbnail_ref")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class VideoCreate(_VideoFields):
    pass


class VideoUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    source_type: VideoSourceType | None = None
    source_ref: str | None = Field(default=None, min_length=1, max_length=500)
    recorded_at: datetime | None = None
    duration_seconds: int | None = Field(default=None, ge=0)
    thumbnail_ref: str | None = Field(default=None, max_length=500)
    category_id: int | None = Field(default=None, gt=0)
    collection_id: int | None = Field(default=None, gt=0)
    is_published: bool | None = None

    @field_validator("title", "source_ref")
    @classmethod
    def normalize_optional_required_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("value must not be blank")
        return value

    @field_validator("description", "thumbnail_ref")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        return None if value is None else (value.strip() or None)

    @model_validator(mode="after")
    def reject_null_values(self) -> Self:
        # Nullable reference/text fields deliberately accept null to clear them.
        for field in self.model_fields_set - {"description", "thumbnail_ref", "category_id", "collection_id", "duration_seconds"}:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class VideoRead(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    church_id: int
    category_id: int | None
    collection_id: int | None
    title: str
    description: str | None
    source_type: VideoSourceType
    # Synology references are internal root-relative NAS paths.  They are
    # deliberately omitted from the member-facing library response.
    source_ref: str | None
    recorded_at: datetime
    duration_seconds: int | None
    thumbnail_ref: str | None
    is_published: bool
    created_at: datetime
    updated_at: datetime
    playback: dict[str, str] | None = None


class VideoPlaybackSessionRead(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: str = "synology"
    playback_url: str
    playback_token: str
    expires_at: datetime


class VideoReviewPageRead(BaseModel):
    items: list[VideoRead]
    total: int
    published_count: int
    unpublished_count: int
    offset: int
    limit: int


class VideoBulkPublishRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    video_ids: list[int] = Field(min_length=1, max_length=200)


class VideoBulkPublishItemRead(BaseModel):
    status: str
    video_id: int
    error_code: str | None


class VideoBulkPublishRead(BaseModel):
    requested_count: int
    published_count: int
    already_published_count: int
    failed_count: int
    items: list[VideoBulkPublishItemRead]


class YouTubeVideoCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    url: str = Field(min_length=1, max_length=2000)
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    recorded_at: datetime
    category_id: int | None = Field(default=None, gt=0)
    collection_id: int | None = Field(default=None, gt=0)
    is_published: bool = True

    @field_validator("url", "title")
    @classmethod
    def normalize_required(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("value must not be blank")
        return value


class VideoListResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    items: list[VideoRead]


class SynologyConnectionRead(BaseModel):
    configured: bool
    reachable: bool
    authenticated: bool
    root_accessible: bool


class SynologyCandidateRead(BaseModel):
    source_ref: str
    relative_path: str
    filename: str
    file_size: int
    extension: str
    inferred_title: str
    inferred_recorded_at: datetime | None
    category_suggestion: str | None
    matched_category_id: int | None
    collection_suggestion: str | None
    matched_collection_id: int | None
    duplicate: bool
    already_imported: bool
    needs_review: bool
    warnings: list[str]
    review_reasons: list[str]


class SynologyPreviewRead(BaseModel):
    snapshot_token: str
    summary: dict[str, int]
    candidates: list[SynologyCandidateRead]
    folder_facets: list[str]
    selectable_source_refs: list[str]
    offset: int
    limit: int


class SynologyImportRequest(BaseModel):
    snapshot_token: str = Field(min_length=16, max_length=100)
    source_refs: list[str] = Field(min_length=1, max_length=200)


class SynologyImportItemRead(BaseModel):
    status: str
    video_id: int | None
    error_code: str | None


class SynologyImportRead(BaseModel):
    requested_count: int
    imported_count: int
    already_imported_count: int
    failed_count: int
    needs_review_count: int
    items: list[SynologyImportItemRead]
    # Kept during the Stage 9-4B API transition for existing administrator
    # consumers; new bulk clients use the explicit count fields above.
    created: int
    skipped: int
    failed: int


class VideoArchiveResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    year: int
    month: int
    video_count: int


class VideoCategoryCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str = Field(min_length=1, max_length=100)
    sort_order: int = 0
    is_active: bool = True

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("name must not be blank")
        return value


class VideoCategoryUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    name: str | None = Field(default=None, min_length=1, max_length=100)
    sort_order: int | None = None
    is_active: bool | None = None

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("name must not be blank")
        return value

    @model_validator(mode="after")
    def reject_null_values(self) -> Self:
        for field in self.model_fields_set:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class VideoCategoryRead(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    church_id: int
    name: str
    sort_order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime


class VideoCollectionCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category_id: int | None = Field(default=None, gt=0)
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    recorded_at: datetime | None = None
    sort_order: int = 0
    is_published: bool = True

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("title must not be blank")
        return value

    @field_validator("description")
    @classmethod
    def normalize_description(cls, value: str | None) -> str | None:
        return None if value is None else (value.strip() or None)


class VideoCollectionUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    category_id: int | None = Field(default=None, gt=0)
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    recorded_at: datetime | None = None
    sort_order: int | None = None
    is_published: bool | None = None

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("title must not be blank")
        return value

    @field_validator("description")
    @classmethod
    def normalize_description(cls, value: str | None) -> str | None:
        return None if value is None else (value.strip() or None)

    @model_validator(mode="after")
    def reject_null_values(self) -> Self:
        for field in self.model_fields_set - {"category_id", "description", "recorded_at"}:
            if getattr(self, field) is None:
                raise ValueError(f"{field} cannot be null")
        return self


class VideoCollectionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True, extra="forbid")

    id: int
    church_id: int
    category_id: int | None
    title: str
    description: str | None
    recorded_at: datetime | None
    sort_order: int
    is_published: bool
    created_at: datetime
    updated_at: datetime

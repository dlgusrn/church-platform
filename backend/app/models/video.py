from datetime import datetime
from enum import StrEnum
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.church import Church


class VideoSourceType(StrEnum):
    SYNOLOGY = "synology"
    YOUTUBE = "youtube"


class VideoCategory(TimestampMixin, Base):
    __tablename__ = "video_categories"
    __table_args__ = (UniqueConstraint("church_id", "name", name="uq_video_categories_church_name"),)
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("churches.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())
    church: Mapped["Church"] = relationship(back_populates="video_categories")


class VideoCollection(TimestampMixin, Base):
    __tablename__ = "video_collections"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("churches.id", ondelete="CASCADE"), nullable=False)
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("video_categories.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    recorded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())
    church: Mapped["Church"] = relationship(back_populates="video_collections")
    category: Mapped["VideoCategory | None"] = relationship()
    videos: Mapped[list["Video"]] = relationship(back_populates="collection")


class Video(TimestampMixin, Base):
    __tablename__ = "videos"
    __table_args__ = (
        UniqueConstraint("church_id", "source_type", "source_ref", name="uq_videos_church_source_ref"),
        Index("ix_videos_church_published_recorded", "church_id", "is_published", "recorded_at"),
        Index("ix_videos_church_category_recorded", "church_id", "category_id", "recorded_at"),
        Index("ix_videos_church_collection", "church_id", "collection_id"),
    )
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("churches.id", ondelete="CASCADE"), nullable=False)
    category_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("video_categories.id", ondelete="SET NULL"))
    collection_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("video_collections.id", ondelete="SET NULL"))
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(Text)
    source_type: Mapped[VideoSourceType] = mapped_column(String(20), nullable=False)
    source_ref: Mapped[str] = mapped_column(String(500), nullable=False)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    thumbnail_ref: Mapped[str | None] = mapped_column(String(500))
    is_published: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())
    church: Mapped["Church"] = relationship(back_populates="videos")
    category: Mapped["VideoCategory | None"] = relationship()
    collection: Mapped["VideoCollection | None"] = relationship(back_populates="videos")

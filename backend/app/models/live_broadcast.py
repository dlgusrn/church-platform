from datetime import date, datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Date, DateTime, Enum, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.enums import LiveBroadcastStatus, LiveWorshipType

if TYPE_CHECKING:
    from app.models.church import Church


class LiveBroadcast(TimestampMixin, Base):
    __tablename__ = "live_broadcasts"
    __table_args__ = (
        Index("ix_live_broadcasts_church", "church_id"),
        Index("ix_live_broadcasts_date", "broadcast_date"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("churches.id", name="fk_live_broadcasts_church", ondelete="CASCADE"),
        nullable=False,
    )
    broadcast_date: Mapped[date] = mapped_column(Date, nullable=False)
    worship_type: Mapped[LiveWorshipType] = mapped_column(
        Enum(
            LiveWorshipType,
            name="live_worship_type",
            values_callable=lambda enum: [item.value for item in enum],
        ),
        nullable=False,
    )
    custom_worship_name: Mapped[str | None] = mapped_column(String(100))
    title_override: Mapped[str | None] = mapped_column(String(200))
    youtube_url: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[LiveBroadcastStatus] = mapped_column(
        Enum(
            LiveBroadcastStatus,
            name="live_broadcast_status",
            values_callable=lambda enum: [item.value for item in enum],
        ),
        nullable=False,
        default=LiveBroadcastStatus.SCHEDULED,
        server_default=LiveBroadcastStatus.SCHEDULED.value,
    )
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    church: Mapped["Church"] = relationship(back_populates="live_broadcasts")

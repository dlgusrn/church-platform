from datetime import time
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, ForeignKey, Index, Integer, String, Time, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
if TYPE_CHECKING:
    from app.models.church import Church


class WorshipSchedule(TimestampMixin, Base):
    __tablename__ = "worship_schedules"
    __table_args__ = (Index("ix_worship_schedules_church", "church_id"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("churches.id", name="fk_worship_schedules_church", ondelete="CASCADE"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(100), nullable=False)
    day_label: Mapped[str] = mapped_column(String(100), nullable=False)
    time: Mapped[time] = mapped_column(Time, nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0, server_default="0")
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())

    church: Mapped["Church"] = relationship(back_populates="worship_schedules")

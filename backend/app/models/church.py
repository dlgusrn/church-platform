from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, String, true
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.live_broadcast import LiveBroadcast
    from app.models.membership import ChurchMembership
    from app.models.notice import Notice
    from app.models.role import Role
    from app.models.worship_schedule import WorshipSchedule


class Church(TimestampMixin, Base):
    __tablename__ = "churches"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    code: Mapped[str] = mapped_column(String(80), nullable=False, unique=True, index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, server_default=true())

    memberships: Mapped[list["ChurchMembership"]] = relationship(back_populates="church")
    roles: Mapped[list["Role"]] = relationship(back_populates="church")
    worship_schedules: Mapped[list["WorshipSchedule"]] = relationship(
        back_populates="church", cascade="all, delete-orphan"
    )
    live_broadcasts: Mapped[list["LiveBroadcast"]] = relationship(
        back_populates="church", cascade="all, delete-orphan"
    )
    notices: Mapped[list["Notice"]] = relationship(
        back_populates="church", cascade="all, delete-orphan"
    )

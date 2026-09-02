from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import BigInteger, DateTime, Enum, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin
from app.models.enums import MembershipStatus

if TYPE_CHECKING:
    from app.models.church import Church
    from app.models.permission_override import MembershipPermissionOverride
    from app.models.notice import Notice
    from app.models.role import Role
    from app.models.user import User


class ChurchMembership(TimestampMixin, Base):
    __tablename__ = "church_memberships"
    __table_args__ = (
        UniqueConstraint("user_id", "church_id", name="uq_church_memberships_user_id_church_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    church_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("churches.id", ondelete="CASCADE"), nullable=False, index=True
    )
    status: Mapped[MembershipStatus] = mapped_column(
        Enum(
            MembershipStatus,
            name="membership_status",
            values_callable=lambda enum: [item.value for item in enum],
        ),
        nullable=False,
        default=MembershipStatus.PENDING,
        server_default=MembershipStatus.PENDING.value,
    )
    role_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("roles.id", ondelete="SET NULL"), index=True
    )
    requested_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    rejected_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    user: Mapped["User"] = relationship(back_populates="memberships")
    church: Mapped["Church"] = relationship(back_populates="memberships")
    role: Mapped[Optional["Role"]] = relationship(back_populates="memberships")
    permission_overrides: Mapped[list["MembershipPermissionOverride"]] = relationship(
        back_populates="membership", cascade="all, delete-orphan"
    )
    authored_notices: Mapped[list["Notice"]] = relationship(back_populates="author_membership")

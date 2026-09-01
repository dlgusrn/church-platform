from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Enum, ForeignKey, Index, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.enums import PermissionEffect

if TYPE_CHECKING:
    from app.models.membership import ChurchMembership
    from app.models.permission import Permission


class MembershipPermissionOverride(Base):
    __tablename__ = "membership_permission_overrides"
    __table_args__ = (
        UniqueConstraint(
            "membership_id",
            "permission_id",
            name="uq_mpo_membership_permission",
        ),
        Index("ix_mpo_membership", "membership_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    membership_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey(
            "church_memberships.id",
            name="fk_mpo_membership",
            ondelete="CASCADE",
        ),
        nullable=False,
    )
    permission_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("permissions.id", name="fk_mpo_permission", ondelete="CASCADE"),
        nullable=False,
    )
    effect: Mapped[PermissionEffect] = mapped_column(
        Enum(
            PermissionEffect,
            name="permission_effect",
            values_callable=lambda enum: [item.value for item in enum],
        ),
        nullable=False,
    )

    membership: Mapped["ChurchMembership"] = relationship(back_populates="permission_overrides")
    permission: Mapped["Permission"] = relationship(back_populates="membership_overrides")

from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, String, Text, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.church import Church
    from app.models.membership import ChurchMembership


class Notice(TimestampMixin, Base):
    __tablename__ = "notices"
    __table_args__ = (
        Index("ix_notices_church_pinned_published", "church_id", "is_pinned", "published_at"),
        Index("ix_notices_author_membership", "author_membership_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("churches.id", name="fk_notices_church", ondelete="CASCADE"),
        nullable=False,
    )
    author_membership_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("church_memberships.id", name="fk_notices_author_membership"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    is_pinned: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=False, server_default=false()
    )
    published_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)

    church: Mapped["Church"] = relationship(back_populates="notices")
    author_membership: Mapped["ChurchMembership"] = relationship(
        back_populates="authored_notices"
    )

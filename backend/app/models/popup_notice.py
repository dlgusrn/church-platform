from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import BigInteger, Boolean, CheckConstraint, DateTime, ForeignKey, Index, String, Text, false
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.church import Church
    from app.models.membership import ChurchMembership


class PopupNotice(TimestampMixin, Base):
    __tablename__ = "popup_notices"
    __table_args__ = (
        CheckConstraint("starts_at < ends_at", name="starts_before_ends"),
        Index("ix_popup_notices_church_active_window", "church_id", "is_active", "starts_at", "ends_at"),
        Index("ix_popup_notices_author_membership", "author_membership_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    church_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("churches.id", name="fk_popup_notices_church", ondelete="CASCADE"), nullable=False
    )
    author_membership_id: Mapped[int] = mapped_column(
        BigInteger,
        ForeignKey("church_memberships.id", name="fk_popup_notices_author_membership"),
        nullable=False,
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    image_storage_key: Mapped[str | None] = mapped_column(String(512))
    image_content_type: Mapped[str | None] = mapped_column(String(100))
    image_size: Mapped[int | None] = mapped_column(BigInteger)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default=false())

    church: Mapped["Church"] = relationship(back_populates="popup_notices")
    author_membership: Mapped["ChurchMembership"] = relationship(back_populates="authored_popup_notices")

from datetime import datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.popup_notice import PopupNotice


class PopupNoticeRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(self, church_id: int) -> list[PopupNotice]:
        return list(self.session.scalars(
            select(PopupNotice).where(PopupNotice.church_id == church_id).order_by(
                PopupNotice.starts_at.desc(), PopupNotice.id.desc()
            )
        ).all())

    def get_for_church(self, popup_notice_id: int, church_id: int, *, for_update: bool = False) -> PopupNotice | None:
        statement = select(PopupNotice).where(
            PopupNotice.id == popup_notice_id, PopupNotice.church_id == church_id
        )
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def current(self, church_id: int, now: datetime) -> PopupNotice | None:
        return self.session.scalar(
            select(PopupNotice).where(
                PopupNotice.church_id == church_id,
                PopupNotice.is_active.is_(True),
                PopupNotice.starts_at <= now,
                PopupNotice.ends_at > now,
            ).order_by(PopupNotice.starts_at.desc(), PopupNotice.id.desc()).limit(1)
        )

    def overlapping_active(self, church_id: int, starts_at: datetime, ends_at: datetime, *, exclude_id: int | None = None) -> PopupNotice | None:
        statement = select(PopupNotice).where(
            PopupNotice.church_id == church_id,
            PopupNotice.is_active.is_(True),
            PopupNotice.starts_at < ends_at,
            PopupNotice.ends_at > starts_at,
        )
        if exclude_id is not None:
            statement = statement.where(PopupNotice.id != exclude_id)
        return self.session.scalar(statement.with_for_update())

    def add(self, notice: PopupNotice) -> PopupNotice:
        self.session.add(notice)
        self.session.flush()
        return notice

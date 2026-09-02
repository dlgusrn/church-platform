from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.notice import Notice


class NoticeRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(self, church_id: int) -> list[Notice]:
        return list(
            self.session.scalars(
                select(Notice)
                .where(Notice.church_id == church_id)
                .order_by(
                    Notice.is_pinned.desc(),
                    Notice.published_at.desc(),
                    Notice.id.desc(),
                )
            ).all()
        )

    def get_for_church(
        self, notice_id: int, church_id: int, *, for_update: bool = False
    ) -> Notice | None:
        statement = select(Notice).where(
            Notice.id == notice_id,
            Notice.church_id == church_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def add(self, notice: Notice) -> Notice:
        self.session.add(notice)
        self.session.flush()
        return notice

    def delete(self, notice: Notice) -> None:
        self.session.delete(notice)

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.church import Church


class ChurchRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_active(self) -> list[Church]:
        return list(
            self.session.scalars(
                select(Church).where(Church.is_active.is_(True)).order_by(Church.name, Church.id)
            ).all()
        )

    def get_by_id(self, church_id: int, *, for_update: bool = False) -> Church | None:
        if not for_update:
            return self.session.get(Church, church_id)
        return self.session.scalar(
            select(Church).where(Church.id == church_id).with_for_update()
        )

    def get_by_code(self, code: str) -> Church | None:
        return self.session.scalar(select(Church).where(Church.code == code))

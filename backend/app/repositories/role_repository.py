from sqlalchemy import or_, select
from sqlalchemy.orm import Session, selectinload

from app.models.role import Role


class RoleRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(self, church_id: int) -> list[Role]:
        return list(
            self.session.scalars(
                select(Role)
                .where(or_(Role.church_id.is_(None), Role.church_id == church_id))
                .options(selectinload(Role.permissions))
                .order_by(Role.is_system.desc(), Role.name, Role.id)
            ).all()
        )

    def get_assignable(self, role_id: int, church_id: int) -> Role | None:
        return self.session.scalar(
            select(Role)
            .where(
                Role.id == role_id,
                or_(Role.church_id.is_(None), Role.church_id == church_id),
            )
            .options(selectinload(Role.permissions))
        )

    def get_system_by_code(self, code: str) -> Role | None:
        return self.session.scalar(
            select(Role)
            .where(Role.church_id.is_(None), Role.code == code, Role.is_system.is_(True))
            .options(selectinload(Role.permissions))
        )

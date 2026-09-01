from collections.abc import Iterable

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.permission import Permission


class PermissionRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def get_by_codes(self, codes: Iterable[str]) -> dict[str, Permission]:
        unique_codes = set(codes)
        if not unique_codes:
            return {}
        permissions = self.session.scalars(
            select(Permission).where(Permission.code.in_(unique_codes))
        ).all()
        return {permission.code: permission for permission in permissions}

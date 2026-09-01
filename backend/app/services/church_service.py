from sqlalchemy.orm import Session

from app.core.exceptions import NotFoundError
from app.repositories.church_repository import ChurchRepository
from app.repositories.role_repository import RoleRepository
from app.schemas.church import ChurchResponse
from app.schemas.role import RoleResponse


class ChurchService:
    def __init__(self, session: Session) -> None:
        self.churches = ChurchRepository(session)
        self.roles = RoleRepository(session)

    def list_churches(self) -> list[ChurchResponse]:
        return [ChurchResponse.model_validate(church) for church in self.churches.list_active()]

    def list_roles(self, church_id: int) -> list[RoleResponse]:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")
        return [
            RoleResponse(
                id=role.id,
                code=role.code,
                name=role.name,
                is_system=role.is_system,
                permissions=sorted(permission.code for permission in role.permissions),
            )
            for role in self.roles.list_for_church(church_id)
        ]

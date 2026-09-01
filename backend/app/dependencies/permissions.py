from collections.abc import Callable
from typing import Annotated

from fastapi import Depends

from app.core.permission_codes import PermissionCode
from app.dependencies.auth import CurrentUser, DatabaseSession
from app.services.authorization_service import AuthorizationService


def require_church_permission(permission: PermissionCode) -> Callable[..., None]:
    def dependency(
        church_id: int,
        current_user: CurrentUser,
        session: DatabaseSession,
    ) -> None:
        AuthorizationService(session).require_church_permission(
            user_id=current_user.id,
            church_id=church_id,
            permission_code=permission.value,
        )

    return dependency


MemberViewPermission = Annotated[
    None, Depends(require_church_permission(PermissionCode.MEMBER_VIEW))
]
MemberManagePermission = Annotated[
    None, Depends(require_church_permission(PermissionCode.MEMBER_MANAGE))
]
RoleViewPermission = Annotated[
    None, Depends(require_church_permission(PermissionCode.ROLE_VIEW))
]
PermissionManagePermission = Annotated[
    None, Depends(require_church_permission(PermissionCode.PERMISSION_MANAGE))
]

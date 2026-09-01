import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.permission_codes import PermissionCode
from app.models.permission import Permission
from app.models.role import Role, RolePermission
from app.scripts.seed_permissions import SYSTEM_ROLE_PERMISSIONS, seed_permissions_and_roles

pytestmark = pytest.mark.integration


def test_permission_and_system_role_seed_is_idempotent(mysql_session: Session) -> None:
    seed_permissions_and_roles(mysql_session)
    seed_permissions_and_roles(mysql_session)

    assert mysql_session.scalar(select(func.count()).select_from(Permission)) == len(
        PermissionCode
    )

    roles = mysql_session.scalars(
        select(Role).where(
            Role.church_id.is_(None),
            Role.code.in_(SYSTEM_ROLE_PERMISSIONS),
        )
    ).all()
    assert {role.code for role in roles} == set(SYSTEM_ROLE_PERMISSIONS)
    assert len(roles) == len(SYSTEM_ROLE_PERMISSIONS)

    for role in roles:
        permission_count = mysql_session.scalar(
            select(func.count())
            .select_from(RolePermission)
            .where(RolePermission.role_id == role.id)
        )
        assert permission_count == len(SYSTEM_ROLE_PERMISSIONS[role.code])

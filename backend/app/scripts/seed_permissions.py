from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.database import get_session_factory
from app.core.permission_codes import PERMISSION_V1, PermissionCode
from app.models.permission import Permission
from app.models.role import Role, RolePermission

SYSTEM_ROLE_PERMISSIONS: dict[str, set[PermissionCode]] = {
    "member": {PermissionCode.LIVE_ACCESS, PermissionCode.VOD_VIEW},
    "staff": {
        PermissionCode.LIVE_ACCESS,
        PermissionCode.VOD_VIEW,
        PermissionCode.MEDIA_VIDEO_VIEW,
        PermissionCode.MEDIA_AUDIO_VIEW,
        PermissionCode.NOTICE_VIEW,
        PermissionCode.SCHEDULE_VIEW,
        PermissionCode.EXPENSE_VIEW,
        PermissionCode.EXPENSE_CREATE,
        PermissionCode.APPROVAL_VIEW,
        PermissionCode.ATTENDANCE_VIEW,
        PermissionCode.DOCUMENT_VIEW,
    },
    "admin": set(PermissionCode),
}

SYSTEM_ROLE_NAMES = {
    "member": "성도",
    "staff": "직원",
    "admin": "관리자",
}


def seed_permissions_and_roles(session: Session) -> None:
    permissions_by_code = {
        permission.code: permission
        for permission in session.scalars(select(Permission)).all()
    }
    for code, name in PERMISSION_V1:
        permission = permissions_by_code.get(code.value)
        if permission is None:
            permission = Permission(code=code.value, name=name)
            session.add(permission)
            permissions_by_code[code.value] = permission
        else:
            permission.name = name
    session.flush()

    for role_code, permission_codes in SYSTEM_ROLE_PERMISSIONS.items():
        role = session.scalar(
            select(Role).where(Role.church_id.is_(None), Role.code == role_code)
        )
        if role is None:
            role = Role(
                church_id=None,
                name=SYSTEM_ROLE_NAMES[role_code],
                code=role_code,
                is_system=True,
            )
            session.add(role)
            session.flush()
        else:
            role.name = SYSTEM_ROLE_NAMES[role_code]
            role.is_system = True

        session.execute(delete(RolePermission).where(RolePermission.role_id == role.id))
        session.add_all(
            RolePermission(
                role_id=role.id,
                permission_id=permissions_by_code[permission_code.value].id,
            )
            for permission_code in permission_codes
        )
    session.commit()


def main() -> None:
    with get_session_factory()() as session:
        try:
            seed_permissions_and_roles(session)
        except Exception:
            session.rollback()
            raise


if __name__ == "__main__":
    main()

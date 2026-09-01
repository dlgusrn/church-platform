import argparse
from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.database import get_session_factory
from app.core.exceptions import NotFoundError
from app.models.church import Church
from app.models.enums import MembershipStatus
from app.models.membership import ChurchMembership
from app.models.role import Role
from app.models.user import User
from app.repositories.church_repository import ChurchRepository
from app.repositories.membership_repository import MembershipRepository
from app.repositories.role_repository import RoleRepository
from app.repositories.user_repository import UserRepository
from app.services.auth_service import normalize_email, normalize_phone


def configure_admin_membership(
    *,
    user: User | None,
    church: Church | None,
    admin_role: Role | None,
    membership: ChurchMembership | None,
    now: datetime,
) -> ChurchMembership:
    if user is None:
        raise NotFoundError("User not found")
    if church is None:
        raise NotFoundError("Church not found")
    if admin_role is None:
        raise NotFoundError("System admin role not found; run permission seed first")
    if membership is None:
        membership = ChurchMembership(
            user_id=user.id,
            church_id=church.id,
            requested_at=now,
        )
    membership.status = MembershipStatus.APPROVED
    membership.role_id = admin_role.id
    membership.approved_at = now
    membership.rejected_at = None
    return membership


def bootstrap_admin(session: Session, identifier: str, church_code: str) -> ChurchMembership:
    users = UserRepository(session)
    churches = ChurchRepository(session)
    memberships = MembershipRepository(session)
    roles = RoleRepository(session)
    normalized = identifier.strip()
    user = (
        users.get_by_email(normalize_email(normalized))
        if "@" in normalized
        else users.get_by_phone(normalize_phone(normalized))
    )
    church = churches.get_by_code(church_code.strip())
    admin_role = roles.get_system_by_code("admin")
    existing = (
        memberships.get_by_user_and_church(user.id, church.id, for_update=True)
        if user is not None and church is not None
        else None
    )
    membership = configure_admin_membership(
        user=user,
        church=church,
        admin_role=admin_role,
        membership=existing,
        now=datetime.now(UTC),
    )
    if existing is None:
        memberships.add(membership)
    else:
        memberships.clear_overrides(membership)
    session.commit()
    return membership


def main() -> None:
    parser = argparse.ArgumentParser(description="Assign the system admin role to an existing membership")
    parser.add_argument("--identifier", required=True)
    parser.add_argument("--church-code", required=True)
    arguments = parser.parse_args()
    with get_session_factory()() as session:
        try:
            membership = bootstrap_admin(session, arguments.identifier, arguments.church_code)
        except Exception:
            session.rollback()
            raise
    print(f"Admin membership ready: membership_id={membership.id}")


if __name__ == "__main__":
    main()

from datetime import UTC, datetime

import pytest

from app.core.exceptions import NotFoundError
from app.models.church import Church
from app.models.enums import MembershipStatus
from app.models.membership import ChurchMembership
from app.models.role import Role
from app.models.user import User
from app.scripts.bootstrap_admin import configure_admin_membership


def _entities() -> tuple[User, Church, Role]:
    return (
        User(id=1, name="Admin", email="admin@example.com", password_hash="hash"),
        Church(id=2, code="skygate", name="하늘문교회"),
        Role(id=3, code="admin", name="관리자", is_system=True),
    )


def test_bootstrap_creates_approved_admin_membership() -> None:
    user, church, role = _entities()
    now = datetime.now(UTC)
    membership = configure_admin_membership(
        user=user,
        church=church,
        admin_role=role,
        membership=None,
        now=now,
    )
    assert membership.user_id == user.id
    assert membership.church_id == church.id
    assert membership.role_id == role.id
    assert membership.status is MembershipStatus.APPROVED
    assert membership.approved_at == now


def test_bootstrap_is_idempotent_for_existing_membership() -> None:
    user, church, role = _entities()
    membership = ChurchMembership(
        id=4,
        user_id=user.id,
        church_id=church.id,
        status=MembershipStatus.REJECTED,
        requested_at=datetime.now(UTC),
    )
    result = configure_admin_membership(
        user=user,
        church=church,
        admin_role=role,
        membership=membership,
        now=datetime.now(UTC),
    )
    assert result is membership
    assert result.status is MembershipStatus.APPROVED
    assert result.role_id == role.id


@pytest.mark.parametrize(
    ("missing", "message"),
    [("user", "User not found"), ("church", "Church not found"), ("role", "System admin role")],
)
def test_bootstrap_requires_existing_entities(missing: str, message: str) -> None:
    user, church, role = _entities()
    values = {"user": user, "church": church, "admin_role": role}
    values[{"user": "user", "church": "church", "role": "admin_role"}[missing]] = None
    with pytest.raises(NotFoundError, match=message):
        configure_admin_membership(
            **values,
            membership=None,
            now=datetime.now(UTC),
        )

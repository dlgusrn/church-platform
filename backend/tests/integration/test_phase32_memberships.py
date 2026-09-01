from collections.abc import Iterator
from dataclasses import dataclass
from datetime import UTC, datetime
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.church import Church
from app.models.enums import MembershipStatus, PermissionEffect
from app.models.membership import ChurchMembership
from app.models.permission import Permission
from app.models.permission_override import MembershipPermissionOverride
from app.models.role import Role, RolePermission
from app.models.user import User
from app.scripts.seed_permissions import seed_permissions_and_roles
from app.scripts.bootstrap_admin import bootstrap_admin
from app.core.exceptions import NotFoundError

pytestmark = pytest.mark.integration


@dataclass
class Scenario:
    church: Church
    other_church: Church
    admin: User
    applicant: User
    admin_membership: ChurchMembership
    admin_role: Role
    member_role: Role
    permissions: dict[str, Permission]

    def headers(self, user: User) -> dict[str, str]:
        return {"Authorization": f"Bearer {create_access_token(user.id)}"}


@pytest.fixture
def client(mysql_session: Session) -> Iterator[TestClient]:
    def override_database() -> Iterator[Session]:
        yield mysql_session

    app.dependency_overrides[get_db] = override_database
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def scenario(mysql_session: Session) -> Scenario:
    seed_permissions_and_roles(mysql_session)
    suffix = uuid4().hex
    church = Church(name="하늘문교회", code=f"skydoor-{suffix}")
    other_church = Church(name="브엘성회", code=f"beersheba-{suffix}")
    admin = User(
        name="Admin",
        email=f"admin-{suffix}@example.com",
        password_hash="argon2-hash",
    )
    applicant = User(
        name="Applicant",
        email=f"applicant-{suffix}@example.com",
        password_hash="argon2-hash",
    )
    mysql_session.add_all([church, other_church, admin, applicant])
    mysql_session.flush()
    roles = {
        role.code: role
        for role in mysql_session.scalars(select(Role).where(Role.church_id.is_(None))).all()
    }
    permissions = {
        permission.code: permission
        for permission in mysql_session.scalars(select(Permission)).all()
    }
    now = datetime.now(UTC)
    admin_membership = ChurchMembership(
        user_id=admin.id,
        church_id=church.id,
        status=MembershipStatus.APPROVED,
        role_id=roles["admin"].id,
        requested_at=now,
        approved_at=now,
    )
    mysql_session.add(admin_membership)
    mysql_session.commit()
    return Scenario(
        church=church,
        other_church=other_church,
        admin=admin,
        applicant=applicant,
        admin_membership=admin_membership,
        admin_role=roles["admin"],
        member_role=roles["member"],
        permissions=permissions,
    )


def test_join_duplicate_reject_and_reapply_reset(
    client: TestClient, mysql_session: Session, scenario: Scenario
) -> None:
    headers = scenario.headers(scenario.applicant)
    churches = client.get("/api/v1/churches", headers=headers)
    assert churches.status_code == 200
    assert {item["id"] for item in churches.json()} >= {
        scenario.church.id,
        scenario.other_church.id,
    }

    join = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships", headers=headers
    )
    assert join.status_code == 201
    membership_id = join.json()["membership_id"]
    assert join.json()["status"] == "pending"
    assert client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships", headers=headers
    ).status_code == 409

    approved_other = ChurchMembership(
        user_id=scenario.applicant.id,
        church_id=scenario.other_church.id,
        status=MembershipStatus.APPROVED,
        role_id=scenario.member_role.id,
        requested_at=datetime.now(UTC),
        approved_at=datetime.now(UTC),
    )
    mysql_session.add(approved_other)
    mysql_session.commit()
    assert client.post(
        f"/api/v1/churches/{scenario.other_church.id}/memberships", headers=headers
    ).status_code == 409

    reject = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships/{membership_id}/reject",
        headers=scenario.headers(scenario.admin),
    )
    assert reject.status_code == 200
    membership = mysql_session.get(ChurchMembership, membership_id)
    assert membership is not None
    membership.role_id = scenario.member_role.id
    mysql_session.add(
        MembershipPermissionOverride(
            membership_id=membership.id,
            permission_id=scenario.permissions["vod.view"].id,
            effect=PermissionEffect.DENY,
        )
    )
    mysql_session.commit()

    reapply = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships", headers=headers
    )
    assert reapply.status_code == 201
    assert reapply.json()["status"] == "pending"
    assert reapply.json()["role"] is None
    assert mysql_session.scalar(
        select(MembershipPermissionOverride).where(
            MembershipPermissionOverride.membership_id == membership_id
        )
    ) is None


def test_approval_effective_permissions_and_validation(
    client: TestClient, mysql_session: Session, scenario: Scenario
) -> None:
    applicant_headers = scenario.headers(scenario.applicant)
    join = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships",
        headers=applicant_headers,
    )
    membership_id = join.json()["membership_id"]
    approve_url = (
        f"/api/v1/churches/{scenario.church.id}/memberships/{membership_id}/approve"
    )
    approve = client.post(
        approve_url,
        headers=scenario.headers(scenario.admin),
        json={
            "role_id": scenario.member_role.id,
            "granted_permissions": ["media.audio.view"],
            "denied_permissions": ["vod.view"],
        },
    )
    assert approve.status_code == 200, approve.text
    assert approve.json()["effective_permissions"] == [
        "live.access",
        "media.audio.view",
    ]
    mysql_session.expire_all()
    stored_overrides = mysql_session.scalars(
        select(MembershipPermissionOverride).where(
            MembershipPermissionOverride.membership_id == membership_id
        )
    ).all()
    assert {
        (override.permission_id, override.effect) for override in stored_overrides
    } == {
        (scenario.permissions["media.audio.view"].id, PermissionEffect.GRANT),
        (scenario.permissions["vod.view"].id, PermissionEffect.DENY),
    }
    own = client.get(
        f"/api/v1/memberships/{membership_id}/permissions",
        headers=applicant_headers,
    )
    assert own.status_code == 200
    assert own.json()["denied_permissions"] == ["vod.view"]
    memberships = client.get("/api/v1/users/me/memberships", headers=applicant_headers)
    assert memberships.status_code == 200
    assert memberships.json()[0]["effective_permissions"] == [
        "live.access",
        "media.audio.view",
    ]

    overlap = client.patch(
        f"/api/v1/churches/{scenario.church.id}/memberships/{membership_id}/permissions",
        headers=scenario.headers(scenario.admin),
        json={
            "role_id": scenario.member_role.id,
            "granted_permissions": ["vod.view"],
            "denied_permissions": ["vod.view"],
        },
    )
    assert overlap.status_code == 422
    unknown = client.patch(
        f"/api/v1/churches/{scenario.church.id}/memberships/{membership_id}/permissions",
        headers=scenario.headers(scenario.admin),
        json={
            "role_id": scenario.member_role.id,
            "granted_permissions": ["unknown.permission"],
            "denied_permissions": [],
        },
    )
    assert unknown.status_code == 422


def test_church_scoped_authorization_and_immediate_jwt_effect(
    client: TestClient, scenario: Scenario
) -> None:
    admin_headers = scenario.headers(scenario.admin)
    assert client.get(
        f"/api/v1/churches/{scenario.church.id}/memberships/pending",
        headers=admin_headers,
    ).status_code == 200
    assert client.get(
        f"/api/v1/churches/{scenario.other_church.id}/memberships/pending",
        headers=admin_headers,
    ).status_code == 403
    assert client.get(
        f"/api/v1/churches/{scenario.church.id}/memberships/pending",
        headers=scenario.headers(scenario.applicant),
    ).status_code == 403

    update_self = client.patch(
        f"/api/v1/churches/{scenario.church.id}/memberships/"
        f"{scenario.admin_membership.id}/permissions",
        headers=admin_headers,
        json={
            "role_id": scenario.admin_role.id,
            "granted_permissions": [],
            "denied_permissions": ["member.view", "member.manage"],
        },
    )
    assert update_self.status_code == 200, update_self.text
    assert client.get(
        f"/api/v1/churches/{scenario.church.id}/memberships/pending",
        headers=admin_headers,
    ).status_code == 403


def test_reject_preserves_user_and_other_church_membership(
    client: TestClient, mysql_session: Session, scenario: Scenario
) -> None:
    headers = scenario.headers(scenario.applicant)
    first = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships", headers=headers
    ).json()
    other = ChurchMembership(
        user_id=scenario.applicant.id,
        church_id=scenario.other_church.id,
        status=MembershipStatus.APPROVED,
        role_id=scenario.member_role.id,
        requested_at=datetime.now(UTC),
        approved_at=datetime.now(UTC),
    )
    mysql_session.add(other)
    mysql_session.commit()
    response = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships/"
        f"{first['membership_id']}/reject",
        headers=scenario.headers(scenario.admin),
    )
    assert response.status_code == 200
    assert mysql_session.get(User, scenario.applicant.id) is not None
    mysql_session.refresh(other)
    assert other.status is MembershipStatus.APPROVED


def test_role_scope_filters_and_rejects_other_church_custom_role(
    client: TestClient, mysql_session: Session, scenario: Scenario
) -> None:
    own_role = Role(name="찬양팀", code=f"worship-{uuid4().hex}", church_id=scenario.church.id)
    other_role = Role(
        name="재정부",
        code=f"finance-{uuid4().hex}",
        church_id=scenario.other_church.id,
    )
    mysql_session.add_all([own_role, other_role])
    mysql_session.flush()
    mysql_session.add(
        RolePermission(
            role_id=own_role.id,
            permission_id=scenario.permissions["document.view"].id,
        )
    )
    mysql_session.commit()
    roles = client.get(
        f"/api/v1/churches/{scenario.church.id}/roles",
        headers=scenario.headers(scenario.admin),
    )
    assert roles.status_code == 200
    role_ids = {item["id"] for item in roles.json()}
    assert own_role.id in role_ids
    assert other_role.id not in role_ids

    join = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships",
        headers=scenario.headers(scenario.applicant),
    ).json()
    invalid = client.post(
        f"/api/v1/churches/{scenario.church.id}/memberships/"
        f"{join['membership_id']}/approve",
        headers=scenario.headers(scenario.admin),
        json={
            "role_id": other_role.id,
            "granted_permissions": [],
            "denied_permissions": [],
        },
    )
    assert invalid.status_code == 404


def test_bootstrap_admin_is_idempotent_and_requires_existing_resources(
    mysql_session: Session, scenario: Scenario
) -> None:
    first = bootstrap_admin(
        mysql_session,
        scenario.applicant.email or "",
        scenario.other_church.code,
    )
    second = bootstrap_admin(
        mysql_session,
        scenario.applicant.email or "",
        scenario.other_church.code,
    )
    assert first.id == second.id
    assert second.status is MembershipStatus.APPROVED
    assert second.role_id == scenario.admin_role.id
    memberships = mysql_session.scalars(
        select(ChurchMembership).where(
            ChurchMembership.user_id == scenario.applicant.id,
            ChurchMembership.church_id == scenario.other_church.id,
        )
    ).all()
    assert len(memberships) == 1

    with pytest.raises(NotFoundError, match="User not found"):
        bootstrap_admin(mysql_session, "missing@example.com", scenario.church.code)
    with pytest.raises(NotFoundError, match="Church not found"):
        bootstrap_admin(mysql_session, scenario.admin.email or "", "missing-church")

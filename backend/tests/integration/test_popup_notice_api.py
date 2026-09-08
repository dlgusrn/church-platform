from collections.abc import Iterator
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from io import BytesIO
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from PIL import Image
from sqlalchemy import create_engine, delete, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.church import Church
from app.models.enums import MembershipStatus, PermissionEffect
from app.models.membership import ChurchMembership
from app.models.permission import Permission
from app.models.permission_override import MembershipPermissionOverride
from app.models.popup_notice import PopupNotice
from app.models.role import Role
from app.models.user import User
from app.scripts.seed_permissions import seed_permissions_and_roles
from app.services.media_storage import LocalPopupNoticeMediaStorage
from app.schemas.popup_notice import PopupNoticeCreateRequest
from app.services.popup_notice_service import PopupNoticeService

pytestmark = pytest.mark.integration


@dataclass
class Scenario:
    church: Church
    other_church: Church
    admin: User
    member: User
    pending: User
    rejected: User

    def headers(self, user: User) -> dict[str, str]:
        return {"Authorization": f"Bearer {create_access_token(user.id)}"}


@pytest.fixture
def client(mysql_session: Session, monkeypatch: pytest.MonkeyPatch, tmp_path: object) -> Iterator[TestClient]:
    from app.services import popup_notice_service
    monkeypatch.setattr(
        popup_notice_service,
        "LocalPopupNoticeMediaStorage",
        lambda _root: LocalPopupNoticeMediaStorage(tmp_path),
    )
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
    church, other = Church(name="팝업 A", code=f"popup-a-{suffix}"), Church(name="팝업 B", code=f"popup-b-{suffix}")
    admin = User(name="관리자", email=f"popup-admin-{suffix}@example.com", password_hash="hash")
    member = User(name="성도", email=f"popup-member-{suffix}@example.com", password_hash="hash")
    pending = User(name="대기", email=f"popup-pending-{suffix}@example.com", password_hash="hash")
    rejected = User(name="거절", email=f"popup-rejected-{suffix}@example.com", password_hash="hash")
    mysql_session.add_all([church, other, admin, member, pending, rejected])
    mysql_session.flush()
    roles = {item.code: item for item in mysql_session.scalars(select(Role).where(Role.church_id.is_(None))).all()}
    now = datetime.now(UTC)
    mysql_session.add_all([
        ChurchMembership(user_id=admin.id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=roles["admin"].id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=member.id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=roles["member"].id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=pending.id, church_id=church.id, status=MembershipStatus.PENDING, role_id=roles["admin"].id, requested_at=now),
        ChurchMembership(user_id=rejected.id, church_id=church.id, status=MembershipStatus.REJECTED, role_id=roles["admin"].id, requested_at=now, rejected_at=now),
    ])
    mysql_session.commit()
    return Scenario(church, other, admin, member, pending, rejected)


def body(start: datetime, end: datetime, **extra: object) -> dict[str, object]:
    return {"title": "팝업", "content": "내용", "starts_at": start.isoformat().replace("+00:00", "Z"), "ends_at": end.isoformat().replace("+00:00", "Z"), **extra}


def create(client: TestClient, s: Scenario, start: datetime, end: datetime, **extra: object) -> dict[str, object]:
    response = client.post(f"/api/v1/churches/{s.church.id}/popup-notices", headers=s.headers(s.admin), json=body(start, end, **extra))
    assert response.status_code == 201, response.text
    return response.json()


def test_current_membership_boundaries_and_management_permissions(client: TestClient, scenario: Scenario) -> None:
    now = datetime.now(UTC).replace(microsecond=0)
    url = f"/api/v1/churches/{scenario.church.id}/popup-notices"
    assert client.get(f"{url}/current", headers=scenario.headers(scenario.member)).json() is None
    item = create(client, scenario, now, now + timedelta(hours=1), is_active=True)
    current = client.get(f"{url}/current", headers=scenario.headers(scenario.member))
    assert current.status_code == 200 and current.json()["id"] == item["id"]
    assert current.json()["starts_at"].endswith("Z")
    assert client.get(f"{url}/current", headers=scenario.headers(scenario.pending)).status_code == 403
    assert client.get(f"{url}/current", headers=scenario.headers(scenario.rejected)).status_code == 403
    assert client.get(url, headers=scenario.headers(scenario.member)).status_code == 403
    assert client.get(f"/api/v1/churches/{scenario.other_church.id}/popup-notices/current", headers=scenario.headers(scenario.admin)).status_code == 403


def test_overlap_update_toggle_exact_boundary_and_spoofing(
    client: TestClient, mysql_session: Session, scenario: Scenario
) -> None:
    base = datetime(2030, 1, 1, tzinfo=UTC)
    first = create(client, scenario, base, base + timedelta(days=2), is_active=True)
    conflict = client.post(f"/api/v1/churches/{scenario.church.id}/popup-notices", headers=scenario.headers(scenario.admin), json=body(base + timedelta(days=1), base + timedelta(days=3), is_active=True))
    assert conflict.status_code == 409 and conflict.json()["code"] == "popup_notice_period_overlap"
    adjacent = create(client, scenario, base + timedelta(days=2), base + timedelta(days=3), is_active=True)
    inactive = create(client, scenario, base + timedelta(days=1), base + timedelta(days=3), is_active=False)
    active = client.patch(f"/api/v1/churches/{scenario.church.id}/popup-notices/{inactive['id']}/active", headers=scenario.headers(scenario.admin), json={"is_active": True})
    assert active.status_code == 409 and active.json()["code"] == "popup_notice_period_overlap"
    changed = client.patch(f"/api/v1/churches/{scenario.church.id}/popup-notices/{adjacent['id']}", headers=scenario.headers(scenario.admin), json={"starts_at": (base + timedelta(days=1)).isoformat()})
    assert changed.status_code == 409
    spoof = client.post(f"/api/v1/churches/{scenario.church.id}/popup-notices", headers=scenario.headers(scenario.admin), json={**body(base + timedelta(days=4), base + timedelta(days=5)), "church_id": scenario.other_church.id, "author_membership_id": 1})
    assert spoof.status_code == 422
    stored = mysql_session.get(PopupNotice, first["id"])
    author_membership = mysql_session.scalar(select(ChurchMembership).where(ChurchMembership.user_id == scenario.admin.id, ChurchMembership.church_id == scenario.church.id))
    assert stored is not None and author_membership is not None
    assert stored.author_membership_id == author_membership.id


def test_deny_override_and_image_lifecycle(
    client: TestClient, mysql_session: Session, scenario: Scenario, tmp_path: object
) -> None:
    now = datetime.now(UTC)
    item = create(client, scenario, now, now + timedelta(days=1))
    url = f"/api/v1/churches/{scenario.church.id}/popup-notices/{item['id']}"
    image = _png()
    uploaded = client.put(f"{url}/image", headers=scenario.headers(scenario.admin), files={"image": ("../../evil.png", image, "image/jpeg")})
    assert uploaded.status_code == 200, uploaded.text
    assert uploaded.json()["image"]["content_type"] == "image/png"
    fetched = client.get(f"{url}/image", headers=scenario.headers(scenario.member))
    assert fetched.status_code == 200 and fetched.headers["content-type"].startswith("image/png")
    replaced = client.put(f"{url}/image", headers=scenario.headers(scenario.admin), files={"image": ("next.png", _png(), "image/png")})
    assert replaced.status_code == 200
    from pathlib import Path
    assert len(list((Path(tmp_path) / "popup-notices").glob("*"))) == 1
    assert client.put(f"{url}/image", headers=scenario.headers(scenario.admin), files={"image": ("bad.png", b"not image", "image/png")}).status_code == 422
    assert client.delete(f"{url}/image", headers=scenario.headers(scenario.admin)).json()["image"] is None
    assert list((Path(tmp_path) / "popup-notices").glob("*")) == []
    membership = mysql_session.scalar(select(ChurchMembership).where(ChurchMembership.user_id == scenario.admin.id, ChurchMembership.church_id == scenario.church.id))
    permission = mysql_session.scalar(select(Permission).where(Permission.code == "popup_notice.manage"))
    assert membership is not None and permission is not None
    mysql_session.add(MembershipPermissionOverride(membership_id=membership.id, permission_id=permission.id, effect=PermissionEffect.DENY))
    mysql_session.commit()
    assert client.get(f"/api/v1/churches/{scenario.church.id}/popup-notices", headers=scenario.headers(scenario.admin)).status_code == 403


def test_mysql_concurrent_overlapping_creates_allow_only_one(
    migrated_test_database: str,
) -> None:
    """Uses two independent MySQL sessions, not TestClient's shared test transaction."""
    engine = create_engine(migrated_test_database, pool_pre_ping=True)
    suffix = uuid4().hex
    church_id = user_id = None
    try:
        with Session(engine) as setup:
            seed_permissions_and_roles(setup)
            role = setup.scalar(select(Role).where(Role.church_id.is_(None), Role.code == "admin"))
            assert role is not None
            church = Church(name="동시성", code=f"popup-concurrency-{suffix}")
            user = User(name="동시성 관리자", email=f"popup-concurrency-{suffix}@example.com", password_hash="hash")
            setup.add_all([church, user])
            setup.flush()
            now = datetime.now(UTC)
            setup.add(ChurchMembership(user_id=user.id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=role.id, requested_at=now, approved_at=now))
            setup.commit()
            church_id, user_id = church.id, user.id

        request = PopupNoticeCreateRequest(
            title="동시 팝업", content="내용", is_active=True,
            starts_at="2031-01-01T00:00:00Z", ends_at="2031-01-02T00:00:00Z",
        )

        def create_once() -> str:
            with Session(engine) as session:
                try:
                    PopupNoticeService(session).create(church_id, user_id, request)  # type: ignore[arg-type]
                    return "created"
                except Exception as exc:
                    return type(exc).__name__

        with ThreadPoolExecutor(max_workers=2) as executor:
            outcomes = list(executor.map(lambda _: create_once(), range(2)))
        assert outcomes.count("created") == 1
        assert outcomes.count("PopupNoticeOverlapError") == 1
    finally:
        if church_id is not None:
            with Session(engine) as cleanup:
                cleanup.execute(delete(PopupNotice).where(PopupNotice.church_id == church_id))
                cleanup.execute(delete(ChurchMembership).where(ChurchMembership.church_id == church_id))
                cleanup.execute(delete(Church).where(Church.id == church_id))
                cleanup.commit()
        if user_id is not None:
            with Session(engine) as cleanup:
                user = cleanup.get(User, user_id)
                if user is not None:
                    cleanup.delete(user)
                    cleanup.commit()
        engine.dispose()


def _png() -> bytes:
    image = Image.new("RGB", (8, 8), "white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()

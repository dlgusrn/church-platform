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
from app.models.video import Video, VideoCategory, VideoCollection
from app.scripts.seed_permissions import seed_permissions_and_roles
from app.services.permission_service import get_permission_breakdown

pytestmark = pytest.mark.integration


@dataclass
class VideoScenario:
    church: Church
    other_church: Church
    admin: User
    vod_user: User
    media_view_user: User
    no_permission_user: User
    manager: User
    denied_user: User

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
def video_scenario(mysql_session: Session) -> VideoScenario:
    seed_permissions_and_roles(mysql_session)
    suffix = uuid4().hex
    church = Church(name="영상 교회", code=f"video-a-{suffix}")
    other_church = Church(name="다른 영상 교회", code=f"video-b-{suffix}")
    users = [
        User(name=name, email=f"video-{name}-{suffix}@example.com", password_hash="hash")
        for name in ("admin", "vod", "media", "named-admin", "manager", "denied")
    ]
    mysql_session.add_all([church, other_church, *users])
    mysql_session.flush()
    permissions = {item.code: item for item in mysql_session.scalars(select(Permission)).all()}
    system_roles = {item.code: item for item in mysql_session.scalars(select(Role).where(Role.church_id.is_(None))).all()}
    media_role = Role(church_id=church.id, name="영상 열람", code=f"media-view-{suffix}")
    named_admin_role = Role(church_id=church.id, name="admin", code=f"name-only-{suffix}")
    manager_role = Role(church_id=church.id, name="영상 관리", code=f"video-manage-{suffix}")
    mysql_session.add_all([media_role, named_admin_role, manager_role])
    mysql_session.flush()
    mysql_session.add_all([
        RolePermission(role_id=media_role.id, permission_id=permissions["media.video.view"].id),
        RolePermission(role_id=manager_role.id, permission_id=permissions["media.video.manage"].id),
    ])
    now = datetime.now(UTC)
    memberships = [
        ChurchMembership(user_id=users[0].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=system_roles["admin"].id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=users[1].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=system_roles["member"].id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=users[2].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=media_role.id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=users[3].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=named_admin_role.id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=users[4].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=manager_role.id, requested_at=now, approved_at=now),
        ChurchMembership(user_id=users[5].id, church_id=church.id, status=MembershipStatus.APPROVED, role_id=system_roles["member"].id, requested_at=now, approved_at=now),
    ]
    mysql_session.add_all(memberships)
    mysql_session.flush()
    mysql_session.add(MembershipPermissionOverride(
        membership_id=memberships[-1].id,
        permission_id=permissions["vod.view"].id,
        effect=PermissionEffect.DENY,
    ))
    mysql_session.commit()
    return VideoScenario(church, other_church, *users)


def videos_url(scenario: VideoScenario) -> str:
    return f"/api/v1/churches/{scenario.church.id}/videos"


def create_video(client: TestClient, scenario: VideoScenario, *, title: str, source_type: str, source_ref: str, recorded_at: str, **extra: object) -> dict:
    response = client.post(videos_url(scenario), headers=scenario.headers(scenario.manager), json={
        "title": title, "source_type": source_type, "source_ref": source_ref,
        "recorded_at": recorded_at, **extra,
    })
    assert response.status_code == 201, response.text
    return response.json()


def test_video_permissions_effective_permissions_and_mutation(client: TestClient, mysql_session: Session, video_scenario: VideoScenario) -> None:
    scenario = video_scenario
    url = videos_url(scenario)
    assert client.get(url, headers=scenario.headers(scenario.no_permission_user)).status_code == 403
    assert client.get(url, headers=scenario.headers(scenario.vod_user)).status_code == 200
    assert client.get(url, headers=scenario.headers(scenario.media_view_user)).status_code == 200
    assert client.get(url, headers=scenario.headers(scenario.denied_user)).status_code == 403
    payload = {"title": "행사 영상", "source_type": "synology", "source_ref": "/events/opening.mp4", "recorded_at": "2026-01-03T10:00:00Z"}
    assert client.post(url, headers=scenario.headers(scenario.vod_user), json=payload).status_code == 403
    assert client.post(url, headers=scenario.headers(scenario.manager), json=payload).status_code == 201
    manager_membership = mysql_session.scalar(select(ChurchMembership).where(ChurchMembership.user_id == scenario.manager.id))
    assert manager_membership is not None
    effective = get_permission_breakdown(manager_membership).effective_permissions
    assert "media.video.manage" in effective
    assert "media.video.download" not in effective


def test_video_sources_sort_filters_archive_and_validation(client: TestClient, video_scenario: VideoScenario) -> None:
    scenario = video_scenario
    category_url = f"/api/v1/churches/{scenario.church.id}/video-categories"
    category = client.post(category_url, headers=scenario.headers(scenario.manager), json={"name": "행사"}).json()
    category_update = client.patch(
        f"{category_url}/{category['id']}",
        headers=scenario.headers(scenario.manager),
        json={"name": "행사 영상", "sort_order": 2},
    )
    assert category_update.status_code == 200
    assert category_update.json()["name"] == "행사 영상"
    collection_url = f"/api/v1/churches/{scenario.church.id}/video-collections"
    collection = client.post(collection_url, headers=scenario.headers(scenario.manager), json={"title": "해외선교", "category_id": category["id"]}).json()
    collection_update = client.patch(
        f"{collection_url}/{collection['id']}",
        headers=scenario.headers(scenario.manager),
        json={"description": "해외선교 행사 영상", "sort_order": 1},
    )
    assert collection_update.status_code == 200
    assert collection_update.json()["description"] == "해외선교 행사 영상"
    old = create_video(client, scenario, title="Synology", source_type="synology", source_ref="/mission/old.mp4", recorded_at="2025-12-10T10:00:00Z", category_id=category["id"])
    first_same = create_video(client, scenario, title="YouTube", source_type="youtube", source_ref="youtube-video-1", recorded_at="2026-02-15T10:00:00Z", collection_id=collection["id"])
    second_same = create_video(client, scenario, title="Same timestamp", source_type="synology", source_ref="/mission/new.mp4", recorded_at="2026-02-15T10:00:00Z", category_id=category["id"], collection_id=collection["id"])
    unpublished = create_video(client, scenario, title="비공개", source_type="youtube", source_ref="private-video", recorded_at="2027-01-01T10:00:00Z", is_published=False)
    listed = client.get(videos_url(scenario), headers=scenario.headers(scenario.vod_user))
    assert listed.status_code == 200
    assert [item["id"] for item in listed.json()] == [second_same["id"], first_same["id"], old["id"]]
    assert unpublished["id"] not in [item["id"] for item in listed.json()]
    assert [item["id"] for item in client.get(f"{videos_url(scenario)}?year=2026&month=2", headers=scenario.headers(scenario.vod_user)).json()] == [second_same["id"], first_same["id"]]
    assert [item["id"] for item in client.get(f"{videos_url(scenario)}?category_id={category['id']}", headers=scenario.headers(scenario.vod_user)).json()] == [second_same["id"], old["id"]]
    assert [item["id"] for item in client.get(f"{videos_url(scenario)}?collection_id={collection['id']}", headers=scenario.headers(scenario.vod_user)).json()] == [second_same["id"], first_same["id"]]
    assert client.get(f"{videos_url(scenario)}?month=13", headers=scenario.headers(scenario.vod_user)).status_code == 422
    for payload in (
        {"title": "x", "source_type": "invalid", "source_ref": "x", "recorded_at": "2026-01-01T00:00:00Z"},
        {"title": " ", "source_type": "youtube", "source_ref": "x", "recorded_at": "2026-01-01T00:00:00Z"},
        {"title": "x", "source_type": "youtube", "source_ref": " ", "recorded_at": "2026-01-01T00:00:00Z"},
        {"title": "x", "source_type": "youtube", "source_ref": "x", "recorded_at": "2026-01-01T00:00:00Z", "duration_seconds": -1},
        {"title": "x", "source_type": "youtube", "source_ref": "x", "recorded_at": "2026-01-01T00:00:00Z", "unknown": True},
    ):
        assert client.post(videos_url(scenario), headers=scenario.headers(scenario.manager), json=payload).status_code == 422
    duplicate = {"title": "duplicate", "source_type": "youtube", "source_ref": "youtube-video-1", "recorded_at": "2026-02-16T10:00:00Z"}
    assert client.post(videos_url(scenario), headers=scenario.headers(scenario.manager), json=duplicate).status_code == 409
    archive = client.get(f"{videos_url(scenario)}/archive", headers=scenario.headers(scenario.vod_user))
    assert archive.json() == [{"year": 2026, "month": 2, "video_count": 2}, {"year": 2025, "month": 12, "video_count": 1}]


def test_video_church_isolation_category_and_collection_lifecycle(client: TestClient, mysql_session: Session, video_scenario: VideoScenario) -> None:
    scenario = video_scenario
    category_url = f"/api/v1/churches/{scenario.church.id}/video-categories"
    category = client.post(category_url, headers=scenario.headers(scenario.manager), json={"name": "일반"}).json()
    collection_url = f"/api/v1/churches/{scenario.church.id}/video-collections"
    collection = client.post(collection_url, headers=scenario.headers(scenario.manager), json={"title": "행사 모음", "category_id": category["id"]}).json()
    without_collection = create_video(client, scenario, title="독립 영상", source_type="synology", source_ref="/standalone.mp4", recorded_at="2026-03-01T00:00:00Z")
    linked_one = create_video(client, scenario, title="행사 1", source_type="synology", source_ref="/event/1.mp4", recorded_at="2026-03-02T00:00:00Z", collection_id=collection["id"])
    linked_two = create_video(client, scenario, title="행사 2", source_type="youtube", source_ref="event-2", recorded_at="2026-03-03T00:00:00Z", collection_id=collection["id"])
    assert without_collection["collection_id"] is None
    other_category = client.post(
        f"/api/v1/churches/{scenario.other_church.id}/video-categories",
        headers=scenario.headers(scenario.admin), json={"name": "other"},
    )
    assert other_category.status_code == 403
    # Create foreign references directly; no A membership can administer church B.
    foreign_category = VideoCategory(church_id=scenario.other_church.id, name="foreign")
    foreign_collection = VideoCollection(church_id=scenario.other_church.id, title="foreign")
    mysql_session.add_all([foreign_category, foreign_collection])
    mysql_session.commit()
    for key, value in (("category_id", foreign_category.id), ("collection_id", foreign_collection.id)):
        response = client.post(videos_url(scenario), headers=scenario.headers(scenario.manager), json={"title": f"cross {key}", "source_type": "youtube", "source_ref": f"cross-{key}", "recorded_at": "2026-03-04T00:00:00Z", key: value})
        assert response.status_code == 422
    assert client.get(f"/api/v1/churches/{scenario.other_church.id}/videos/{linked_one['id']}", headers=scenario.headers(scenario.vod_user)).status_code == 403
    assert client.delete(f"{category_url}/{category['id']}", headers=scenario.headers(scenario.manager)).status_code == 200
    assert mysql_session.get(Video, linked_one["id"]) is not None
    assert client.post(videos_url(scenario), headers=scenario.headers(scenario.manager), json={"title": "inactive category", "source_type": "youtube", "source_ref": "inactive", "recorded_at": "2026-03-04T00:00:00Z", "category_id": category["id"]}).status_code == 422
    assert client.delete(f"{collection_url}/{collection['id']}", headers=scenario.headers(scenario.manager)).status_code == 204
    mysql_session.expire_all()
    assert mysql_session.get(Video, linked_one["id"]).collection_id is None
    assert mysql_session.get(Video, linked_two["id"]).collection_id is None
    assert client.delete(f"{videos_url(scenario)}/{linked_one['id']}", headers=scenario.headers(scenario.manager)).status_code == 204
    assert mysql_session.get(Video, linked_one["id"]) is None

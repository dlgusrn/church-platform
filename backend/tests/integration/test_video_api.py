from collections.abc import Iterator
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from uuid import uuid4

import pytest
import httpx
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session, sessionmaker

from app.core.database import get_db, get_playback_session
from app.core.security import create_access_token, create_video_playback_token
from app.main import app
from app.models.church import Church
from app.models.enums import MembershipStatus, PermissionEffect
from app.models.membership import ChurchMembership
from app.models.permission import Permission
from app.models.permission_override import MembershipPermissionOverride
from app.models.role import Role, RolePermission
from app.models.user import User
from app.models.video import Video, VideoCategory, VideoCollection, VideoSourceType
from app.scripts.seed_permissions import seed_permissions_and_roles
from app.services.permission_service import get_permission_breakdown
from app.services.video_sources.synology.client import SynologyEntry
from app.services.video_sources.synology.parser import infer_candidate
from app.services.video_sources.synology.service import MAX_BATCH_SIZE, Snapshot, SynologyImportService, _snapshots
from app.services.video_playback_service import VideoPlaybackService
from app.core.exceptions import RequestValidationError

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

    def override_playback_database() -> Session:
        return sessionmaker(bind=mysql_session.get_bind(), autoflush=False, expire_on_commit=False)()

    app.dependency_overrides[get_db] = override_database
    app.dependency_overrides[get_playback_session] = override_playback_database
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


def test_synology_playback_session_is_scoped_and_member_response_hides_source_ref(
    client: TestClient, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    created = create_video(
        client, scenario, title="NAS", source_type="synology", source_ref="2026/private.mp4",
        recorded_at="2026-01-03T10:00:00Z",
    )
    listed = client.get(videos_url(scenario), headers=scenario.headers(scenario.vod_user))
    assert listed.status_code == 200
    assert listed.json()[0]["source_ref"] is None
    session = client.post(
        f"{videos_url(scenario)}/{created['id']}/playback-session",
        headers=scenario.headers(scenario.vod_user),
    )
    assert session.status_code == 200, session.text
    body = session.json()
    assert body["type"] == "synology"
    assert body["playback_url"] == "/api/v1/playback"
    assert "?" not in body["playback_url"]
    assert body["playback_token"]
    assert "source_ref" not in body
    assert client.post(
        f"{videos_url(scenario)}/{created['id']}/playback-session",
        headers=scenario.headers(scenario.no_permission_user),
    ).status_code == 403


def test_playback_endpoint_relays_range_over_http(
    client: TestClient, video_scenario: VideoScenario, monkeypatch: pytest.MonkeyPatch
) -> None:
    scenario = video_scenario
    created = create_video(
        client, scenario, title="NAS range", source_type="synology", source_ref="2026/video.mp4",
        recorded_at="2026-01-03T10:00:00Z",
    )

    class FakeDownloadClient:
        closed = False
        range_header: str | None = None
        async def connect(self) -> None: pass
        async def open_download(self, _path: str, *, range_header: str | None, method: str) -> httpx.Response:
            self.range_header = range_header
            return httpx.Response(206, headers={
                "content-type": "video/mp4", "content-length": "3",
                "content-range": "bytes 0-2/10", "accept-ranges": "bytes",
            }, content=b"abc")
        async def close(self) -> None: self.closed = True

    fake = FakeDownloadClient()
    monkeypatch.setattr(VideoPlaybackService, "_download_client", lambda _: fake)
    monkeypatch.setattr(VideoPlaybackService, "_absolute_path", staticmethod(lambda _: "/test/video.mp4"))
    session = client.post(
        f"{videos_url(scenario)}/{created['id']}/playback-session",
        headers=scenario.headers(scenario.vod_user),
    )
    response = client.get(session.json()["playback_url"], headers={
        "Range": "bytes=0-2", "X-Playback-Token": session.json()["playback_token"],
    })
    assert response.status_code == 206
    assert response.content == b"abc"
    assert response.headers["content-range"] == "bytes 0-2/10"
    assert response.headers["content-length"] == "3"
    assert response.headers["content-type"].startswith("video/mp4")
    assert response.headers["accept-ranges"] == "bytes"
    assert fake.range_header == "bytes=0-2"
    head = client.head(session.json()["playback_url"], headers={
        "Range": "bytes=0-2", "X-Playback-Token": session.json()["playback_token"],
    })
    assert head.status_code == 206
    assert head.headers["content-range"] == "bytes 0-2/10"
    assert head.headers["content-length"] == "3"


def test_playback_header_is_required_and_invalid_tokens_are_rejected(
    client: TestClient, mysql_session: Session, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    created = create_video(
        client, scenario, title="NAS header auth", source_type="synology", source_ref="2026/header.mp4",
        recorded_at="2026-01-03T10:00:00Z",
    )
    playback_url = client.post(
        f"{videos_url(scenario)}/{created['id']}/playback-session", headers=scenario.headers(scenario.vod_user),
    ).json()["playback_url"]
    assert client.get(playback_url).status_code == 401
    assert client.get(playback_url, headers={"X-Playback-Token": "invalid"}).status_code == 401
    expired = create_video_playback_token(
        scenario.vod_user.id, scenario.church.id, created["id"], expires_delta=timedelta(seconds=-1),
    )
    assert client.get(playback_url, headers={"X-Playback-Token": expired}).status_code == 401
    issued = client.post(
        f"{videos_url(scenario)}/{created['id']}/playback-session", headers=scenario.headers(scenario.vod_user),
    ).json()
    membership = mysql_session.scalar(select(ChurchMembership).where(
        ChurchMembership.user_id == scenario.vod_user.id,
        ChurchMembership.church_id == scenario.church.id,
    ))
    assert membership is not None
    membership.status = MembershipStatus.PENDING
    mysql_session.commit()
    assert client.get(issued["playback_url"], headers={"X-Playback-Token": issued["playback_token"]}).status_code == 403


class _FakeSynologyClient:
    def __init__(self) -> None:
        self.list_calls = 0
        self.entries = {
            "/root": [
                SynologyEntry("/root/arbitrary", "arbitrary", True),
                SynologyEntry("/root/2026", "2026", True),
            ],
            "/root/arbitrary": [
                SynologyEntry("/root/arbitrary/20260101-a.mp4", "20260101-a.mp4", False, 1),
                SynologyEntry("/root/arbitrary/20260102-b.mov", "20260102-b.mov", False, 2),
            ],
            "/root/2026": [SynologyEntry("/root/2026/09", "09", True)],
            "/root/2026/09": [SynologyEntry("/root/2026/09/주일예배", "주일예배", True)],
            "/root/2026/09/주일예배": [
                SynologyEntry("/root/2026/09/주일예배/20260103-c.m4v", "20260103-c.m4v", False, 3),
            ],
        }

    def __enter__(self) -> "_FakeSynologyClient":
        return self

    def __exit__(self, *_: object) -> None:
        return None

    def list_directory(self, path: str, *, offset: int = 0, limit: int = 500) -> tuple[list[SynologyEntry], int]:
        self.list_calls += 1
        entries = self.entries[path]
        return entries[offset:offset + limit], len(entries)


def test_synology_snapshot_pagination_filters_and_selected_import(
    mysql_session: Session, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    mysql_session.add(Video(
        church_id=scenario.church.id,
        source_type="synology",
        source_ref="arbitrary/20260101-a.mp4",
        title="duplicate",
        recorded_at=datetime.now(UTC),
    ))
    mysql_session.commit()
    client = _FakeSynologyClient()
    service = SynologyImportService(mysql_session)
    service.configured = lambda: True  # type: ignore[method-assign]
    service._root = lambda: "/root"  # type: ignore[method-assign]
    service._client = lambda: client  # type: ignore[method-assign]

    token, page, summary, folders, selectable = service.preview(
        scenario.church.id, offset=0, limit=1
    )
    assert summary == {
        "total": 3, "filtered_total": 3, "new": 2, "already_imported": 1,
        "needs_review": 0, "ready": 2, "duplicate": 1, "warning": 0,
    }
    assert len(page) == 1
    assert folders == ["2026", "2026/09", "2026/09/주일예배", "arbitrary"]
    assert selectable == ["arbitrary/20260102-b.mov", "2026/09/주일예배/20260103-c.m4v"]
    initial_calls = client.list_calls

    _, filtered, filtered_summary, _, filtered_refs = service.preview(
        scenario.church.id,
        snapshot_token=token,
        offset=0,
        limit=100,
        status_filter="new",
        folder="2026/09",
    )
    assert client.list_calls == initial_calls
    assert len(filtered) == 1
    assert filtered_summary["filtered_total"] == 1
    assert filtered_refs == ["2026/09/주일예배/20260103-c.m4v"]

    _, next_page, _, _, _ = service.preview(
        scenario.church.id, snapshot_token=token, offset=1, limit=1
    )
    assert len(next_page) == 1
    assert client.list_calls == initial_calls
    with pytest.raises(RequestValidationError):
        service.preview(scenario.church.id, snapshot_token="missing-snapshot-token", offset=0, limit=1)

    result = service.import_candidates(
        scenario.church.id, token, ["arbitrary/20260102-b.mov", "outside/path.mp4"]
    )
    assert result["imported_count"] == 1
    assert result["failed_count"] == 1
    assert result["items"][1]["error_code"] == "candidate_not_in_snapshot"
    retry = service.import_candidates(scenario.church.id, token, ["arbitrary/20260102-b.mov"])
    assert retry["already_imported_count"] == 1


def test_synology_bulk_import_is_bounded_idempotent_and_unpublished(
    mysql_session: Session, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    token = uuid4().hex
    refs = [
        f"batch/2026{((index - 1) // 28) + 1:02d}{((index - 1) % 28) + 1:02d}-video.mp4"
        for index in range(1, 101)
    ]
    _snapshots[token] = Snapshot(scenario.church.id, tuple(infer_candidate(ref, file_size=index + 1) for index, ref in enumerate(refs)))
    service = SynologyImportService(mysql_session)
    result = service.import_candidates(scenario.church.id, token, refs)
    assert result["requested_count"] == 100
    assert result["imported_count"] == 100
    assert result["failed_count"] == 0
    videos = [service.videos.get_by_source_for_church(scenario.church.id, VideoSourceType.SYNOLOGY, ref) for ref in refs]
    assert all(video is not None and video.is_published is False and video.category_id is None and video.collection_id is None for video in videos)
    retry = service.import_candidates(scenario.church.id, token, refs)
    assert retry["imported_count"] == 0
    assert retry["already_imported_count"] == 100
    with pytest.raises(RequestValidationError):
        service.import_candidates(scenario.church.id, token, refs + ["batch/20260411-extra.mp4"] * (MAX_BATCH_SIZE - len(refs) + 1))


def test_synology_preview_review_filters_and_soft_duplicates(
    mysql_session: Session, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    token = uuid4().hex
    duplicate_one = infer_candidate("folder/20260104-message.mp4", file_size=12)
    duplicate_two = infer_candidate("folder/other/20260104-message.mp4", file_size=12)
    missing_date = infer_candidate("unknown/video.mp4", file_size=5)
    _snapshots[token] = Snapshot(scenario.church.id, (duplicate_one, duplicate_two, missing_date))
    service = SynologyImportService(mysql_session)
    _, review_page, review_summary, _, _ = service.preview(scenario.church.id, snapshot_token=token, offset=0, limit=100, status_filter="needs_review")
    assert len(review_page) == 3
    assert review_summary["needs_review"] == 3
    assert all(item["needs_review"] for item in review_page)
    assert "possible_duplicate" in review_page[0]["review_reasons"]
    missing_result = service.import_candidates(scenario.church.id, token, [missing_date.source_ref])
    assert missing_result["needs_review_count"] == 1
    assert missing_result["imported_count"] == 0


def test_synology_bulk_import_is_partial_failure_safe_and_snapshot_errors_are_explicit(
    mysql_session: Session, video_scenario: VideoScenario, monkeypatch: pytest.MonkeyPatch
) -> None:
    scenario = video_scenario
    token = uuid4().hex
    first = infer_candidate("partial/20260104-first.mp4", file_size=10)
    second = infer_candidate("partial/20260105-second.mp4", file_size=11)
    _snapshots[token] = Snapshot(scenario.church.id, (first, second))
    service = SynologyImportService(mysql_session)
    original_add = service.videos.add_video
    calls = 0

    def fail_once(video: Video) -> Video:
        nonlocal calls
        calls += 1
        if calls == 1:
            raise RuntimeError("expected item failure")
        return original_add(video)

    monkeypatch.setattr(service.videos, "add_video", fail_once)
    result = service.import_candidates(scenario.church.id, token, [first.source_ref, second.source_ref])
    assert result["failed_count"] == 1
    assert result["imported_count"] == 1
    assert result["items"][0]["error_code"] == "import_failed"
    assert result["items"][1]["status"] == "imported"
    with pytest.raises(RequestValidationError, match="snapshot_not_found"):
        service.import_candidates(scenario.church.id, "missing-snapshot-token", [first.source_ref])


def test_synology_import_endpoint_requires_manage_permission(
    client: TestClient, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    token = uuid4().hex
    candidate = infer_candidate("permission/20260106-video.mp4", file_size=10)
    _snapshots[token] = Snapshot(scenario.church.id, (candidate,))
    response = client.post(
        f"{videos_url(scenario)}/synology/import",
        headers=scenario.headers(scenario.vod_user),
        json={"snapshot_token": token, "source_refs": [candidate.source_ref]},
    )
    assert response.status_code == 403


def test_unpublished_video_security_review_and_bulk_publish(
    client: TestClient, mysql_session: Session, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    unpublished = create_video(
        client, scenario, title="Review video", source_type="synology", source_ref="review/private.mp4",
        recorded_at="2026-01-06T10:00:00Z", is_published=False,
    )
    videos = videos_url(scenario)
    assert all(item["id"] != unpublished["id"] for item in client.get(videos, headers=scenario.headers(scenario.vod_user)).json())
    assert client.get(f"{videos}?published=false", headers=scenario.headers(scenario.vod_user)).status_code == 403
    assert client.get(f"{videos}/{unpublished['id']}", headers=scenario.headers(scenario.vod_user)).status_code == 404
    assert client.post(f"{videos}/{unpublished['id']}/playback-session", headers=scenario.headers(scenario.vod_user)).status_code == 404
    manager_review = client.get(f"{videos}/review?status=unpublished&offset=0&limit=100", headers=scenario.headers(scenario.manager))
    assert manager_review.status_code == 200
    assert manager_review.json()["unpublished_count"] >= 1
    assert any(item["id"] == unpublished["id"] for item in manager_review.json()["items"])
    assert client.get(f"{videos}/{unpublished['id']}", headers=scenario.headers(scenario.manager)).status_code == 200
    assert client.post(f"{videos}/{unpublished['id']}/playback-session", headers=scenario.headers(scenario.manager)).status_code == 200
    assert client.patch(f"{videos}/{unpublished['id']}", headers=scenario.headers(scenario.vod_user), json={"title": "blocked"}).status_code == 403
    assert client.patch(f"{videos}/{unpublished['id']}", headers=scenario.headers(scenario.manager), json={"title": "Reviewed", "category_id": None, "collection_id": None}).status_code == 200
    assert client.post(f"{videos}/bulk-publish", headers=scenario.headers(scenario.vod_user), json={"video_ids": [unpublished["id"]]}).status_code == 403
    published = client.post(f"{videos}/bulk-publish", headers=scenario.headers(scenario.manager), json={"video_ids": [unpublished["id"]]})
    assert published.status_code == 200
    assert published.json()["published_count"] == 1
    retried = client.post(f"{videos}/bulk-publish", headers=scenario.headers(scenario.manager), json={"video_ids": [unpublished["id"]]})
    assert retried.json()["published_count"] == 0
    assert retried.json()["already_published_count"] == 1
    foreign = Video(church_id=scenario.other_church.id, source_type="synology", source_ref="foreign/private.mp4", title="foreign", recorded_at=datetime.now(UTC), is_published=False)
    mysql_session.add(foreign); mysql_session.commit()
    cross = client.post(f"{videos}/bulk-publish", headers=scenario.headers(scenario.manager), json={"video_ids": [foreign.id]})
    assert cross.status_code == 200
    assert cross.json()["failed_count"] == 1
    assert client.post(f"{videos}/bulk-publish", headers=scenario.headers(scenario.manager), json={"video_ids": list(range(1, 202))}).status_code == 422


def test_viewer_playback_token_is_revoked_when_video_becomes_unpublished(
    client: TestClient, video_scenario: VideoScenario
) -> None:
    scenario = video_scenario
    video = create_video(
        client, scenario, title="Token video", source_type="synology", source_ref="review/token.mp4",
        recorded_at="2026-01-07T10:00:00Z",
    )
    issued = client.post(f"{videos_url(scenario)}/{video['id']}/playback-session", headers=scenario.headers(scenario.vod_user)).json()
    assert client.patch(f"{videos_url(scenario)}/{video['id']}", headers=scenario.headers(scenario.manager), json={"is_published": False}).status_code == 200
    response = client.get(issued["playback_url"], headers={"X-Playback-Token": issued["playback_token"]})
    assert response.status_code == 404


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

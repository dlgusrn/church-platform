from collections.abc import Iterator
from dataclasses import dataclass
from datetime import UTC, date, datetime, timedelta
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import create_access_token
from app.main import app
from app.models.church import Church
from app.models.enums import MembershipStatus
from app.models.membership import ChurchMembership
from app.models.permission import Permission
from app.models.role import Role
from app.models.user import User
from app.scripts.seed_permissions import seed_permissions_and_roles

pytestmark = pytest.mark.integration


@dataclass
class LiveScenario:
    church: Church
    other_church: Church
    admin: User
    member: User

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
def live_scenario(mysql_session: Session) -> LiveScenario:
    seed_permissions_and_roles(mysql_session)
    suffix = uuid4().hex
    church = Church(name="교회 A", code=f"live-a-{suffix}")
    other_church = Church(name="교회 B", code=f"live-b-{suffix}")
    admin = User(
        name="관리자", email=f"live-admin-{suffix}@example.com", password_hash="hash"
    )
    member = User(
        name="성도", email=f"live-member-{suffix}@example.com", password_hash="hash"
    )
    mysql_session.add_all([church, other_church, admin, member])
    mysql_session.flush()
    roles = {
        role.code: role
        for role in mysql_session.scalars(
            select(Role).where(Role.church_id.is_(None))
        ).all()
    }
    now = datetime.now(UTC)
    mysql_session.add_all(
        [
            ChurchMembership(
                user_id=admin.id,
                church_id=church.id,
                status=MembershipStatus.APPROVED,
                role_id=roles["admin"].id,
                requested_at=now,
                approved_at=now,
            ),
            ChurchMembership(
                user_id=member.id,
                church_id=church.id,
                status=MembershipStatus.APPROVED,
                role_id=roles["member"].id,
                requested_at=now,
                approved_at=now,
            ),
        ]
    )
    mysql_session.commit()
    return LiveScenario(church, other_church, admin, member)


def create_schedule(client: TestClient, scenario: LiveScenario) -> dict:
    response = client.post(
        f"/api/v1/churches/{scenario.church.id}/worship-schedules",
        headers=scenario.headers(scenario.admin),
        json={
            "title": "낮예배",
            "day_label": "수요일",
            "time": "11:00:00",
            "display_order": 1,
            "is_active": True,
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_schedule_crud_inactive_permissions_and_church_scope(
    client: TestClient, live_scenario: LiveScenario
) -> None:
    schedule = create_schedule(client, live_scenario)
    url = f"/api/v1/churches/{live_scenario.church.id}/worship-schedules"
    listed = client.get(url, headers=live_scenario.headers(live_scenario.admin))
    assert [item["id"] for item in listed.json()] == [schedule["id"]]

    updated = client.patch(
        f"{url}/{schedule['id']}",
        headers=live_scenario.headers(live_scenario.admin),
        json={"title": "수요예배", "is_active": False, "display_order": 3},
    )
    assert updated.status_code == 200
    assert updated.json()["title"] == "수요예배"
    assert client.get(url, headers=live_scenario.headers(live_scenario.admin)).json() == []
    inactive = client.get(
        f"{url}?include_inactive=true",
        headers=live_scenario.headers(live_scenario.admin),
    )
    assert [item["id"] for item in inactive.json()] == [schedule["id"]]

    assert client.get(
        url, headers=live_scenario.headers(live_scenario.member)
    ).status_code == 403
    assert client.post(
        url,
        headers=live_scenario.headers(live_scenario.member),
        json={
            "title": "금요예배",
            "day_label": "금요일",
            "time": "20:00:00",
        },
    ).status_code == 403
    assert client.get(
        f"/api/v1/churches/{live_scenario.other_church.id}/worship-schedules",
        headers=live_scenario.headers(live_scenario.admin),
    ).status_code == 403


def test_live_create_update_titles_and_validation(
    client: TestClient, live_scenario: LiveScenario
) -> None:
    url = f"/api/v1/churches/{live_scenario.church.id}/live-broadcasts"
    created = client.post(
        url,
        headers=live_scenario.headers(live_scenario.admin),
        json={
            "worship_type": "day",
            "broadcast_date": "2026-09-02",
            "youtube_url": "https://www.youtube.com/watch?v=example",
            "status": "scheduled",
        },
    )
    assert created.status_code == 201, created.text
    assert created.json()["display_title"] == "2026년 09월 02일(수) 낮예배 생방송"

    updated = client.patch(
        f"{url}/{created.json()['id']}",
        headers=live_scenario.headers(live_scenario.admin),
        json={"title_override": "특별 제목", "status": "live"},
    )
    assert updated.status_code == 200, updated.text
    assert updated.json()["display_title"] == "특별 제목"
    assert updated.json()["started_at"] is not None

    custom_without_name = client.post(
        url,
        headers=live_scenario.headers(live_scenario.admin),
        json={
            "worship_type": "custom",
            "broadcast_date": "2026-09-02",
            "youtube_url": "https://youtu.be/example",
        },
    )
    assert custom_without_name.status_code == 422
    invalid_url = client.post(
        url,
        headers=live_scenario.headers(live_scenario.admin),
        json={
            "broadcast_date": "2026-09-02",
            "worship_type": "special",
            "title_override": "특별 방송",
            "youtube_url": "not-a-url",
        },
    )
    assert invalid_url.status_code == 422


def test_current_live_returns_only_live_status_and_isolated_by_church(
    client: TestClient, live_scenario: LiveScenario
) -> None:
    url = f"/api/v1/churches/{live_scenario.church.id}/live-broadcasts"
    headers = live_scenario.headers(live_scenario.admin)
    tomorrow = (date.today() + timedelta(days=1)).isoformat()
    first = client.post(
        url,
        headers=headers,
        json={
            "worship_type": "day",
            "broadcast_date": tomorrow,
            "youtube_url": "https://youtu.be/first",
        },
    ).json()
    past = client.post(
        url,
        headers=headers,
        json={
            "worship_type": "special",
            "title_override": "지난 예정 방송",
            "broadcast_date": (date.today() - timedelta(days=1)).isoformat(),
            "youtube_url": "https://youtu.be/past-scheduled",
        },
    )
    assert past.status_code == 201, past.text
    second = client.post(
        url,
        headers=headers,
        json={
            "worship_type": "day",
            "broadcast_date": tomorrow,
            "youtube_url": "https://youtu.be/second",
        },
    ).json()
    current_url = f"{url}/current"
    # Scheduled broadcasts, even future ones, are not a current LIVE fallback.
    assert client.get(current_url, headers=headers).json() is None

    live = client.post(
        url,
        headers=headers,
        json={
            "worship_type": "special",
            "title_override": "현재 생방송",
            "broadcast_date": date.today().isoformat(),
            "youtube_url": "https://youtu.be/live",
            "status": "live",
        },
    ).json()
    assert client.get(current_url, headers=headers).json()["id"] == live["id"]
    client.patch(f"{url}/{live['id']}", headers=headers, json={"status": "ended"})
    assert client.get(current_url, headers=headers).json() is None
    assert second["id"] != first["id"]

    assert client.get(
        f"/api/v1/churches/{live_scenario.other_church.id}/live-broadcasts/current",
        headers=headers,
    ).status_code == 403
    assert client.get(
        f"/api/v1/churches/{live_scenario.other_church.id}/live-broadcasts",
        headers=headers,
    ).status_code == 403


def test_live_manage_permission_seed_and_authorization(
    client: TestClient, mysql_session: Session, live_scenario: LiveScenario
) -> None:
    permission = mysql_session.scalar(
        select(Permission).where(Permission.code == "live.manage")
    )
    assert permission is not None
    url = f"/api/v1/churches/{live_scenario.church.id}/live-broadcasts"
    assert client.get(
        url, headers=live_scenario.headers(live_scenario.member)
    ).status_code == 403
    assert client.get(
        f"{url}/current", headers=live_scenario.headers(live_scenario.member)
    ).status_code == 200

from datetime import date

import pytest
from pydantic import ValidationError

from app.models.live_broadcast import LiveBroadcast
from app.models.enums import LiveWorshipType
from app.schemas.live_broadcast import LiveBroadcastCreateRequest
from app.services.live_broadcast_service import live_display_title


def test_display_title_uses_date_weekday_and_live_worship_type() -> None:
    broadcast = LiveBroadcast(
        church_id=1,
        broadcast_date=date(2026, 9, 2),
        worship_type=LiveWorshipType.DAY,
        youtube_url="https://youtu.be/example",
    )

    assert live_display_title(broadcast) == "2026년 09월 02일(수) 낮예배 생방송"


def test_title_override_has_precedence() -> None:
    broadcast = LiveBroadcast(
        church_id=1,
        broadcast_date=date(2026, 9, 2),
        worship_type=LiveWorshipType.SPECIAL,
        title_override="특별 부흥회 생방송",
        youtube_url="https://youtu.be/example",
    )

    assert live_display_title(broadcast) == "특별 부흥회 생방송"


def test_custom_live_requires_name_and_youtube_url_is_validated() -> None:
    with pytest.raises(ValidationError, match="custom_worship_name is required"):
        LiveBroadcastCreateRequest(
            worship_type=LiveWorshipType.CUSTOM,
            broadcast_date=date(2026, 9, 2),
            youtube_url="https://youtu.be/example",
        )

    with pytest.raises(ValidationError, match="valid YouTube URL"):
        LiveBroadcastCreateRequest(
            worship_type=LiveWorshipType.SPECIAL,
            broadcast_date=date(2026, 9, 2),
            title_override="특별 방송",
            youtube_url="not-a-url",
        )

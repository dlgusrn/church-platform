from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.exceptions import NotFoundError, RequestValidationError
from app.models.enums import LiveBroadcastStatus, LiveWorshipType
from app.models.live_broadcast import LiveBroadcast
from app.repositories.church_repository import ChurchRepository
from app.repositories.live_broadcast_repository import LiveBroadcastRepository
from app.schemas.live_broadcast import (
    LiveBroadcastCreateRequest,
    LiveBroadcastResponse,
    LiveBroadcastUpdateRequest,
    validate_youtube_url,
)

KOREAN_WEEKDAYS = ("월", "화", "수", "목", "금", "토", "일")
WORSHIP_TYPE_LABELS = {
    LiveWorshipType.DAY: "낮예배",
    LiveWorshipType.NIGHT: "밤예배",
    LiveWorshipType.PRAYER_11: "11시기도",
    LiveWorshipType.SPECIAL: "특별성회",
}


def worship_type_label(broadcast: LiveBroadcast) -> str:
    if broadcast.worship_type is LiveWorshipType.CUSTOM:
        if not broadcast.custom_worship_name:
            raise RequestValidationError("custom_worship_name is required for custom worship_type")
        return broadcast.custom_worship_name
    return WORSHIP_TYPE_LABELS[broadcast.worship_type]


def live_display_title(broadcast: LiveBroadcast) -> str:
    if broadcast.title_override:
        return broadcast.title_override
    day = broadcast.broadcast_date
    return (
        f"{day.year:04d}년 {day.month:02d}월 {day.day:02d}일"
        f"({KOREAN_WEEKDAYS[day.weekday()]}) {worship_type_label(broadcast)} 생방송"
    )


class LiveBroadcastService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.broadcasts = LiveBroadcastRepository(session)

    def list_broadcasts(self, church_id: int) -> list[LiveBroadcastResponse]:
        self._require_church(church_id)
        return [self._response(item) for item in self.broadcasts.list_for_church(church_id)]

    def current(self, church_id: int) -> LiveBroadcastResponse | None:
        self._require_church(church_id)
        broadcast = self.broadcasts.current(church_id)
        return None if broadcast is None else self._response(broadcast)

    def create(
        self, church_id: int, request: LiveBroadcastCreateRequest
    ) -> LiveBroadcastResponse:
        self._require_church(church_id)
        now = datetime.now(UTC)
        values = request.model_dump()
        values["youtube_url"] = validate_youtube_url(request.youtube_url)
        broadcast = LiveBroadcast(church_id=church_id, **values)
        self._apply_status_timestamps(broadcast, now)
        live_display_title(broadcast)
        self.broadcasts.add(broadcast)
        self.session.commit()
        return self._response(broadcast)

    def update(
        self,
        church_id: int,
        broadcast_id: int,
        request: LiveBroadcastUpdateRequest,
    ) -> LiveBroadcastResponse:
        broadcast = self.broadcasts.get_for_church(
            broadcast_id, church_id, for_update=True
        )
        if broadcast is None:
            raise NotFoundError("Live broadcast not found")
        values = request.model_dump(exclude_unset=True)
        if "youtube_url" in values:
            values["youtube_url"] = validate_youtube_url(values["youtube_url"])
        for field, value in values.items():
            setattr(broadcast, field, value)
        self._validate_worship_type_fields(broadcast)
        self._apply_status_timestamps(broadcast, datetime.now(UTC))
        live_display_title(broadcast)
        self.session.commit()
        return self._response(broadcast)

    @staticmethod
    def _validate_worship_type_fields(broadcast: LiveBroadcast) -> None:
        if broadcast.worship_type is LiveWorshipType.CUSTOM:
            if not broadcast.custom_worship_name:
                raise RequestValidationError("custom_worship_name is required for custom worship_type")
        elif broadcast.custom_worship_name is not None:
            raise RequestValidationError(
                "custom_worship_name is only allowed for custom worship_type"
            )

    @staticmethod
    def _apply_status_timestamps(broadcast: LiveBroadcast, now: datetime) -> None:
        if broadcast.status is LiveBroadcastStatus.LIVE:
            broadcast.started_at = broadcast.started_at or now
            broadcast.ended_at = None
        elif broadcast.status is LiveBroadcastStatus.ENDED:
            broadcast.ended_at = broadcast.ended_at or now
        else:
            broadcast.ended_at = None

    @staticmethod
    def _response(broadcast: LiveBroadcast) -> LiveBroadcastResponse:
        return LiveBroadcastResponse(
            id=broadcast.id,
            church_id=broadcast.church_id,
            broadcast_date=broadcast.broadcast_date,
            worship_type=broadcast.worship_type,
            custom_worship_name=broadcast.custom_worship_name,
            title_override=broadcast.title_override,
            display_title=live_display_title(broadcast),
            youtube_url=broadcast.youtube_url,
            status=broadcast.status,
            started_at=broadcast.started_at,
            ended_at=broadcast.ended_at,
            created_at=broadcast.created_at,
            updated_at=broadcast.updated_at,
        )

    def _require_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")

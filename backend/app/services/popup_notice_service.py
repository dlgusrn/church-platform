from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.exceptions import NotFoundError, PopupNoticeOverlapError, RequestValidationError
from app.models.enums import MembershipStatus
from app.models.popup_notice import PopupNotice
from app.repositories.church_repository import ChurchRepository
from app.repositories.membership_repository import MembershipRepository
from app.repositories.popup_notice_repository import PopupNoticeRepository
from app.schemas.popup_notice import (
    PopupNoticeActiveRequest,
    PopupNoticeCreateRequest,
    PopupNoticeImageResponse,
    PopupNoticeResponse,
    PopupNoticeUpdateRequest,
)
from app.services.media_storage import LocalPopupNoticeMediaStorage, PopupNoticeMediaStorage


def utc_database_value(value: datetime) -> datetime:
    """MySQL DATETIME comes back naive; its application contract is UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC).replace(tzinfo=None)
    return value.astimezone(UTC).replace(tzinfo=None)


def utc_response_value(value: datetime) -> datetime:
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


class PopupNoticeService:
    def __init__(self, session: Session, storage: PopupNoticeMediaStorage | None = None) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.memberships = MembershipRepository(session)
        self.notices = PopupNoticeRepository(session)
        self.storage = storage or LocalPopupNoticeMediaStorage(get_settings().popup_media_root)

    def list_notices(self, church_id: int) -> list[PopupNoticeResponse]:
        self._require_church(church_id)
        return [self._response(item) for item in self.notices.list_for_church(church_id)]

    def get_notice(self, church_id: int, popup_notice_id: int) -> PopupNoticeResponse:
        self._require_church(church_id)
        return self._response(self._notice_or_raise(church_id, popup_notice_id))

    def current(self, church_id: int) -> PopupNoticeResponse | None:
        self._require_church(church_id)
        item = self.notices.current(church_id, datetime.now(UTC).replace(tzinfo=None))
        return None if item is None else self._response(item)

    def create(self, church_id: int, user_id: int, request: PopupNoticeCreateRequest) -> PopupNoticeResponse:
        try:
            self._lock_active_church(church_id)
            membership = self.memberships.get_by_user_and_church(user_id, church_id)
            if membership is None or membership.status is not MembershipStatus.APPROVED:
                raise RequestValidationError("Approved church membership required")
            values = self._normalized_values(request.model_dump())
            self._assert_no_overlap(church_id, values["starts_at"], values["ends_at"], values["is_active"])
            notice = self.notices.add(PopupNotice(church_id=church_id, author_membership_id=membership.id, **values))
            self.session.commit()
            return self._response(notice)
        except Exception:
            self.session.rollback()
            raise

    def update(self, church_id: int, popup_notice_id: int, request: PopupNoticeUpdateRequest) -> PopupNoticeResponse:
        try:
            self._lock_active_church(church_id)
            notice = self._notice_or_raise(church_id, popup_notice_id, for_update=True)
            values = self._normalized_values(request.model_dump(exclude_unset=True))
            for field, value in values.items():
                setattr(notice, field, value)
            self._validate_window(notice.starts_at, notice.ends_at)
            self._assert_no_overlap(church_id, notice.starts_at, notice.ends_at, notice.is_active, exclude_id=notice.id)
            self.session.commit()
            return self._response(notice)
        except Exception:
            self.session.rollback()
            raise

    def set_active(self, church_id: int, popup_notice_id: int, request: PopupNoticeActiveRequest) -> PopupNoticeResponse:
        return self.update(church_id, popup_notice_id, PopupNoticeUpdateRequest(is_active=request.is_active))

    def delete(self, church_id: int, popup_notice_id: int) -> None:
        old_key: str | None = None
        try:
            self._lock_active_church(church_id)
            notice = self._notice_or_raise(church_id, popup_notice_id, for_update=True)
            old_key = notice.image_storage_key
            self.session.delete(notice)
            self.session.commit()
        except Exception:
            self.session.rollback()
            raise
        if old_key:
            self._best_effort_delete(old_key)

    def replace_image(self, church_id: int, popup_notice_id: int, data: bytes, filename: str | None) -> PopupNoticeResponse:
        staged = self.storage.stage(data, filename)
        old_key: str | None = None
        try:
            self._lock_active_church(church_id)
            notice = self._notice_or_raise(church_id, popup_notice_id, for_update=True)
            old_key = notice.image_storage_key
            notice.image_storage_key = staged.final_key
            notice.image_content_type = staged.content_type
            notice.image_size = staged.size
            # Promote before commit: a process crash can leave an orphan object,
            # but never a committed DB reference to a missing final object.
            self.storage.promote(staged)
            self.session.commit()
        except Exception:
            self.session.rollback()
            self._best_effort_delete(staged.staging_key)
            self._best_effort_delete(staged.final_key)
            raise
        if old_key:
            self._best_effort_delete(old_key)
        return self.get_notice(church_id, popup_notice_id)

    def remove_image(self, church_id: int, popup_notice_id: int) -> PopupNoticeResponse:
        old_key: str | None = None
        try:
            self._lock_active_church(church_id)
            notice = self._notice_or_raise(church_id, popup_notice_id, for_update=True)
            old_key = notice.image_storage_key
            notice.image_storage_key = None
            notice.image_content_type = None
            notice.image_size = None
            self.session.commit()
            response = self._response(notice)
        except Exception:
            self.session.rollback()
            raise
        if old_key:
            self._best_effort_delete(old_key)
        return response

    def image_bytes(self, church_id: int, popup_notice_id: int) -> tuple[bytes, str]:
        self._require_church(church_id)
        notice = self._notice_or_raise(church_id, popup_notice_id)
        if not notice.image_storage_key or not notice.image_content_type:
            raise NotFoundError("Popup notice image not found")
        return self.storage.read(notice.image_storage_key), notice.image_content_type

    def _lock_active_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id, for_update=True)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")

    def _require_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")

    def _notice_or_raise(self, church_id: int, popup_notice_id: int, *, for_update: bool = False) -> PopupNotice:
        notice = self.notices.get_for_church(popup_notice_id, church_id, for_update=for_update)
        if notice is None:
            raise NotFoundError("Popup notice not found")
        return notice

    @staticmethod
    def _normalized_values(values: dict[str, object]) -> dict[str, object]:
        for key in ("starts_at", "ends_at"):
            if key in values:
                values[key] = utc_database_value(values[key])  # type: ignore[arg-type]
        return values

    @staticmethod
    def _validate_window(starts_at: datetime, ends_at: datetime) -> None:
        if starts_at >= ends_at:
            raise RequestValidationError("starts_at must be before ends_at")

    def _assert_no_overlap(self, church_id: int, starts_at: datetime, ends_at: datetime, is_active: bool, *, exclude_id: int | None = None) -> None:
        self._validate_window(starts_at, ends_at)
        if is_active and self.notices.overlapping_active(church_id, starts_at, ends_at, exclude_id=exclude_id):
            raise PopupNoticeOverlapError("Popup notice display period overlaps an active popup notice")

    def _response(self, notice: PopupNotice) -> PopupNoticeResponse:
        image = None
        if notice.image_storage_key and notice.image_content_type and notice.image_size is not None:
            image = PopupNoticeImageResponse(
                content_type=notice.image_content_type,
                size=notice.image_size,
                url=f"/api/v1/churches/{notice.church_id}/popup-notices/{notice.id}/image",
            )
        return PopupNoticeResponse(
            id=notice.id, church_id=notice.church_id, author_membership_id=notice.author_membership_id,
            title=notice.title, content=notice.content,
            starts_at=utc_response_value(notice.starts_at), ends_at=utc_response_value(notice.ends_at),
            is_active=notice.is_active, image=image,
            created_at=utc_response_value(notice.created_at), updated_at=utc_response_value(notice.updated_at),
        )

    def _best_effort_delete(self, key: str) -> None:
        try:
            self.storage.delete(key)
        except Exception:
            pass

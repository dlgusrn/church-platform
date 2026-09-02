from datetime import UTC, datetime

from sqlalchemy.orm import Session

from app.core.exceptions import ForbiddenError, NotFoundError
from app.models.enums import MembershipStatus
from app.models.notice import Notice
from app.repositories.church_repository import ChurchRepository
from app.repositories.membership_repository import MembershipRepository
from app.repositories.notice_repository import NoticeRepository
from app.schemas.notice import NoticeCreateRequest, NoticeResponse, NoticeUpdateRequest


class NoticeService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.memberships = MembershipRepository(session)
        self.notices = NoticeRepository(session)

    def list_notices(self, church_id: int) -> list[NoticeResponse]:
        self._require_church(church_id)
        return [NoticeResponse.model_validate(item) for item in self.notices.list_for_church(church_id)]

    def get_notice(self, church_id: int, notice_id: int) -> NoticeResponse:
        self._require_church(church_id)
        return NoticeResponse.model_validate(self._notice_or_raise(church_id, notice_id))

    def create(
        self, church_id: int, user_id: int, request: NoticeCreateRequest
    ) -> NoticeResponse:
        self._require_church(church_id)
        membership = self.memberships.get_by_user_and_church(user_id, church_id)
        if membership is None or membership.status is not MembershipStatus.APPROVED:
            raise ForbiddenError("Approved church membership required")
        notice = self.notices.add(
            Notice(
                church_id=church_id,
                author_membership_id=membership.id,
                published_at=datetime.now(UTC),
                **request.model_dump(),
            )
        )
        self.session.commit()
        return NoticeResponse.model_validate(notice)

    def update(
        self, church_id: int, notice_id: int, request: NoticeUpdateRequest
    ) -> NoticeResponse:
        self._require_church(church_id)
        notice = self._notice_or_raise(church_id, notice_id, for_update=True)
        for field, value in request.model_dump(exclude_unset=True).items():
            setattr(notice, field, value)
        self.session.commit()
        return NoticeResponse.model_validate(notice)

    def delete(self, church_id: int, notice_id: int) -> None:
        self._require_church(church_id)
        notice = self._notice_or_raise(church_id, notice_id, for_update=True)
        self.notices.delete(notice)
        self.session.commit()

    def _notice_or_raise(
        self, church_id: int, notice_id: int, *, for_update: bool = False
    ) -> Notice:
        notice = self.notices.get_for_church(notice_id, church_id, for_update=for_update)
        if notice is None:
            raise NotFoundError("Notice not found")
        return notice

    def _require_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")

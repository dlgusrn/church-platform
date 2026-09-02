from sqlalchemy.orm import Session

from app.core.exceptions import NotFoundError
from app.models.worship_schedule import WorshipSchedule
from app.repositories.church_repository import ChurchRepository
from app.repositories.worship_schedule_repository import WorshipScheduleRepository
from app.schemas.worship_schedule import (
    WorshipScheduleCreateRequest,
    WorshipScheduleResponse,
    WorshipScheduleUpdateRequest,
)


class WorshipScheduleService:
    def __init__(self, session: Session) -> None:
        self.session = session
        self.churches = ChurchRepository(session)
        self.schedules = WorshipScheduleRepository(session)

    def list_schedules(
        self, church_id: int, *, include_inactive: bool = False
    ) -> list[WorshipScheduleResponse]:
        self._require_church(church_id)
        return [
            WorshipScheduleResponse.model_validate(item)
            for item in self.schedules.list_for_church(
                church_id, include_inactive=include_inactive
            )
        ]

    def create(
        self, church_id: int, request: WorshipScheduleCreateRequest
    ) -> WorshipScheduleResponse:
        self._require_church(church_id)
        schedule = self.schedules.add(
            WorshipSchedule(church_id=church_id, **request.model_dump())
        )
        self.session.commit()
        return WorshipScheduleResponse.model_validate(schedule)

    def update(
        self,
        church_id: int,
        schedule_id: int,
        request: WorshipScheduleUpdateRequest,
    ) -> WorshipScheduleResponse:
        schedule = self.schedules.get_for_church(
            schedule_id, church_id, for_update=True
        )
        if schedule is None:
            raise NotFoundError("Worship schedule not found")
        for field, value in request.model_dump(exclude_unset=True).items():
            setattr(schedule, field, value)
        self.session.commit()
        return WorshipScheduleResponse.model_validate(schedule)

    def _require_church(self, church_id: int) -> None:
        church = self.churches.get_by_id(church_id)
        if church is None or not church.is_active:
            raise NotFoundError("Church not found")

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.worship_schedule import WorshipSchedule


class WorshipScheduleRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(
        self, church_id: int, *, include_inactive: bool = False
    ) -> list[WorshipSchedule]:
        statement = select(WorshipSchedule).where(
            WorshipSchedule.church_id == church_id
        )
        if not include_inactive:
            statement = statement.where(WorshipSchedule.is_active.is_(True))
        return list(
            self.session.scalars(
                statement.order_by(
                    WorshipSchedule.display_order,
                    WorshipSchedule.time,
                    WorshipSchedule.id,
                )
            ).all()
        )

    def get_for_church(
        self, schedule_id: int, church_id: int, *, for_update: bool = False
    ) -> WorshipSchedule | None:
        statement = select(WorshipSchedule).where(
            WorshipSchedule.id == schedule_id,
            WorshipSchedule.church_id == church_id,
        )
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def add(self, schedule: WorshipSchedule) -> WorshipSchedule:
        self.session.add(schedule)
        self.session.flush()
        return schedule

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import LiveBroadcastStatus
from app.models.live_broadcast import LiveBroadcast


class LiveBroadcastRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_for_church(self, church_id: int) -> list[LiveBroadcast]:
        return list(
            self.session.scalars(
                select(LiveBroadcast)
                .where(LiveBroadcast.church_id == church_id)
                .order_by(
                    LiveBroadcast.broadcast_date.desc(), LiveBroadcast.id.desc()
                )
            ).all()
        )

    def get_for_church(
        self, broadcast_id: int, church_id: int, *, for_update: bool = False
    ) -> LiveBroadcast | None:
        statement = (
            select(LiveBroadcast)
            .where(
                LiveBroadcast.id == broadcast_id,
                LiveBroadcast.church_id == church_id,
            )
        )
        if for_update:
            statement = statement.with_for_update()
        return self.session.scalar(statement)

    def current(self, church_id: int) -> LiveBroadcast | None:
        return self.session.scalar(
            select(LiveBroadcast)
            .where(
                LiveBroadcast.church_id == church_id,
                LiveBroadcast.status == LiveBroadcastStatus.LIVE,
            )
            .order_by(
                LiveBroadcast.broadcast_date.desc(),
                LiveBroadcast.id.desc(),
            )
            .limit(1)
        )

    def add(self, broadcast: LiveBroadcast) -> LiveBroadcast:
        self.session.add(broadcast)
        self.session.flush()
        return broadcast

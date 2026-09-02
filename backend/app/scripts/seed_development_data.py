from datetime import time

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.church import Church
from app.models.worship_schedule import WorshipSchedule

DEVELOPMENT_CHURCHES = (
    ("skygate", "하늘문교회", "skydoor"),
    ("beer", "브엘성회", "beersheba"),
)
DEVELOPMENT_SCHEDULE_NAME = "개발 테스트 예배"


def reconcile_development_church(
    *,
    canonical: Church | None,
    legacy: Church | None,
    code: str,
    name: str,
) -> tuple[Church, bool]:
    if canonical is not None and legacy is not None:
        raise RuntimeError(
            f"Both canonical church code '{code}' and legacy code "
            f"'{legacy.code}' exist; reconcile them manually before seeding"
        )

    church = canonical or legacy
    created = church is None
    if church is None:
        church = Church(code=code, name=name, is_active=True)
    else:
        # Updating the existing row preserves its id and all membership FKs.
        church.code = code
        church.name = name
        church.is_active = True
    return church, created


def seed_development_churches(session: Session) -> None:
    for code, name, legacy_code in DEVELOPMENT_CHURCHES:
        canonical = session.scalar(select(Church).where(Church.code == code))
        legacy = session.scalar(select(Church).where(Church.code == legacy_code))
        church, created = reconcile_development_church(
            canonical=canonical,
            legacy=legacy,
            code=code,
            name=name,
        )
        if created:
            session.add(church)
    session.commit()


def seed_development_worship_schedules(session: Session) -> None:
    church = session.scalar(select(Church).where(Church.code == "skygate"))
    if church is None:
        raise RuntimeError("Run development church seed before schedule seed")
    schedule = session.scalar(
        select(WorshipSchedule).where(
            WorshipSchedule.church_id == church.id,
            WorshipSchedule.title == DEVELOPMENT_SCHEDULE_NAME,
        )
    )
    if schedule is None:
        schedule = WorshipSchedule(
            church_id=church.id,
            title=DEVELOPMENT_SCHEDULE_NAME,
            day_label="개발용",
            time=time(19, 0),
            display_order=0,
            is_active=True,
        )
        session.add(schedule)
    session.commit()


def main() -> None:
    if get_settings().app_env.lower() == "production":
        raise SystemExit("Development data seed is disabled in production")
    with get_session_factory()() as session:
        try:
            seed_development_churches(session)
            seed_development_worship_schedules(session)
        except Exception:
            session.rollback()
            raise


if __name__ == "__main__":
    main()

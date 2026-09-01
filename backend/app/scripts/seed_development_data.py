from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.models.church import Church

DEVELOPMENT_CHURCHES = (
    ("skygate", "하늘문교회", "skydoor"),
    ("beer", "브엘성회", "beersheba"),
)


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


def main() -> None:
    if get_settings().app_env.lower() == "production":
        raise SystemExit("Development data seed is disabled in production")
    with get_session_factory()() as session:
        try:
            seed_development_churches(session)
        except Exception:
            session.rollback()
            raise


if __name__ == "__main__":
    main()

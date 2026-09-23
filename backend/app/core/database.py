from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import get_settings


@lru_cache
def get_engine() -> Engine:
    engine = create_engine(
        get_settings().database_url,
        pool_pre_ping=True,
        pool_recycle=3600,
    )
    # MySQL DATETIME values are treated as UTC throughout the application.
    # Keep the connection session aligned with that contract in every environment.
    if engine.dialect.name == "mysql":
        @event.listens_for(engine, "connect")
        def set_mysql_utc_timezone(dbapi_connection: object, _connection_record: object) -> None:
            cursor = dbapi_connection.cursor()  # type: ignore[attr-defined]
            try:
                cursor.execute("SET time_zone = '+00:00'")
            finally:
                cursor.close()
    return engine


@lru_cache
def get_session_factory() -> sessionmaker[Session]:
    return sessionmaker(bind=get_engine(), autoflush=False, expire_on_commit=False)


def get_db() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
    finally:
        session.close()


def get_playback_session() -> Session:
    """Create a session owned explicitly by the playback authorization phase.

    Playback closes this session before returning its StreamingResponse; it is
    intentionally not a yield dependency because request-scoped cleanup occurs
    only after a streaming body has finished.
    """
    return get_session_factory()()

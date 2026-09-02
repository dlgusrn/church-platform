import argparse
import os
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, make_url

from app.core.config import get_settings

BACKEND_ROOT = Path(__file__).resolve().parents[2]
DEVELOPMENT_DATABASE_NAME = "church_app"


def _validated_target(confirmation: str) -> tuple[str, URL]:
    settings = get_settings()
    if os.getenv("APP_ENV", "").lower() != "development":
        raise SystemExit("Refusing to reset unless APP_ENV is explicitly development")

    database_url = settings.database_url
    target = make_url(database_url)
    if target.get_backend_name() != "mysql":
        raise SystemExit("DATABASE_URL must use MySQL")
    if target.database != DEVELOPMENT_DATABASE_NAME:
        raise SystemExit(
            f"Refusing to reset any database except '{DEVELOPMENT_DATABASE_NAME}'"
        )
    if confirmation != DEVELOPMENT_DATABASE_NAME:
        raise SystemExit(
            f"Confirmation must exactly match: {DEVELOPMENT_DATABASE_NAME}"
        )
    return database_url, target


def _server_url(target: URL) -> URL:
    return target.set(database="")


def _recreate_database(target: URL) -> None:
    database_name = target.database
    assert database_name == DEVELOPMENT_DATABASE_NAME
    engine = create_engine(
        _server_url(target), isolation_level="AUTOCOMMIT", pool_pre_ping=True
    )
    try:
        with engine.connect() as connection:
            connection.execute(text(f"DROP DATABASE IF EXISTS `{database_name}`"))
            connection.execute(
                text(
                    f"CREATE DATABASE `{database_name}` "
                    "CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci"
                )
            )
    finally:
        engine.dispose()


def _upgrade_to_head(database_url: str) -> None:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_ROOT / "alembic"))
    config.set_main_option("sqlalchemy.url", database_url.replace("%", "%%"))
    command.upgrade(config, "head")


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Drop, recreate, and migrate only the church_app development database."
        )
    )
    parser.add_argument(
        "--confirm-database",
        required=True,
        help="Must be exactly 'church_app'",
    )
    arguments = parser.parse_args()
    database_url, target = _validated_target(arguments.confirm_database)
    _recreate_database(target)
    _upgrade_to_head(database_url)
    print(f"Recreated and migrated development database: {target.database}")


if __name__ == "__main__":
    main()

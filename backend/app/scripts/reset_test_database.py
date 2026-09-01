import argparse
import os
import re
from pathlib import Path

from alembic import command
from alembic.config import Config
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL, make_url

from app.core.config import get_settings

BACKEND_ROOT = Path(__file__).resolve().parents[2]
SAFE_DATABASE_NAME = re.compile(r"^[A-Za-z0-9_]+$")


def _validated_target(confirmation: str) -> tuple[str, URL]:
    database_url = os.getenv("TEST_DATABASE_URL")
    if database_url is None:
        raise SystemExit("TEST_DATABASE_URL is required")

    target = make_url(database_url)
    database_name = target.database
    if target.get_backend_name() != "mysql":
        raise SystemExit("TEST_DATABASE_URL must use MySQL")
    if not database_name or "test" not in database_name.lower():
        raise SystemExit("Refusing to reset a database whose name does not contain 'test'")
    if not SAFE_DATABASE_NAME.fullmatch(database_name):
        raise SystemExit("Test database name may contain only letters, digits, and underscores")
    if confirmation != database_name:
        raise SystemExit(f"Confirmation must exactly match the test database name: {database_name}")

    development_url = os.getenv("DATABASE_URL")
    if development_url is not None:
        development = make_url(development_url)
        same_server = (development.host, development.port) == (target.host, target.port)
        if same_server and development.database == database_name:
            raise SystemExit("Refusing to reset DATABASE_URL; TEST_DATABASE_URL must be separate")
    return database_url, target


def _recreate_database(target: URL) -> None:
    database_name = target.database
    assert database_name is not None
    server_url = _server_url(target)
    engine = create_engine(server_url, isolation_level="AUTOCOMMIT", pool_pre_ping=True)
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


def _server_url(target: URL) -> URL:
    return target.set(database="")


def _upgrade_to_head(database_url: str) -> None:
    previous_database_url = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = database_url
    get_settings.cache_clear()
    try:
        config = Config(str(BACKEND_ROOT / "alembic.ini"))
        config.set_main_option("script_location", str(BACKEND_ROOT / "alembic"))
        command.upgrade(config, "head")
    finally:
        if previous_database_url is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = previous_database_url
        get_settings.cache_clear()


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Drop, recreate, and migrate only the configured MySQL test database."
    )
    parser.add_argument(
        "--confirm-database",
        required=True,
        help="Must exactly match the database name in TEST_DATABASE_URL",
    )
    arguments = parser.parse_args()
    database_url, target = _validated_target(arguments.confirm_database)
    _recreate_database(target)
    _upgrade_to_head(database_url)
    print(f"Recreated and migrated test database: {target.database}")


if __name__ == "__main__":
    main()

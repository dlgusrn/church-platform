import os
from collections.abc import Iterator
from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config
from alembic.migration import MigrationContext
from alembic.script import ScriptDirectory
from sqlalchemy import create_engine, inspect
from sqlalchemy.engine import make_url
from sqlalchemy.orm import Session

from app.core.config import get_settings

BACKEND_ROOT = Path(__file__).resolve().parents[2]
EXPECTED_TABLES = {
    "users",
    "churches",
    "church_memberships",
    "roles",
    "permissions",
    "role_permissions",
    "membership_permission_overrides",
    "refresh_tokens",
}


def _validated_test_database_url() -> str:
    database_url = os.getenv("TEST_DATABASE_URL")
    if database_url is None:
        pytest.skip("TEST_DATABASE_URL is not configured")

    url = make_url(database_url)
    if url.get_backend_name() != "mysql" or not url.database or "test" not in url.database.lower():
        pytest.fail("Integration tests require a MySQL database whose name contains 'test'")

    development_url = os.getenv("DATABASE_URL")
    if development_url is not None:
        development = make_url(development_url)
        same_server = (development.host, development.port) == (url.host, url.port)
        if same_server and development.database == url.database:
            pytest.fail("TEST_DATABASE_URL must not target the development database")
    return database_url


def _alembic_config() -> Config:
    config = Config(str(BACKEND_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_ROOT / "alembic"))
    return config


@pytest.fixture(scope="session")
def migrated_test_database() -> Iterator[str]:
    database_url = _validated_test_database_url()
    previous_database_url = os.environ.get("DATABASE_URL")
    os.environ["DATABASE_URL"] = database_url
    get_settings.cache_clear()
    config = _alembic_config()
    try:
        command.upgrade(config, "head")
    finally:
        if previous_database_url is None:
            os.environ.pop("DATABASE_URL", None)
        else:
            os.environ["DATABASE_URL"] = previous_database_url
        get_settings.cache_clear()

    engine = create_engine(database_url, pool_pre_ping=True)
    try:
        with engine.connect() as connection:
            actual_revision = MigrationContext.configure(connection).get_current_revision()
            expected_revision = ScriptDirectory.from_config(config).get_current_head()
            actual_tables = set(inspect(connection).get_table_names())
    finally:
        engine.dispose()

    missing_tables = EXPECTED_TABLES - actual_tables
    if actual_revision != expected_revision or missing_tables:
        pytest.fail(
            "church_app_test schema is not a complete Alembic head. "
            f"revision={actual_revision!r}, head={expected_revision!r}, "
            f"missing_tables={sorted(missing_tables)}. "
            "Run: python -m app.scripts.reset_test_database "
            "--confirm-database church_app_test"
        )
    yield database_url


@pytest.fixture
def mysql_session(migrated_test_database: str) -> Iterator[Session]:
    engine = create_engine(migrated_test_database, pool_pre_ping=True)
    connection = engine.connect()
    transaction = connection.begin()
    session = Session(bind=connection, join_transaction_mode="create_savepoint")
    try:
        yield session
    finally:
        session.close()
        if transaction.is_active:
            transaction.rollback()
        connection.close()
        engine.dispose()

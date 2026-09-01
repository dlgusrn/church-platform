import re
from pathlib import Path

from app.models import Base

MYSQL_IDENTIFIER_MAX_LENGTH = 64
MIGRATION_PATH = (
    Path(__file__).resolve().parents[2]
    / "alembic"
    / "versions"
    / "20260901_0001_create_initial_schema.py"
)
SCHEMA_IDENTIFIER = re.compile(r'"((?:pk|fk|uq|ix|ck)_[a-z0-9_]+)"')


def _metadata_schema_names() -> set[str]:
    names: set[str] = set()
    for table in Base.metadata.tables.values():
        names.update(
            constraint.name
            for constraint in table.constraints
            if constraint.name is not None
        )
        names.update(index.name for index in table.indexes if index.name is not None)
    return names


def test_all_metadata_identifiers_fit_mysql_limit() -> None:
    names = _metadata_schema_names()
    too_long = {name: len(name) for name in names if len(name) > MYSQL_IDENTIFIER_MAX_LENGTH}

    assert too_long == {}


def test_initial_migration_names_match_metadata_and_fit_mysql_limit() -> None:
    migration_names = set(SCHEMA_IDENTIFIER.findall(MIGRATION_PATH.read_text()))
    metadata_names = _metadata_schema_names()

    assert migration_names == metadata_names
    assert all(len(name) <= MYSQL_IDENTIFIER_MAX_LENGTH for name in migration_names)

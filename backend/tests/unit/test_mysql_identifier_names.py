import re
from pathlib import Path

from app.models import Base

MYSQL_IDENTIFIER_MAX_LENGTH = 64
MIGRATION_DIRECTORY = Path(__file__).resolve().parents[2] / "alembic" / "versions"
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


def test_migration_names_match_metadata_and_fit_mysql_limit() -> None:
    migration_names = {
        name
        for path in MIGRATION_DIRECTORY.glob("*.py")
        for name in SCHEMA_IDENTIFIER.findall(path.read_text())
    }
    metadata_names = _metadata_schema_names()

    # Earlier revisions legitimately retain names for columns and constraints
    # removed by later migrations.  The head metadata must still be represented
    # in the complete migration history.
    assert metadata_names <= migration_names
    assert all(len(name) <= MYSQL_IDENTIFIER_MAX_LENGTH for name in migration_names)

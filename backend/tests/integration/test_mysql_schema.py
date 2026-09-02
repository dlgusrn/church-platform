import pytest
from sqlalchemy import inspect
from sqlalchemy.dialects.mysql import ENUM
from sqlalchemy.engine.reflection import Inspector
from sqlalchemy.orm import Session

pytestmark = pytest.mark.integration

EXPECTED_TABLES = {
    "alembic_version",
    "users",
    "churches",
    "church_memberships",
    "roles",
    "permissions",
    "role_permissions",
    "membership_permission_overrides",
    "refresh_tokens",
    "worship_schedules",
    "live_broadcasts",
}

EXPECTED_UNIQUE_COLUMNS = {
    "users": {frozenset({"email"}), frozenset({"phone"})},
    "churches": {frozenset({"code"})},
    "church_memberships": {frozenset({"user_id", "church_id"})},
    "permissions": {frozenset({"code"})},
    "membership_permission_overrides": {
        frozenset({"membership_id", "permission_id"})
    },
}

EXPECTED_FOREIGN_KEYS = {
    "roles": {("church_id", "churches")},
    "church_memberships": {
        ("user_id", "users"),
        ("church_id", "churches"),
        ("role_id", "roles"),
    },
    "role_permissions": {
        ("role_id", "roles"),
        ("permission_id", "permissions"),
    },
    "membership_permission_overrides": {
        ("membership_id", "church_memberships"),
        ("permission_id", "permissions"),
    },
    "refresh_tokens": {("user_id", "users")},
    "worship_schedules": {("church_id", "churches")},
    "live_broadcasts": {("church_id", "churches")},
}

EXPECTED_COLUMNS = {
    "worship_schedules": {"title", "day_label", "time", "display_order", "is_active"},
    "live_broadcasts": {
        "worship_type",
        "custom_worship_name",
        "broadcast_date",
        "youtube_url",
        "status",
        "title_override",
    },
}

REMOVED_COLUMNS = {
    "worship_schedules": {"name", "day_of_week", "start_time"},
    "live_broadcasts": {"worship_schedule_id"},
}


def _unique_column_sets(inspector: Inspector, table_name: str) -> set[frozenset[str]]:
    unique_constraints = inspector.get_unique_constraints(table_name)
    unique_indexes = [
        index
        for index in inspector.get_indexes(table_name)
        if index.get("unique")
    ]
    return {
        frozenset(item["column_names"])
        for item in [*unique_constraints, *unique_indexes]
    }


def test_migrated_tables_constraints_and_foreign_keys(mysql_session: Session) -> None:
    inspector = inspect(mysql_session.connection())
    assert EXPECTED_TABLES <= set(inspector.get_table_names())

    for table_name, expected_columns in EXPECTED_UNIQUE_COLUMNS.items():
        assert expected_columns <= _unique_column_sets(inspector, table_name)

    for table_name, expected_foreign_keys in EXPECTED_FOREIGN_KEYS.items():
        actual = {
            (foreign_key["constrained_columns"][0], foreign_key["referred_table"])
            for foreign_key in inspector.get_foreign_keys(table_name)
        }
        assert expected_foreign_keys <= actual

    for table_name, expected_columns in EXPECTED_COLUMNS.items():
        columns = {column["name"] for column in inspector.get_columns(table_name)}
        assert expected_columns <= columns
        assert not (REMOVED_COLUMNS[table_name] & columns)


def test_mysql_enum_values_match_python_contract(mysql_session: Session) -> None:
    inspector = inspect(mysql_session.connection())
    membership_columns = {
        column["name"]: column for column in inspector.get_columns("church_memberships")
    }
    override_columns = {
        column["name"]: column
        for column in inspector.get_columns("membership_permission_overrides")
    }

    membership_enum = membership_columns["status"]["type"]
    override_enum = override_columns["effect"]["type"]
    live_columns = {
        column["name"]: column for column in inspector.get_columns("live_broadcasts")
    }
    live_status_enum = live_columns["status"]["type"]
    live_worship_type_enum = live_columns["worship_type"]["type"]
    assert isinstance(membership_enum, ENUM)
    assert membership_enum.enums == ["pending", "approved", "rejected"]
    assert isinstance(override_enum, ENUM)
    assert override_enum.enums == ["grant", "deny"]
    assert isinstance(live_status_enum, ENUM)
    assert live_status_enum.enums == ["scheduled", "live", "ended"]
    assert isinstance(live_worship_type_enum, ENUM)
    assert live_worship_type_enum.enums == ["day", "night", "prayer_11", "special", "custom"]

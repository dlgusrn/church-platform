from app.models import Base


EXPECTED_TABLES = {
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
    "notices",
}


def test_initial_tables_are_registered_in_metadata() -> None:
    assert EXPECTED_TABLES <= set(Base.metadata.tables)


def test_membership_and_override_unique_constraints_exist() -> None:
    membership_constraints = {
        constraint.name for constraint in Base.metadata.tables["church_memberships"].constraints
    }
    override_constraints = {
        constraint.name
        for constraint in Base.metadata.tables["membership_permission_overrides"].constraints
    }
    assert "uq_church_memberships_user_id_church_id" in membership_constraints
    assert "uq_mpo_membership_permission" in override_constraints

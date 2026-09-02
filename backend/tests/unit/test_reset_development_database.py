import pytest
from sqlalchemy.engine import make_url

from app.core.config import get_settings
from app.scripts.reset_development_database import _server_url, _validated_target


@pytest.fixture(autouse=True)
def clear_settings_cache() -> None:
    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def set_valid_settings(monkeypatch: pytest.MonkeyPatch, database_name: str) -> None:
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv(
        "DATABASE_URL",
        f"mysql+pymysql://church_app:password@127.0.0.1:3307/{database_name}",
    )
    monkeypatch.setenv("JWT_SECRET_KEY", "unit-test-secret-key")


def test_reset_accepts_only_confirmed_development_database(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    set_valid_settings(monkeypatch, "church_app")

    _, target = _validated_target("church_app")

    assert target.database == "church_app"


def test_reset_rejects_non_development_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    set_valid_settings(monkeypatch, "church_app")
    monkeypatch.setenv("APP_ENV", "production")

    with pytest.raises(SystemExit, match="APP_ENV is explicitly development"):
        _validated_target("church_app")


def test_reset_rejects_missing_app_environment(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    set_valid_settings(monkeypatch, "church_app")
    monkeypatch.delenv("APP_ENV")

    with pytest.raises(SystemExit, match="APP_ENV is explicitly development"):
        _validated_target("church_app")


def test_reset_rejects_test_database(monkeypatch: pytest.MonkeyPatch) -> None:
    set_valid_settings(monkeypatch, "church_app_test")

    with pytest.raises(SystemExit, match="except 'church_app'"):
        _validated_target("church_app")


def test_reset_requires_exact_confirmation(monkeypatch: pytest.MonkeyPatch) -> None:
    set_valid_settings(monkeypatch, "church_app")

    with pytest.raises(SystemExit, match="Confirmation must exactly match"):
        _validated_target("wrong_database")


def test_reset_connects_without_selecting_target_database() -> None:
    target = make_url(
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app"
    )

    assert _server_url(target).database == ""

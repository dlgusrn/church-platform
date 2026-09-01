import pytest

from sqlalchemy.engine import make_url

from app.scripts.reset_test_database import _server_url, _validated_target


def test_reset_requires_test_database_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TEST_DATABASE_URL", raising=False)

    with pytest.raises(SystemExit, match="TEST_DATABASE_URL is required"):
        _validated_target("church_app_test")


def test_reset_rejects_database_without_test_in_name(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(
        "TEST_DATABASE_URL",
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app",
    )

    with pytest.raises(SystemExit, match="does not contain 'test'"):
        _validated_target("church_app")


def test_reset_rejects_development_database(monkeypatch: pytest.MonkeyPatch) -> None:
    database_url = (
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app_test"
    )
    monkeypatch.setenv("DATABASE_URL", database_url)
    monkeypatch.setenv("TEST_DATABASE_URL", database_url)

    with pytest.raises(SystemExit, match="Refusing to reset DATABASE_URL"):
        _validated_target("church_app_test")


def test_reset_requires_exact_database_confirmation(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv(
        "TEST_DATABASE_URL",
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app_test",
    )
    monkeypatch.setenv(
        "DATABASE_URL",
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app",
    )

    with pytest.raises(SystemExit, match="Confirmation must exactly match"):
        _validated_target("wrong_test")


def test_reset_connects_without_selecting_target_database() -> None:
    target = make_url(
        "mysql+pymysql://church_app:password@127.0.0.1:3307/church_app_test"
    )

    assert _server_url(target).database == ""

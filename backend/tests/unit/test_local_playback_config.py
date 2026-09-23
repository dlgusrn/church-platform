import pytest
from pydantic import ValidationError

from app.core.config import Settings


def test_local_playback_upstream_is_rejected_in_production() -> None:
    with pytest.raises(ValidationError, match="development-only"):
        Settings(
            app_env="production",
            database_url="sqlite+pysqlite:///:memory:",
            jwt_secret_key="a-long-enough-test-secret",
            local_playback_upstream_url="http://127.0.0.1:18099",
        )


def test_synology_tls_is_verified_by_default_and_in_development() -> None:
    for app_env, insecure in (("development", False), ("development", True), ("test", True), ("production", False)):
        settings = Settings(
            app_env=app_env,
            database_url="sqlite+pysqlite:///:memory:",
            jwt_secret_key="a-long-enough-test-secret",
            synology_allow_insecure_tls=insecure,
        )
        assert settings.synology_tls_verify is (not insecure)


def test_synology_insecure_tls_is_rejected_outside_development_or_test() -> None:
    for app_env in ("production", "staging"):
        with pytest.raises(ValidationError, match="limited to development/test"):
            Settings(
                app_env=app_env,
                database_url="sqlite+pysqlite:///:memory:",
                jwt_secret_key="a-long-enough-test-secret",
                synology_allow_insecure_tls=True,
            )

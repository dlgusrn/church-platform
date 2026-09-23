from functools import lru_cache

from pydantic import Field, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        case_sensitive=False,
        extra="ignore",
    )

    app_env: str = "development"
    app_name: str = "Church App API"
    database_url: str
    jwt_secret_key: str = Field(min_length=16)
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = Field(default=30, gt=0)
    jwt_refresh_token_expire_days: int = Field(default=30, gt=0)
    video_playback_token_expire_minutes: int = Field(default=15, gt=0, le=60)
    cors_origins: str = ""
    popup_media_root: str = "./popup-media"
    popup_media_staging_ttl_hours: int = Field(default=24, gt=0)
    synology_base_url: str | None = None
    synology_username: str | None = None
    synology_password: str | None = None
    synology_video_root: str | None = None
    synology_allow_insecure_tls: bool = False
    local_playback_upstream_url: str | None = None

    @property
    def synology_tls_verify(self) -> bool:
        return not self.synology_allow_insecure_tls

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @model_validator(mode="after")
    def reject_insecure_production_settings(self) -> "Settings":
        if self.app_env.lower() == "production" and self.jwt_secret_key == "change-me":
            raise ValueError("JWT_SECRET_KEY must be changed in production")
        if self.app_env.lower() == "production" and self.local_playback_upstream_url:
            raise ValueError("LOCAL_PLAYBACK_UPSTREAM_URL is development-only")
        if self.synology_allow_insecure_tls and self.app_env.lower() not in {"development", "test"}:
            raise ValueError("SYNOLOGY_ALLOW_INSECURE_TLS is limited to development/test")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]

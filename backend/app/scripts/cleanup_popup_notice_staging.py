from datetime import UTC, datetime, timedelta

from app.core.config import get_settings
from app.services.media_storage import LocalPopupNoticeMediaStorage


def cleanup() -> int:
    settings = get_settings()
    return LocalPopupNoticeMediaStorage(settings.popup_media_root).cleanup_stale_staging(
        datetime.now(UTC) - timedelta(hours=settings.popup_media_staging_ttl_hours)
    )


if __name__ == "__main__":
    print(f"Removed {cleanup()} stale popup notice staging file(s).")

from datetime import UTC, datetime, timedelta
from io import BytesIO

import pytest
from PIL import Image
from pydantic import ValidationError

from app.schemas.popup_notice import PopupNoticeCreateRequest
from app.services.media_storage import LocalPopupNoticeMediaStorage


def _request(**overrides: object) -> PopupNoticeCreateRequest:
    values: dict[str, object] = {
        "title": "팝업", "content": "내용",
        "starts_at": "2026-09-03T00:00:00Z",
        "ends_at": "2026-09-04T00:00:00+00:00",
    }
    values.update(overrides)
    return PopupNoticeCreateRequest(**values)


def test_popup_notice_requires_offset_and_valid_window() -> None:
    with pytest.raises(ValidationError, match="timezone offset"):
        _request(starts_at="2026-09-03T00:00:00")
    with pytest.raises(ValidationError, match="starts_at must be before ends_at"):
        _request(starts_at="2026-09-04T00:00:00Z")
    assert _request().is_active is False


def test_local_storage_validates_content_and_uses_server_generated_paths(tmp_path: object) -> None:
    storage = LocalPopupNoticeMediaStorage(tmp_path)  # type: ignore[arg-type]
    image = Image.new("RGB", (10, 10), "white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    staged = storage.stage(buffer.getvalue(), "../../unsafe.png")
    assert staged.staging_key.startswith("staging/")
    assert staged.final_key.startswith("popup-notices/")
    assert "unsafe" not in staged.final_key
    storage.promote(staged)
    assert storage.read(staged.final_key).startswith(b"\x89PNG")
    with pytest.raises(Exception):
        storage.stage(b"not an image", "image.png")
    with pytest.raises(Exception):
        storage.stage(b"x" * (5 * 1024 * 1024 + 1), "large.png")


def test_stale_staging_cleanup(tmp_path: object) -> None:
    storage = LocalPopupNoticeMediaStorage(tmp_path)  # type: ignore[arg-type]
    staged = storage.stage(_png(), "a.png")
    path = storage._path(staged.staging_key)
    old = (datetime.now(UTC) - timedelta(hours=2)).timestamp()
    import os
    os.utime(path, (old, old))
    assert storage.cleanup_stale_staging(datetime.now(UTC) - timedelta(hours=1)) == 1


def _png() -> bytes:
    image = Image.new("RGB", (10, 10), "white")
    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()

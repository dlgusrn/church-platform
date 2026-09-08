from __future__ import annotations

import os
from dataclasses import dataclass
from datetime import UTC, datetime
from io import BytesIO
from pathlib import Path
from uuid import uuid4

from PIL import Image, UnidentifiedImageError

from app.core.exceptions import RequestValidationError

MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_IMAGE_DIMENSION = 4096
MAX_IMAGE_PIXELS = 16_000_000
IMAGE_FORMATS = {"JPEG": ("image/jpeg", "jpg"), "PNG": ("image/png", "png"), "WEBP": ("image/webp", "webp")}


@dataclass(frozen=True)
class StagedImage:
    staging_key: str
    final_key: str
    content_type: str
    size: int


class PopupNoticeMediaStorage:
    """Storage boundary; a future S3 adapter implements the same operations."""

    def stage(self, data: bytes, filename: str | None) -> StagedImage:
        del filename  # Client names are intentionally never used in storage paths.
        content_type, extension = self._validate_image(data)
        token = uuid4().hex
        return self._write_staged(data, token, content_type, extension)

    def _validate_image(self, data: bytes) -> tuple[str, str]:
        if not data:
            raise RequestValidationError("Image file is empty")
        if len(data) > MAX_IMAGE_BYTES:
            raise RequestValidationError("Image file exceeds 5 MiB")
        try:
            with Image.open(BytesIO(data)) as image:
                self._validate_image_header(image)
                image.verify()
            with Image.open(BytesIO(data)) as image:
                content_type, extension = self._validate_image_header(image)
                image.load()
                return content_type, extension
        except (UnidentifiedImageError, OSError, ValueError) as exc:
            raise RequestValidationError("Invalid image file") from exc

    @staticmethod
    def _validate_image_header(image: Image.Image) -> tuple[str, str]:
        if image.format not in IMAGE_FORMATS:
            raise RequestValidationError("Only JPEG, PNG, and WebP images are allowed")
        width, height = image.size
        if width > MAX_IMAGE_DIMENSION or height > MAX_IMAGE_DIMENSION or width * height > MAX_IMAGE_PIXELS:
            raise RequestValidationError("Image dimensions are too large")
        return IMAGE_FORMATS[image.format]

    def _write_staged(self, data: bytes, token: str, content_type: str, extension: str) -> StagedImage:
        raise NotImplementedError

    def promote(self, staged: StagedImage) -> None:
        raise NotImplementedError

    def delete(self, key: str) -> None:
        raise NotImplementedError

    def read(self, key: str) -> bytes:
        raise NotImplementedError

    def cleanup_stale_staging(self, older_than: datetime) -> int:
        raise NotImplementedError


class LocalPopupNoticeMediaStorage(PopupNoticeMediaStorage):
    def __init__(self, root: str | Path) -> None:
        self.root = Path(root).resolve()
        (self.root / "staging").mkdir(parents=True, exist_ok=True)
        (self.root / "popup-notices").mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        if not key or Path(key).is_absolute() or ".." in Path(key).parts:
            raise RequestValidationError("Invalid media storage key")
        path = (self.root / key).resolve()
        if self.root not in path.parents:
            raise RequestValidationError("Invalid media storage key")
        return path

    def _write_staged(self, data: bytes, token: str, content_type: str, extension: str) -> StagedImage:
        staging_key = f"staging/{token}.{extension}"
        final_key = f"popup-notices/{token}.{extension}"
        path = self._path(staging_key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return StagedImage(staging_key, final_key, content_type, len(data))

    def promote(self, staged: StagedImage) -> None:
        source, destination = self._path(staged.staging_key), self._path(staged.final_key)
        destination.parent.mkdir(parents=True, exist_ok=True)
        os.replace(source, destination)

    def delete(self, key: str) -> None:
        try:
            self._path(key).unlink()
        except FileNotFoundError:
            return

    def read(self, key: str) -> bytes:
        try:
            return self._path(key).read_bytes()
        except FileNotFoundError as exc:
            raise RequestValidationError("Popup notice image is unavailable") from exc

    def cleanup_stale_staging(self, older_than: datetime) -> int:
        count = 0
        cutoff = older_than.astimezone(UTC).timestamp()
        for path in (self.root / "staging").glob("*"):
            if path.is_file() and path.stat().st_mtime < cutoff:
                path.unlink()
                count += 1
        return count

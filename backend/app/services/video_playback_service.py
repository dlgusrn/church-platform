"""Authorization and streaming boundary for Synology video playback."""
from __future__ import annotations

import re
import logging
from collections.abc import AsyncIterator
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import PurePosixPath

import httpx
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.exceptions import AuthenticationError, ForbiddenError, NotFoundError, RequestValidationError
from app.core.security import create_video_playback_token, decode_token
from app.models.enums import MembershipStatus
from app.models.video import Video, VideoSourceType
from app.repositories.user_repository import UserRepository
from app.services.video_service import VideoService
from app.services.video_sources.synology.client import SynologyDownloadClient, SynologyError
from app.services.video_sources.local_playback import LOCAL_PLAYBACK_SOURCE_REF, LocalPlaybackDownloadClient

_SINGLE_RANGE = re.compile(r"^bytes=(?:\d+-\d*|-\d+)$")
_FORWARDED_HEADERS = ("content-range", "content-length", "content-type", "accept-ranges")
logger = logging.getLogger(__name__)


class PlaybackRangeError(Exception):
    """Safe range error converted to HTTP 416 by the router."""


class PlaybackRangeErrorWithHeaders(PlaybackRangeError):
    def __init__(self, headers: dict[str, str]) -> None:
        self.headers = headers


class PlaybackUpstreamError(Exception):
    def __init__(self, status_code: int = 503) -> None:
        self.status_code = status_code


@dataclass(frozen=True)
class PlaybackStreamDescriptor:
    """Plain playback data safe to use after the authorization session closes."""

    source_ref: str
    absolute_path: str


class VideoPlaybackService:
    def __init__(self, session: Session, download_client_factory=SynologyDownloadClient) -> None:
        self.session = session
        self.videos = VideoService(session)
        self.users = UserRepository(session)
        self.download_client_factory = download_client_factory

    def create_session(self, church_id: int, video_id: int, user_id: int) -> tuple[str, datetime]:
        video = self._require_playable(church_id, video_id, user_id)
        if video.source_type != VideoSourceType.SYNOLOGY:
            raise RequestValidationError("Playback session is only available for Synology videos")
        settings = get_settings()
        expires_at = datetime.now(UTC) + timedelta(minutes=settings.video_playback_token_expire_minutes)
        logger.debug("[PLAYBACK] session issued")
        return create_video_playback_token(user_id, church_id, video_id), expires_at

    @staticmethod
    def validate_range(range_header: str | None) -> None:
        if range_header is not None and ("," in range_header or not _SINGLE_RANGE.fullmatch(range_header.strip())):
            raise PlaybackRangeError()

    def prepare_stream(self, token: str) -> PlaybackStreamDescriptor:
        """Revalidate playback access and detach only stream-safe plain values."""
        claims = decode_token(token, "video_playback")
        if claims.get("purpose") != "video_playback" or not isinstance(claims.get("nonce"), str) or not claims["nonce"]:
            raise AuthenticationError("Invalid playback token")
        try:
            user_id, church_id, video_id = int(claims["sub"]), int(claims["church_id"]), int(claims["video_id"])
        except (KeyError, TypeError, ValueError) as exc:
            raise AuthenticationError("Invalid playback token") from exc
        if self.users.get_by_id(user_id) is None:
            raise AuthenticationError("Invalid playback token")
        video = self._require_playable(church_id, video_id, user_id)
        if video.source_type != VideoSourceType.SYNOLOGY:
            raise RequestValidationError("Playback source is unavailable")
        # Do not return an ORM object: the caller closes its DB session before
        # opening the upstream stream.
        return PlaybackStreamDescriptor(
            source_ref=video.source_ref,
            absolute_path=self._absolute_path(video.source_ref),
        )

    async def stream(self, token: str, *, range_header: str | None, method: str) -> StreamingResponse:
        """Backward-compatible combined API for direct service callers."""
        self.validate_range(range_header)
        descriptor = self.prepare_stream(token)
        return await self.stream_prepared(descriptor, range_header=range_header, method=method)

    async def stream_prepared(
        self, descriptor: PlaybackStreamDescriptor, *, range_header: str | None, method: str,
    ) -> StreamingResponse:
        """Stream an already-authorized descriptor without touching the DB session."""
        self.validate_range(range_header)
        logger.debug("[PLAYBACK] range=%s", "yes" if range_header else "no")
        client = self._download_client_for_source_ref(descriptor.source_ref)
        try:
            await client.connect()
            upstream = await client.open_download(
                # Do not turn a HEAD metadata request into a whole-file GET.
                # If a DSM deployment does not support HEAD, GET playback still
                # works and HEAD capability remains an integration-test gate.
                descriptor.absolute_path, range_header=range_header, method=method,
            )
        except SynologyError as exc:
            await client.close()
            raise PlaybackUpstreamError(504 if "timed out" in str(exc).lower() else 503) from exc
        logger.debug("[PLAYBACK] upstream=%s", upstream.status_code)
        if range_header and upstream.status_code == 200:
            await upstream.aclose(); await client.close()
            raise PlaybackUpstreamError(502)
        if upstream.status_code == 416:
            headers = self._headers(upstream)
            await upstream.aclose(); await client.close()
            raise PlaybackRangeErrorWithHeaders(headers)
        if upstream.status_code not in (200, 206):
            await upstream.aclose(); await client.close()
            raise PlaybackUpstreamError(503)
        headers = self._headers(upstream)
        if upstream.status_code == 206 and "Content-Range" not in headers:
            await upstream.aclose(); await client.close()
            raise PlaybackUpstreamError(502)
        if method == "HEAD":
            await upstream.aclose(); await client.close()
            logger.debug("[PLAYBACK] downstream=%s", upstream.status_code)
            logger.debug("[PLAYBACK] stream closed")
            return StreamingResponse(iter(()), status_code=upstream.status_code, headers=headers)

        async def body() -> AsyncIterator[bytes]:
            try:
                async for chunk in upstream.aiter_bytes(chunk_size=64 * 1024):
                    if chunk:
                        yield chunk
            finally:
                await upstream.aclose()
                await client.close()
                logger.debug("[PLAYBACK] stream closed")

        logger.debug("[PLAYBACK] downstream=%s", upstream.status_code)
        return StreamingResponse(body(), status_code=upstream.status_code, headers=headers, media_type=None)

    def _require_playable(self, church_id: int, video_id: int, user_id: int) -> Video:
        membership = self.videos.memberships.get_by_user_and_church(user_id, church_id)
        if membership is None or membership.status is not MembershipStatus.APPROVED:
            raise ForbiddenError("Approved church membership required")
        video = self.videos._video_or_raise(church_id, video_id)
        if not video.is_published and not self.videos._has_manage_permission(church_id, user_id):
            raise NotFoundError("Video not found")
        if not self.videos._has_manage_permission(church_id, user_id):
            self.videos._require_read_permission(church_id, user_id)
        return video

    def _download_client(self) -> SynologyDownloadClient:
        settings = get_settings()
        if not all((settings.synology_base_url, settings.synology_username, settings.synology_password, settings.synology_video_root)):
            raise PlaybackUpstreamError(503)
        return self.download_client_factory(
            settings.synology_base_url,
            settings.synology_username,
            settings.synology_password,
            verify=settings.synology_tls_verify,
            shared=True,
        )

    def _download_client_for_video(self, video: Video) -> SynologyDownloadClient | LocalPlaybackDownloadClient:
        return self._download_client_for_source_ref(video.source_ref)

    def _download_client_for_source_ref(self, source_ref: str) -> SynologyDownloadClient | LocalPlaybackDownloadClient:
        settings = get_settings()
        if (
            settings.app_env.lower() == "development"
            and settings.local_playback_upstream_url
            and source_ref == LOCAL_PLAYBACK_SOURCE_REF
        ):
            return LocalPlaybackDownloadClient(settings.local_playback_upstream_url)
        return self._download_client()

    @staticmethod
    def _headers(response: httpx.Response) -> dict[str, str]:
        result = {name.title(): response.headers[name] for name in _FORWARDED_HEADERS if name in response.headers}
        if response.status_code == 206:
            result["Accept-Ranges"] = "bytes"
        return result

    @staticmethod
    def _absolute_path(source_ref: str) -> str:
        root = get_settings().synology_video_root or ""
        if not root.startswith("/") or ".." in root.split("/"):
            raise PlaybackUpstreamError(503)
        relative = PurePosixPath(source_ref)
        if relative.is_absolute() or ".." in relative.parts or not relative.parts:
            raise PlaybackUpstreamError(502)
        return f"{root.rstrip('/')}/{relative.as_posix()}"

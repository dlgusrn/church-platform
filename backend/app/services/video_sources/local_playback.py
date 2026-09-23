"""Development-only HTTP upstream for the synthetic local playback fixture."""
from __future__ import annotations

import httpx

from app.services.video_sources.synology.client import SynologyError


# This is intentionally a normal root-relative NAS-style reference.  The
# mapping only exists when APP_ENV=development and a local upstream is enabled.
LOCAL_PLAYBACK_SOURCE_REF = "development/local-playback-test.mp4"


class LocalPlaybackDownloadClient:
    """Streaming client for the fixed endpoint of local_video_range_server."""

    def __init__(self, upstream_url: str, *, timeout: float = 30.0) -> None:
        self.upstream_url = upstream_url.rstrip("/") + "/sample.mp4"
        self.http = httpx.AsyncClient(timeout=httpx.Timeout(timeout, connect=10.0), follow_redirects=False)

    async def connect(self) -> None:
        return None

    async def open_download(self, _absolute_path: str, *, range_header: str | None = None, method: str = "GET") -> httpx.Response:
        request = self.http.build_request(method, self.upstream_url, headers={"Range": range_header} if range_header else None)
        try:
            return await self.http.send(request, stream=True)
        except httpx.TimeoutException as exc:
            raise SynologyError("Local playback upstream timed out") from exc
        except httpx.HTTPError as exc:
            raise SynologyError("Local playback upstream failed") from exc

    async def close(self) -> None:
        await self.http.aclose()

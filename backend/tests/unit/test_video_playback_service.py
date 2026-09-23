import asyncio

import httpx
import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import QueuePool

from app.models.video import Video, VideoSourceType
from app.services.video_playback_service import (
    PlaybackRangeError,
    PlaybackStreamDescriptor,
    PlaybackUpstreamError,
    VideoPlaybackService,
)
from app.services.video_sources.synology.client import (
    SynologyDownloadClient,
    close_shared_playback_connections,
)
from app.services.video_sources.local_playback import LOCAL_PLAYBACK_SOURCE_REF, LocalPlaybackDownloadClient


def test_synology_playback_path_is_root_relative(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SYNOLOGY_VIDEO_ROOT", "/video-root")
    from app.core.config import get_settings
    get_settings.cache_clear()
    assert VideoPlaybackService._absolute_path("2026/sermon.mp4") == "/video-root/2026/sermon.mp4"
    with pytest.raises(PlaybackUpstreamError):
        VideoPlaybackService._absolute_path("../outside.mp4")
    with pytest.raises(PlaybackUpstreamError):
        VideoPlaybackService._absolute_path("/absolute.mp4")
    get_settings.cache_clear()


class _FakeDownloadClient:
    def __init__(self, status: int) -> None:
        self.status = status
        self.range_header: str | None = None
        self.closed = False

    async def connect(self) -> None:
        return None

    async def open_download(self, _path: str, *, range_header: str | None, method: str) -> httpx.Response:
        self.range_header = range_header
        headers = {"content-type": "video/mp4", "content-length": "3"}
        if self.status == 206:
            headers.update({"content-range": "bytes 0-2/10", "accept-ranges": "bytes"})
        return httpx.Response(self.status, headers=headers, content=b"abc")

    async def close(self) -> None:
        self.closed = True


def _stream_service(monkeypatch: pytest.MonkeyPatch, upstream_status: int) -> tuple[VideoPlaybackService, _FakeDownloadClient]:
    monkeypatch.setenv("SYNOLOGY_VIDEO_ROOT", "/video-root")
    monkeypatch.setenv("SYNOLOGY_BASE_URL", "http://synology.test")
    monkeypatch.setenv("SYNOLOGY_USERNAME", "test")
    monkeypatch.setenv("SYNOLOGY_PASSWORD", "test")
    from app.core.config import get_settings
    get_settings.cache_clear()
    upstream = _FakeDownloadClient(upstream_status)
    service = VideoPlaybackService(None, download_client_factory=lambda *_, **__: upstream)  # type: ignore[arg-type]
    service.users = type("Users", (), {"get_by_id": lambda *_: object()})()
    service._require_playable = lambda *_: Video(  # type: ignore[method-assign]
        church_id=1, source_type=VideoSourceType.SYNOLOGY, source_ref="folder/video.mp4",
        title="video", recorded_at=__import__("datetime").datetime.now(__import__("datetime").UTC), is_published=True,
    )
    return service, upstream


def test_range_is_forwarded_and_206_headers_are_relayed(monkeypatch: pytest.MonkeyPatch) -> None:
    service, upstream = _stream_service(monkeypatch, 206)
    monkeypatch.setattr(
        "app.services.video_playback_service.decode_token",
        lambda *_: {"sub": "1", "church_id": 1, "video_id": 2, "purpose": "video_playback", "nonce": "test-nonce"},
    )
    response = asyncio.run(service.stream("token", range_header="bytes=0-2", method="GET"))
    assert response.status_code == 206
    assert response.headers["content-range"] == "bytes 0-2/10"
    assert upstream.range_header == "bytes=0-2"
    async def consume() -> list[bytes]:
        return [chunk async for chunk in response.body_iterator]  # type: ignore[attr-defined]
    assert asyncio.run(consume()) == [b"abc"]
    assert upstream.closed


def test_range_ignored_by_upstream_is_not_faked(monkeypatch: pytest.MonkeyPatch) -> None:
    service, upstream = _stream_service(monkeypatch, 200)
    monkeypatch.setattr(
        "app.services.video_playback_service.decode_token",
        lambda *_: {"sub": "1", "church_id": 1, "video_id": 2, "purpose": "video_playback", "nonce": "test-nonce"},
    )
    with pytest.raises(PlaybackUpstreamError) as error:
        asyncio.run(service.stream("token", range_header="bytes=1-2", method="GET"))
    assert error.value.status_code == 502
    assert upstream.closed


def test_invalid_and_multi_range_are_rejected_before_upstream() -> None:
    service = VideoPlaybackService(None)  # type: ignore[arg-type]
    for value in ("items=0-1", "bytes=0-1,2-3", "bytes=-"):
        with pytest.raises(PlaybackRangeError):
            asyncio.run(service.stream("unused", range_header=value, method="GET"))


def test_local_playback_adapter_is_selected_only_in_development(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_ENV", "development")
    monkeypatch.setenv("LOCAL_PLAYBACK_UPSTREAM_URL", "http://127.0.0.1:18099")
    from app.core.config import get_settings
    get_settings.cache_clear()
    service = VideoPlaybackService(None)  # type: ignore[arg-type]
    video = Video(
        church_id=1, source_type=VideoSourceType.SYNOLOGY, source_ref=LOCAL_PLAYBACK_SOURCE_REF,
        title="Local Playback Test", recorded_at=__import__("datetime").datetime.now(__import__("datetime").UTC), is_published=True,
    )
    assert isinstance(service._download_client_for_video(video), LocalPlaybackDownloadClient)
    get_settings.cache_clear()


def test_real_download_client_uses_discovery_and_relays_mock_http_range(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Exercise the production async client against a local in-memory HTTP upstream."""
    service, _ = _stream_service(monkeypatch, 206)
    ranges: list[str | None] = []

    def upstream(request: httpx.Request) -> httpx.Response:
        if request.url.path.endswith("query.cgi"):
            return httpx.Response(200, json={"success": True, "data": {
                "SYNO.API.Auth": {"path": "auth.cgi", "maxVersion": 7},
                "SYNO.FileStation.List": {"path": "download.cgi", "maxVersion": 2},
                "SYNO.FileStation.Download": {"path": "download.cgi", "maxVersion": 2},
            }})
        if request.url.path.endswith("auth.cgi"):
            if request.url.params.get("method") == "logout":
                return httpx.Response(200, json={"success": True})
            return httpx.Response(200, json={"success": True, "data": {"sid": "server-only"}})
        assert request.url.path.endswith("download.cgi")
        ranges.append(request.headers.get("range"))
        return httpx.Response(206, headers={
            "content-type": "video/mp4", "content-length": "3",
            "content-range": "bytes 0-2/10", "accept-ranges": "bytes",
        }, content=b"abc")

    transport = httpx.MockTransport(upstream)
    service._download_client = lambda: SynologyDownloadClient(  # type: ignore[method-assign]
        "http://local-upstream.test", "user", "password", transport=transport,
    )
    monkeypatch.setattr(
        "app.services.video_playback_service.decode_token",
        lambda *_: {"sub": "1", "church_id": 1, "video_id": 2, "purpose": "video_playback", "nonce": "test-nonce"},
    )
    response = asyncio.run(service.stream("token", range_header="bytes=0-2", method="GET"))
    async def consume() -> list[bytes]:
        return [chunk async for chunk in response.body_iterator]  # type: ignore[attr-defined]
    assert asyncio.run(consume()) == [b"abc"]
    assert response.status_code == 206
    assert response.headers["content-range"] == "bytes 0-2/10"
    assert ranges == ["bytes=0-2"]


def test_playback_authorization_connection_is_returned_before_concurrent_streams(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Request-scoped streaming must not retain authorization pool checkouts."""
    from app.core import database
    from app.main import app

    engine = create_engine(
        "sqlite://",
        poolclass=QueuePool,
        pool_size=5,
        max_overflow=10,
        pool_timeout=0.01,
    )
    factory = sessionmaker(bind=engine)
    pool = engine.pool
    checkins = 0

    @event.listens_for(pool, "checkin")
    def count_checkins(*_: object) -> None:
        nonlocal checkins
        checkins += 1

    descriptor = PlaybackStreamDescriptor(source_ref="folder/video.mp4", absolute_path="/root/folder/video.mp4")
    release = asyncio.Event()

    def prepare(self: VideoPlaybackService, _token: str) -> PlaybackStreamDescriptor:
        # Force a real QueuePool checkout during the authorization phase.
        self.session.connection()
        return descriptor

    async def stream_prepared(
        _self: VideoPlaybackService, _descriptor: PlaybackStreamDescriptor, *, range_header: str | None, method: str,
    ) -> httpx.Response:
        async def body():
            await release.wait()
            yield b"range"
        from fastapi.responses import StreamingResponse
        return StreamingResponse(body(), status_code=206, headers={"Content-Range": "bytes 0-4/5"})

    monkeypatch.setattr(VideoPlaybackService, "prepare_stream", prepare)
    monkeypatch.setattr(VideoPlaybackService, "stream_prepared", stream_prepared)
    # Preserve the route's function-scoped get_db dependency. An override would
    # be rebuilt with its own default scope and would not exercise that policy.
    monkeypatch.setattr(database, "get_session_factory", lambda: factory)

    async def run() -> None:
        # More than pool_size + max_overflow streams remain open, but their
        # authorization sessions must already have returned their connections.
        started = 0
        all_started = asyncio.Event()

        async def receive() -> dict[str, object]:
            return {"type": "http.request", "body": b"", "more_body": False}

        async def send(message: dict[str, object]) -> None:
            nonlocal started
            if message["type"] == "http.response.start":
                started += 1
                if started == 16:
                    all_started.set()

        def scope() -> dict[str, object]:
            return {
                "type": "http", "asgi": {"version": "3.0", "spec_version": "2.4"},
                "http_version": "1.1", "method": "GET", "scheme": "http",
                "path": "/api/v1/playback", "raw_path": b"/api/v1/playback",
                "query_string": b"", "root_path": "", "headers": [
                    (b"x-playback-token", b"token"), (b"range", b"bytes=0-4"),
                ], "client": ("testclient", 1), "server": ("testserver", 80), "state": {},
            }

        tasks = [asyncio.create_task(app(scope(), receive, send)) for _ in range(16)]
        await asyncio.wait_for(all_started.wait(), timeout=1)
        assert pool.checkedout() == 0
        assert checkins == 16
        release.set()
        await asyncio.gather(*tasks)

    try:
        asyncio.run(run())
    finally:
        engine.dispose()


def test_shared_synology_connection_caches_discovery_and_reuses_sid_for_concurrent_ranges(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Control-plane work is single-flight while Range downloads stay concurrent."""
    counts = {"info": 0, "login": 0, "logout": 0, "download": 0}
    expire_sid: str | None = None

    async def upstream(request: httpx.Request) -> httpx.Response:
        nonlocal expire_sid
        if request.url.path.endswith("query.cgi"):
            counts["info"] += 1
            return httpx.Response(200, json={"success": True, "data": {
                "SYNO.API.Auth": {"path": "entry.cgi", "maxVersion": 7},
                "SYNO.FileStation.List": {"path": "entry.cgi", "maxVersion": 2},
                "SYNO.FileStation.Download": {"path": "entry.cgi", "maxVersion": 2},
            }})
        method = request.url.params.get("method")
        api = request.url.params.get("api")
        if api == "SYNO.API.Auth" and method == "login":
            counts["login"] += 1
            return httpx.Response(200, json={"success": True, "data": {"sid": f"sid-{counts['login']}"}})
        if api == "SYNO.API.Auth" and method == "logout":
            counts["logout"] += 1
            return httpx.Response(200, json={"success": True})
        assert api == "SYNO.FileStation.Download"
        counts["download"] += 1
        if request.url.params.get("_sid") == expire_sid:
            await asyncio.sleep(0)
            return httpx.Response(200, headers={"content-type": "application/json"}, json={
                "success": False, "error": {"code": 106},
            })
        return httpx.Response(206, headers={
            "content-type": "video/mp4", "content-length": "3",
            "content-range": "bytes 0-2/10", "accept-ranges": "bytes",
        }, content=b"abc")

    transport = httpx.MockTransport(upstream)
    from app.services.video_sources.synology import client as synology_client_module
    warnings: list[str] = []
    monkeypatch.setattr(synology_client_module.logger, "warning", warnings.append)

    async def request_range() -> httpx.Response:
        client = SynologyDownloadClient(
            "https://synology.test", "user", "password", transport=transport, verify=False, shared=True,
        )
        await client.connect()
        response = await client.open_download("/root/video.mp4", range_header="bytes=0-2")
        await response.aclose()
        assert await client.close()  # Per-range close must not close the shared client.
        return response

    async def run() -> None:
        nonlocal expire_sid
        await close_shared_playback_connections()
        cold = await asyncio.gather(*[request_range() for _ in range(10)])
        assert all(response.status_code == 206 for response in cold)
        assert counts == {"info": 1, "login": 1, "logout": 0, "download": 10}

        warm = await asyncio.gather(*[request_range() for _ in range(10)])
        assert all(response.status_code == 206 for response in warm)
        assert counts == {"info": 1, "login": 1, "logout": 0, "download": 20}

        # All concurrent requests first observe the same expired SID. The
        # replacement is single-flight and every request retries once.
        expire_sid = "sid-1"
        recovered = await asyncio.gather(*[request_range() for _ in range(10)])
        assert all(response.status_code == 206 for response in recovered)
        assert counts["info"] == 1
        assert counts["login"] == 2
        assert counts["download"] == 40

        probe = SynologyDownloadClient(
            "https://synology.test", "user", "password", transport=transport, verify=False, shared=True,
        )
        assert probe._connection.http is not None and not probe._connection.http.is_closed
        await close_shared_playback_connections()
        assert probe._connection.http is None
        assert counts["logout"] == 1

    asyncio.run(run())
    assert warnings == ["Synology TLS verification disabled for development"]


def test_cancelled_range_stream_closes_upstream_without_closing_shared_client() -> None:
    class BlockingStream(httpx.AsyncByteStream):
        def __init__(self) -> None:
            self.started = asyncio.Event()
            self.release = asyncio.Event()
            self.closed = False

        async def __aiter__(self):
            self.started.set()
            try:
                await self.release.wait()
                yield b"range"
            finally:
                self.closed = True

        async def aclose(self) -> None:
            self.closed = True

    class SharedClient:
        def __init__(self, stream: BlockingStream) -> None:
            self.stream, self.close_calls, self.still_open = stream, 0, True

        async def connect(self) -> None:
            return None

        async def open_download(self, *_: object, **__: object) -> httpx.Response:
            return httpx.Response(206, headers={"content-range": "bytes 0-4/5"}, stream=self.stream)

        async def close(self) -> bool:
            self.close_calls += 1
            return True  # Mirrors a shared manager: per-range close is a no-op.

    async def run() -> None:
        stream = BlockingStream()
        client = SharedClient(stream)
        service = VideoPlaybackService(None)  # type: ignore[arg-type]
        service._download_client_for_source_ref = lambda _: client  # type: ignore[method-assign]
        response = await service.stream_prepared(
            PlaybackStreamDescriptor(source_ref="folder/video.mp4", absolute_path="/root/folder/video.mp4"),
            range_header="bytes=0-4", method="GET",
        )
        pending = asyncio.create_task(anext(response.body_iterator))  # type: ignore[attr-defined]
        await stream.started.wait()
        pending.cancel()
        with pytest.raises(asyncio.CancelledError):
            await pending
        assert stream.closed
        assert client.close_calls == 1
        assert client.still_open

    asyncio.run(run())

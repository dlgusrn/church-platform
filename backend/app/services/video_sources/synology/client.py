"""Small wrappers around the official DSM File Station WebAPI.

The synchronous client is intentionally kept for import metadata scans.  The
async client below is dedicated to playback and never exposes a SID outside
the backend process.
"""
import asyncio
from dataclasses import dataclass
from hashlib import sha256
import json
import logging
from typing import Any
import httpx

logger = logging.getLogger(__name__)


class SynologyError(Exception):
    """A deliberately non-provider-specific error safe for API responses."""

    def __init__(self, message: str, *, error_code: int | None = None) -> None:
        super().__init__(message)
        self.error_code = error_code


class _SynologySessionExpired(SynologyError):
    """Internal-only signal for documented DSM session errors."""


_SESSION_EXPIRED_CODES = frozenset({106, 107, 119})


@dataclass(frozen=True)
class SynologyEntry:
    path: str
    name: str
    is_dir: bool
    size: int = 0


class SynologyFileStationClient:
    def __init__(self, base_url: str, username: str, password: str, *, timeout: float = 15.0, verify: bool = True) -> None:
        self.base_url, self.username, self.password = base_url.rstrip("/"), username, password
        if not verify:
            logger.warning("Synology TLS verification disabled for development")
        self.http = httpx.Client(timeout=timeout, follow_redirects=False, verify=verify)
        self._sid: str | None = None
        self._paths: dict[str, str] = {}
        self._versions: dict[str, int] = {}

    def __enter__(self) -> "SynologyFileStationClient":
        self.connect(); return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def connect(self) -> None:
        try:
            info = self._request("/webapi/query.cgi", {"api": "SYNO.API.Info", "version": "1", "method": "query", "query": "SYNO.API.Auth,SYNO.FileStation.List"}, authenticated=False)
            data = info.get("data", {})
            for api in ("SYNO.API.Auth", "SYNO.FileStation.List"):
                entry = data.get(api)
                if not entry: raise SynologyError("Synology service is unavailable")
                discovered_path = str(entry["path"])
                # DSM returns paths such as "auth.cgi"; normalize only the API path,
                # never a NAS file path supplied by a client.
                self._paths[api] = "/webapi/" + discovered_path.lstrip("/") if not discovered_path.startswith("/webapi/") else discovered_path
                self._versions[api] = int(entry.get("maxVersion", 1))
            auth = self._request(self._paths["SYNO.API.Auth"], {"api": "SYNO.API.Auth", "version": str(self._versions["SYNO.API.Auth"]), "method": "login", "account": self.username, "passwd": self.password, "session": "church-platform", "format": "sid"}, authenticated=False)
            sid = auth.get("data", {}).get("sid")
            if not sid: raise SynologyError("Synology authentication failed")
            self._sid = str(sid)
        except (httpx.HTTPError, KeyError, TypeError, ValueError) as exc:
            self.close(); raise SynologyError("Synology connection failed") from exc

    def list_directory(self, path: str, *, offset: int = 0, limit: int = 500) -> tuple[list[SynologyEntry], int]:
        payload = self._request(self._paths["SYNO.FileStation.List"], {"api": "SYNO.FileStation.List", "version": str(self._versions["SYNO.FileStation.List"]), "method": "list", "folder_path": path, "offset": str(offset), "limit": str(limit), "additional": '["size"]'})
        data = payload.get("data", {})
        entries = [SynologyEntry(str(x.get("path", "")), str(x.get("name", "")), bool(x.get("isdir")), int(x.get("additional", {}).get("size", x.get("size", 0)) or 0)) for x in data.get("files", [])]
        return entries, int(data.get("total", len(entries)))

    def _request(self, path: str, params: dict[str, str], *, authenticated: bool = True) -> dict[str, Any]:
        if authenticated:
            if not self._sid: raise SynologyError("Synology session is unavailable")
            params = {**params, "_sid": self._sid}
        response = self.http.get(f"{self.base_url}{path}", params=params)
        response.raise_for_status()
        value = response.json()
        if not value.get("success"):
            # DSM error codes and body may contain sensitive provider detail; never propagate them.
            raise SynologyError("Synology request was rejected")
        return value

    def close(self) -> bool:
        logout_succeeded = True
        if self._sid and self._paths.get("SYNO.API.Auth"):
            try:
                self._request(self._paths["SYNO.API.Auth"], {"api": "SYNO.API.Auth", "version": str(self._versions["SYNO.API.Auth"]), "method": "logout", "session": "church-platform"})
            except (SynologyError, httpx.HTTPError):
                logout_succeeded = False
        self._sid = None
        self.http.close()
        return logout_succeeded


class _SynologyPlaybackConnection:
    """Process-local control plane; download responses remain request-owned."""

    def __init__(
        self, base_url: str, username: str, password: str, *, timeout: float, verify: bool,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.base_url, self.username, self.password = base_url.rstrip("/"), username, password
        self.timeout, self.verify, self.transport = timeout, verify, transport
        self.http: httpx.AsyncClient | None = None
        self._sid: str | None = None
        self._paths: dict[str, str] = {}
        self._versions: dict[str, int] = {}
        self._control_lock = asyncio.Lock()

    async def connect(self) -> None:
        async with self._control_lock:
            await self._ensure_http()
            if not self._paths:
                await self._discover_locked()
            if self._sid is None:
                await self._login_locked()

    async def open_download(self, absolute_path: str, *, range_header: str | None, method: str) -> httpx.Response:
        await self.connect()
        sid = self._sid
        if not sid:
            raise SynologyError("Synology session is unavailable")
        try:
            return await self._open_download_once(sid, absolute_path, range_header=range_header, method=method)
        except _SynologySessionExpired:
            # Only the request that observed the old SID performs re-login.
            # Other concurrent failures reuse the replacement SID after the lock.
            await self._replace_expired_sid(sid)
            replacement = self._sid
            if not replacement:
                raise SynologyError("Synology authentication failed")
            return await self._open_download_once(replacement, absolute_path, range_header=range_header, method=method)

    async def _ensure_http(self) -> None:
        if self.http is not None and not self.http.is_closed:
            return
        if not self.verify:
            logger.warning("Synology TLS verification disabled for development")
        self.http = httpx.AsyncClient(
            timeout=httpx.Timeout(self.timeout, connect=10.0),
            follow_redirects=False,
            verify=self.verify,
            transport=self.transport,
            limits=httpx.Limits(max_keepalive_connections=20, max_connections=100),
        )

    async def _discover_locked(self) -> None:
        info = await self._request_json(
            "/webapi/query.cgi",
            {"api": "SYNO.API.Info", "version": "1", "method": "query", "query": "SYNO.API.Auth,SYNO.FileStation.List,SYNO.FileStation.Download"},
            authenticated=False,
        )
        data = info.get("data", {})
        paths: dict[str, str] = {}
        versions: dict[str, int] = {}
        for api in ("SYNO.API.Auth", "SYNO.FileStation.List", "SYNO.FileStation.Download"):
            entry = data.get(api)
            if not entry:
                raise SynologyError("Synology service is unavailable")
            path = str(entry["path"])
            paths[api] = "/webapi/" + path.lstrip("/") if not path.startswith("/webapi/") else path
            versions[api] = int(entry.get("maxVersion", 1))
        self._paths, self._versions = paths, versions

    async def _login_locked(self) -> None:
        auth = await self._request_json(
            self._paths["SYNO.API.Auth"],
            {"api": "SYNO.API.Auth", "version": str(self._versions["SYNO.API.Auth"]), "method": "login", "account": self.username, "passwd": self.password, "session": "church-platform", "format": "sid"},
            authenticated=False,
        )
        sid = auth.get("data", {}).get("sid")
        if not sid:
            raise SynologyError("Synology authentication failed")
        self._sid = str(sid)

    async def _replace_expired_sid(self, expired_sid: str) -> None:
        async with self._control_lock:
            if self._sid != expired_sid:
                return
            # Do not logout here: another Range stream may still be consuming
            # data under this SID. DSM already declared this particular request
            # session-invalid, and shutdown remains the only normal logout time.
            self._sid = None
            await self._login_locked()

    async def _open_download_once(
        self, sid: str, absolute_path: str, *, range_header: str | None, method: str,
    ) -> httpx.Response:
        if self.http is None:
            raise SynologyError("Synology connection is unavailable")
        params = {
            "api": "SYNO.FileStation.Download", "version": str(self._versions["SYNO.FileStation.Download"]),
            "method": "download", "path": json.dumps([absolute_path]), "mode": "open", "_sid": sid,
        }
        request = self.http.build_request(
            method, f"{self.base_url}{self._paths['SYNO.FileStation.Download']}", params=params,
            headers={"Range": range_header} if range_header else None,
        )
        try:
            response = await self.http.send(request, stream=True)
        except httpx.TimeoutException as exc:
            raise SynologyError("Synology download timed out") from exc
        except httpx.HTTPError as exc:
            raise SynologyError("Synology download failed") from exc
        if "json" not in response.headers.get("content-type", "").lower():
            return response
        try:
            value = json.loads((await response.aread()).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return response
        if value.get("success"):
            return response
        await response.aclose()
        self._raise_provider_error(value)

    async def _request_json(self, path: str, params: dict[str, str], *, authenticated: bool) -> dict[str, Any]:
        if self.http is None:
            raise SynologyError("Synology connection is unavailable")
        if authenticated:
            if not self._sid:
                raise SynologyError("Synology session is unavailable")
            params = {**params, "_sid": self._sid}
        try:
            response = await self.http.get(f"{self.base_url}{path}", params=params)
            response.raise_for_status()
            value = response.json()
        except httpx.HTTPError as exc:
            raise SynologyError("Synology connection failed") from exc
        finally:
            if "response" in locals():
                await response.aclose()
        if not value.get("success"):
            self._raise_provider_error(value)
        return value

    @staticmethod
    def _raise_provider_error(value: dict[str, Any]) -> None:
        raw_code = value.get("error", {}).get("code")
        code = raw_code if isinstance(raw_code, int) else None
        if code in _SESSION_EXPIRED_CODES:
            raise _SynologySessionExpired("Synology session expired", error_code=code)
        raise SynologyError("Synology request was rejected", error_code=code)

    async def close(self) -> bool:
        async with self._control_lock:
            http, sid = self.http, self._sid
            self.http, self._sid = None, None
            if http is None:
                return True
            logout_succeeded = True
            if sid and self._paths.get("SYNO.API.Auth"):
                try:
                    response = await http.get(
                        f"{self.base_url}{self._paths['SYNO.API.Auth']}",
                        params={"api": "SYNO.API.Auth", "version": str(self._versions["SYNO.API.Auth"]), "method": "logout", "session": "church-platform", "_sid": sid},
                    )
                    response.raise_for_status()
                    if not response.json().get("success"):
                        logout_succeeded = False
                except (httpx.HTTPError, ValueError):
                    logout_succeeded = False
                finally:
                    if "response" in locals():
                        await response.aclose()
            await http.aclose()
            return logout_succeeded


_shared_playback_connections: dict[bytes, _SynologyPlaybackConnection] = {}


def _connection_key(base_url: str, username: str, password: str, verify: bool, transport: object | None) -> bytes:
    # The opaque digest prevents credentials from becoming a printable cache key.
    material = "\0".join((base_url.rstrip("/"), username, password, str(verify), str(id(transport))))
    return sha256(material.encode()).digest()


async def close_shared_playback_connections() -> None:
    connections = list(_shared_playback_connections.values())
    _shared_playback_connections.clear()
    await asyncio.gather(*(connection.close() for connection in connections))


class SynologyDownloadClient:
    """Async streaming facade with optional process-local shared connection state."""

    def __init__(
        self,
        base_url: str,
        username: str,
        password: str,
        *,
        timeout: float = 30.0,
        verify: bool = True,
        transport: httpx.AsyncBaseTransport | None = None,
        shared: bool = False,
    ) -> None:
        if shared:
            key = _connection_key(base_url, username, password, verify, transport)
            connection = _shared_playback_connections.get(key)
            if connection is None:
                connection = _SynologyPlaybackConnection(
                    base_url, username, password, timeout=timeout, verify=verify, transport=transport,
                )
                _shared_playback_connections[key] = connection
            self._connection = connection
        else:
            self._connection = _SynologyPlaybackConnection(
                base_url, username, password, timeout=timeout, verify=verify, transport=transport,
            )
        self._shared = shared

    async def connect(self) -> None:
        await self._connection.connect()

    async def open_download(self, absolute_path: str, *, range_header: str | None = None, method: str = "GET") -> httpx.Response:
        return await self._connection.open_download(absolute_path, range_header=range_header, method=method)

    async def close(self) -> bool:
        # Per-range cleanup owns only the response. A shared process connection
        # is closed during application shutdown, not after each Range request.
        return True if self._shared else await self._connection.close()

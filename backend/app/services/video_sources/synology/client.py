"""Small, metadata-only wrapper around the official DSM File Station WebAPI."""
from dataclasses import dataclass
from typing import Any
import httpx


class SynologyError(Exception):
    """A deliberately non-provider-specific error safe for API responses."""


@dataclass(frozen=True)
class SynologyEntry:
    path: str
    name: str
    is_dir: bool
    size: int = 0


class SynologyFileStationClient:
    def __init__(self, base_url: str, username: str, password: str, *, timeout: float = 15.0) -> None:
        self.base_url, self.username, self.password = base_url.rstrip("/"), username, password
        self.http = httpx.Client(timeout=timeout, follow_redirects=False)
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

    def close(self) -> None:
        if self._sid and self._paths.get("SYNO.API.Auth"):
            try:
                self._request(self._paths["SYNO.API.Auth"], {"api": "SYNO.API.Auth", "version": str(self._versions["SYNO.API.Auth"]), "method": "logout", "session": "church-platform"})
            except (SynologyError, httpx.HTTPError):
                pass
        self._sid = None
        self.http.close()

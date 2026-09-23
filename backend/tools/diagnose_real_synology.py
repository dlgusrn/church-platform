#!/usr/bin/env python3
"""Read-only discovery, list, and 1 KiB Range diagnostic for Synology.

Load local settings in the invoking shell.  This script never writes to the
NAS, prints credentials/SIDs/paths, follows redirects, or disables TLS checks.
"""
from __future__ import annotations

import asyncio
import argparse
import os
import re
from pathlib import PurePosixPath
from urllib.parse import urlparse

import httpx
from app.core.config import get_settings
from app.services.video_sources.synology.client import (
    SynologyDownloadClient,
    SynologyError,
    SynologyFileStationClient,
)

_APIS = ("SYNO.API.Auth", "SYNO.FileStation.List", "SYNO.FileStation.Download")
_VIDEO_SUFFIXES = {".mp4", ".mov", ".m4v"}
_CONTENT_RANGE = re.compile(r"^bytes 0-1023/\d+$", re.IGNORECASE)


def _configured() -> tuple[str, str, str, str]:
    settings = get_settings()
    values = (
        settings.synology_base_url,
        settings.synology_username,
        settings.synology_password,
        settings.synology_video_root,
    )
    if not all(values):
        raise SystemExit("CONFIG: INCOMPLETE")
    return values  # type: ignore[return-value]


def _show_discovery(client: SynologyFileStationClient) -> bool:
    try:
        response = client._request(  # pyright: ignore[reportPrivateUsage]
            "/webapi/query.cgi",
            {
                "api": "SYNO.API.Info",
                "version": "1",
                "method": "query",
                "query": ",".join(_APIS),
            },
            authenticated=False,
        )
    except (SynologyError, httpx.HTTPError):
        print("API.INFO: FAIL")
        return False
    data = response.get("data", {})
    print("API.INFO: SUCCESS")
    complete = True
    for api in _APIS:
        entry = data.get(api)
        if not isinstance(entry, dict) or not entry.get("path"):
            print(f"{api}: NOT FOUND")
            complete = False
            continue
        # DSM API paths are safe to report; NAS host and filesystem paths are not.
        path = "/webapi/" + str(entry["path"]).lstrip("/")
        print(f"{api}: FOUND path={path} maxVersion={entry.get('maxVersion', 1)}")
    return complete


async def _range_probe(base_url: str, username: str, password: str, path: str, *, verify: bool) -> None:
    client = SynologyDownloadClient(base_url, username, password, verify=verify)
    response = None
    try:
        await client.connect()
        response = await client.open_download(path, range_header="bytes=0-1023")
        content_range = response.headers.get("content-range", "")
        print(f"HTTP_STATUS: {response.status_code}")
        print(f"CONTENT_TYPE: {'PRESENT' if 'content-type' in response.headers else 'MISSING'}")
        print(f"CONTENT_LENGTH: {'PRESENT' if 'content-length' in response.headers else 'MISSING'}")
        print(f"ACCEPT_RANGES: {'bytes' if response.headers.get('accept-ranges', '').lower() == 'bytes' else 'MISSING'}")
        print(f"CONTENT_RANGE: {'VALID' if _CONTENT_RANGE.fullmatch(content_range) else 'MISSING_OR_INVALID'}")
        if response.status_code == 200:
            print("UPSTREAM_IGNORED_RANGE: YES")
            print("REAL_NAS_RANGE_SUPPORT: NO")
            return
        # Consume no more than 1 KiB; do not read or discard a whole video.
        iterator = response.aiter_bytes(chunk_size=1024)
        await anext(iterator, b"")
        print("UPSTREAM_IGNORED_RANGE: NO")
        print(f"REAL_NAS_RANGE_SUPPORT: {'YES' if response.status_code == 206 and _CONTENT_RANGE.fullmatch(content_range) else 'NO'}")
    except SynologyError:
        print("RANGE_PROBE: FAIL")
        print("REAL_NAS_RANGE_SUPPORT: NOT TESTED")
    finally:
        if response is not None:
            await response.aclose()
        logout_succeeded = await client.close()
        print("DOWNLOAD_STREAM_CLOSED: YES")
        print("DOWNLOAD_CLIENT_CLOSED: YES")
        print(f"DOWNLOAD_LOGOUT: {'SUCCESS' if logout_succeeded else 'FAIL'}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--allow-insecure-tls",
        action="store_true",
        help="Diagnostic-only: permit an invalid HTTPS certificate for this process.",
    )
    arguments = parser.parse_args()
    if os.getenv("LOCAL_PLAYBACK_UPSTREAM_URL"):
        raise SystemExit("Refusing to run while LOCAL_PLAYBACK_UPSTREAM_URL is set")
    base_url, username, password, root = _configured()
    parsed = urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise SystemExit("CONFIG: INVALID_BASE_URL")
    print(f"TRANSPORT: {'HTTPS' if parsed.scheme == 'https' else 'PLAINTEXT'}")
    print("TLS_VERIFICATION_BYPASS: NO")
    if arguments.allow_insecure_tls:
        print("WARNING: INSECURE TLS DIAGNOSTIC MODE")
        print("TLS_VERIFICATION_BYPASS: DIAGNOSTIC_ONLY")

    sync = SynologyFileStationClient(base_url, username, password, verify=not arguments.allow_insecure_tls)
    try:
        if not _show_discovery(sync):
            return
        try:
            sync.connect()
            print("AUTH: SUCCESS")
        except (SynologyError, httpx.HTTPError):
            print("AUTH: FAIL")
            print("ERROR_CODE: NOT_EXPOSED_BY_CLIENT")
            return
        try:
            entries, _ = sync.list_directory(root, limit=100)
            print("LIST: SUCCESS")
        except (SynologyError, httpx.HTTPError):
            print("LIST: FAIL")
            return
        candidate = next(
            (entry for entry in entries if not entry.is_dir and PurePosixPath(entry.name).suffix.lower() in _VIDEO_SUFFIXES),
            None,
        )
        if candidate is None:
            print("VIDEO_CANDIDATE: NOT FOUND")
            return
        print("VIDEO_CANDIDATE: FOUND")
        asyncio.run(_range_probe(base_url, username, password, candidate.path, verify=not arguments.allow_insecure_tls))
    finally:
        logout_succeeded = sync.close()
        print("FILESTATION_CLIENT_CLOSED: YES")
        print(f"FILESTATION_LOGOUT: {'SUCCESS' if logout_succeeded else 'FAIL'}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Development-only HTTP range server for the synthetic playback fixture.

It deliberately exposes only ``/sample.mp4``.  It is not part of the API
application and never accepts an arbitrary filesystem path from a request.
"""
from __future__ import annotations

import argparse
import re
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


FIXTURE_PATH = Path(__file__).resolve().parents[1] / "tests" / "fixtures" / "sample.mp4"
CHUNK_SIZE = 64 * 1024
_SINGLE_RANGE = re.compile(r"^bytes=(\d*)-(\d*)$")


def parse_range(value: str | None, size: int) -> tuple[int, int] | None:
    """Return inclusive byte bounds; reject malformed, multi, and unsatisfiable ranges."""
    if value is None:
        return None
    match = _SINGLE_RANGE.fullmatch(value.strip())
    if match is None:
        raise ValueError("invalid range")
    start_text, end_text = match.groups()
    if not start_text and not end_text:
        raise ValueError("invalid range")
    if not start_text:
        suffix = int(end_text)
        if suffix <= 0:
            raise ValueError("invalid range")
        return max(size - suffix, 0), size - 1
    start = int(start_text)
    if start >= size:
        raise ValueError("unsatisfiable range")
    end = size - 1 if not end_text else int(end_text)
    if end < start:
        raise ValueError("invalid range")
    return start, min(end, size - 1)


class LocalVideoRangeHandler(BaseHTTPRequestHandler):
    server_version = "LocalVideoRangeServer/1.0"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._serve(include_body=True)

    def do_HEAD(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler API
        self._serve(include_body=False)

    def _serve(self, *, include_body: bool) -> None:
        if self.path.split("?", 1)[0] != "/sample.mp4":
            self.send_error(HTTPStatus.NOT_FOUND)
            return
        try:
            size = FIXTURE_PATH.stat().st_size
            byte_range = parse_range(self.headers.get("Range"), size)
        except (FileNotFoundError, ValueError):
            self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
            self.send_header("Content-Range", f"bytes */{FIXTURE_PATH.stat().st_size if FIXTURE_PATH.exists() else 0}")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if byte_range is None:
            start, end, status = 0, size - 1, HTTPStatus.OK
        else:
            start, end, status = *byte_range, HTTPStatus.PARTIAL_CONTENT
        length = end - start + 1
        self.send_response(status)
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if status is HTTPStatus.PARTIAL_CONTENT:
            self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.end_headers()
        if not include_body:
            return
        with FIXTURE_PATH.open("rb") as fixture:
            fixture.seek(start)
            remaining = length
            while remaining:
                chunk = fixture.read(min(CHUNK_SIZE, remaining))
                if not chunk:
                    break
                self.wfile.write(chunk)
                remaining -= len(chunk)

    def log_message(self, _format: str, *_args: object) -> None:
        """Keep fixture requests quiet; callers own their verification output."""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8099, type=int)
    arguments = parser.parse_args()
    if not FIXTURE_PATH.is_file():
        raise SystemExit(f"Fixture is required: {FIXTURE_PATH}")
    server = ThreadingHTTPServer((arguments.host, arguments.port), LocalVideoRangeHandler)
    print(f"Local video range server listening on http://{arguments.host}:{arguments.port}/sample.mp4")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()

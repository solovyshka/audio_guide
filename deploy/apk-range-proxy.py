#!/usr/bin/env python3
"""Serve the APK in small Range slices.

MegaFon cuts plaintext HTTP to this VPS after ~32 KiB. The installed app
asks for 4 MiB ranges; we return at most MAX bytes and a correct
Content-Range so the existing downloader continues.
"""

from __future__ import annotations

import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

APK = Path(os.environ.get("APK_PATH", "/var/www/audio-guide-app/audio_guide.apk"))
MAX = int(os.environ.get("APK_RANGE_MAX", str(16 * 1024)))
HOST = os.environ.get("APK_PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("APK_PROXY_PORT", "8098"))


def _parse_range(header: str | None, size: int) -> tuple[int, int]:
    start, end = 0, min(MAX - 1, size - 1)
    if not header or not header.startswith("bytes="):
        return start, end
    spec = header.split("=", 1)[1].split(",", 1)[0].strip()
    left, _, right = spec.partition("-")
    if left:
        start = int(left)
    if right:
        end = int(right)
    else:
        end = start + MAX - 1
    if start < 0 or start >= size:
        raise ValueError("range start")
    end = min(end, start + MAX - 1, size - 1)
    if end < start:
        raise ValueError("range end")
    return start, end


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def do_HEAD(self) -> None:
        self._send(body=False)

    def do_GET(self) -> None:
        self._send(body=True)

    def _send(self, *, body: bool) -> None:
        if not APK.is_file():
            self.send_error(404)
            return
        size = APK.stat().st_size
        if not body:
            self.send_response(200)
            self.send_header("Content-Type", "application/octet-stream")
            self.send_header("Content-Length", str(size))
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            return
        try:
            start, end = _parse_range(self.headers.get("Range"), size)
        except ValueError:
            self.send_response(416)
            self.send_header("Content-Range", f"bytes */{size}")
            self.end_headers()
            return
        length = end - start + 1
        self.send_response(206)
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Content-Length", str(length))
        self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if not body:
            return
        with APK.open("rb") as handle:
            handle.seek(start)
            self.wfile.write(handle.read(length))

    def log_message(self, format: str, *args) -> None:  # noqa: A003
        return


def main() -> None:
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()

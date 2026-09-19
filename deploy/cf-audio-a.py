#!/usr/bin/env python3
"""Point audio.solovyshka.com at OVH (DNS only). Never prints the token."""

from __future__ import annotations

import json
import os
import sys
import urllib.request
from pathlib import Path

TARGET = "51.254.219.211"
NAME = "audio.solovyshka.com"
ZONE = "solovyshka.com"


def load_env(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.is_file():
        return data
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        data[key.strip()] = value.strip().strip('"').strip("'")
    return data


def token() -> str:
    env: dict[str, str] = {}
    for path in (Path("/opt/secrets/cloudflare/.env"), Path.home() / ".cloudflare.env"):
        env.update(load_env(path))
    found = (
        os.environ.get("CLOUDFLARE_API_TOKEN")
        or os.environ.get("CF_API_TOKEN")
        or env.get("CLOUDFLARE_API_TOKEN")
        or env.get("CF_API_TOKEN")
        or env.get("API_TOKEN")
    )
    if not found:
        raise SystemExit("NO_TOKEN")
    return found


def cf(method: str, url: str, payload: dict | None, auth: str) -> dict:
    request = urllib.request.Request(url, method=method)
    request.add_header("Authorization", f"Bearer {auth}")
    request.add_header("Content-Type", "application/json")
    body = None if payload is None else json.dumps(payload).encode()
    with urllib.request.urlopen(request, data=body, timeout=20) as response:
        return json.load(response)


def main() -> None:
    auth = token()
    zones = cf("GET", f"https://api.cloudflare.com/client/v4/zones?name={ZONE}", None, auth)
    if not zones.get("success") or not zones.get("result"):
        raise SystemExit("NO_ZONE")
    zone_id = zones["result"][0]["id"]
    recs = cf(
        "GET",
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records?name={NAME}",
        None,
        auth,
    )
    records = recs.get("result") or []
    desired = {
        "type": "A",
        "name": NAME,
        "content": TARGET,
        "ttl": 60,
        "proxied": False,
    }
    if records:
        rec_id = records[0]["id"]
        out = cf(
            "PUT",
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{rec_id}",
            desired,
            auth,
        )
    else:
        out = cf(
            "POST",
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
            desired,
            auth,
        )
    result = out.get("result") or {}
    print(
        "OK" if out.get("success") else "FAIL",
        result.get("type"),
        result.get("content"),
        f"proxied={result.get('proxied')}",
    )
    if not out.get("success"):
        print("errors", out.get("errors"))
        raise SystemExit(4)


if __name__ == "__main__":
    sys.exit(main())

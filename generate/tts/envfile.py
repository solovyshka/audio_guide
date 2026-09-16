from __future__ import annotations

import os
from pathlib import Path

_LOADED = False
_ROOT = Path(__file__).resolve().parents[2]


def env_candidates() -> list[Path]:
    return [
        Path("/opt/secrets/audio_guide/.env"),
        _ROOT / "generate" / ".env",
        _ROOT / ".env",
    ]


def load_env() -> None:
    global _LOADED
    if _LOADED:
        return
    for path in env_candidates():
        try:
            readable = path.is_file() and os.access(path, os.R_OK)
        except OSError:
            continue
        if not readable:
            continue
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key and key not in os.environ:
                os.environ[key] = value
    _LOADED = True

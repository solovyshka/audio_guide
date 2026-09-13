from __future__ import annotations

import os
from pathlib import Path

_LOADED = False


def load_env() -> None:
    global _LOADED
    if _LOADED:
        return
    root = Path(__file__).resolve().parents[2]
    for path in (root / ".env", root / "generate" / ".env"):
        if not path.is_file():
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

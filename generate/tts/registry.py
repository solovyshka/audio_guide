from __future__ import annotations

from generate.tts.backends import ALL_BACKENDS
from generate.tts.base import TtsBackend


def get_backend(name: str) -> TtsBackend:
    try:
        cls = ALL_BACKENDS[name]
    except KeyError as exc:
        known = ", ".join(ALL_BACKENDS)
        raise SystemExit(f"Неизвестный движок {name!r}. Есть: {known}") from exc
    return cls()


def available() -> list[tuple[str, bool, str]]:
    rows = []
    for name, cls in ALL_BACKENDS.items():
        ok, reason = cls().available()
        rows.append((name, ok, reason))
    return rows

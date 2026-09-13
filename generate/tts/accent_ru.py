from __future__ import annotations

import sys

_accentor = None
_failed = False


def mark_stress(text: str) -> str:
    """Insert Silero '+' stress marks. No-op if silero-stress is missing."""
    accentor = _load()
    if accentor is None:
        return text
    return accentor(text)


def _load():
    global _accentor, _failed
    if _accentor is not None:
        return _accentor
    if _failed:
        return None
    try:
        from silero_stress import load_accentor

        _accentor = load_accentor(lang="ru")
    except Exception as error:
        _failed = True
        print(
            f"silero-stress недоступен, ударения ставит сама TTS: {error}",
            file=sys.stderr,
        )
        return None
    return _accentor

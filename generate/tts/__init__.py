from __future__ import annotations


def available():
    from generate.tts.registry import available as _available

    return _available()


def get_backend(name: str):
    from generate.tts.registry import get_backend as _get_backend

    return _get_backend(name)

__all__ = ["available", "get_backend"]

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Protocol


@dataclass(frozen=True)
class BackendInfo:
    name: str
    extension: str
    quality: str
    cost: str
    needs: str


class TtsBackend(Protocol):
    info: BackendInfo

    def available(self) -> tuple[bool, str]:
        """Return (ok, reason). reason is empty when ok."""

    def synthesize(self, text: str, dest: Path, *, voice: str | None = None) -> int:
        """Write audio to dest and return duration in seconds."""

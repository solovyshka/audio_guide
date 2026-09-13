from __future__ import annotations

import asyncio
from pathlib import Path

from generate.tts.audio import duration_mp3
from generate.tts.base import BackendInfo

DEFAULT_VOICE = "ru-RU-DmitryNeural"
ALT_VOICES = ("ru-RU-DmitryNeural", "ru-RU-SvetlanaNeural")
SAMPLE_VOICES = ALT_VOICES


class EdgeBackend:
    info = BackendInfo(
        name="edge",
        extension="mp3",
        quality="нейросеть Microsoft, живой экскурсионный голос",
        cost="бесплатно, нужен интернет",
        needs="пакет edge-tts",
    )

    def available(self) -> tuple[bool, str]:
        try:
            import edge_tts  # noqa: F401
        except ImportError:
            return False, "pip install edge-tts mutagen"
        return True, ""

    def synthesize(self, text: str, dest: Path, *, voice: str | None = None) -> int:
        return asyncio.run(self._synthesize(text, dest, voice or DEFAULT_VOICE))

    async def _synthesize(self, text: str, dest: Path, voice: str) -> int:
        import edge_tts

        dest.parent.mkdir(parents=True, exist_ok=True)
        communicate = edge_tts.Communicate(text, voice, rate="-8%")
        await communicate.save(str(dest))
        return duration_mp3(dest)

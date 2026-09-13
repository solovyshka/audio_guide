from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path

from generate.tts.audio import duration_wav
from generate.tts.base import BackendInfo

_SCRIPT = Path(__file__).resolve().parents[1] / "speak.ps1"
DEFAULT_VOICE = "Microsoft Irina Desktop"


class SapiBackend:
    info = BackendInfo(
        name="sapi",
        extension="wav",
        quality="встроенный Windows, сухой, уже стоит на Коломне",
        cost="бесплатно, офлайн",
        needs="Windows + голос Microsoft Irina",
    )

    def available(self) -> tuple[bool, str]:
        if sys.platform != "win32":
            return False, "только Windows"
        return True, ""

    def synthesize(self, text: str, dest: Path, *, voice: str | None = None) -> int:
        dest.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory() as tmp:
            text_file = Path(tmp) / "text.txt"
            text_file.write_text(text, encoding="utf-8")
            completed = subprocess.run(
                [
                    "powershell",
                    "-NoProfile",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(_SCRIPT),
                    "-TextFile",
                    str(text_file),
                    "-Dest",
                    str(dest),
                    "-Voice",
                    voice or DEFAULT_VOICE,
                ],
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            if completed.returncode != 0:
                raise RuntimeError(
                    completed.stderr.strip() or completed.stdout.strip() or "SAPI failed"
                )
        return duration_wav(dest)

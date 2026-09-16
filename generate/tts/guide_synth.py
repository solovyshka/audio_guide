from __future__ import annotations

import json
from pathlib import Path

from generate.tts.registry import get_backend

ROOT = Path(__file__).resolve().parents[2]


def synthesize_guide(
    guide_path: Path,
    out_dir: Path | None = None,
    *,
    backend_name: str = "silero",
    voice: str | None = None,
) -> Path:
    """Write wav/mp3 next to a guide.json and update durationSec / audioPath."""
    guide_path = guide_path.resolve()
    data = json.loads(guide_path.read_text(encoding="utf-8"))
    backend = get_backend(backend_name)
    ok, reason = backend.available()
    if not ok:
        raise RuntimeError(f"{backend_name}: {reason}")
    dest_root = (out_dir or guide_path.parent).resolve()
    audio_dir = dest_root / "audio"
    audio_dir.mkdir(parents=True, exist_ok=True)
    total = 0

    def render(item: dict, fallback_name: str) -> None:
        nonlocal total
        relative = Path(
            item.get("audioPath") or f"audio/{fallback_name}.{backend.info.extension}"
        )
        dest = audio_dir / f"{relative.stem}.{backend.info.extension}"
        seconds = backend.synthesize(item["text"], dest, voice=voice)
        item["audioPath"] = f"audio/{dest.name}"
        item["durationSec"] = seconds
        total += seconds
        print(f"{dest.name}\t{seconds}s")

    render(data["intro"], "intro")
    for stop in data["stops"]:
        render(stop, stop["id"])
    data["durationSec"] = total
    dest_root.mkdir(parents=True, exist_ok=True)
    (dest_root / "guide.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"total\t{total}s")
    print(f"wrote\t{dest_root}")
    return dest_root

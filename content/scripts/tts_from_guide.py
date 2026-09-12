"""Synthesize MP3 tracks from a guide.json package using Microsoft Edge TTS."""

from __future__ import annotations

import argparse
import asyncio
import json
from pathlib import Path

import edge_tts
from mutagen.mp3 import MP3

VOICE = "ru-RU-DmitryNeural"
RATE = "-8%"


async def synthesize(text: str, dest: Path) -> int:
    dest.parent.mkdir(parents=True, exist_ok=True)
    communicate = edge_tts.Communicate(text, VOICE, rate=RATE)
    await communicate.save(str(dest))
    duration = int(round(MP3(dest).info.length))
    return duration


async def build(guide_path: Path) -> None:
    data = json.loads(guide_path.read_text(encoding="utf-8"))
    root = guide_path.parent
    total = 0

    intro = data["intro"]
    intro_file = root / intro["audioPath"]
    intro["durationSec"] = await synthesize(intro["text"], intro_file)
    total += intro["durationSec"]
    print(f"intro\t{intro['durationSec']}s\t{intro_file.name}")

    for stop in data["stops"]:
        audio_file = root / stop["audioPath"]
        stop["durationSec"] = await synthesize(stop["text"], audio_file)
        total += stop["durationSec"]
        print(f"{stop['order']:02d}\t{stop['durationSec']}s\t{audio_file.name}")

    guide_path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    catalog_path = root.parent.parent / "catalog.json"
    if catalog_path.exists():
        catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
        for item in catalog.get("guides", []):
            if item.get("id") == data["id"]:
                item["durationSec"] = total
                item["stopsCount"] = len(data["stops"])
                item["contentVersion"] = data.get("contentVersion", 1)
        catalog_path.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    print(f"total\t{total}s")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "guide",
        nargs="?",
        default=Path(__file__).resolve().parents[1] / "guides" / "kolomna" / "guide.json",
        type=Path,
    )
    args = parser.parse_args()
    asyncio.run(build(args.guide.resolve()))


if __name__ == "__main__":
    main()

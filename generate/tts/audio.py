from __future__ import annotations

import re
import wave
from pathlib import Path


_SENTENCE = re.compile(r"(?<=[.!?…])\s+")


def duration_wav(path: Path) -> int:
    with wave.open(str(path), "rb") as handle:
        frames = handle.getnframes()
        rate = handle.getframerate()
    if rate <= 0:
        return 0
    return int(round(frames / rate))


def duration_mp3(path: Path) -> int:
    from mutagen.mp3 import MP3

    return int(round(MP3(path).info.length))


def duration_of(path: Path) -> int:
    suffix = path.suffix.lower()
    if suffix == ".wav":
        return duration_wav(path)
    if suffix == ".mp3":
        return duration_mp3(path)
    raise ValueError(f"Неизвестный формат: {path.suffix}")


def split_text(text: str, limit: int) -> list[str]:
    text = " ".join(text.split())
    if len(text) <= limit:
        return [text]
    parts: list[str] = []
    current = ""
    for sentence in _SENTENCE.split(text):
        sentence = sentence.strip()
        if not sentence:
            continue
        candidate = sentence if not current else f"{current} {sentence}"
        if len(candidate) <= limit:
            current = candidate
            continue
        if current:
            parts.append(current)
        if len(sentence) <= limit:
            current = sentence
            continue
        for start in range(0, len(sentence), limit):
            chunk = sentence[start : start + limit].strip()
            if chunk:
                parts.append(chunk)
        current = ""
    if current:
        parts.append(current)
    return parts


def concat_wavs(parts: list[Path], dest: Path) -> int:
    if not parts:
        raise ValueError("Нет кусков для склейки")
    dest.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(parts[0]), "rb") as first:
        params = first.getparams()
        frames = [first.readframes(first.getnframes())]
    for part in parts[1:]:
        with wave.open(str(part), "rb") as handle:
            if handle.getparams()[:3] != params[:3]:
                raise ValueError(f"Разный формат WAV: {part}")
            frames.append(handle.readframes(handle.getnframes()))
    with wave.open(str(dest), "wb") as out:
        out.setparams(params)
        for chunk in frames:
            out.writeframes(chunk)
    return duration_wav(dest)

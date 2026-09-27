from __future__ import annotations

import re
import wave
from dataclasses import dataclass
from pathlib import Path


_SENTENCE = re.compile(r"(?<=[.!?…])\s+")
_PARAGRAPH = re.compile(r"\s*\n+\s*")
_SOFT_BOUNDARY = re.compile(r"[;:—–,]\s+")

SENTENCE_PAUSE_MS = 320
QUESTION_PAUSE_MS = 420
ELLIPSIS_PAUSE_MS = 500
PARAGRAPH_PAUSE_MS = 700
CLAUSE_PAUSE_MS = 180


@dataclass(frozen=True)
class SpeechChunk:
    text: str
    pause_after_ms: int


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
    """Split text at speech-friendly boundaries without cutting words."""
    return [chunk.text for chunk in split_speech_text(text, limit)]


def split_speech_text(text: str, limit: int) -> list[SpeechChunk]:
    """Return semantic chunks and a deterministic pause after each chunk."""
    if limit <= 0:
        raise ValueError("Лимит текста должен быть положительным")

    paragraphs = [
        " ".join(part.split())
        for part in _PARAGRAPH.split(text.strip())
        if part.strip()
    ]
    chunks: list[SpeechChunk] = []
    for paragraph_index, paragraph in enumerate(paragraphs):
        sentences = [part.strip() for part in _SENTENCE.split(paragraph) if part.strip()]
        for sentence_index, sentence in enumerate(sentences):
            pieces = _split_long_phrase(sentence, limit)
            for piece_index, piece in enumerate(pieces):
                is_last_piece = piece_index == len(pieces) - 1
                is_last_sentence = sentence_index == len(sentences) - 1
                is_last_paragraph = paragraph_index == len(paragraphs) - 1
                if not is_last_piece:
                    pause = CLAUSE_PAUSE_MS
                elif is_last_sentence and not is_last_paragraph:
                    pause = PARAGRAPH_PAUSE_MS
                else:
                    pause = _sentence_pause(piece)
                chunks.append(SpeechChunk(piece, pause))
    return chunks


def _split_long_phrase(text: str, limit: int) -> list[str]:
    remaining = text.strip()
    parts: list[str] = []
    while len(remaining) > limit:
        window = remaining[: limit + 1]
        boundaries = [match.end() for match in _SOFT_BOUNDARY.finditer(window)]
        split_at = boundaries[-1] if boundaries else window.rfind(" ")
        if split_at <= 0:
            # A single token can legitimately exceed the model limit.
            split_at = limit
        piece = remaining[:split_at].strip()
        if piece:
            parts.append(piece)
        remaining = remaining[split_at:].strip()
    if remaining:
        parts.append(remaining)
    return parts


def _sentence_pause(text: str) -> int:
    stripped = text.rstrip()
    if stripped.endswith("…"):
        return ELLIPSIS_PAUSE_MS
    if stripped.endswith(("?", "!")):
        return QUESTION_PAUSE_MS
    return SENTENCE_PAUSE_MS


def concat_wavs(
    parts: list[Path],
    dest: Path,
    *,
    pauses_ms: list[int] | None = None,
) -> int:
    if not parts:
        raise ValueError("Нет кусков для склейки")
    if pauses_ms is None:
        pauses_ms = [0] * (len(parts) - 1)
    if len(pauses_ms) != len(parts) - 1:
        raise ValueError("Пауз должно быть на одну меньше, чем WAV-фрагментов")
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
        for index, chunk in enumerate(frames):
            out.writeframes(chunk)
            if index < len(pauses_ms):
                silence_frames = round(params.framerate * pauses_ms[index] / 1000)
                silence_bytes = silence_frames * params.nchannels * params.sampwidth
                out.writeframes(b"\x00" * silence_bytes)
    return duration_wav(dest)

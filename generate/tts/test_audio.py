from __future__ import annotations

import tempfile
import unittest
import wave
from pathlib import Path

from generate.tts.audio import (
    CLAUSE_PAUSE_MS,
    PARAGRAPH_PAUSE_MS,
    QUESTION_PAUSE_MS,
    SENTENCE_PAUSE_MS,
    concat_wavs,
    split_speech_text,
)


class SplitSpeechTextTest(unittest.TestCase):
    def test_sentences_and_paragraphs_have_different_pauses(self) -> None:
        chunks = split_speech_text(
            "Первое предложение. Второе?\n\nНовый абзац.",
            100,
        )

        self.assertEqual(
            [chunk.text for chunk in chunks],
            ["Первое предложение.", "Второе?", "Новый абзац."],
        )
        self.assertEqual(
            [chunk.pause_after_ms for chunk in chunks],
            [SENTENCE_PAUSE_MS, PARAGRAPH_PAUSE_MS, SENTENCE_PAUSE_MS],
        )

    def test_long_phrase_splits_on_punctuation_without_cutting_words(self) -> None:
        chunks = split_speech_text(
            "Очень длинная часть: один, два, три; затем продолжение и заключение.",
            40,
        )

        self.assertTrue(all(len(chunk.text) <= 40 for chunk in chunks))
        self.assertEqual(chunks[0].pause_after_ms, CLAUSE_PAUSE_MS)
        self.assertEqual(chunks[-1].pause_after_ms, SENTENCE_PAUSE_MS)
        self.assertEqual(
            " ".join(chunk.text for chunk in chunks),
            "Очень длинная часть: один, два, три; затем продолжение и заключение.",
        )

    def test_question_pause(self) -> None:
        chunks = split_speech_text("Куда мы идём?", 100)
        self.assertEqual(chunks[0].pause_after_ms, QUESTION_PAUSE_MS)


class ConcatWavsTest(unittest.TestCase):
    def test_inserts_requested_silence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            first = root / "first.wav"
            second = root / "second.wav"
            dest = root / "joined.wav"
            self._write_wav(first, frames=800)
            self._write_wav(second, frames=800)

            concat_wavs([first, second], dest, pauses_ms=[250])

            with wave.open(str(dest), "rb") as result:
                self.assertEqual(result.getnframes(), 800 + 2000 + 800)

    @staticmethod
    def _write_wav(path: Path, *, frames: int) -> None:
        with wave.open(str(path), "wb") as output:
            output.setnchannels(1)
            output.setsampwidth(2)
            output.setframerate(8000)
            output.writeframes(b"\x01\x00" * frames)


if __name__ == "__main__":
    unittest.main()

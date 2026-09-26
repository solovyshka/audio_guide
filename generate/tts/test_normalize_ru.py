from __future__ import annotations

import unittest

from generate.tts.normalize_ru import expand_for_silero


class RomanNumeralNormalizationTest(unittest.TestCase):
    def test_centuries_use_the_case_of_the_noun(self) -> None:
        self.assertEqual(expand_for_silero("XVI век"), "шестнадцатый век")
        self.assertEqual(expand_for_silero("с XIV века"), "с четырнадцатого века")
        self.assertEqual(expand_for_silero("в IX веке"), "в девятом веке")

    def test_century_range_is_spoken(self) -> None:
        self.assertEqual(
            expand_for_silero("XIV–XII веков"),
            "четырнадцатого–двенадцатого веков",
        )

    def test_regnal_number_uses_locative_after_preposition(self) -> None:
        self.assertEqual(
            expand_for_silero("при императоре Льве VI"),
            "при императоре Льве шестом",
        )

    def test_invalid_roman_sequence_is_not_rewritten(self) -> None:
        self.assertEqual(expand_for_silero("архив VX"), "архив VX")


if __name__ == "__main__":
    unittest.main()

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
            "с четырнадцатого по двенадцатый век",
        )
        self.assertEqual(
            expand_for_silero("XIV–XVI веков"),
            "с четырнадцатого по шестнадцатый век",
        )

    def test_regnal_number_uses_locative_after_preposition(self) -> None:
        self.assertEqual(
            expand_for_silero("при императоре Льве VI"),
            "при императоре Льве шестом",
        )
        self.assertEqual(
            expand_for_silero("При императоре Льве VI"),
            "При императоре Льве шестом",
        )

    def test_invalid_roman_sequence_is_not_rewritten(self) -> None:
        self.assertEqual(expand_for_silero("архив VX"), "архив VX")


class CardinalNumberNormalizationTest(unittest.TestCase):
    def test_plain_number_is_spoken(self) -> None:
        self.assertEqual(
            expand_for_silero("Маршрут длиной 7 километров."),
            "Маршрут длиной семь километров.",
        )

    def test_number_after_around_uses_genitive(self) -> None:
        self.assertEqual(
            expand_for_silero("История насчитывает около 11 тысяч лет."),
            "История насчитывает около одиннадцати тысяч лет.",
        )

    def test_grouped_population_number_is_spoken_as_one_number(self) -> None:
        self.assertEqual(
            expand_for_silero("Население — 923 381 человек."),
            "Население — девятьсот двадцать три тысячи триста восемьдесят один человек.",
        )

    def test_clock_and_hyphenated_ordinal_are_left_for_special_rules(self) -> None:
        self.assertEqual(expand_for_silero("с 09:00 до 20:00, 1-й дом"), "с 09:00 до 20:00, 1-й дом")


if __name__ == "__main__":
    unittest.main()

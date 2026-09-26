from __future__ import annotations

import re

from num2words import num2words

_MONTHS = (
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
)
_MONTH = "|".join(_MONTHS)
_YEAR = r"(?:1[0-9]{3}|20[0-9]{2})"
_RANGE = re.compile(
    rf"(?<!\d)({_YEAR})\s*[–-]\s*({_YEAR})(?:-м)?(?:\s+(годах|гг\.))?",
    re.IGNORECASE,
)
_DATE = re.compile(
    rf"(?<!\d)(\d{{1,2}})\s+({_MONTH})\s+({_YEAR})(?:\s+года)?",
    re.IGNORECASE,
)
_YEAR_CASE = re.compile(
    rf"(?<!\d)({_YEAR})(-м)?(?:\s+(года|году|годом|годах|г\.))?",
    re.IGNORECASE,
)
_ROMAN = r"[IVXLCDM]+"
_ROMAN_RANGE_CENTURY = re.compile(
    rf"(?<![A-Za-zА-Яа-яЁё])({_ROMAN})\s*([–—-])\s*({_ROMAN})"
    r"(\s+)(век|века|веков|веке)\b",
    re.IGNORECASE,
)
_ROMAN_CENTURY = re.compile(
    rf"(?<![A-Za-zА-Яа-яЁё])({_ROMAN})(\s+)(век|века|веков|веке)\b",
    re.IGNORECASE,
)
_ROMAN_AFTER_LOCATIVE_NAME = re.compile(
    rf"(\b(?:при|о|об)\s+(?:(?:императоре|короле|царе|папе)\s+)?"
    rf"[А-ЯЁ][а-яё]+)(\s+)({_ROMAN})(?![A-Za-z])"
)
_ROMAN_TOKEN = re.compile(
    rf"(?<![A-Za-z])({_ROMAN})(?![A-Za-z])",
    re.IGNORECASE,
)


def expand_for_silero(text: str) -> str:
    """Turn dates, years and Roman numerals into words for Silero only."""
    text = expand_roman_numerals(text)
    text = _RANGE.sub(_range_repl, text)
    text = _DATE.sub(_date_repl, text)
    text = _YEAR_CASE.sub(_year_repl, text)
    return text


def expand_roman_numerals(text: str) -> str:
    """Expand canonical Roman numerals without changing stored guide text."""
    text = _ROMAN_RANGE_CENTURY.sub(_roman_range_century_repl, text)
    text = _ROMAN_CENTURY.sub(_roman_century_repl, text)
    text = _ROMAN_AFTER_LOCATIVE_NAME.sub(_roman_locative_name_repl, text)
    return _ROMAN_TOKEN.sub(_roman_token_repl, text)


def _ordinal(number: int, case: str) -> str:
    words = num2words(number, lang="ru", to="ordinal")
    return _inflect(words, case)


def _inflect(phrase: str, case: str) -> str:
    if case == "nom":
        return phrase
    parts = phrase.split()
    last = parts[-1]
    special = {
        "первый": ("первого", "первом"),
        "второй": ("второго", "втором"),
        "третий": ("третьего", "третьем"),
    }
    if last in special:
        parts[-1] = special[last][0 if case == "gent" else 1]
        return " ".join(parts)
    if last.endswith(("ый", "ой", "ий")):
        stem = last[:-2]
        parts[-1] = stem + ("ого" if case == "gent" else "ом")
        return " ".join(parts)
    return phrase


def _range_repl(match: re.Match[str]) -> str:
    case = "loct" if match.group(3) else "gent"
    left = _ordinal(int(match.group(1)), case)
    right = _ordinal(int(match.group(2)), case)
    tail = " годах" if match.group(3) else ""
    return f"{left} — {right}{tail}"


def _date_repl(match: re.Match[str]) -> str:
    day = _ordinal(int(match.group(1)), "gent")
    month = match.group(2).lower()
    year = _ordinal(int(match.group(3)), "gent")
    return f"{day} {month} {year} года"


def _year_repl(match: re.Match[str]) -> str:
    year = int(match.group(1))
    em = match.group(2)
    word = (match.group(3) or "").lower()
    if em or word in {"году", "г."}:
        return f"{_ordinal(year, 'loct')} году"
    if word in {"года", "годах", "годом"}:
        return f"{_ordinal(year, 'gent')} {word}"
    return f"{_ordinal(year, 'nom')} год"


def _roman_range_century_repl(match: re.Match[str]) -> str:
    left = _roman_ordinal(match.group(1), _century_case(match.group(5)))
    right = _roman_ordinal(match.group(3), _century_case(match.group(5)))
    if not left or not right:
        return match.group(0)
    return f"{left}{match.group(2)}{right}{match.group(4)}{match.group(5)}"


def _roman_century_repl(match: re.Match[str]) -> str:
    ordinal = _roman_ordinal(match.group(1), _century_case(match.group(3)))
    if not ordinal:
        return match.group(0)
    return f"{ordinal}{match.group(2)}{match.group(3)}"


def _roman_locative_name_repl(match: re.Match[str]) -> str:
    ordinal = _roman_ordinal(match.group(3), "loct")
    if not ordinal:
        return match.group(0)
    return f"{match.group(1)}{match.group(2)}{ordinal}"


def _roman_token_repl(match: re.Match[str]) -> str:
    return _roman_ordinal(match.group(1), "nom") or match.group(0)


def _century_case(word: str) -> str:
    lowered = word.lower()
    if lowered == "веке":
        return "loct"
    if lowered in {"века", "веков"}:
        return "gent"
    return "nom"


def _roman_ordinal(token: str, case: str) -> str | None:
    value = _roman_to_int(token)
    if value is None:
        return None
    return _ordinal(value, case)


def _roman_to_int(token: str) -> int | None:
    roman = token.upper()
    values = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100, "D": 500, "M": 1000}
    total = 0
    previous = 0
    for char in reversed(roman):
        value = values[char]
        if value < previous:
            total -= value
        else:
            total += value
            previous = value
    if not 0 < total < 4000 or _int_to_roman(total) != roman:
        return None
    return total


def _int_to_roman(number: int) -> str:
    parts: list[str] = []
    for value, token in (
        (1000, "M"),
        (900, "CM"),
        (500, "D"),
        (400, "CD"),
        (100, "C"),
        (90, "XC"),
        (50, "L"),
        (40, "XL"),
        (10, "X"),
        (9, "IX"),
        (5, "V"),
        (4, "IV"),
        (1, "I"),
    ):
        count, number = divmod(number, value)
        parts.append(token * count)
    return "".join(parts)

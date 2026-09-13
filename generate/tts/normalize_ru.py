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

# Longest first so XVIII wins over XVII / XV / X.
_ROMAN = (
    "XXI|XX|XIX|XVIII|XVII|XVI|XV|XIV|XIII|XII|XI|X|"
    "IX|VIII|VII|VI|V|IV|III|II|I"
)
_CENTURY_NUM = rf"(?:{_ROMAN}|[1-9]|1[0-9]|2[01])"
# Longer endings first: otherwise «века» matches as «век» + leftover «а».
_CENTURY_WORD = r"(?:веков|веком|века|веке|веку|век|вв\.)"
# Guides often write «концу III — началу IV века».
_SOFT_RANGE_MID = r"(?:началу|концу|середине|конца|начала|середины)"
_CENTURY_SOFT_RANGE = re.compile(
    rf"(?<![A-Za-zА-Яа-яЁё])({_CENTURY_NUM})\s*[–—]\s*"
    rf"({_SOFT_RANGE_MID})\s+({_CENTURY_NUM})\s+({_CENTURY_WORD})",
    re.IGNORECASE,
)
_CENTURY_RANGE = re.compile(
    rf"(?<![A-Za-zА-Яа-яЁё])({_CENTURY_NUM})\s*[–—-]\s*"
    rf"({_CENTURY_NUM})\s+({_CENTURY_WORD})",
    re.IGNORECASE,
)
_CENTURY = re.compile(
    rf"(?<![A-Za-zА-Яа-яЁё])({_CENTURY_NUM})\s+({_CENTURY_WORD})",
    re.IGNORECASE,
)

_ROMAN_VALUES = {
    "I": 1,
    "II": 2,
    "III": 3,
    "IV": 4,
    "V": 5,
    "VI": 6,
    "VII": 7,
    "VIII": 8,
    "IX": 9,
    "X": 10,
    "XI": 11,
    "XII": 12,
    "XIII": 13,
    "XIV": 14,
    "XV": 15,
    "XVI": 16,
    "XVII": 17,
    "XVIII": 18,
    "XIX": 19,
    "XX": 20,
    "XXI": 21,
}


def expand_for_silero(text: str) -> str:
    """Turn years, centuries and calendar dates into words. Silero skips raw digits/romans."""
    text = _CENTURY_SOFT_RANGE.sub(_century_soft_range_repl, text)
    text = _CENTURY_RANGE.sub(_century_range_repl, text)
    text = _CENTURY.sub(_century_repl, text)
    text = _RANGE.sub(_range_repl, text)
    text = _DATE.sub(_date_repl, text)
    text = _YEAR_CASE.sub(_year_repl, text)
    return text


def _ordinal(number: int, case: str) -> str:
    words = num2words(number, lang="ru", to="ordinal")
    return _inflect(words, case)


def _inflect(phrase: str, case: str) -> str:
    if case == "nom":
        return phrase
    parts = phrase.split()
    last = parts[-1]
    special = {
        "первый": {
            "gent": "первого",
            "loct": "первом",
            "dat": "первому",
            "instr": "первым",
        },
        "второй": {
            "gent": "второго",
            "loct": "втором",
            "dat": "второму",
            "instr": "вторым",
        },
        "третий": {
            "gent": "третьего",
            "loct": "третьем",
            "dat": "третьему",
            "instr": "третьим",
        },
    }
    if last in special and case in special[last]:
        parts[-1] = special[last][case]
        return " ".join(parts)
    if last.endswith(("ый", "ой", "ий")):
        stem = last[:-2]
        endings = {
            "gent": "ого",
            "loct": "ом",
            "dat": "ому",
            "instr": "ым",
        }
        if case in endings:
            parts[-1] = stem + endings[case]
            return " ".join(parts)
    return phrase


def _parse_century(token: str) -> int | None:
    raw = token.strip().upper().replace("Ё", "Е")
    if raw in _ROMAN_VALUES:
        return _ROMAN_VALUES[raw]
    if raw.isdigit():
        value = int(raw)
        if 1 <= value <= 21:
            return value
    return None


def _century_case(word: str) -> str:
    word = word.lower()
    if word in {"веке"}:
        return "loct"
    if word in {"веку"}:
        return "dat"
    if word in {"веком"}:
        return "instr"
    if word in {"век"}:
        return "nom"
    # века / веков / вв.
    return "gent"


def _century_tail(word: str) -> str:
    word = word.lower()
    if word == "вв.":
        return "веков"
    return word


def _century_soft_range_repl(match: re.Match[str]) -> str:
    left = _parse_century(match.group(1))
    right = _parse_century(match.group(3))
    if left is None or right is None:
        return match.group(0)
    case = _century_case(match.group(4))
    mid = match.group(2)
    tail = _century_tail(match.group(4))
    return f"{_ordinal(left, case)} — {mid} {_ordinal(right, case)} {tail}"


def _century_range_repl(match: re.Match[str]) -> str:
    left = _parse_century(match.group(1))
    right = _parse_century(match.group(2))
    if left is None or right is None:
        return match.group(0)
    case = _century_case(match.group(3))
    tail = _century_tail(match.group(3))
    return f"{_ordinal(left, case)} — {_ordinal(right, case)} {tail}"


def _century_repl(match: re.Match[str]) -> str:
    value = _parse_century(match.group(1))
    if value is None:
        return match.group(0)
    word = match.group(2)
    case = _century_case(word)
    return f"{_ordinal(value, case)} {_century_tail(word)}"


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

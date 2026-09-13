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


def expand_for_silero(text: str) -> str:
    """Turn years and calendar dates into words. Silero skips raw digits."""
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

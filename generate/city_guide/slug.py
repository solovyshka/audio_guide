from __future__ import annotations

import re
import unicodedata


def slugify(s: str) -> str:
    s = unicodedata.normalize("NFKD", s)
    ascii_s = s.encode("ascii", "ignore").decode("ascii").lower()
    ascii_s = re.sub(r"[^a-z0-9]+", "-", ascii_s).strip("-")
    if ascii_s:
        return ascii_s
    table = str.maketrans(
        {
            "а": "a",
            "б": "b",
            "в": "v",
            "г": "g",
            "д": "d",
            "е": "e",
            "ё": "e",
            "ж": "zh",
            "з": "z",
            "и": "i",
            "й": "y",
            "к": "k",
            "л": "l",
            "м": "m",
            "н": "n",
            "о": "o",
            "п": "p",
            "р": "r",
            "с": "s",
            "т": "t",
            "у": "u",
            "ф": "f",
            "х": "h",
            "ц": "c",
            "ч": "ch",
            "ш": "sh",
            "щ": "shch",
            "ъ": "",
            "ы": "y",
            "ь": "",
            "э": "e",
            "ю": "yu",
            "я": "ya",
        }
    )
    return re.sub(r"[^a-z0-9]+", "-", s.lower().translate(table)).strip("-") or "city"


def stop_slug(name: str) -> str:
    return slugify(name)[:48] or "stop"

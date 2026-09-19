from __future__ import annotations

import re

from generate.city_guide.geo import bbox_diagonal_m, decimal_places
from generate.city_guide.schemas import CityGuide, CityResearch, QAError, QAResult

_GENERIC = {
    "музей",
    "собор",
    "церковь",
    "площадь",
    "улица",
    "памятник",
    "здание",
    "сквер",
    "парк",
    "театр",
    "проспект",
    "переулок",
    "башня",
    "дом",
    "усадьба",
    "монастырь",
    "храм",
}


def sentence_count(text: str) -> int:
    protected = re.sub(r"(?<=\b[A-ZА-ЯЁ])\.", "•", text)
    protected = re.sub(
        r"\b(?:в|г|ул|пр|н|тыс|кв|д)\.",
        lambda match: match.group(0)[:-1] + "•",
        protected,
        flags=re.IGNORECASE,
    )
    parts = [x for x in re.split(r"(?<=[.!?…])\s+", protected.strip()) if x]
    return len(parts)


def local_checks(research: CityResearch, guide: CityGuide) -> QAResult:
    errors: list[QAError] = []

    if len(research.stops) != len(guide.stops):
        errors.append(
            QAError(
                type="stop_count",
                description=(
                    f"Остановок в research {len(research.stops)}, "
                    f"в guide {len(guide.stops)}"
                ),
            )
        )

    seen_ids: set[str] = set()
    for i, stop in enumerate(guide.stops):
        expected_order = i + 1
        if stop.order != expected_order:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="order",
                    description=f"Ожидался order={expected_order}, получен {stop.order}",
                )
            )
        if stop.id in seen_ids:
            errors.append(
                QAError(stop_id=stop.id, type="duplicate_id", description="Повтор id")
            )
        seen_ids.add(stop.id)
        if not stop.audioPath:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="audioPath",
                    description="Пустой audioPath",
                )
            )

        if i >= len(research.stops):
            continue
        src = research.stops[i]
        if stop.name != src.name:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="name",
                    description=f"Имя «{stop.name}» ≠ research «{src.name}»",
                )
            )
        if (
            abs(stop.lat - src.coordinates.lat) > 1e-5
            or abs(stop.lon - src.coordinates.lon) > 1e-5
        ):
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="coordinates",
                    description="Изменены координаты относительно research",
                )
            )
        if stop.category != src.category:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="category",
                    description="Изменена category",
                )
            )

        tokens = [
            w.lower()
            for w in re.findall(r"[A-Za-zА-Яа-яЁё-]{5,}", src.name)
            if w.lower() not in _GENERIC
        ]
        hay = stop.text.lower()
        if tokens and not any(token in hay for token in tokens):
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="wrong_object",
                    description=(
                        f"Текст не про «{src.name}»: нет маркеров {', '.join(tokens[:3])}"
                    ),
                )
            )

        n = sentence_count(stop.text)
        if not 4 <= n <= 7:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="sentence_count",
                    description=f"{n} предложений вместо 4–7",
                )
            )
        # Soft band around writer target 450–800; allow disputed tails.
        if not 400 <= len(stop.text) <= 1100:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="length",
                    description=f"{len(stop.text)} знаков; целевой диапазон ~450–800",
                )
            )
        if src.disputed and "неизвестно" not in stop.text.lower():
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="disputed",
                    description="В research есть disputed, в тексте нет «неизвестно»",
                )
            )

        if decimal_places(stop.lat) < 3 or decimal_places(stop.lon) < 3:
            errors.append(
                QAError(
                    stop_id=stop.id,
                    type="coarse_coordinates",
                    description=(
                        f"Слишком грубые координаты {stop.lat}, {stop.lon} "
                        "— похоже на выдуманный центр, а не точку объекта"
                    ),
                )
            )

    points = [src.coordinates for src in research.stops]
    if len(points) >= 12:
        span = bbox_diagonal_m(points)
        if span < 1200:
            errors.append(
                QAError(
                    type="coords_clustered",
                    description=(
                        f"Все {len(points)} точек в квадрате {span:.0f} м. "
                        "Для длинного маршрута координаты, скорее всего, свалили "
                        "в одну кучу у выдуманного центра"
                    ),
                )
            )

    if not guide.intro.audioPath:
        errors.append(
            QAError(type="intro_audioPath", description="Пустой intro.audioPath")
        )
    intro_len = len(guide.intro.text)
    if not 600 <= intro_len <= 1600:
        errors.append(
            QAError(
                type="intro_length",
                description=f"Intro {intro_len} знаков; цель ~700–1200",
            )
        )

    return QAResult(valid=not errors, errors=errors)

from __future__ import annotations

import re

from generate.city_guide.schemas import CityGuide, CityResearch, QAError, QAResult


def sentence_count(text: str) -> int:
    parts = [x for x in re.split(r"(?<=[.!?…])\s+", text.strip()) if x]
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

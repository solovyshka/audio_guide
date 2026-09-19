from __future__ import annotations

from dataclasses import dataclass

from generate.city_guide.slug import slugify

SHORT = "short"
LONG = "long"


@dataclass(frozen=True)
class LengthProfile:
    key: str
    label: str
    id_suffix: str
    min_stops: int
    max_stops: int
    min_sentences: int
    max_sentences: int
    min_stop_chars: int
    max_stop_chars: int
    min_intro: int
    max_intro: int
    duration_hint: str
    research_block: str
    writer_block: str


PROFILES = {
    SHORT: LengthProfile(
        key=SHORT,
        label="короткий",
        id_suffix="",
        min_stops=6,
        max_stops=8,
        min_sentences=4,
        max_sentences=6,
        min_stop_chars=400,
        max_stop_chars=700,
        min_intro=600,
        max_intro=1000,
        duration_hint="40–70 минут пешком",
        research_block="""
Формат гида: КОРОТКИЙ.
Выбери строго 6–8 остановок — только ядро исторического центра.
Один пеший маршрут на 40–70 минут, без окраин, без второй петли
и без точек, до которых «лучше доехать отдельно».
Если объект спорный или далеко — пропусти его, не растягивай маршрут.
""".strip(),
        writer_block="""
Формат гида: КОРОТКИЙ.
Это сжатый маршрут: 6–8 точек, на слух около часа.
На остановку: 4–6 предложений, примерно 400–700 знаков.
Intro: 600–1000 знаков — зачем этот короткий круг и сколько точек.
Не раздувай текст «для полноты»: одна опора из фактов, одно действие, дальше.
""".strip(),
    ),
    LONG: LengthProfile(
        key=LONG,
        label="длинный",
        id_suffix="-long",
        min_stops=15,
        max_stops=30,
        min_sentences=5,
        max_sentences=7,
        min_stop_chars=500,
        max_stop_chars=900,
        min_intro=900,
        max_intro=1500,
        duration_hint="3–6 часов",
        research_block="""
Формат гида: ДЛИННЫЙ.
Выбери строго 15–30 остановок на маршрут 3–6 часов.
Для небольшого исторического города бери 15–20 точек, не добивай
маршрут слабыми объектами. Для крупного — ближе к 20–30.
Ядро центра обязательно, плюс соседние кварталы, набережные, монастыри
или отдельные ансамбли, если они помогают рассказать город.
Каждая остановка — один объект. Парк, монастырь, церковь, площадь
нельзя сливать в одну точку, даже если они рядом.
1–2 точки могут быть чуть в стороне — явно отметь это в порядке маршрута.
Не повторяй одно и то же место дважды под разными именами.
""".strip(),
        writer_block="""
Формат гида: ДЛИННЫЙ.
Это развёрнутый маршрут: 15–30 точек, на слух 3–6 часов.
На остановку: 5–7 предложений, примерно 500–900 знаков.
Intro: 900–1500 знаков — картина города, зачем длинный круг,
какие 1–2 точки удобнее дойти или доехать отдельно.
Каждая точка строго про свой объект из research той же позиции:
текст остановки N только про research.stops[N], без сдвига абзацев.
Не пересказывай всю историю города на одной точке.
""".strip(),
    ),
}


def parse_length(value: str | None) -> str:
    raw = (value or SHORT).strip().lower()
    if raw in {LONG, "длинный", "длинная", "full"}:
        return LONG
    if raw in {SHORT, "короткий", "короткая", "compact"}:
        return SHORT
    raise ValueError("length: short или long")


def profile(length: str | None) -> LengthProfile:
    return PROFILES[parse_length(length)]


def guide_id_for(city: str, length: str | None) -> str:
    base = slugify(city)
    extra = profile(length).id_suffix
    return f"{base}{extra}" if extra else base


def length_from_id(guide_id: str) -> str:
    return LONG if guide_id.endswith("-long") else SHORT

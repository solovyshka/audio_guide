from __future__ import annotations

import json
import os
from pathlib import Path

from generate.city_guide.checks import local_checks
from generate.city_guide.package import dump, save_json, write_package
from generate.city_guide.prompts import (
    FIX_SYSTEM,
    QA_SYSTEM,
    RESEARCH_SYSTEM,
    WRITER_SYSTEM,
)
from generate.city_guide.schemas import CityGuide, CityResearch, QAResult
from generate.city_guide.slug import slugify

SHORT_MIN_STOPS = int(os.getenv("SHORT_MIN_STOPS", "8"))
SHORT_MAX_STOPS = int(os.getenv("SHORT_MAX_STOPS", "15"))
LONG_MIN_STOPS = int(os.getenv("LONG_MIN_STOPS", "15"))
LONG_MAX_STOPS = int(os.getenv("LONG_MAX_STOPS", "30"))
QA_RETRIES = int(os.getenv("QA_RETRIES", "2"))
MODEL = os.getenv("OPENAI_MODEL", "gpt-5.6-terra")
QA_MODEL = os.getenv("OPENAI_QA_MODEL", MODEL)

COORD_ARBITRATE_SYSTEM = """
Ты проверяешь координаты остановки аудиогида.
Тебе дают координаты из research (возможно от LLM) и кандидат из OpenStreetMap.
Ответь structured JSON:
- confident=true — исходные research-координаты верны (или ближе к реальному объекту),
  OSM-кандидат ошибочный/другой объект; менять не нужно.
- confident=false — research, скорее всего, ошибся; разумнее принять OSM.
Кратко обоснуй на русском. Не выдумывай факты вне данных запроса.
""".strip()



def _client():
    from openai import OpenAI

    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError("Не задан OPENAI_API_KEY (generate/.env или окружение)")
    return OpenAI()


def parse(client, model, system, user, schema, web=False):
    kwargs = {
        "model": model,
        "input": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "text_format": schema,
    }
    if web:
        kwargs["tools"] = [{"type": "web_search", "search_context_size": "high"}]
    r = client.responses.parse(**kwargs)
    if r.output_parsed is None:
        raise RuntimeError(f"No structured output; response={getattr(r, 'id', 'unknown')}")
    return r.output_parsed


def _variant_config(variant: str) -> tuple[int, int, str]:
    if variant == "long":
        return (
            LONG_MIN_STOPS,
            LONG_MAX_STOPS,
            (
                "Это длинный маршрут на несколько часов. Собери несколько "
                "логичных пеших кластеров и добавляй переезды только там, "
                "где без них маршрут был бы неразумным."
            ),
        )
    return (
        SHORT_MIN_STOPS,
        SHORT_MAX_STOPS,
        "Это короткий маршрут: предпочитай один компактный пеший кластер.",
    )


def research_city(client, city: str, *, variant: str = "short") -> CityResearch:
    min_stops, max_stops, route_instruction = _variant_config(variant)
    prompt = f"""
Исследуй город: {city}

Нужно {min_stops}–{max_stops} остановок для одного логичного маршрута.
{route_instruction}
Выбирай площади, исторические здания, храмы, памятники, музеи, набережные,
улицы и другие объекты, если они помогают рассказать историю города.

Не пиши аудиотексты. Нужны только факты, координаты, disputed и источники.
"""
    return parse(client, MODEL, RESEARCH_SYSTEM, prompt, CityResearch, web=True)


def arbitrate_coords(client, stop, osm_hit, distance_m: float) -> "CoordArbitration":
    from generate.city_guide.schemas import CoordArbitration

    prompt = f"""
Остановка: {stop.name}
Категория: {stop.category}
Адрес research: {stop.address or "—"}
Координаты research: lat={stop.coordinates.lat}, lon={stop.coordinates.lon}
Кандидат OSM: lat={osm_hit.lat}, lon={osm_hit.lon}
OSM display_name: {osm_hit.display_name}
Расстояние: {distance_m:.0f} м
"""
    return parse(client, QA_MODEL, COORD_ARBITRATE_SYSTEM, prompt, CoordArbitration)


def verify_and_maybe_fix_coords(client, research: CityResearch, *, apply: bool = True):
    from generate.city_guide.osm import DEFAULT_THRESHOLD_M, verify_research_coords

    def _arb(stop, hit, distance_m):
        return arbitrate_coords(client, stop, hit, distance_m)

    return verify_research_coords(
        research,
        threshold_m=DEFAULT_THRESHOLD_M,
        arbitrate=_arb,
        apply=apply,
    )


def write_guide(client, research: CityResearch, *, package_id: str, variant: str) -> CityGuide:
    payload = json.dumps(dump(research), ensure_ascii=False, indent=2)
    prompt = f"""
Вот проверенная исследовательская база:

{payload}

Создай конечный CityGuide.
Количество и порядок остановок должны совпадать с research.
id гида должен быть строго `{package_id}`.
Вариант маршрута: `{variant}`. Для long отрази во вступлении пешие кластеры
и отдельные переезды из `next_leg`, если они есть.
title должен быть строго «{research.city} — {'длинный маршрут' if variant == 'long' else 'короткий маршрут'}».
id остановки — стабильный ASCII slug от названия.
lat/lon/name/category/order возьми из research (не меняй).
contentVersion=1, language="ru".
audioPath и durationSec можно оставить пустыми/0 — пайплайн проставит.
Спорное из disputed — в тексте с «— неизвестно».
"""
    return parse(client, MODEL, WRITER_SYSTEM, prompt, CityGuide)


def qa(client, research: CityResearch, guide: CityGuide) -> QAResult:
    payload = json.dumps(
        {"research": dump(research), "guide": dump(guide)},
        ensure_ascii=False,
        indent=2,
    )
    remote = parse(client, QA_MODEL, QA_SYSTEM, payload, QAResult)
    local = local_checks(research, guide)
    return QAResult(
        valid=remote.valid and local.valid,
        errors=remote.errors + local.errors,
    )


def fix(client, research: CityResearch, guide: CityGuide, result: QAResult) -> CityGuide:
    payload = json.dumps(
        {
            "research": dump(research),
            "guide": dump(guide),
            "qa": dump(result),
        },
        ensure_ascii=False,
        indent=2,
    )
    return parse(client, MODEL, FIX_SYSTEM, payload, CityGuide)


def run_api_city(
    city: str, *, variant: str = "short", update_catalog: bool = True
) -> Path:
    client = _client()
    city_id = slugify(city)
    package_id = f"{city_id}-long" if variant == "long" else city_id
    print(f"[1/5] Web research ({variant}): {city}")
    research = research_city(client, city, variant=variant)

    print("[2/5] Сверка координат с OSM")
    research, osm_checks = verify_and_maybe_fix_coords(client, research, apply=True)
    applied = sum(1 for c in osm_checks if c.applied)
    kept = sum(1 for c in osm_checks if c.status == "mismatch_kept")
    print(f"OSM: applied={applied}, kept_llm={kept}, total={len(osm_checks)}")

    print("[3/5] Генерация аудиогида")
    guide = write_guide(client, research, package_id=package_id, variant=variant)

    for attempt in range(QA_RETRIES + 1):
        print(f"[4/5] QA, попытка {attempt + 1}")
        # Normalize paths before local length/audio checks inside qa
        from generate.city_guide.package import normalize_guide

        guide = normalize_guide(
            research,
            guide,
            package_id=package_id,
            variant=variant,
        )
        result = qa(client, research, guide)
        if result.valid:
            print("QA OK")
            break
        if attempt == QA_RETRIES:
            raise RuntimeError(json.dumps(dump(result), ensure_ascii=False, indent=2))
        guide = fix(client, research, guide, result)

    guide = normalize_guide(
        research,
        guide,
        package_id=package_id,
        variant=variant,
    )
    final = local_checks(research, guide)
    if not final.valid:
        raise RuntimeError(
            "Финальная локальная проверка не пройдена:\n"
            + json.dumps(dump(final), ensure_ascii=False, indent=2)
        )

    print("[5/5] Сохраняю пакет")
    folder = write_package(
        research,
        guide,
        update_catalog=update_catalog,
        package_id=package_id,
        variant=variant,
    )
    from generate.city_guide.osm import DEFAULT_THRESHOLD_M, report_payload

    save_json(
        report_payload(research, osm_checks, threshold_m=DEFAULT_THRESHOLD_M),
        folder / f"{package_id}.osm-report.json",
    )
    # also stash under generate/out for convenience
    out = Path(__file__).resolve().parents[1] / "out" / package_id
    out.mkdir(parents=True, exist_ok=True)
    save_json(research, out / f"{package_id}.research.json")
    save_json(guide, out / "guide.json")
    print(f"Готово: {folder / 'guide.json'}")
    print(f"Остановок: {len(guide.stops)}")
    return folder

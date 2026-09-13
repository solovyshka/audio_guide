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

MIN_STOPS = int(os.getenv("MIN_STOPS", "8"))
MAX_STOPS = int(os.getenv("MAX_STOPS", "15"))
QA_RETRIES = int(os.getenv("QA_RETRIES", "2"))
MODEL = os.getenv("OPENAI_MODEL", "gpt-5.6-terra")
QA_MODEL = os.getenv("OPENAI_QA_MODEL", MODEL)


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


def research_city(client, city: str) -> CityResearch:
    prompt = f"""
Исследуй город: {city}

Нужно {MIN_STOPS}–{MAX_STOPS} остановок для одного логичного маршрута.
Выбирай площади, исторические здания, храмы, памятники, музеи, набережные,
улицы и другие объекты, если они помогают рассказать историю города.

Не пиши аудиотексты. Нужны только факты, координаты, disputed и источники.
"""
    return parse(client, MODEL, RESEARCH_SYSTEM, prompt, CityResearch, web=True)


def write_guide(client, research: CityResearch) -> CityGuide:
    payload = json.dumps(dump(research), ensure_ascii=False, indent=2)
    prompt = f"""
Вот проверенная исследовательская база:

{payload}

Создай конечный CityGuide.
Количество и порядок остановок должны совпадать с research.
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


def run_api_city(city: str, *, update_catalog: bool = True) -> Path:
    client = _client()
    city_id = slugify(city)
    print(f"[1/4] Web research: {city}")
    research = research_city(client, city)

    print("[2/4] Генерация аудиогида")
    guide = write_guide(client, research)

    for attempt in range(QA_RETRIES + 1):
        print(f"[3/4] QA, попытка {attempt + 1}")
        # Normalize paths before local length/audio checks inside qa
        from generate.city_guide.package import normalize_guide

        guide = normalize_guide(research, guide)
        result = qa(client, research, guide)
        if result.valid:
            print("QA OK")
            break
        if attempt == QA_RETRIES:
            raise RuntimeError(json.dumps(dump(result), ensure_ascii=False, indent=2))
        guide = fix(client, research, guide, result)

    guide = normalize_guide(research, guide)
    final = local_checks(research, guide)
    if not final.valid:
        raise RuntimeError(
            "Финальная локальная проверка не пройдена:\n"
            + json.dumps(dump(final), ensure_ascii=False, indent=2)
        )

    print("[4/4] Сохраняю пакет")
    folder = write_package(research, guide, update_catalog=update_catalog)
    # also stash under generate/out for convenience
    out = Path(__file__).resolve().parents[1] / "out" / city_id
    out.mkdir(parents=True, exist_ok=True)
    save_json(research, out / f"{city_id}.research.json")
    save_json(guide, out / "guide.json")
    print(f"Готово: {folder / 'guide.json'}")
    print(f"Остановок: {len(guide.stops)}")
    return folder

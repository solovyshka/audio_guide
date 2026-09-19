from __future__ import annotations

import json
import os
from pathlib import Path
from typing import List

from pydantic import Field

from generate.city_guide.checks import local_checks
from generate.city_guide.package import dump, load_guide, save_json, upsert_catalog, write_package
from generate.city_guide.length import guide_id_for, parse_length, profile
from generate.city_guide.prompts import (
    fix_system,
    qa_system,
    research_system,
    writer_system,
)
from generate.city_guide.schemas import (
    CityGuide,
    CityResearch,
    GuideStop,
    Intro,
    QAResult,
    StopResearch,
    Strict,
)
from generate.city_guide.slug import stop_slug

QA_RETRIES = int(os.getenv("QA_RETRIES", "4"))
MODEL = os.getenv("OPENAI_MODEL", "gpt-4.1")
QA_MODEL = os.getenv("OPENAI_QA_MODEL", MODEL)

_MODELS: dict[str, tuple[type[CityResearch], type[CityGuide]]] = {}


def _models(length: str) -> tuple[type[CityResearch], type[CityGuide]]:
    key = parse_length(length)
    cached = _MODELS.get(key)
    if cached:
        return cached
    spec = profile(key)

    class Research(CityResearch):
        stops: List[StopResearch] = Field(
            min_length=spec.min_stops,
            max_length=spec.max_stops,
        )

    class Guide(CityGuide):
        stops: List[GuideStop] = Field(
            min_length=spec.min_stops,
            max_length=spec.max_stops,
        )

    Research.__name__ = f"CityResearch_{key}"
    Guide.__name__ = f"CityGuide_{key}"
    _MODELS[key] = (Research, Guide)
    return Research, Guide


class _StopText(Strict):
    text: str


class _IntroText(Strict):
    title: str
    text: str


def _client():
    from openai import OpenAI

    if not os.getenv("OPENAI_API_KEY"):
        raise RuntimeError(
            "Не задан OPENAI_API_KEY (generate/.env или /opt/secrets/audio_guide/.env)"
        )
    timeout = float(os.getenv("OPENAI_TIMEOUT", "600"))
    return OpenAI(timeout=timeout)


def _require_openai_network() -> None:
    from urllib.error import HTTPError, URLError
    from urllib.request import ProxyHandler, Request, build_opener, urlopen

    req = Request("https://api.openai.com/v1/models", method="GET")
    proxy = os.getenv("HTTPS_PROXY") or os.getenv("HTTP_PROXY")
    try:
        if proxy:
            opener = build_opener(ProxyHandler({"http": proxy, "https": proxy}))
            opener.open(req, timeout=12)
        else:
            urlopen(req, timeout=8)
    except HTTPError:
        return
    except URLError as error:
        raise RuntimeError(
            "api.openai.com недоступен. Нужен HTTP-прокси на OVH "
            "(ovh-telegram-proxy, HTTPS_PROXY=http://127.0.0.1:8888)."
        ) from error


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


def research_city(client, city: str, length: str = "short") -> CityResearch:
    spec = profile(length)
    research_model, _ = _models(length)
    prompt = f"""
Исследуй город: {city}

{spec.research_block}

Не пиши аудиотексты. Нужны только факты, координаты, disputed и источники.
"""
    return parse(client, MODEL, research_system(length), prompt, research_model, web=True)


def _next_line(names: list[str], index: int) -> str:
    if index + 1 >= len(names):
        return "Это последняя точка: маршрут здесь заканчивается."
    return f"Последняя фраза ведёт только к следующей точке: {names[index + 1]}."


def _write_stop_text(
    client,
    src: StopResearch,
    *,
    length: str,
    ending: str,
    notes: list[str] | None = None,
) -> str:
    spec = profile(length)
    extra = ""
    if notes:
        extra = f"\nЗамечания QA: {json.dumps(notes, ensure_ascii=False)}\n"
    prompt = f"""
Перепиши ТОЛЬКО текст этой остановки.

{spec.writer_block}

Объект: {src.name}
Категория: {src.category}
Факты: {json.dumps(src.facts, ensure_ascii=False)}
Даты: {json.dumps(src.dates, ensure_ascii=False)}
Люди: {json.dumps(src.people, ensure_ascii=False)}
Легенды: {json.dumps(src.legends, ensure_ascii=False)}
Disputed: {json.dumps(src.disputed, ensure_ascii=False)}
{extra}
Текст должен быть про «{src.name}», не про соседние здания.
{spec.min_sentences}–{spec.max_sentences} предложений, примерно {spec.min_stop_chars}–{spec.max_stop_chars} знаков.
{ending}
Спорное пометь «— неизвестно».
"""
    return parse(client, MODEL, writer_system(length), prompt, _StopText).text


def _write_guide_by_stops(
    client, research: CityResearch, length: str
) -> CityGuide:
    spec = profile(length)
    names = [item.name for item in research.stops]
    route = "; ".join(f"{i + 1}. {name}" for i, name in enumerate(names))
    print(f"пишу intro ({len(research.stops)} точек)")
    intro = parse(
        client,
        MODEL,
        writer_system(length),
        f"""
Город: {research.city}
Подзаголовок: {research.subtitle}
Маршрут: {route}

{spec.writer_block}

Напиши только intro: title и text.
{spec.min_intro}–{spec.max_intro} знаков.
Не описывай каждую точку подробно — зачем этот длинный круг и сколько остановок.
Не выдумывай факты вне research.
""",
        _IntroText,
    )
    stops: list[GuideStop] = []
    for index, src in enumerate(research.stops):
        print(f"пишу остановку {index + 1}/{len(research.stops)}: {src.name}")
        text = _write_stop_text(
            client,
            src,
            length=length,
            ending=_next_line(names, index),
        )
        stops.append(
            GuideStop(
                id=stop_slug(src.name),
                name=src.name,
                lat=src.coordinates.lat,
                lon=src.coordinates.lon,
                category=src.category,
                order=index + 1,
                text=text,
            )
        )
    return CityGuide(
        id=guide_id_for(research.city, length),
        contentVersion=1,
        title=f"{research.city} · длинный",
        subtitle=research.subtitle,
        city=research.city,
        region=research.region,
        language="ru",
        center=research.center,
        aliases=list(research.aliases or []),
        intro=Intro(title=intro.title, text=intro.text),
        stops=stops,
    )


def write_guide(client, research: CityResearch, length: str = "short") -> CityGuide:
    spec = profile(length)
    if spec.key == "long":
        return _write_guide_by_stops(client, research, length)
    _, guide_model = _models(length)
    payload = json.dumps(dump(research), ensure_ascii=False, indent=2)
    prompt = f"""
Вот проверенная исследовательская база:

{payload}

{spec.writer_block}

Создай конечный CityGuide.
Количество и порядок остановок должны совпадать с research.
id остановки — стабильный ASCII slug от названия.
lat/lon/name/category/order возьми из research (не меняй).
contentVersion=1, language="ru".
audioPath и durationSec можно оставить пустыми/0 — пайплайн проставит.
Спорное из disputed — в тексте с «— неизвестно».
"""
    return parse(client, MODEL, writer_system(length), prompt, guide_model)


_NIT = (
    "не существенн",
    "несущественн",
    "не критич",
    "формулировк",
    "парафраз",
)


def _blocking_remote(error) -> bool:
    text = error.description.lower()
    if any(hint in text for hint in _NIT):
        return False
    if error.type in {"style", "naming", "wording", "nit"}:
        return False
    return True


def qa(client, research: CityResearch, guide: CityGuide, length: str = "short") -> QAResult:
    payload = json.dumps(
        {"research": dump(research), "guide": dump(guide)},
        ensure_ascii=False,
        indent=2,
    )
    remote = parse(client, QA_MODEL, qa_system(length), payload, QAResult)
    remote_errors = [item for item in remote.errors if _blocking_remote(item)]
    local = local_checks(research, guide)
    return QAResult(
        valid=local.valid and not remote_errors,
        errors=remote_errors + local.errors,
    )


def fix(
    client,
    research: CityResearch,
    guide: CityGuide,
    result: QAResult,
    length: str = "short",
) -> CityGuide:
    _, guide_model = _models(length)
    payload = json.dumps(
        {
            "research": dump(research),
            "guide": dump(guide),
            "qa": dump(result),
        },
        ensure_ascii=False,
        indent=2,
    )
    return parse(client, MODEL, fix_system(length), payload, guide_model)


def _qa_summary(result: QAResult) -> str:
    parts: list[str] = []
    for error in result.errors[:5]:
        loc = error.stop_id or "гид"
        parts.append(f"{loc}: {error.description}")
    extra = len(result.errors) - 5
    text = "; ".join(parts) or "неизвестная ошибка QA"
    if extra > 0:
        text += f" (+ ещё {extra})"
    return text


def _print_qa(result: QAResult) -> None:
    for error in result.errors:
        loc = error.stop_id or "-"
        print(f"QA_FAIL {error.type} {loc}: {error.description}")


def _save_draft(city_id: str, research: CityResearch, guide: CityGuide) -> None:
    out = Path(__file__).resolve().parents[1] / "out" / city_id
    out.mkdir(parents=True, exist_ok=True)
    save_json(research, out / f"{city_id}.research.json")
    save_json(guide, out / "guide.draft.json")
    print(f"черновик: {out / 'guide.draft.json'}")


def _stamp(research: CityResearch, guide: CityGuide, length: str) -> CityGuide:
    spec = profile(length)
    city_id = guide_id_for(research.city, length)
    title = research.city if spec.key == "short" else f"{research.city} · длинный"
    aliases = list(
        dict.fromkeys(
            [
                *(guide.aliases or []),
                *(research.aliases or []),
                research.city,
                f"{research.city} {spec.label}",
            ]
        )
    )
    return guide.model_copy(update={"id": city_id, "title": title, "aliases": aliases})


def rewrite_stop(
    client,
    research: CityResearch,
    guide: CityGuide,
    stop: GuideStop,
    notes: list[str],
    length: str = "short",
) -> GuideStop:
    idx = next((i for i, item in enumerate(guide.stops) if item.id == stop.id), None)
    if idx is None or idx >= len(research.stops):
        return stop
    text = _write_stop_text(
        client,
        research.stops[idx],
        length=length,
        ending=_next_line([item.name for item in research.stops], idx),
        notes=notes,
    )
    return stop.model_copy(update={"text": text})


def _rewrite_flagged(
    client,
    research: CityResearch,
    guide: CityGuide,
    result: QAResult,
    length: str = "short",
) -> CityGuide:
    notes: dict[str, list[str]] = {}
    for error in result.errors:
        if not error.stop_id:
            continue
        notes.setdefault(error.stop_id, []).append(error.description)
    stops = []
    for stop in guide.stops:
        if stop.id in notes:
            print(f"переписываю остановку {stop.id}")
            stops.append(
                rewrite_stop(client, research, guide, stop, notes[stop.id], length)
            )
        else:
            stops.append(stop)
    return guide.model_copy(update={"stops": stops})


def run_api_city(
    city: str,
    *,
    length: str = "short",
    update_catalog: bool = True,
    tts: bool = True,
    tts_backend: str = "silero",
    tts_voice: str = "xenia",
) -> Path:
    length = parse_length(length)
    spec = profile(length)
    _require_openai_network()
    client = _client()
    city_id = guide_id_for(city, length)
    print(f"[1/5] Web research: {city} ({spec.label})")
    research = research_city(client, city, length)
    from generate.city_guide.geo import snap_research_coords

    print("уточняю координаты по OSM")
    research = snap_research_coords(research)

    print(f"[2/5] Сборка {spec.label} текста")
    guide = _stamp(research, write_guide(client, research, length), length)

    from generate.city_guide.package import normalize_guide

    result = QAResult(valid=False, errors=[])
    for attempt in range(QA_RETRIES + 1):
        print(f"[3/5] QA, попытка {attempt + 1}")
        guide = _stamp(research, normalize_guide(research, guide), length)
        result = qa(client, research, guide, length)
        if result.valid:
            print("QA OK")
            break
        _print_qa(result)
        if attempt == QA_RETRIES:
            print("точечная перепись замечаний")
            guide = _stamp(
                research,
                _rewrite_flagged(client, research, guide, result, length),
                length,
            )
            guide = _stamp(research, normalize_guide(research, guide), length)
            result = qa(client, research, guide, length)
            if result.valid:
                print("QA OK")
                break
            _print_qa(result)
            local = local_checks(research, guide)
            if local.valid:
                print("QA remote замечания пропущены, локальная проверка OK")
                break
            _save_draft(city_id, research, guide)
            raise RuntimeError(f"QA не пропустил текст: {_qa_summary(result)}")
        if spec.key == "long" or attempt >= 2:
            guide = _stamp(
                research,
                _rewrite_flagged(client, research, guide, result, length),
                length,
            )
        else:
            guide = _stamp(
                research, fix(client, research, guide, result, length), length
            )

    guide = _stamp(research, normalize_guide(research, guide), length)
    final = local_checks(research, guide)
    if not final.valid:
        _save_draft(city_id, research, guide)
        raise RuntimeError(f"Локальная проверка: {_qa_summary(final)}")

    print("[4/5] Сохраняю пакет")
    folder = write_package(research, guide, update_catalog=update_catalog)
    out = Path(__file__).resolve().parents[1] / "out" / city_id
    out.mkdir(parents=True, exist_ok=True)
    save_json(research, out / f"{city_id}.research.json")
    save_json(guide, out / "guide.json")

    if tts:
        import time

        from generate.tts.guide_synth import synthesize_guide

        print(f"[5/5] TTS {tts_backend}/{tts_voice}")
        started = time.monotonic()
        synthesize_guide(
            folder / "guide.json",
            folder,
            backend_name=tts_backend,
            voice=tts_voice or None,
        )
        print(f"tts_wall_sec={time.monotonic() - started:.1f}")
        guide = load_guide(folder / "guide.json")
        save_json(guide, out / "guide.json")
        if update_catalog:
            upsert_catalog(guide)
    else:
        print("[5/5] TTS пропущен")

    print(f"GUIDE_ID={guide.id}")
    print(f"Готово: {folder / 'guide.json'}")
    print(f"Остановок: {len(guide.stops)}")
    return folder

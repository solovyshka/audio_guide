from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import List

from pydantic import Field

from generate.city_guide.checks import local_checks
from generate.city_guide.package import (
    dump,
    guide_package_ready,
    load_city,
    load_guide,
    load_research,
    save_json,
    upsert_catalog,
    write_city,
    write_package,
)
from generate.city_guide.length import guide_id_for, parse_length, profile
from generate.city_guide.prompts import (
    COUNTRY_DOSSIER_SYSTEM,
    DOSSIER_SYSTEM,
    fix_system,
    qa_system,
    research_system,
    writer_system,
)
from generate.city_guide.schemas import (
    CityDossier,
    CityDossierGen,
    CountryDossierGen,
    CityGuide,
    CityGuides,
    CityPlace,
    CityResearch,
    GuideStop,
    HistoryBlock,
    Intro,
    PresentBlock,
    QAResult,
    StopResearch,
    Strict,
)
from generate.city_guide.slug import slugify, stop_slug

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
            "Не задан OPENAI_API_KEY"
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


_SIGHT_KINDS = {"sight"}
_NATURE_KINDS = {"park", "viewpoint"}
_CULTURE_KINDS = {"museum", "theater", "culture"}
_LEISURE_KINDS = {"coffee", "pastry", "restaurant"}


def _normalize_place(place: CityPlace, fallback: str) -> CityPlace:
    kind = (place.kind or fallback).strip().lower()
    if fallback == "sight" and kind not in _SIGHT_KINDS:
        kind = "sight"
    elif fallback == "nature" and kind not in _NATURE_KINDS:
        kind = "park" if "парк" in place.summary.lower() or "сквер" in place.name.lower() else "viewpoint"
    elif fallback == "culture" and kind not in _CULTURE_KINDS:
        kind = "museum"
    elif fallback == "leisure" and kind not in _LEISURE_KINDS:
        kind = "restaurant"
    return place.model_copy(
        update={
            "id": stop_slug(place.id or place.name),
            "kind": kind,
            "summary": (place.summary or "").strip(),
        }
    )


def _dossier_from_gen(raw: CityDossierGen, city_id: str) -> CityDossier:
    from generate.city_guide.geo import snap_city_places

    sights = [_normalize_place(item, "sight") for item in raw.sights]
    nature = [_normalize_place(item, "nature") for item in raw.nature]
    culture = [_normalize_place(item, "culture") for item in raw.culture]
    leisure = [_normalize_place(item, "leisure") for item in raw.leisure]
    print("уточняю координаты POI по OSM")
    sights = snap_city_places(raw.city, sights)
    nature = snap_city_places(raw.city, nature)
    culture = snap_city_places(raw.city, culture)
    leisure = snap_city_places(raw.city, leisure)
    aliases = list(dict.fromkeys([*(raw.aliases or []), raw.city, raw.title]))
    return CityDossier(
        id=city_id,
        contentVersion=1,
        title=raw.title or raw.city,
        subtitle=raw.subtitle,
        city=raw.city,
        region=raw.region,
        language="ru",
        center=raw.center,
        aliases=aliases,
        history=HistoryBlock(
            founded=raw.history.founded,
            summary=raw.history.summary,
            events=list(raw.history.events),
        ),
        present=PresentBlock(
            summary=raw.present.summary,
            population=raw.present.population,
            economy=raw.present.economy,
        ),
        sights=sights,
        nature=nature,
        culture=culture,
        leisure=leisure,
        guides=CityGuides(),
    )


def research_dossier(client, city: str) -> CityDossier:
    city_id = slugify(city)
    prompt = f"""
Собери досье города: {city}

Нужны история, настоящее, городские места, парки и смотровые, культура и досуг.
Места, природу и досуг бери с карт по стране города, не из OSM.
Координаты каждого места — самого объекта.
id места — ASCII slug.
"""
    raw = parse(client, MODEL, DOSSIER_SYSTEM, prompt, CityDossierGen, web=True)
    return _dossier_from_gen(raw, city_id)


def _ensure_guide(
    city: str,
    length: str,
    *,
    update_catalog: bool,
    tts: bool,
    tts_backend: str,
    tts_voice: str,
):
    from generate.city_guide.package import guide_dir
    from generate.tts.guide_synth import synthesize_guide

    guide_id = guide_id_for(city, length)
    folder = guide_dir(guide_id)
    if (folder / "guide.json").exists():
        if tts and not (folder / "audio" / "intro.wav").is_file():
            print(f"пакет {guide_id} есть, озвучиваю недостающее")
            synthesize_guide(
                folder / "guide.json",
                folder,
                backend_name=tts_backend,
                voice=tts_voice or None,
            )
            guide = load_guide(folder / "guide.json")
            if update_catalog:
                upsert_catalog(guide)
        else:
            print(f"гид {guide_id} уже есть")
        return guide_id
    print(f"собираю {length} гид {guide_id}")
    run_api_city(
        city,
        length=length,
        update_catalog=update_catalog,
        tts=tts,
        tts_backend=tts_backend,
        tts_voice=tts_voice,
    )
    return guide_id if (folder / "guide.json").exists() else None


def run_api_city_batch(
    city: str,
    *,
    update_catalog: bool = True,
    tts: bool = True,
    tts_backend: str = "silero",
    tts_voice: str = "xenia",
) -> Path:
    city_id = slugify(city)
    existing = load_city(city_id)
    need_dossier = existing is None or not (existing.history.summary or "").strip()
    if need_dossier:
        print(f"[1/4] Досье города: {city}")
        _require_openai_network()
        client = _client()
        dossier = research_dossier(client, city)
    else:
        print(f"[1/4] Досье {city_id} уже есть, не переписываю")
        dossier = existing

    print("[2/4] Короткий аудиогид")
    short_id = _ensure_guide(
        city,
        "short",
        update_catalog=update_catalog,
        tts=tts,
        tts_backend=tts_backend,
        tts_voice=tts_voice,
    )
    print("[3/4] Длинный аудиогид")
    long_id = _ensure_guide(
        city,
        "long",
        update_catalog=update_catalog,
        tts=tts,
        tts_backend=tts_backend,
        tts_voice=tts_voice,
    )
    dossier = dossier.model_copy(
        update={
            "guides": CityGuides(
                short=short_id,
                long=long_id,
            )
        }
    )
    print("[4/4] Сохраняю city.json")
    folder = write_city(dossier)
    print(f"CITY_ID={dossier.id}")
    if short_id:
        print(f"GUIDE_ID={short_id}")
    print(f"Готово: {folder / 'city.json'}")
    return folder


_COUNTRY_SECTIONS = ("history", "present", "sights", "nature", "culture", "leisure")


def _country_area_path(area_id: str) -> Path:
    return Path(__file__).resolve().parents[2] / "content" / "areas" / area_id / "area.json"


def _country_dossier_ready(area: dict) -> bool:
    history = area.get("history") or {}
    present = area.get("present") or {}
    return bool(
        str(history.get("summary") or "").strip()
        and str(present.get("summary") or "").strip()
        and all(area.get(key) for key in ("sights", "nature", "culture", "leisure"))
    )


def _validate_country_area(area: dict) -> None:
    missing = [key for key in _COUNTRY_SECTIONS if not area.get(key)]
    if missing:
        raise RuntimeError("В досье страны нет разделов: " + ", ".join(missing))
    minimums = {"sights": 10, "nature": 5, "culture": 6, "leisure": 6}
    for key, minimum in minimums.items():
        count = len(area.get(key) or [])
        if count < minimum:
            raise RuntimeError(f"Раздел {key}: {count} карточек, нужно не меньше {minimum}")
    guide_id = str(area.get("overviewGuideId") or "").strip()
    if not guide_id:
        raise RuntimeError("У страны не задан overviewGuideId")
    guide_path = Path(__file__).resolve().parents[2] / "content" / "guides" / guide_id / "guide.json"
    research_path = guide_path.parent / f"{guide_id}.research.json"
    if not guide_path.exists() or not research_path.exists():
        raise RuntimeError(f"Нет пакета общего гида {guide_id}")
    guide = load_guide(guide_path)
    research = load_research(research_path)
    if len(guide.stops) != len(research.stops) or len(guide.stops) < 15:
        raise RuntimeError("Общий гид страны должен иметь минимум 15 совпадающих остановок")


def research_country_dossier(client, country: str) -> CountryDossierGen:
    prompt = f"""
Собери досье страны: {country}.

Сохрани ровно городскую структуру разделов, но расширь объём для масштаба
всей страны. Подборка должна покрывать основные географические части страны,
а не только столицу. Кофейни и рестораны распределяй между главными городами.
"""
    return parse(
        client,
        MODEL,
        COUNTRY_DOSSIER_SYSTEM,
        prompt,
        CountryDossierGen,
        web=True,
    )


def _merge_country_dossier(area: dict, dossier: CountryDossierGen) -> dict:
    updated = dict(area)
    updated.update(
        {
            "title": dossier.title,
            "subtitle": dossier.subtitle,
            "center": dump(dossier.center),
            "aliases": list(dict.fromkeys([*(area.get("aliases") or []), *dossier.aliases])),
            "history": dump(dossier.history),
            "present": dump(dossier.present),
            "sights": [dump(item) for item in dossier.sights],
            "nature": [dump(item) for item in dossier.nature],
            "culture": [dump(item) for item in dossier.culture],
            "leisure": [dump(item) for item in dossier.leisure],
            "sourceUrls": dossier.sourceUrls,
        }
    )
    updated["contentVersion"] = int(area.get("contentVersion") or 0) + 1
    return updated


def run_api_country_batch(
    area_id: str,
    *,
    country: str | None = None,
    refresh_dossier: bool = False,
    tts: bool = True,
    tts_backend: str = "silero",
    tts_voice: str = "xenia",
) -> Path:
    area_path = _country_area_path(area_id)
    if not area_path.exists():
        raise RuntimeError(f"Территория не найдена: {area_id}")
    area = json.loads(area_path.read_text(encoding="utf-8"))
    if area.get("type") != "country":
        raise RuntimeError(f"{area_id} — не страна")

    if refresh_dossier or not _country_dossier_ready(area):
        name = (country or area.get("title") or area_id).strip()
        print(f"[1/4] Досье страны: {name}")
        _require_openai_network()
        area = _merge_country_dossier(area, research_country_dossier(_client(), name))
        area_path.write_text(
            json.dumps(area, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    else:
        print(f"[1/4] Досье {area_id} уже есть, не переписываю")

    print("[2/4] Проверяю структуру и общий гид")
    _validate_country_area(area)
    guide_id = area["overviewGuideId"]
    guide_path = Path(__file__).resolve().parents[2] / "content" / "guides" / guide_id / "guide.json"
    guide = load_guide(guide_path)
    upsert_catalog(guide)

    if tts:
        from generate.tts.guide_synth import synthesize_guide

        print(f"[3/4] TTS {tts_backend}/{tts_voice}")
        synthesize_guide(
            guide_path,
            guide_path.parent,
            backend_name=tts_backend,
            voice=tts_voice or None,
            only_missing=True,
        )
        upsert_catalog(load_guide(guide_path))
    else:
        print("[3/4] TTS пропущен")

    print("[4/4] Собираю офлайн-пакет")
    root = Path(__file__).resolve().parents[2]
    subprocess.run(
        [sys.executable, str(root / "deploy" / "pack-json.py")],
        cwd=root,
        check=True,
    )
    print(f"AREA_ID={area_id}")
    print(f"GUIDE_ID={guide_id}")
    print(f"Готово: {area_path}")
    return area_path.parent

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from generate.city_guide.schemas import CityGuide, CityResearch, Coordinates, GuideStop
from generate.city_guide.slug import slugify, stop_slug

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "content"
CATALOG = CONTENT / "catalog.json"


def dump(model) -> dict:
    return model.model_dump(mode="json")


def save_json(obj: dict | CityGuide | CityResearch, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if hasattr(obj, "model_dump"):
        payload = dump(obj)
    else:
        payload = obj
    path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def load_research(path: Path) -> CityResearch:
    return CityResearch.model_validate_json(path.read_text(encoding="utf-8"))


def load_guide(path: Path) -> CityGuide:
    return CityGuide.model_validate_json(path.read_text(encoding="utf-8"))


def normalize_guide(
    research: CityResearch,
    guide: CityGuide,
    *,
    content_version: int | None = None,
) -> CityGuide:
    """Fill id, audioPath, lock coords/names from research by order."""
    city_id = guide.id if guide.id else slugify(research.city)
    stops: list[GuideStop] = []
    for i, src in enumerate(research.stops):
        raw = guide.stops[i] if i < len(guide.stops) else None
        sid = (raw.id if raw and raw.id else stop_slug(src.name))
        text = raw.text if raw else ""
        order = i + 1
        stops.append(
            GuideStop(
                id=sid,
                name=src.name,
                lat=src.coordinates.lat,
                lon=src.coordinates.lon,
                category=src.category,
                order=order,
                text=text,
                audioPath=f"audio/{order:02d}-{sid}.wav",
                durationSec=raw.durationSec if raw else 0,
            )
        )
    intro = guide.intro
    intro.audioPath = "audio/intro.wav"
    if not intro.title:
        intro.title = research.city
    version = content_version if content_version is not None else guide.contentVersion or 1
    return CityGuide(
        id=city_id,
        contentVersion=version,
        title=guide.title or research.city,
        subtitle=guide.subtitle or research.subtitle,
        city=research.city,
        region=research.region,
        language=guide.language or "ru",
        center=Coordinates(lat=research.center.lat, lon=research.center.lon),
        aliases=guide.aliases or research.aliases,
        intro=intro,
        stops=stops,
        durationSec=intro.durationSec + sum(s.durationSec for s in stops),
    )


def guide_dir(city_id: str, out_root: Path | None = None) -> Path:
    base = out_root or (CONTENT / "guides")
    return base / city_id


def write_package(
    research: CityResearch,
    guide: CityGuide,
    *,
    out_root: Path | None = None,
    update_catalog: bool = True,
) -> Path:
    guide = normalize_guide(research, guide)
    folder = guide_dir(guide.id, out_root)
    (folder / "audio").mkdir(parents=True, exist_ok=True)
    save_json(research, folder / f"{guide.id}.research.json")
    save_json(guide, folder / "guide.json")
    try:
        from generate.city_guide.static_map import ensure_map_image

        ensure_map_image(folder, guide.stops)
    except Exception:
        pass
    if update_catalog and out_root is None:
        upsert_catalog(guide)
    return folder


def upsert_catalog(guide: CityGuide) -> None:
    if CATALOG.exists():
        data = json.loads(CATALOG.read_text(encoding="utf-8"))
    else:
        data = {"version": 1, "updatedAt": "", "guides": []}
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    data["updatedAt"] = now
    entry = {
        "id": guide.id,
        "title": guide.title,
        "subtitle": guide.subtitle,
        "aliases": guide.aliases,
        "city": guide.city,
        "region": guide.region,
        "center": {"lat": guide.center.lat, "lon": guide.center.lon},
        "stopsCount": len(guide.stops),
        "durationSec": guide.durationSec,
        "language": guide.language,
        "guidePath": f"guides/{guide.id}/guide.json",
        "contentVersion": guide.contentVersion,
    }
    guides = data.setdefault("guides", [])
    for i, item in enumerate(guides):
        if item.get("id") == guide.id:
            guides[i] = entry
            break
    else:
        guides.append(entry)
    save_json(data, CATALOG)


def read_cities_list(path: Path) -> list[str]:
    cities: list[str] = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        cities.append(line)
    return cities

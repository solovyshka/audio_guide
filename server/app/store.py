import json
from pathlib import Path

from app.config import settings
from app.models import AreaSummary, City, CitySummary, Guide, GuideSummary, city_from_package, guide_from_package


def _catalog_path() -> Path:
    return settings.content_dir / "catalog.json"


def load_catalog() -> list[GuideSummary]:
    path = _catalog_path()
    if not path.exists():
        return []
    payload = json.loads(path.read_text(encoding="utf-8"))
    items = []
    for raw in payload.get("guides", []):
        items.append(
            GuideSummary(
                id=raw["id"],
                title=raw["title"],
                subtitle=raw.get("subtitle"),
                city=raw.get("city", raw["title"]),
                region=raw.get("region"),
                aliases=raw.get("aliases", []),
                center=raw.get("center") or {"lat": 0, "lon": 0},
                stops_count=raw.get("stopsCount", 0),
                duration_sec=raw.get("durationSec", 0),
                language=raw.get("language", "ru"),
                content_version=raw.get("contentVersion", 1),
                route_mode=raw.get("routeMode"),
                route_distance_km=raw.get("routeDistanceKm"),
                estimated_duration_min=raw.get("estimatedDurationMin"),
                route_notice=raw.get("routeNotice"),
                reviewed_at=raw.get("reviewedAt"),
            )
        )
    return items


def load_guide(guide_id: str) -> Guide | None:
    path = settings.content_dir / "guides" / guide_id / "guide.json"
    if not path.exists():
        return None
    raw = json.loads(path.read_text(encoding="utf-8"))
    return guide_from_package(raw, settings.public_base_url)


def search_guides(query: str) -> list[GuideSummary]:
    needle = query.strip().lower()
    catalog = load_catalog()
    if not needle:
        return catalog

    scored: list[tuple[int, GuideSummary]] = []
    for item in catalog:
        aliases = [alias.lower() for alias in item.aliases]
        haystack = " ".join([item.id, item.title, item.city, *aliases]).lower()
        if needle == item.id.lower() or needle in aliases:
            scored.append((100, item))
        elif needle in haystack or any(needle in alias for alias in aliases):
            scored.append((80, item))
        elif any(alias in needle for alias in aliases if len(alias) >= 4):
            scored.append((60, item))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [item for _, item in scored]


def _city_summary(raw: dict) -> CitySummary:
    return CitySummary(
        id=raw["id"],
        title=raw["title"],
        subtitle=raw.get("subtitle"),
        city=raw.get("city", raw["title"]),
        region=raw.get("region"),
        aliases=raw.get("aliases") or [],
        center=raw.get("center") or {"lat": 0, "lon": 0},
        guides=raw.get("guides") or {},
        content_version=raw.get("contentVersion", 1),
        language=raw.get("language", "ru"),
        reviewed_at=raw.get("reviewedAt"),
        source_urls=raw.get("sourceUrls") or [],
        entry_type=raw.get("entryType", "city"),
        country_id=raw.get("countryId"),
        region_id=raw.get("regionId"),
    )


def load_cities() -> list[CitySummary]:
    catalog_path = _catalog_path()
    order: list[str] = []
    if catalog_path.exists():
        payload = json.loads(catalog_path.read_text(encoding="utf-8"))
        order = [
            raw["id"]
            for raw in payload.get("cities") or []
            if isinstance(raw, dict) and raw.get("id")
        ]
    cities_by_id: dict[str, CitySummary] = {}
    for path in sorted((settings.content_dir / "cities").glob("*/city.json")):
        raw = json.loads(path.read_text(encoding="utf-8"))
        city_id = raw.get("id")
        if city_id and city_id != "gazgoldernaya":
            cities_by_id[city_id] = _city_summary(raw)
    cities = [cities_by_id[city_id] for city_id in order if city_id in cities_by_id]
    cities.extend(
        city for city_id, city in cities_by_id.items() if city_id not in order
    )
    return cities


def load_city(city_id: str) -> City | None:
    path = settings.content_dir / "cities" / city_id / "city.json"
    if not path.exists():
        return None
    raw = json.loads(path.read_text(encoding="utf-8"))
    return city_from_package(raw)


def search_cities(query: str) -> list[CitySummary]:
    needle = query.strip().lower()
    catalog = load_cities()
    if not needle:
        return catalog
    scored: list[tuple[int, CitySummary]] = []
    for item in catalog:
        aliases = [alias.lower() for alias in item.aliases]
        haystack = " ".join([item.id, item.title, item.city, *aliases]).lower()
        if needle == item.id.lower() or needle in aliases:
            scored.append((100, item))
        elif needle in haystack or any(needle in alias for alias in aliases):
            scored.append((80, item))
        elif any(alias in needle for alias in aliases if len(alias) >= 4):
            scored.append((60, item))
    scored.sort(key=lambda pair: pair[0], reverse=True)
    return [item for _, item in scored]


def _area_summary(raw: dict) -> AreaSummary:
    return AreaSummary.model_validate(raw)


def load_areas() -> list[AreaSummary]:
    root = settings.content_dir / "areas"
    if not root.exists():
        return []
    areas = []
    for path in sorted(root.glob("*/area.json")):
        raw = json.loads(path.read_text(encoding="utf-8"))
        areas.append(_area_summary(raw))
    return areas


def load_area(area_id: str) -> AreaSummary | None:
    path = settings.content_dir / "areas" / area_id / "area.json"
    if not path.exists():
        return None
    return _area_summary(json.loads(path.read_text(encoding="utf-8")))

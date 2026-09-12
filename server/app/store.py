import json
from pathlib import Path

from app.config import settings
from app.models import Guide, GuideSummary, guide_from_package


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

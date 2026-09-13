from __future__ import annotations

import json
import math
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import asdict, dataclass
from typing import Any, Callable

from generate.city_guide.schemas import (
    CityResearch,
    Coordinates,
    CoordArbitration,
    StopResearch,
)

DEFAULT_THRESHOLD_M = float(os.getenv("OSM_DISTANCE_M", "200"))
DEFAULT_SLEEP_S = float(os.getenv("OSM_SLEEP_S", "1.1"))
DEFAULT_USER_AGENT = os.getenv(
    "OSM_USER_AGENT",
    "audio-guide-city-guide/1.0 (local; coords check)",
)
NOMINATIM_URL = os.getenv(
    "NOMINATIM_URL",
    "https://nominatim.openstreetmap.org/search",
)

# viewbox half-span ~0.25° ≈ 25–30 km around city center
_VIEWBOX_DELTA = 0.25


@dataclass
class OsmHit:
    lat: float
    lon: float
    display_name: str
    osm_type: str | None = None
    osm_id: int | None = None


@dataclass
class OsmCheck:
    stop_index: int
    stop_name: str
    status: str
    distance_m: float | None = None
    research: Coordinates | None = None
    osm: OsmHit | None = None
    arbitration: CoordArbitration | None = None
    applied: bool = False
    note: str | None = None

    def to_dict(self) -> dict[str, Any]:
        payload = asdict(self)
        if self.research is not None:
            payload["research"] = self.research.model_dump()
        if self.arbitration is not None:
            payload["arbitration"] = self.arbitration.model_dump()
        if self.osm is not None:
            payload["osm"] = asdict(self.osm)
        return payload


def haversine_m(a: Coordinates | tuple[float, float], b: Coordinates | tuple[float, float]) -> float:
    lat1, lon1 = (a.lat, a.lon) if isinstance(a, Coordinates) else a
    lat2, lon2 = (b.lat, b.lon) if isinstance(b, Coordinates) else b
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    x = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * r * math.asin(math.sqrt(x))


def nominatim_search(
    query: str,
    *,
    viewbox: tuple[float, float, float, float] | None = None,
    bounded: bool = False,
    countrycodes: str | None = None,
    user_agent: str = DEFAULT_USER_AGENT,
    url: str = NOMINATIM_URL,
    timeout: float = 30.0,
    limit: int = 5,
) -> list[OsmHit]:
    params: dict[str, str] = {
        "q": query,
        "format": "json",
        "limit": str(limit),
        "addressdetails": "0",
        "accept-language": "ru",
    }
    if countrycodes:
        params["countrycodes"] = countrycodes
    if viewbox is not None:
        # left, top, right, bottom = min_lon, max_lat, max_lon, min_lat
        params["viewbox"] = ",".join(str(x) for x in viewbox)
        if bounded:
            params["bounded"] = "1"
    encoded = urllib.parse.urlencode(params)
    req = urllib.request.Request(
        f"{url}?{encoded}",
        headers={
            "User-Agent": user_agent,
            "Accept": "application/json",
            "Accept-Language": "ru",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as error:
        raise RuntimeError(f"Nominatim error for «{query}»: {error}") from error
    hits: list[OsmHit] = []
    for item in data or []:
        hits.append(
            OsmHit(
                lat=float(item["lat"]),
                lon=float(item["lon"]),
                display_name=str(item.get("display_name") or ""),
                osm_type=item.get("osm_type"),
                osm_id=int(item["osm_id"]) if item.get("osm_id") is not None else None,
            )
        )
    return hits


def _viewbox_around(center: Coordinates) -> tuple[float, float, float, float]:
    return (
        center.lon - _VIEWBOX_DELTA,
        center.lat + _VIEWBOX_DELTA,
        center.lon + _VIEWBOX_DELTA,
        center.lat - _VIEWBOX_DELTA,
    )


def _countrycodes_for_region(region: str) -> str | None:
    text = region.lower()
    if any(x in text for x in ("кипр", "cyprus", "κύπρ")):
        return "cy"
    if any(x in text for x in ("китай", "china", "цзянсу", "сучжоу")):
        return "cn"
    if any(x in text for x in ("росси", "russia", "область", "край", "республика")):
        return "ru"
    return None


def _queries_for_stop(research: CityResearch, stop: StopResearch) -> list[str]:
    """Short queries first — long address strings often return nothing."""
    seen: set[str] = set()
    out: list[str] = []
    for candidate in (
        f"{stop.name}, {research.city}",
        f"{stop.name}, {research.city}, {research.region}",
        stop.name,
    ):
        text = " ".join(candidate.split())
        if text and text not in seen:
            seen.add(text)
            out.append(text)
    return out


def _pick_hit(
    hits: list[OsmHit],
    *,
    near: Coordinates,
    max_from_near_m: float = 25000.0,
) -> OsmHit | None:
    if not hits:
        return None
    ranked = sorted(hits, key=lambda h: haversine_m(near, (h.lat, h.lon)))
    best = ranked[0]
    if haversine_m(near, (best.lat, best.lon)) > max_from_near_m:
        return None
    return best


def _lookup_stop(
    research: CityResearch,
    stop: StopResearch,
    *,
    user_agent: str,
    sleep_s: float,
) -> OsmHit | None:
    viewbox = _viewbox_around(research.center)
    country = _countrycodes_for_region(research.region)
    near = stop.coordinates
    for i, query in enumerate(_queries_for_stop(research, stop)):
        if i > 0 and sleep_s > 0:
            time.sleep(sleep_s)
        hits = nominatim_search(
            query,
            viewbox=viewbox,
            bounded=False,
            countrycodes=country,
            user_agent=user_agent,
        )
        hit = _pick_hit(hits, near=near)
        if hit is not None:
            return hit
    return None


def verify_research_coords(
    research: CityResearch,
    *,
    threshold_m: float = DEFAULT_THRESHOLD_M,
    sleep_s: float = DEFAULT_SLEEP_S,
    user_agent: str = DEFAULT_USER_AGENT,
    arbitrate: Callable[[StopResearch, OsmHit, float], CoordArbitration] | None = None,
    apply: bool = False,
) -> tuple[CityResearch, list[OsmCheck]]:
    """Compare each stop with Nominatim; optionally apply OSM after LLM arbitration.

    When ``apply`` is True and arbitration says not confident, rewrite
    ``coordinates`` and stash the previous value in ``llm_coordinates``.
    """
    checks: list[OsmCheck] = []
    stops = list(research.stops)

    for index, stop in enumerate(stops):
        if index > 0 and sleep_s > 0:
            time.sleep(sleep_s)
        try:
            hit = _lookup_stop(
                research, stop, user_agent=user_agent, sleep_s=sleep_s
            )
        except RuntimeError as error:
            checks.append(
                OsmCheck(
                    stop_index=index,
                    stop_name=stop.name,
                    status="nominatim_error",
                    research=stop.coordinates,
                    note=str(error),
                )
            )
            continue

        if hit is None:
            checks.append(
                OsmCheck(
                    stop_index=index,
                    stop_name=stop.name,
                    status="not_found",
                    research=stop.coordinates,
                    note=(
                        "Nominatim: нет подходящего результата рядом с точкой "
                        f"(запросы: {_queries_for_stop(research, stop)})"
                    ),
                )
            )
            continue

        distance = haversine_m(stop.coordinates, (hit.lat, hit.lon))
        if distance <= threshold_m:
            checks.append(
                OsmCheck(
                    stop_index=index,
                    stop_name=stop.name,
                    status="ok",
                    distance_m=round(distance, 1),
                    research=stop.coordinates,
                    osm=hit,
                )
            )
            continue

        arbitration: CoordArbitration | None = None
        applied = False
        status = "mismatch"
        note: str | None = None

        if arbitrate is not None:
            try:
                arbitration = arbitrate(stop, hit, distance)
            except Exception as error:  # noqa: BLE001 — keep batch going
                status = "llm_error"
                note = str(error)
                checks.append(
                    OsmCheck(
                        stop_index=index,
                        stop_name=stop.name,
                        status=status,
                        distance_m=round(distance, 1),
                        research=stop.coordinates,
                        osm=hit,
                        note=note,
                    )
                )
                continue

            if arbitration.confident:
                status = "mismatch_kept"
            elif apply:
                previous = stop.coordinates
                stops[index] = stop.model_copy(
                    update={
                        "coordinates": Coordinates(lat=hit.lat, lon=hit.lon),
                        "llm_coordinates": previous
                        if stop.llm_coordinates is None
                        else stop.llm_coordinates,
                    }
                )
                applied = True
                status = "mismatch_applied"
            else:
                status = "mismatch_would_apply"
        elif apply:
            # Without LLM, never silently rewrite — report only.
            status = "mismatch_needs_llm"
            note = "Расхождение > порога; нужен LLM-арбитраж или --no-llm отчёт"
        else:
            status = "mismatch"

        checks.append(
            OsmCheck(
                stop_index=index,
                stop_name=stop.name,
                status=status,
                distance_m=round(distance, 1),
                research=stop.coordinates if not applied else stops[index].llm_coordinates,
                osm=hit,
                arbitration=arbitration,
                applied=applied,
                note=note or (arbitration.reason if arbitration else None),
            )
        )

    updated = research.model_copy(update={"stops": stops})
    return updated, checks


def report_payload(
    research: CityResearch,
    checks: list[OsmCheck],
    *,
    threshold_m: float,
) -> dict[str, Any]:
    counts: dict[str, int] = {}
    for item in checks:
        counts[item.status] = counts.get(item.status, 0) + 1
    return {
        "city": research.city,
        "threshold_m": threshold_m,
        "counts": counts,
        "checks": [c.to_dict() for c in checks],
    }

from __future__ import annotations

import json
import math
import time
import urllib.parse
import urllib.request

from generate.city_guide.schemas import CityResearch, Coordinates, StopResearch

_UA = "audio-guide/1.0 (github.com/solovyshka/audio_guide)"
_EARTH_M = 6371000.0


def haversine_m(a: Coordinates, b: Coordinates) -> float:
    lat1, lon1 = math.radians(a.lat), math.radians(a.lon)
    lat2, lon2 = math.radians(b.lat), math.radians(b.lon)
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    h = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    )
    return 2 * _EARTH_M * math.asin(min(1.0, math.sqrt(h)))


def bbox_diagonal_m(points: list[Coordinates]) -> float:
    if len(points) < 2:
        return 0.0
    south = Coordinates(lat=min(p.lat for p in points), lon=min(p.lon for p in points))
    north = Coordinates(lat=max(p.lat for p in points), lon=max(p.lon for p in points))
    return haversine_m(south, north)


def decimal_places(value: float) -> int:
    text = f"{value:.6f}".rstrip("0")
    if "." not in text:
        return 0
    return len(text.split(".", 1)[1])


def nominatim(name: str, city: str) -> Coordinates | None:
    query = urllib.parse.urlencode(
        {
            "q": f"{name}, {city}",
            "format": "json",
            "limit": 1,
        }
    )
    req = urllib.request.Request(
        f"https://nominatim.openstreetmap.org/search?{query}",
        headers={"User-Agent": _UA},
    )
    try:
        with urllib.request.urlopen(req, timeout=12) as resp:
            rows = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None
    if not rows:
        return None
    return Coordinates(lat=float(rows[0]["lat"]), lon=float(rows[0]["lon"]))


def snap_research_coords(research: CityResearch) -> CityResearch:
    """Replace invented coords when OSM geocode is far from research."""
    stops: list[StopResearch] = []
    for src in research.stops:
        found = nominatim(src.name, research.city)
        time.sleep(1.1)
        if found is None:
            stops.append(src)
            continue
        drift = haversine_m(src.coordinates, found)
        if drift > 800:
            print(
                f"геокод {src.name}: "
                f"{src.coordinates.lat:.5f},{src.coordinates.lon:.5f} → "
                f"{found.lat:.5f},{found.lon:.5f} ({drift:.0f} м)"
            )
            stops.append(src.model_copy(update={"coordinates": found}))
        else:
            stops.append(src)
    if not stops:
        return research
    center = Coordinates(
        lat=sum(item.coordinates.lat for item in stops) / len(stops),
        lon=sum(item.coordinates.lon for item in stops) / len(stops),
    )
    return research.model_copy(update={"stops": stops, "center": center})

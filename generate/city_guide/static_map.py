"""Static map snapshot for a guide (Yandex Static API)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable
from urllib.request import Request, urlopen

MAP_WIDTH = 650
MAP_HEIGHT = 450
MAP_NAME = "map.png"
PAD = 0.22
MIN_LAT_SPAN = 0.004
MIN_LON_SPAN = 0.006
USER_AGENT = "audio-guide/1.0 (github.com/solovyshka/audio_guide)"


@dataclass(frozen=True)
class MapBounds:
    lat_min: float
    lat_max: float
    lon_min: float
    lon_max: float
    width: int = MAP_WIDTH
    height: int = MAP_HEIGHT

    def as_json(self) -> dict[str, int | float]:
        return {
            "latMin": self.lat_min,
            "latMax": self.lat_max,
            "lonMin": self.lon_min,
            "lonMax": self.lon_max,
            "width": self.width,
            "height": self.height,
        }


def _lat_lon(stop: Any) -> tuple[float, float]:
    if hasattr(stop, "lat") and hasattr(stop, "lon"):
        return float(stop.lat), float(stop.lon)
    return float(stop["lat"]), float(stop["lon"])


def bounds_for_stops(stops: Iterable[Any]) -> MapBounds:
    points = [_lat_lon(stop) for stop in stops]
    if not points:
        raise ValueError("Нет точек для карты")
    lats = [lat for lat, _ in points]
    lons = [lon for _, lon in points]
    lat_min, lat_max = min(lats), max(lats)
    lon_min, lon_max = min(lons), max(lons)
    lat_pad = max((lat_max - lat_min) * PAD, MIN_LAT_SPAN / 2)
    lon_pad = max((lon_max - lon_min) * PAD, MIN_LON_SPAN / 2)
    return MapBounds(
        lat_min=lat_min - lat_pad,
        lat_max=lat_max + lat_pad,
        lon_min=lon_min - lon_pad,
        lon_max=lon_max + lon_pad,
    )


def yandex_static_url(bounds: MapBounds) -> str:
    lat_c = (bounds.lat_min + bounds.lat_max) / 2
    lon_c = (bounds.lon_min + bounds.lon_max) / 2
    spn_lat = bounds.lat_max - bounds.lat_min
    spn_lon = bounds.lon_max - bounds.lon_min
    return (
        "https://static-maps.yandex.ru/1.x/"
        f"?ll={lon_c},{lat_c}&spn={spn_lon},{spn_lat}"
        f"&l=map&size={bounds.width},{bounds.height}&lang=ru_RU"
    )


def fetch_png(url: str, timeout: float = 20) -> bytes:
    req = Request(url, headers={"User-Agent": USER_AGENT})
    with urlopen(req, timeout=timeout) as resp:
        data = resp.read()
    if not data.startswith(b"\x89PNG"):
        raise RuntimeError("Статика Яндекса вернула не PNG")
    return data


def map_path(folder: Path) -> Path:
    return folder / MAP_NAME


def ensure_map_image(folder: Path, stops: Iterable[Any]) -> Path | None:
    dest = map_path(folder)
    guide_json = folder / "guide.json"
    if dest.is_file() and guide_json.is_file():
        if dest.stat().st_mtime >= guide_json.stat().st_mtime:
            return dest
    try:
        bounds = bounds_for_stops(stops)
        dest.write_bytes(fetch_png(yandex_static_url(bounds)))
        return dest
    except Exception:
        return dest if dest.is_file() else None

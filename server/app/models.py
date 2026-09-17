from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class LatLon(BaseModel):
    lat: float
    lon: float


class Track(BaseModel):
    title: str
    text: str
    audio_path: str | None = Field(default=None, alias="audioPath")
    audio_url: str | None = Field(default=None, alias="audioUrl")
    duration_sec: int = Field(default=0, alias="durationSec")

    model_config = ConfigDict(populate_by_name=True, ser_json_by_alias=True)


class Stop(Track):
    id: str
    name: str
    lat: float
    lon: float
    category: str | None = None
    order: int = 0


class MapBounds(BaseModel):
    lat_min: float = Field(alias="latMin")
    lat_max: float = Field(alias="latMax")
    lon_min: float = Field(alias="lonMin")
    lon_max: float = Field(alias="lonMax")
    width: int = 650
    height: int = 450

    model_config = ConfigDict(populate_by_name=True, ser_json_by_alias=True)


class GuideSummary(BaseModel):
    id: str
    title: str
    subtitle: str | None = None
    city: str
    region: str | None = None
    aliases: list[str] = []
    center: LatLon
    stops_count: int = Field(alias="stopsCount")
    duration_sec: int = Field(alias="durationSec")
    language: str = "ru"
    content_version: int = Field(alias="contentVersion")

    model_config = ConfigDict(populate_by_name=True, ser_json_by_alias=True)


class Guide(GuideSummary):
    intro: Track
    stops: list[Stop]
    map_url: str | None = Field(default=None, alias="mapUrl")
    map_bounds: MapBounds | None = Field(default=None, alias="mapBounds")


def public_audio_url(base: str, guide_id: str, audio_path: str | None) -> str | None:
    if not audio_path:
        return None
    path = audio_path.lstrip("/")
    return f"{base.rstrip('/')}/media/guides/{guide_id}/{path}"


def public_map_url(base: str, guide_id: str) -> str:
    return f"{base.rstrip('/')}/guides/{guide_id}/map.png"


def guide_from_package(raw: dict[str, Any], base_url: str) -> Guide:
    guide_id = raw["id"]
    intro_raw = raw["intro"]
    intro = Track(
        title=intro_raw.get("title", raw.get("title", "")),
        text=intro_raw.get("text", ""),
        audio_path=intro_raw.get("audioPath"),
        audio_url=public_audio_url(base_url, guide_id, intro_raw.get("audioPath")),
        duration_sec=intro_raw.get("durationSec", 0),
    )
    stops = []
    for item in raw.get("stops", []):
        stops.append(
            Stop(
                id=item["id"],
                name=item["name"],
                title=item["name"],
                text=item.get("text", ""),
                lat=item["lat"],
                lon=item["lon"],
                category=item.get("category"),
                order=item.get("order", 0),
                audio_path=item.get("audioPath"),
                audio_url=public_audio_url(base_url, guide_id, item.get("audioPath")),
                duration_sec=item.get("durationSec", 0),
            )
        )
    center = raw.get("center") or {}
    map_bounds = None
    if stops:
        from app.static_map import bounds_for_stops

        box = bounds_for_stops(stops)
        map_bounds = MapBounds(
            lat_min=box.lat_min,
            lat_max=box.lat_max,
            lon_min=box.lon_min,
            lon_max=box.lon_max,
            width=box.width,
            height=box.height,
        )
    return Guide(
        id=guide_id,
        title=raw["title"],
        subtitle=raw.get("subtitle"),
        city=raw.get("city", raw["title"]),
        region=raw.get("region"),
        aliases=raw.get("aliases", []),
        center=LatLon(lat=center.get("lat", 0), lon=center.get("lon", 0)),
        stops_count=len(stops),
        duration_sec=intro.duration_sec + sum(s.duration_sec for s in stops),
        language=raw.get("language", "ru"),
        content_version=raw.get("contentVersion", 1),
        intro=intro,
        stops=stops,
        map_url=public_map_url(base_url, guide_id),
        map_bounds=map_bounds,
    )

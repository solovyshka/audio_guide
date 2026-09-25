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
    route_mode: str | None = Field(default=None, alias="routeMode")
    route_distance_km: float | None = Field(default=None, alias="routeDistanceKm")
    estimated_duration_min: int | None = Field(default=None, alias="estimatedDurationMin")
    route_notice: str | None = Field(default=None, alias="routeNotice")
    reviewed_at: str | None = Field(default=None, alias="reviewedAt")

    model_config = ConfigDict(populate_by_name=True, ser_json_by_alias=True)


class Guide(GuideSummary):
    intro: Track
    stops: list[Stop]
    map_url: str | None = Field(default=None, alias="mapUrl")
    map_bounds: MapBounds | None = Field(default=None, alias="mapBounds")


class HistoryEvent(BaseModel):
    year: str
    text: str


class HistoryBlock(BaseModel):
    founded: str = ""
    summary: str = ""
    events: list[HistoryEvent] = []


class PresentBlock(BaseModel):
    summary: str = ""
    population: str = ""
    economy: str = ""


class CityPlace(BaseModel):
    id: str
    name: str
    lat: float
    lon: float
    kind: str
    summary: str = ""


class CityGuides(BaseModel):
    short: str | None = None
    long: str | None = None


class CitySummary(BaseModel):
    id: str
    title: str
    subtitle: str | None = None
    city: str
    region: str | None = None
    aliases: list[str] = []
    center: LatLon
    guides: CityGuides = Field(default_factory=CityGuides)
    content_version: int = Field(alias="contentVersion")
    language: str = "ru"
    reviewed_at: str | None = Field(default=None, alias="reviewedAt")
    source_urls: list[str] = Field(default_factory=list, alias="sourceUrls")

    model_config = ConfigDict(populate_by_name=True, ser_json_by_alias=True)


class City(CitySummary):
    history: HistoryBlock = Field(default_factory=HistoryBlock)
    present: PresentBlock = Field(default_factory=PresentBlock)
    sights: list[CityPlace] = []
    nature: list[CityPlace] = []
    culture: list[CityPlace] = []
    leisure: list[CityPlace] = []


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
        route_mode=raw.get("routeMode"),
        route_distance_km=raw.get("routeDistanceKm"),
        estimated_duration_min=raw.get("estimatedDurationMin"),
        route_notice=raw.get("routeNotice"),
        reviewed_at=raw.get("reviewedAt"),
        intro=intro,
        stops=stops,
        map_url=public_map_url(base_url, guide_id),
        map_bounds=map_bounds,
    )


def city_from_package(raw: dict[str, Any]) -> City:
    center = raw.get("center") or {}
    guides_raw = raw.get("guides") or {}
    history_raw = raw.get("history") or {}
    present_raw = raw.get("present") or {}
    events = [
        HistoryEvent(year=item.get("year", ""), text=item.get("text", ""))
        for item in history_raw.get("events") or []
        if isinstance(item, dict)
    ]

    def places(key: str) -> list[CityPlace]:
        out: list[CityPlace] = []
        for item in raw.get(key) or []:
            if not isinstance(item, dict):
                continue
            out.append(
                CityPlace(
                    id=item["id"],
                    name=item["name"],
                    lat=float(item["lat"]),
                    lon=float(item["lon"]),
                    kind=item.get("kind", "sight"),
                    summary=item.get("summary") or "",
                )
            )
        return out

    return City(
        id=raw["id"],
        title=raw["title"],
        subtitle=raw.get("subtitle"),
        city=raw.get("city", raw["title"]),
        region=raw.get("region"),
        aliases=raw.get("aliases") or [],
        center=LatLon(lat=center.get("lat", 0), lon=center.get("lon", 0)),
        guides=CityGuides(
            short=guides_raw.get("short"),
            long=guides_raw.get("long"),
        ),
        content_version=raw.get("contentVersion", 1),
        language=raw.get("language", "ru"),
        reviewed_at=raw.get("reviewedAt"),
        source_urls=raw.get("sourceUrls") or [],
        history=HistoryBlock(
            founded=history_raw.get("founded") or "",
            summary=history_raw.get("summary") or "",
            events=events,
        ),
        present=PresentBlock(
            summary=present_raw.get("summary") or "",
            population=present_raw.get("population") or "",
            economy=present_raw.get("economy") or "",
        ),
        sights=places("sights"),
        nature=places("nature"),
        culture=places("culture"),
        leisure=places("leisure"),
    )

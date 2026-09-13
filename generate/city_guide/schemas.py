from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, ConfigDict, Field


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Coordinates(Strict):
    lat: float
    lon: float


class Source(Strict):
    title: str
    url: str


class StopResearch(Strict):
    name: str
    coordinates: Coordinates
    address: Optional[str] = None
    category: str
    facts: List[str] = Field(min_length=1)
    dates: List[str] = Field(default_factory=list)
    people: List[str] = Field(default_factory=list)
    legends: List[str] = Field(default_factory=list)
    disputed: List[str] = Field(
        default_factory=list,
        description="Спорные пункты; в тексте — с «— неизвестно».",
    )
    next_leg: Optional[str] = Field(
        default=None,
        description=(
            "Как добраться к следующему кластеру маршрута, только если нужен "
            "отдельный переезд. Должно быть подтверждено источниками."
        ),
    )
    access_info: Optional[str] = None
    sources: List[Source] = Field(min_length=1)
    llm_coordinates: Optional[Coordinates] = Field(
        default=None,
        description=(
            "Исходные координаты research до подстановки OSM; "
            "заполняется только при osm-правке."
        ),
    )


class CoordArbitration(Strict):
    confident: bool = Field(
        description="True, если исходные координаты research верны и менять не нужно.",
    )
    reason: str = Field(description="Краткое обоснование на русском.")


class CityResearch(Strict):
    city: str
    region: str
    center: Coordinates
    subtitle: str
    aliases: List[str]
    stops: List[StopResearch] = Field(min_length=8, max_length=30)


class GuideStop(Strict):
    id: str
    name: str
    lat: float
    lon: float
    category: str
    order: int
    text: str
    audioPath: str = ""
    durationSec: int = 0


class Intro(Strict):
    title: str
    text: str
    audioPath: str = "audio/intro.wav"
    durationSec: int = 0


class CityGuide(Strict):
    id: str
    contentVersion: int
    title: str
    subtitle: str
    city: str
    region: str
    language: str
    center: Coordinates
    aliases: List[str]
    intro: Intro
    stops: List[GuideStop] = Field(min_length=8, max_length=30)
    durationSec: int = 0


class QAError(Strict):
    stop_id: Optional[str] = None
    type: str
    description: str


class QAResult(Strict):
    valid: bool
    errors: List[QAError] = Field(default_factory=list)

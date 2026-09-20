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
    access_info: Optional[str] = None
    sources: List[Source] = Field(min_length=1)


class CityResearch(Strict):
    city: str
    region: str
    center: Coordinates
    subtitle: str
    aliases: List[str]
    stops: List[StopResearch] = Field(min_length=6, max_length=30)


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
    stops: List[GuideStop] = Field(min_length=6, max_length=30)
    durationSec: int = 0


class QAError(Strict):
    stop_id: Optional[str] = None
    type: str
    description: str


class QAResult(Strict):
    valid: bool
    errors: List[QAError] = Field(default_factory=list)


class HistoryEvent(Strict):
    year: str
    text: str


class HistoryBlock(Strict):
    founded: str
    summary: str
    events: List[HistoryEvent] = Field(default_factory=list)


class PresentBlock(Strict):
    summary: str
    population: str
    economy: str


class CityPlace(Strict):
    id: str = ""
    name: str
    lat: float
    lon: float
    kind: str
    summary: str = ""


class CityGuides(Strict):
    short: Optional[str] = None
    long: Optional[str] = None


class CityDossier(Strict):
    id: str
    contentVersion: int = 1
    title: str
    subtitle: str = ""
    city: str
    region: str = ""
    language: str = "ru"
    center: Coordinates
    aliases: List[str] = Field(default_factory=list)
    history: HistoryBlock
    present: PresentBlock
    sights: List[CityPlace] = Field(default_factory=list)
    culture: List[CityPlace] = Field(default_factory=list)
    leisure: List[CityPlace] = Field(default_factory=list)
    guides: CityGuides = Field(default_factory=CityGuides)


class HistoryBlockGen(Strict):
    founded: str
    summary: str = Field(min_length=400, max_length=2500)
    events: List[HistoryEvent] = Field(min_length=5, max_length=12)


class PresentBlockGen(Strict):
    summary: str = Field(min_length=200, max_length=1600)
    population: str
    economy: str


class CityDossierGen(Strict):
    title: str
    subtitle: str
    city: str
    region: str
    aliases: List[str]
    center: Coordinates
    history: HistoryBlockGen
    present: PresentBlockGen
    sights: List[CityPlace] = Field(min_length=6, max_length=14)
    culture: List[CityPlace] = Field(min_length=4, max_length=12)
    leisure: List[CityPlace] = Field(min_length=6, max_length=14)

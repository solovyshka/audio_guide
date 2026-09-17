from typing import Literal

from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from app import generate_jobs, store
from app.config import settings
from app.models import Guide, GuideSummary
from app.static_map import ensure_map_image

router = APIRouter()


class GenerateIn(BaseModel):
    city: str = Field(min_length=2, max_length=80)
    length: Literal["short", "long"] = "short"


@router.get("/guides", response_model=list[GuideSummary])
def list_guides() -> list[GuideSummary]:
    return store.load_catalog()


@router.get("/guides/search", response_model=list[GuideSummary])
def search_guides(q: str = Query(default="")) -> list[GuideSummary]:
    return store.search_guides(q)


@router.post("/guides/generate")
def start_generate(body: GenerateIn) -> dict:
    try:
        job = generate_jobs.start_job(body.city, body.length)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return job.as_dict()


@router.get("/guides/jobs/{job_id}")
def generate_status(job_id: str) -> dict:
    job = generate_jobs.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job.as_dict()


@router.get("/guides/{guide_id}/map.png")
def get_guide_map(guide_id: str) -> FileResponse:
    guide = store.load_guide(guide_id)
    if guide is None:
        raise HTTPException(status_code=404, detail="Guide not found")
    folder = settings.content_dir / "guides" / guide_id
    path = ensure_map_image(folder, guide.stops)
    if path is None:
        raise HTTPException(status_code=503, detail="Map image unavailable")
    return FileResponse(path, media_type="image/png")


@router.get("/guides/{guide_id}", response_model=Guide)
def get_guide(guide_id: str) -> Guide:
    guide = store.load_guide(guide_id)
    if guide is None:
        raise HTTPException(status_code=404, detail="Guide not found")
    return guide

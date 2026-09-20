from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from app import generate_jobs, store
from app.models import City, CitySummary

router = APIRouter()


class CityGenerateIn(BaseModel):
    city: str = Field(min_length=2, max_length=80)


@router.get("/cities", response_model=list[CitySummary])
def list_cities() -> list[CitySummary]:
    return store.load_cities()


@router.get("/cities/search", response_model=list[CitySummary])
def search_cities(q: str = Query(default="")) -> list[CitySummary]:
    return store.search_cities(q)


@router.post("/cities/generate")
def start_city_generate(body: CityGenerateIn) -> dict:
    try:
        job = generate_jobs.start_job(body.city, length="city")
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except RuntimeError as error:
        raise HTTPException(status_code=409, detail=str(error)) from error
    return job.as_dict()


@router.get("/cities/jobs/{job_id}")
def city_job(job_id: str) -> dict:
    job = generate_jobs.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")
    return job.as_dict()


@router.get("/cities/{city_id}", response_model=City)
def get_city(city_id: str) -> City:
    city = store.load_city(city_id)
    if city is None:
        raise HTTPException(status_code=404, detail="City not found")
    return city

from fastapi import APIRouter, HTTPException

from app import store
from app.models import AreaSummary

router = APIRouter()


@router.get("/areas", response_model=list[AreaSummary])
def list_areas() -> list[AreaSummary]:
    return store.load_areas()


@router.get("/areas/{area_id}", response_model=AreaSummary)
def get_area(area_id: str) -> AreaSummary:
    area = store.load_area(area_id)
    if area is None:
        raise HTTPException(status_code=404, detail="Area not found")
    return area

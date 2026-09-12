from fastapi import APIRouter, HTTPException, Query

from app import store
from app.models import Guide, GuideSummary

router = APIRouter()


@router.get("/guides", response_model=list[GuideSummary])
def list_guides() -> list[GuideSummary]:
    return store.load_catalog()


@router.get("/guides/search", response_model=list[GuideSummary])
def search_guides(q: str = Query(default="")) -> list[GuideSummary]:
    return store.search_guides(q)


@router.get("/guides/{guide_id}", response_model=Guide)
def get_guide(guide_id: str) -> Guide:
    guide = store.load_guide(guide_id)
    if guide is None:
        raise HTTPException(status_code=404, detail="Guide not found")
    return guide

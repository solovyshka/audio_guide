from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import cities, guides

app = FastAPI(title="Audio Guide API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(guides.router)
app.include_router(cities.router)

media_root = settings.content_dir
if media_root.exists():
    app.mount("/media", StaticFiles(directory=media_root), name="media")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/app/version.json")
def app_version() -> FileResponse:
    path = Path(__file__).resolve().parents[2] / "deploy" / "out" / "version.json"
    if not path.is_file():
        raise HTTPException(status_code=404, detail="version.json missing")
    return FileResponse(path, media_type="application/json")

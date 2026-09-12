from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import guides

app = FastAPI(title="Audio Guide API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(guides.router)

media_root = settings.content_dir
if media_root.exists():
    app.mount("/media", StaticFiles(directory=media_root), name="media")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}

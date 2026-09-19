import os
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

_ENV_FILE = Path(__file__).resolve().parents[1] / ".env"
_READABLE_ENV = _ENV_FILE if os.access(_ENV_FILE, os.R_OK) else None


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=_READABLE_ENV, extra="ignore")

    database_url: str = ""
    admin_api_key: str = ""
    content_dir: Path = Path(__file__).resolve().parents[2] / "content"
    public_base_url: str = "https://audio.solovyshka.com"
    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()

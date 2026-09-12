from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = ""
    admin_api_key: str = ""
    content_dir: Path = Path(__file__).resolve().parents[2] / "content"
    public_base_url: str = "http://161.104.53.72"
    host: str = "0.0.0.0"
    port: int = 8000


settings = Settings()

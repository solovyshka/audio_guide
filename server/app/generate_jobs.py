from __future__ import annotations

import os
import re
import subprocess
import sys
import threading
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

from app import store

REPO = Path(__file__).resolve().parents[2]
if str(REPO) not in sys.path:
    sys.path.insert(0, str(REPO))
from generate.city_guide.length import guide_id_for, parse_length, profile
from generate.city_guide.slug import slugify
PYTHON = REPO / "generate" / ".venv" / "bin" / "python"
OPENAI_PROXY = os.getenv("OPENAI_HTTPS_PROXY", "http://127.0.0.1:8888")
CITY_RE = re.compile(r"^[\w\s\-.'’«»]+$", re.UNICODE)


@dataclass
class GenerateJob:
    id: str
    city: str
    status: str = "queued"
    step: str = "В очереди"
    length: str = "city"
    guide_id: str | None = None
    city_id: str | None = None
    error: str | None = None
    created_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    def as_dict(self) -> dict:
        return {
            "id": self.id,
            "city": self.city,
            "status": self.status,
            "step": self.step,
            "length": self.length,
            "guideId": self.guide_id,
            "cityId": self.city_id,
            "error": self.error,
            "createdAt": self.created_at,
        }


_LOCK = threading.Lock()
_JOBS: dict[str, GenerateJob] = {}


def _existing_guide_id(city: str, length: str) -> str | None:
    expected = guide_id_for(city, length)
    if store.load_guide(expected) is not None:
        return expected
    return None


def _existing_city_id(city: str) -> str | None:
    city_id = slugify(city)
    loaded = store.load_city(city_id)
    if loaded is None:
        return None
    if not (loaded.history.summary or "").strip():
        return None
    short_ok = loaded.guides.short and store.load_guide(loaded.guides.short)
    long_ok = loaded.guides.long and store.load_guide(loaded.guides.long)
    if short_ok and long_ok:
        return city_id
    return None


def _parse_job_length(length: str | None) -> str:
    raw = (length or "city").strip().lower()
    if raw in {"city", "город", "batch", "dossier"}:
        return "city"
    return parse_length(raw)


def _validate_city(city: str) -> str:
    city = " ".join(city.split())
    if len(city) < 2 or len(city) > 80:
        raise ValueError("Название города слишком короткое или длинное")
    if not CITY_RE.match(city):
        raise ValueError("Некорректное название города")
    return city


def get_job(job_id: str) -> GenerateJob | None:
    with _LOCK:
        return _JOBS.get(job_id)


def start_job(city: str, length: str = "city") -> GenerateJob:
    city = _validate_city(city)
    length = _parse_job_length(length)
    existing_city = _existing_city_id(city) if length == "city" else None
    existing = None if length == "city" else _existing_guide_id(city, length)
    with _LOCK:
        if existing_city:
            job = GenerateJob(
                id=uuid.uuid4().hex[:12],
                city=city,
                length=length,
                status="done",
                step="Город уже есть в каталоге",
                city_id=existing_city,
                guide_id=guide_id_for(city, "short"),
            )
            _JOBS[job.id] = job
            return job
        if existing:
            job = GenerateJob(
                id=uuid.uuid4().hex[:12],
                city=city,
                length=length,
                status="done",
                step="Гид уже есть в каталоге",
                guide_id=existing,
            )
            _JOBS[job.id] = job
            return job
        running = [
            job
            for job in _JOBS.values()
            if job.status in {"queued", "running"}
        ]
        for job in running:
            if slugify(job.city) == slugify(city) and job.length == length:
                return job
        if running:
            raise RuntimeError("Уже собирается другой гид, подождите")
        job = GenerateJob(id=uuid.uuid4().hex[:12], city=city, length=length)
        _JOBS[job.id] = job
    thread = threading.Thread(target=_run, args=(job.id,), daemon=True)
    thread.start()
    return job


def _set(job_id: str, **fields: object) -> None:
    with _LOCK:
        job = _JOBS[job_id]
        for key, value in fields.items():
            setattr(job, key, value)


def _ensure_proxy() -> None:
    from urllib.error import HTTPError, URLError
    from urllib.request import ProxyHandler, Request, build_opener

    opener = build_opener(ProxyHandler({"http": OPENAI_PROXY, "https": OPENAI_PROXY}))
    req = Request("https://api.openai.com/v1/models", method="GET")
    try:
        opener.open(req, timeout=12)
    except HTTPError:
        return
    except URLError as error:
        raise RuntimeError(
            f"OpenAI недоступен через {OPENAI_PROXY}. "
            "Проверь ovh-telegram-proxy.service"
        ) from error


def _run(job_id: str) -> None:
    with _LOCK:
        city = _JOBS[job_id].city
        length = _JOBS[job_id].length
    label = "город" if length == "city" else profile(length).label
    _set(job_id, status="running", step=f"Проверяю прокси OpenAI ({label})")
    log_lines: list[str] = []
    try:
        if not PYTHON.is_file():
            raise RuntimeError("Нет generate/.venv на FIREBAT")
        env = os.environ.copy()
        env["PYTHONUNBUFFERED"] = "1"
        env["HTTPS_PROXY"] = OPENAI_PROXY
        env["HTTP_PROXY"] = OPENAI_PROXY
        env["NO_PROXY"] = "127.0.0.1,localhost,192.168.100.0/24"
        env.pop("ALL_PROXY", None)
        _ensure_proxy()
        cmd = [str(PYTHON), "-m", "generate.city_guide", "api"]
        if length != "city":
            cmd.extend(["--length", length])
        cmd.append(city)
        proc = subprocess.Popen(
            cmd,
            cwd=str(REPO),
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        guide_id = None if length == "city" else guide_id_for(city, length)
        city_id = slugify(city)
        assert proc.stdout is not None
        for raw in proc.stdout:
            line = raw.strip()
            if not line:
                continue
            log_lines.append(line)
            if line.startswith("GUIDE_ID="):
                guide_id = line.split("=", 1)[1].strip() or guide_id
            if line.startswith("CITY_ID="):
                city_id = line.split("=", 1)[1].strip() or city_id
            _set(job_id, step=line[:240])
        code = proc.wait()
        if code != 0:
            errors = [line for line in log_lines if line.startswith("ERROR:")]
            fails = [line for line in log_lines if line.startswith("QA_FAIL")]
            if errors:
                detail = errors[-1].removeprefix("ERROR:").strip()
            elif fails:
                detail = "; ".join(item.split(": ", 1)[-1] for item in fails[:4])
            else:
                detail = "нет вывода"
            raise RuntimeError(detail)
        if length == "city":
            if store.load_city(city_id) is None:
                raise RuntimeError("Пакет города не появился в каталоге")
            _set(
                job_id,
                status="done",
                step="Готово",
                city_id=city_id,
                guide_id=guide_id,
            )
            return
        if store.load_guide(guide_id) is None:
            raise RuntimeError("Пакет не появился в каталоге")
        _set(job_id, status="done", step="Готово", guide_id=guide_id)
    except Exception as error:
        _set(job_id, status="error", error=str(error)[:500], step="Ошибка")

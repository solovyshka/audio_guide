from __future__ import annotations

import os
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request

from generate.tts.audio import duration_mp3
from generate.tts.base import BackendInfo
from generate.tts.direct_http import urlopen_direct
from generate.tts.envfile import load_env

DEFAULT_VOICE = "filipp"
SAMPLE_VOICES = ("filipp", "alena")
ENDPOINT = "https://tts.api.cloud.yandex.net/speech/v1/tts:synthesize"


class YandexBackend:
    info = BackendInfo(
        name="yandex",
        extension="mp3",
        quality="SpeechKit, самый «яндексовый» гид",
        cost="платно по символам",
        needs="YANDEX_API_KEY или YANDEX_IAM_TOKEN + YANDEX_FOLDER_ID",
    )

    def available(self) -> tuple[bool, str]:
        load_env()
        if os.environ.get("YANDEX_API_KEY") or os.environ.get("YANDEX_IAM_TOKEN"):
            return True, ""
        return False, "нет YANDEX_API_KEY / YANDEX_IAM_TOKEN"

    def synthesize(self, text: str, dest: Path, *, voice: str | None = None) -> int:
        load_env()
        api_key = os.environ.get("YANDEX_API_KEY")
        iam = os.environ.get("YANDEX_IAM_TOKEN")
        folder = os.environ.get("YANDEX_FOLDER_ID", "")
        if api_key:
            auth = f"Api-Key {api_key}"
        elif iam:
            auth = f"Bearer {iam}"
        else:
            raise RuntimeError("Нет ключа SpeechKit")

        chosen = voice or DEFAULT_VOICE
        payload = {
            "text": text,
            "lang": "ru-RU",
            "voice": chosen,
            "emotion": "good" if chosen == "alena" else "neutral",
            "speed": "0.95",
            "format": "mp3",
        }
        if folder:
            payload["folderId"] = folder
        body = urlencode(payload).encode("utf-8")
        request = Request(
            ENDPOINT,
            data=body,
            headers={
                "Authorization": auth,
                "Content-Type": "application/x-www-form-urlencoded",
            },
            method="POST",
        )
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            with urlopen_direct(request, timeout=60) as response:
                dest.write_bytes(response.read())
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")[:400]
            raise RuntimeError(f"SpeechKit HTTP {error.code}: {detail}") from error
        except URLError as error:
            raise RuntimeError(
                f"SpeechKit недоступен напрямую (без прокси/VPN): {error.reason}"
            ) from error
        return duration_mp3(dest)

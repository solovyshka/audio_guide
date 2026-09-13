from __future__ import annotations

import tempfile
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

from generate.tts.accent_ru import mark_stress
from generate.tts.audio import concat_wavs, duration_wav, split_text
from generate.tts.base import BackendInfo
from generate.tts.normalize_ru import expand_for_silero

DEFAULT_VOICE = "xenia"
SAMPLE_VOICES = ("xenia", "aidar", "baya", "kseniya", "eugene")
SAMPLE_RATE = 48000
CHUNK_LIMIT = 900
CACHE = Path(__file__).resolve().parents[2] / ".models"
GENERATE_ROOT = Path(__file__).resolve().parents[2]

# Prefer v5.5; models.silero.ai often times out from this network, then fall back to HF v4.
MODEL_CANDIDATES = (
    (
        "silero_v5_5_ru.pt",
        "https://models.silero.ai/models/tts/ru/v5_5_ru.pt",
    ),
    (
        "silero_v5_5_ru.pt",
        "https://github.com/snakers4/silero-models/releases/download/v5_5_ru/v5_5_ru.pt",
    ),
    (
        "silero_v4_ru.pt",
        "https://huggingface.co/Derur/silero-models/resolve/main/tts/ru/ru_v4/v4_ru.pt",
    ),
)


class SileroBackend:
    info = BackendInfo(
        name="silero",
        extension="wav",
        quality="локальная нейросеть Silero v5.5 (иначе v4)",
        cost="бесплатно, офлайн после скачивания модели",
        needs="torch + модель v5.5 или v4 + silero-stress",
    )

    def __init__(self) -> None:
        self._model = None
        self._device = None
        self.loaded_name = ""

    def available(self) -> tuple[bool, str]:
        try:
            import torch  # noqa: F401
        except ImportError:
            return False, "pip install torch numpy"
        return True, ""

    def synthesize(self, text: str, dest: Path, *, voice: str | None = None) -> int:
        model, device = self._load()
        speaker = voice or DEFAULT_VOICE
        spoken = expand_for_silero(text)
        chunks = [mark_stress(chunk) for chunk in split_text(spoken, CHUNK_LIMIT)]
        dest.parent.mkdir(parents=True, exist_ok=True)
        if len(chunks) == 1:
            self._write_chunk(model, device, chunks[0], speaker, dest)
            return duration_wav(dest)

        with tempfile.TemporaryDirectory() as tmp:
            parts: list[Path] = []
            for index, chunk in enumerate(chunks):
                part = Path(tmp) / f"{index:02d}.wav"
                self._write_chunk(model, device, chunk, speaker, part)
                parts.append(part)
            return concat_wavs(parts, dest)

    def _load(self):
        if self._model is not None:
            return self._model, self._device
        import torch

        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        CACHE.mkdir(parents=True, exist_ok=True)
        path = _resolve_model()
        model = torch.package.PackageImporter(str(path)).load_pickle(
            "tts_models",
            "model",
        )
        model.to(device)
        self._model = model
        self._device = device
        self.loaded_name = path.name
        return model, device

    def _write_chunk(self, model, device, text: str, speaker: str, dest: Path) -> None:
        import numpy as np
        import torch
        import wave

        kwargs = {
            "text": text,
            "speaker": speaker,
            "sample_rate": SAMPLE_RATE,
        }
        try:
            audio = model.apply_tts(**kwargs, put_accent=True, put_yo=True)
        except TypeError:
            audio = model.apply_tts(**kwargs)
        if not torch.is_tensor(audio):
            audio = torch.tensor(audio)
        samples = audio.detach().cpu().float().numpy()
        if samples.ndim > 1:
            samples = samples.reshape(-1)
        pcm = np.clip(samples * 32767, -32768, 32767).astype("<i2")
        dest.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(dest), "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(SAMPLE_RATE)
            handle.writeframes(pcm.tobytes())


def _resolve_model() -> Path:
    for directory in (CACHE, GENERATE_ROOT):
        for name in ("silero_v5_5_ru.pt", "v5_5_ru.pt"):
            local = directory / name
            if local.exists() and local.stat().st_size > 1_000_000:
                return local
    errors: list[str] = []
    seen: set[tuple[str, str]] = set()
    for filename, url in MODEL_CANDIDATES:
        key = (filename, url)
        if key in seen:
            continue
        seen.add(key)
        dest = CACHE / filename
        if dest.exists() and dest.stat().st_size > 1_000_000:
            if filename == "silero_v5_5_ru.pt":
                return dest
            continue
        try:
            _download(url, dest)
            return dest
        except Exception as error:
            errors.append(f"{url}: {error}")
            if dest.exists() and dest.stat().st_size < 1_000_000:
                dest.unlink(missing_ok=True)
    fallback = CACHE / "silero_v4_ru.pt"
    if fallback.exists() and fallback.stat().st_size > 1_000_000:
        print(
            "Silero v5.5 с models.silero.ai недоступен, используем локальный v4.",
            file=__import__("sys").stderr,
        )
        return fallback
    raise RuntimeError("Не удалось скачать Silero. " + " | ".join(errors[:3]))


def _download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    tmp = dest.with_suffix(dest.suffix + ".part")
    with urlopen(url, timeout=180) as response, tmp.open("wb") as out:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            out.write(chunk)
    if tmp.stat().st_size < 1_000_000:
        tmp.unlink(missing_ok=True)
        raise URLError(f"слишком маленький файл с {url}")
    tmp.replace(dest)

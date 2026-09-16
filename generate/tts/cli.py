from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from generate.tts.backends import ALL_BACKENDS
from generate.tts.backends.edge import SAMPLE_VOICES as EDGE_VOICES
from generate.tts.backends.silero import SAMPLE_VOICES as SILERO_VOICES
from generate.tts.backends.yandex import SAMPLE_VOICES as YANDEX_VOICES
from generate.tts.envfile import load_env
from generate.tts.guide_synth import synthesize_guide
from generate.tts.registry import get_backend

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GUIDE = ROOT / "content" / "guides" / "kolomna" / "guide.json"
SAMPLES = ROOT / "generate" / "samples"
DEFAULT_SAMPLE_VOICES = {
    "edge": EDGE_VOICES,
    "silero": SILERO_VOICES,
    "yandex": YANDEX_VOICES,
}


def main(argv: list[str] | None = None) -> None:
    load_env()
    parser = argparse.ArgumentParser(
        description="Озвучка текста для аудиогида. Не трогает плеер.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("list", help="Какие движки доступны на этой машине")

    sample = sub.add_parser("sample", help="Один абзац всеми выбранными движками")
    sample.add_argument("--backends", default="edge,sapi")
    sample.add_argument("--guide", type=Path, default=DEFAULT_GUIDE)
    sample.add_argument("--text", default="")
    sample.add_argument("--voices", default="")
    sample.add_argument("--out", type=Path, default=SAMPLES)

    guide = sub.add_parser("guide", help="Озвучить весь guide.json в отдельную папку")
    guide.add_argument("guide", nargs="?", type=Path, default=DEFAULT_GUIDE)
    guide.add_argument("--backend", default="edge")
    guide.add_argument("--voice", default="")
    guide.add_argument("--out-dir", type=Path)

    args = parser.parse_args(argv)
    if args.cmd == "list":
        _list()
        return
    if args.cmd == "sample":
        _sample(args)
        return
    _guide(args)


def _list() -> None:
    print(f"{'движок':<10} {'есть':<6} формат  заметка")
    for name, cls in ALL_BACKENDS.items():
        info = cls.info
        ok, reason = cls().available()
        mark = "да" if ok else "нет"
        note = reason or f"{info.quality}; {info.cost}"
        print(f"{name:<10} {mark:<6} {info.extension:<6} {note}")


def _sample(args) -> None:
    text = args.text.strip() or _intro_excerpt(args.guide)
    names = [item.strip() for item in args.backends.split(",") if item.strip()]
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "text.txt").write_text(text + "\n", encoding="utf-8")
    print(text)
    if any(name.strip() == "silero" for name in names):
        from generate.tts.accent_ru import mark_stress
        from generate.tts.normalize_ru import expand_for_silero

        print(mark_stress(expand_for_silero(text)))
    print()
    for name in names:
        backend = get_backend(name)
        ok, reason = backend.available()
        if not ok:
            print(f"{name}\tпропуск\t{reason}")
            continue
        requested = [item.strip() for item in args.voices.split(",") if item.strip()]
        voices = requested or DEFAULT_SAMPLE_VOICES.get(name, (None,))
        for voice in voices:
            label = (voice or "default").replace("ru-RU-", "").replace("Neural", "").lower()
            dest = args.out / f"kolomna-intro-{name}-{label}.{backend.info.extension}"
            try:
                seconds = backend.synthesize(text, dest, voice=voice)
            except Exception as error:
                print(f"{name}\tошибка\t{error}")
                continue
            extra = ""
            loaded = getattr(backend, "loaded_name", "")
            if loaded:
                extra = f"\t{loaded}"
            print(f"{dest.name}\t{seconds}s{extra}")


def _guide(args) -> None:
    guide_path = args.guide.resolve()
    data = json.loads(guide_path.read_text(encoding="utf-8"))
    out_dir = args.out_dir or (ROOT / "generate" / "out" / f"{data['id']}-{args.backend}")
    synthesize_guide(
        guide_path,
        out_dir,
        backend_name=args.backend,
        voice=args.voice or None,
    )


def _intro_excerpt(guide: Path) -> str:
    data = json.loads(guide.read_text(encoding="utf-8"))
    text = data["intro"]["text"]
    sentences = [part.strip() for part in text.split(".") if part.strip()]
    excerpt = ". ".join(sentences[:2]).strip()
    if not excerpt.endswith("."):
        excerpt += "."
    return excerpt


if __name__ == "__main__":
    main(sys.argv[1:])

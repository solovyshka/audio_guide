from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from generate.city_guide.checks import local_checks
from generate.city_guide.package import (
    dump,
    load_guide,
    load_research,
    normalize_guide,
    read_cities_list,
    save_json,
    write_package,
)
from generate.city_guide.prompts import AGENT_BATCH_STEPS, WRITER_SYSTEM
from generate.city_guide.schemas import CityGuide, CityResearch
from generate.tts.envfile import load_env

ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> None:
    load_env()
    parser = argparse.ArgumentParser(
        description="Генерация гида: research → текст → TTS. OpenAI ходит через HideMe OpenVPN.",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_val = sub.add_parser("validate", help="Локальный QA: research + guide")
    p_val.add_argument("research", type=Path)
    p_val.add_argument("guide", type=Path)

    p_nw = sub.add_parser(
        "normalize-write",
        help="Проставить audioPath, записать content/guides/{id}/, catalog",
    )
    p_nw.add_argument("--research", type=Path, required=True)
    p_nw.add_argument(
        "--guide",
        type=Path,
        required=True,
        help="Черновик guide.json (или stdin-совместимый файл)",
    )
    p_nw.add_argument("--no-catalog", action="store_true")
    p_nw.add_argument("--out-root", type=Path, help="Не content/guides, а другая папка")

    p_api = sub.add_parser(
        "api",
        help="OpenAI research+writer+QA, затем Silero в content/guides/{id}/",
    )
    p_api.add_argument("city", nargs="+")
    p_api.add_argument(
        "--length",
        choices=["short", "long"],
        default="short",
        help="Короткий (6–8 точек) или длинный (12–15) гид",
    )
    p_api.add_argument("--no-catalog", action="store_true")
    p_api.add_argument("--no-tts", action="store_true")
    p_api.add_argument("--backend", default="silero")
    p_api.add_argument("--voice", default="xenia")

    p_list = sub.add_parser(
        "list-cities",
        help="Показать очередь generate/cities.txt",
    )
    p_list.add_argument(
        "--file",
        type=Path,
        default=ROOT / "generate" / "cities.txt",
    )

    p_prompt = sub.add_parser("prompts", help="Печать system-промптов для агента")
    p_prompt.add_argument(
        "name",
        choices=["research", "writer", "qa", "fix", "agent"],
    )
    p_prompt.add_argument(
        "--length",
        choices=["short", "long"],
        default="short",
    )

    args = parser.parse_args(argv)

    if args.cmd == "validate":
        research = load_research(args.research)
        guide = load_guide(args.guide)
        guide = normalize_guide(research, guide)
        result = local_checks(research, guide)
        print(json.dumps(dump(result), ensure_ascii=False, indent=2))
        sys.exit(0 if result.valid else 1)

    if args.cmd == "normalize-write":
        research = load_research(args.research)
        guide = load_guide(args.guide)
        folder = write_package(
            research,
            guide,
            out_root=args.out_root,
            update_catalog=not args.no_catalog and args.out_root is None,
        )
        print(folder / "guide.json")
        return

    if args.cmd == "api":
        from generate.city_guide.openai_pipeline import run_api_city

        city = " ".join(args.city).strip()
        run_api_city(
            city,
            length=args.length,
            update_catalog=not args.no_catalog,
            tts=not args.no_tts,
            tts_backend=args.backend,
            tts_voice=args.voice,
        )
        return

    if args.cmd == "list-cities":
        path = args.file
        if not path.exists():
            print(f"Нет файла {path}", file=sys.stderr)
            sys.exit(1)
        for city in read_cities_list(path):
            print(city)
        return

    if args.cmd == "prompts":
        from generate.city_guide import prompts as P

        mapping = {
            "research": P.research_system(args.length),
            "writer": P.writer_system(args.length),
            "qa": P.qa_system(args.length),
            "fix": P.fix_system(args.length),
            "agent": P.AGENT_BATCH_STEPS,
        }
        print(mapping[args.name])
        return


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)

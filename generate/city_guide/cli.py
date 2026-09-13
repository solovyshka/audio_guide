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
from generate.tts.envfile import load_env

ROOT = Path(__file__).resolve().parents[2]


def main(argv: list[str] | None = None) -> None:
    load_env()
    parser = argparse.ArgumentParser(
        description="Генерация guide.json (research → текст). Озвучка отдельно: generate.tts",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_val = sub.add_parser("validate", help="Локальный QA: research + guide")
    p_val.add_argument("research", type=Path)
    p_val.add_argument("guide", type=Path)

    p_coords = sub.add_parser(
        "verify-coords",
        help="Сверка координат research с OSM (Nominatim)",
    )
    p_coords.add_argument("research", type=Path)
    p_coords.add_argument(
        "--threshold-m",
        type=float,
        default=None,
        help="Порог расхождения в метрах (по умолчанию OSM_DISTANCE_M или 200)",
    )
    p_coords.add_argument(
        "--write",
        action="store_true",
        help="Подставить OSM в research (и guide.json рядом), если LLM не уверена",
    )
    p_coords.add_argument(
        "--no-llm",
        action="store_true",
        help="Только отчёт Nominatim, без арбитража и без записи координат",
    )
    p_coords.add_argument(
        "--report",
        type=Path,
        help="Куда писать osm-report.json (по умолчанию рядом с research)",
    )

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
    p_nw.add_argument(
        "--package-id",
        help="id пакета; для длинной версии, например moscow-long",
    )
    p_nw.add_argument(
        "--variant",
        choices=["short", "long"],
        help="Подписывает title как короткий или длинный маршрут",
    )

    p_api = sub.add_parser("api", help="Полный прогон через OpenAI Responses + web_search")
    p_api.add_argument("city", nargs="+")
    p_api.add_argument("--no-catalog", action="store_true")
    p_api.add_argument(
        "--variant",
        choices=["short", "long"],
        default="short",
        help="short: 8–15 точек пешком; long: 15–30 точек и переезды",
    )

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

    args = parser.parse_args(argv)

    if args.cmd == "validate":
        research = load_research(args.research)
        guide = load_guide(args.guide)
        guide = normalize_guide(research, guide)
        result = local_checks(research, guide)
        print(json.dumps(dump(result), ensure_ascii=False, indent=2))
        sys.exit(0 if result.valid else 1)

    if args.cmd == "verify-coords":
        from generate.city_guide.osm import (
            DEFAULT_THRESHOLD_M,
            report_payload,
            verify_research_coords,
        )

        research = load_research(args.research)
        threshold = (
            args.threshold_m if args.threshold_m is not None else DEFAULT_THRESHOLD_M
        )
        arbitrate = None
        apply = bool(args.write) and not args.no_llm
        if not args.no_llm:
            from generate.city_guide.openai_pipeline import _client, arbitrate_coords

            client = _client()

            def arbitrate(stop, hit, distance_m):
                return arbitrate_coords(client, stop, hit, distance_m)

        updated, checks = verify_research_coords(
            research,
            threshold_m=threshold,
            arbitrate=arbitrate,
            apply=apply,
        )
        report = report_payload(updated, checks, threshold_m=threshold)
        report_path = args.report
        if report_path is None:
            stem = args.research.name.removesuffix(".research.json").removesuffix(
                ".json"
            )
            report_path = args.research.with_name(f"{stem}.osm-report.json")
        save_json(report, report_path)

        if apply:
            save_json(updated, args.research)
            guide_path = args.research.parent / "guide.json"
            if guide_path.exists():
                guide = load_guide(guide_path)
                package_id = guide.id
                guide = normalize_guide(updated, guide, package_id=package_id)
                save_json(guide, guide_path)

        print(json.dumps(report["counts"], ensure_ascii=False, indent=2))
        print(f"report: {report_path}")
        # Report-only (--no-llm): fail only on transport errors.
        # With LLM: also fail if arbitration itself failed or apply needed LLM.
        if args.no_llm:
            hard = sum(1 for c in checks if c.status == "nominatim_error")
        else:
            hard = sum(
                1
                for c in checks
                if c.status
                in {"nominatim_error", "llm_error", "mismatch_needs_llm"}
            )
        sys.exit(1 if hard else 0)

    if args.cmd == "normalize-write":
        research = load_research(args.research)
        guide = load_guide(args.guide)
        folder = write_package(
            research,
            guide,
            out_root=args.out_root,
            update_catalog=not args.no_catalog and args.out_root is None,
            package_id=args.package_id,
            variant=args.variant,
        )
        print(folder / "guide.json")
        return

    if args.cmd == "api":
        from generate.city_guide.openai_pipeline import run_api_city

        city = " ".join(args.city).strip()
        run_api_city(
            city,
            variant=args.variant,
            update_catalog=not args.no_catalog,
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
            "research": P.RESEARCH_SYSTEM,
            "writer": P.WRITER_SYSTEM,
            "qa": P.QA_SYSTEM,
            "fix": P.FIX_SYSTEM,
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

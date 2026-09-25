#!/usr/bin/env python3
"""Bundle city and guide JSON into the APK asset. Audio stays on the server."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONTENT = ROOT / "content"
OUT = ROOT / "app" / "assets" / "content" / "pack.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> None:
    catalog_path = CONTENT / "catalog.json"
    catalog = load(catalog_path) if catalog_path.exists() else {"cities": [], "guides": []}
    order = [item["id"] for item in catalog.get("cities") or [] if item.get("id")]
    cities_by_id: dict[str, dict] = {}
    for path in sorted((CONTENT / "cities").glob("*/city.json")):
        city = load(path)
        city_id = city.get("id") or path.parent.name
        cities_by_id[city_id] = city
    cities = [cities_by_id[city_id] for city_id in order if city_id in cities_by_id]
    cities.extend(
        city for city_id, city in cities_by_id.items() if city_id not in order
    )

    guides = []
    for path in sorted((CONTENT / "guides").glob("*/guide.json")):
        guides.append(load(path))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        json.dumps({"cities": cities, "guides": guides}, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"{OUT} cities={len(cities)} guides={len(guides)}")


if __name__ == "__main__":
    main()

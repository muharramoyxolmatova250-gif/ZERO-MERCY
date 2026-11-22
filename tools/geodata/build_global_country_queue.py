#!/usr/bin/env python3
"""Derive a deduplicated country-level processing queue from the Geofabrik catalogue."""
from __future__ import annotations
import argparse, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "data/world/global_regions.json"
OUT = ROOT / "data/world/global_country_queue.json"

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog", type=Path, default=CATALOG)
    p.add_argument("--output", type=Path, default=OUT)
    a = p.parse_args()
    catalog = json.loads(a.catalog.read_text(encoding="utf-8"))
    regions = catalog.get("regions", [])
    # Keep the shallowest downloadable extract for each ISO-3166-1 country.
    # This avoids downloading both a country PBF and all of its subdivisions.
    chosen = {}
    for region in regions:
        codes = region.get("iso3166_1") or []
        if len(codes) != 1 or not isinstance(codes[0], str) or len(codes[0]) != 2:
            continue
        code = codes[0].upper()
        region_id = str(region.get("id", ""))
        depth = region_id.count("/")
        candidate = {"id": region_id, "name": region.get("name", region_id),
                     "iso3166_1": code, "pbf_url": region.get("pbf_url"),
                     "estimated_size_bytes": region.get("estimated_size_bytes"),
                     "hierarchy_depth": depth}
        current = chosen.get(code)
        if current is None or (depth, len(region_id)) < (current["hierarchy_depth"], len(current["id"])):
            chosen[code] = candidate
    entries = sorted(chosen.values(), key=lambda x: (x["name"].casefold(), x["iso3166_1"]))
    result = {
        "schema_version": 1,
        "source_catalogue": str(a.catalog),
        "selection": "one shallowest Geofabrik extract per ISO-3166-1 code; nested subdivisions excluded",
        "country_count": len(entries),
        "countries": entries,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\\n", encoding="utf-8")
    print(f"Wrote {len(entries)} country extracts to {a.output}")
    for item in entries:
        print(f'{item["iso3166_1"]}\\t{item["id"]}\\t{item["name"]}')
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

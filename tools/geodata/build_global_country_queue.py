#!/usr/bin/env python3
"""Build a country-level OSM extract queue with global geographic bounds."""
from __future__ import annotations
import argparse, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "data/world/global_regions.json"
OUT = ROOT / "data/world/global_country_queue.json"

def build_queue(catalog: dict) -> list[dict]:
    selected, seen = [], set()
    for region in catalog.get("regions", []):
        region_id = str(region.get("id", "")).strip()
        raw_codes = region.get("iso3166_1") or []
        if isinstance(raw_codes, str):
            raw_codes = [raw_codes]
        codes = sorted({str(code).upper() for code in raw_codes
                        if isinstance(code, str) and len(code) == 2})
        bboxes = region.get("bboxes") or ([region["bbox"]] if isinstance(region.get("bbox"), list) else [])
        if not region_id or region_id in seen or not codes or not isinstance(bboxes, list):
            continue
        valid = []
        for bbox in bboxes:
            if (isinstance(bbox, list) and len(bbox) == 4
                and all(isinstance(v, (int, float)) for v in bbox)
                and -180 <= bbox[0] < bbox[2] <= 180
                and -90 <= bbox[1] < bbox[3] <= 90):
                valid.append([float(v) for v in bbox])
        if not valid:
            continue
        selected.append({
            "id": region_id, "name": str(region.get("name", region_id)),
            "iso3166_1": codes, "parent": region.get("parent"),
            "pbf_url": region.get("pbf_url"),
            "estimated_size_bytes": region.get("estimated_size_bytes"),
            "bboxes": valid,
        })
        seen.add(region_id)
    return sorted(selected, key=lambda x: (x["name"].casefold(), x["id"]))

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog", type=Path, default=CATALOG)
    p.add_argument("--output", type=Path, default=OUT)
    a = p.parse_args()
    entries = build_queue(json.loads(a.catalog.read_text(encoding="utf-8")))
    if not entries:
        raise SystemExit("No country extracts with valid ISO codes and geographic bounds were found.")
    result = {
        "schema_version": 2, "source_catalogue": str(a.catalog),
        "selection": "Geofabrik country-level extracts carrying ISO-3166-1 codes; combined extracts retain all codes",
        "country_extract_count": len(entries), "countries": entries,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} country-level extracts to {a.output}")
    for item in entries:
        print(f'{",".join(item["iso3166_1"])}\t{item["id"]}\t{item["name"]}\t{len(item["bboxes"])} bbox part(s)')
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

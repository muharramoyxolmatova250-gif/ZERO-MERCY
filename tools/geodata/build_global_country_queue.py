#!/usr/bin/env python3
"""Build the worldwide country queue, including supplemental parent extracts."""
from __future__ import annotations
import argparse, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools.geodata.build_global_manifest import _geometry_bboxes

CATALOG = ROOT / "data/world/global_regions.json"
NATURAL_EARTH = ROOT / "data/geodata/world-110m.geojson"
OUT = ROOT / "data/world/global_country_queue.json"

# Countries/territories without a dedicated Geofabrik country extract are
# clipped from their continent extract instead.
FALLBACK_PARENT_BY_ISO = {
    "EH": "africa", "TF": "africa", "FK": "south-america",
    "SA": "asia", "XK": "europe", "TT": "central-america",
}
# Keep the current Afghanistan cursor resumable, then prioritize the player's
# Uzbekistan starting region before other major world hubs.
COUNTRY_PRIORITY = {
    "UZ": 0, "AF": 1, "US": 2, "CN": 3, "JP": 4,
    "IN": 5, "KR": 6, "GB": 7, "DE": 8, "FR": 9,
}

def _iso_codes(region: dict) -> list[str]:
    raw = region.get("iso3166_1") or []
    if isinstance(raw, str):
        raw = raw.split(",")
    return sorted({str(code).strip().upper() for code in raw
                   if isinstance(code, str) and len(str(code).strip()) == 2})

def build_queue(catalog: dict, natural_earth_path: Path = NATURAL_EARTH) -> list[dict]:
    selected, seen, covered = [], set(), set()
    region_by_id = {str(item.get("id", "")): item for item in catalog.get("regions", [])}
    for region in catalog.get("regions", []):
        region_id = str(region.get("id", "")).strip()
        # A catalogue can contain overlapping/duplicate ISO assignments (for example\n        # disputed or offshore features). Keep each ISO code in exactly one queue\n        # entry so coverage totals cannot double-count a country/territory.\n        codes = [code for code in _iso_codes(region) if code not in covered]\n        bboxes = region.get("bboxes") or ([region["bbox"]] if isinstance(region.get("bbox"), list) else [])
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
            "bboxes": valid, "extract_kind": "country",
        })
        seen.add(region_id)
        covered.update(codes)

    fallback_groups: dict[str, dict] = {}
    if natural_earth_path.is_file():
        natural = json.loads(natural_earth_path.read_text(encoding="utf-8"))
        for feature in natural.get("features", []):
            props = feature.get("properties", {})
            code = str(props.get("ISO_A2_EH") or props.get("ISO_A2") or "").upper()
            parent_id = FALLBACK_PARENT_BY_ISO.get(code)
            if len(code) != 2 or code in covered or parent_id is None:
                continue
            parent = region_by_id.get(parent_id)
            if not parent or not parent.get("pbf_url"):
                continue
            boxes = _geometry_bboxes(feature.get("geometry") or {})
            if not boxes:
                continue
            group = fallback_groups.setdefault(parent_id, {
                "id": parent_id, "name": f"{parent.get('name', parent_id)} supplemental extracts",
                "iso3166_1": [], "parent": parent.get("parent"),
                "pbf_url": parent.get("pbf_url"),
                "estimated_size_bytes": parent.get("estimated_size_bytes"),
                "bboxes": [], "extract_kind": "supplemental_parent",
            })
            group["iso3166_1"].append(code)
            group["bboxes"].extend(boxes)
            covered.add(code)

    for parent_id, entry in fallback_groups.items():
        entry["iso3166_1"] = sorted(set(entry["iso3166_1"]))
        selected.append(entry)
        seen.add(parent_id)

    def priority(item: dict) -> int:
        return min((COUNTRY_PRIORITY.get(code, 100) for code in item["iso3166_1"]), default=100)
    return sorted(selected, key=lambda x: (
        x.get("extract_kind") != "country", priority(x), x["name"].casefold(), x["id"]
    ))

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--catalog", type=Path, default=CATALOG)
    p.add_argument("--natural-earth", type=Path, default=NATURAL_EARTH)
    p.add_argument("--output", type=Path, default=OUT)
    a = p.parse_args()
    entries = build_queue(json.loads(a.catalog.read_text(encoding="utf-8")), a.natural_earth)
    if not entries:
        raise SystemExit("No country extracts with valid ISO codes and geographic bounds were found.")
    supplemental = sum(item.get("extract_kind") == "supplemental_parent" for item in entries)
    codes = sorted({code for item in entries for code in item["iso3166_1"]})
    result = {
        "schema_version": 4, "source_catalogue": str(a.catalog),
        "selection": "Priority country extracts plus continent PBF fallbacks clipped to uncovered country boundaries",
        "extract_count": len(entries), "covered_iso3166_1_count": len(codes),
        "supplemental_parent_extract_count": supplemental, "countries": entries,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {len(entries)} extract jobs covering {len(codes)} ISO codes ({supplemental} supplemental parent extracts).")
    for item in entries:
        print(f'{",".join(item["iso3166_1"])}\t{item["id"]}\t{item["name"]}\t{len(item["bboxes"])} bbox part(s)')
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

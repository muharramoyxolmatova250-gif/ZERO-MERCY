#!/usr/bin/env python3
"""Validate a planned OSM tile batch and its GeoJSON exports before runtime use."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


def load_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise ValueError(f"{path}: invalid or unreadable JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{path}: expected a JSON object")
    return value


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan", type=Path, help="Tile plan JSON")
    parser.add_argument("--start", type=int, default=0, help="First tile index in the processed batch")
    parser.add_argument("--count", type=int, default=None, help="Number of tile entries to validate")
    parser.add_argument("--index", type=Path, default=Path("data/world/region_tiles.json"))
    args = parser.parse_args()
    if args.start < 0 or (args.count is not None and args.count < 1):
        parser.error("--start must be >= 0 and --count must be >= 1")

    plan = load_json(args.plan)
    tiles = plan.get("tiles")
    if not isinstance(tiles, list) or not tiles:
        raise ValueError("Tile plan contains no tiles")
    selected = tiles[args.start:] if args.count is None else tiles[args.start:args.start + args.count]
    if not selected:
        raise ValueError("Selected tile batch is empty")
    runtime = load_json(args.index)
    totals = {"tiles": 0, "features": 0, "roads": 0, "buildings": 0, "waterways": 0}
    seen_ids: set[str] = set()

    for tile in selected:
        tile_id = str(tile.get("id", ""))
        if not tile_id or tile_id in seen_ids:
            raise ValueError(f"Missing or duplicate tile id: {tile_id!r}")
        seen_ids.add(tile_id)
        path = Path(tile.get("geojson_output", ""))
        if not path.is_file() or path.stat().st_size < 2:
            raise ValueError(f"{tile_id}: missing or empty GeoJSON: {path}")
        data = load_json(path)
        if data.get("type") != "FeatureCollection" or not isinstance(data.get("features"), list):
            raise ValueError(f"{tile_id}: expected GeoJSON FeatureCollection")
        features = data["features"]
        if not features:
            raise ValueError(f"{tile_id}: no exported features")
        counts = {"roads": 0, "buildings": 0, "waterways": 0}
        for feature in features:
            props = feature.get("properties") or {}
            tags = props.get("tags") or props
            counts["roads"] += int("highway" in tags)
            counts["buildings"] += int("building" in tags)
            counts["waterways"] += int("waterway" in tags or "natural" in tags and tags.get("natural") == "water")
        if not any(counts.values()):
            raise ValueError(f"{tile_id}: no recognized road/building/water features")
        totals["tiles"] += 1
        totals["features"] += len(features)
        for key, value in counts.items():
            totals[key] += value
        bbox = tile.get("bbox")
        if not isinstance(bbox, list) or len(bbox) != 4:
            raise ValueError(f"{tile_id}: invalid geographic bbox")
        print(f"PASS {tile_id}: {len(features):,} features; {counts}; {path.stat().st_size:,} bytes")

    if totals["roads"] == 0 or totals["buildings"] == 0:
        raise ValueError(f"Batch lacks required roads/buildings: {totals}")

    indexed = 0
    for key, entry in runtime.items():
        if key.startswith("_") or not isinstance(entry, dict):
            continue
        source_regions = entry.get("source_regions", [entry.get("region")])
        if plan.get("region") in source_regions:
            indexed += 1
    if indexed < len(tiles):
        raise ValueError(f"Runtime index has {indexed} entries for region {plan.get('region')}, expected at least {len(tiles)}")
    print("VALIDATED OSM TILE BATCH:", json.dumps(totals, sort_keys=True))
    print("Attribution required: © OpenStreetMap contributors — https://www.openstreetmap.org/copyright")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"VALIDATION FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)

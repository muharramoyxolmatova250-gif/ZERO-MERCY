#!/usr/bin/env python3
"""Validate planned OSM tile GeoJSON files and their shared global runtime index."""
from __future__ import annotations
import argparse, json, math, sys
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
    parser.add_argument("plan", type=Path)
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--count", type=int, default=None)
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
    tile_size = float(runtime.get("_tile_size_m", plan.get("tile_size_m", 0)))
    if tile_size <= 0:
        raise ValueError("Runtime index is missing a valid _tile_size_m")
    totals = {"tiles": 0, "empty_tiles": 0, "features": 0,
              "roads": 0, "buildings": 0, "waterways": 0}
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
        features = data.get("features")
        if data.get("type") != "FeatureCollection" or not isinstance(features, list):
            raise ValueError(f"{tile_id}: expected GeoJSON FeatureCollection")
        counts = {"roads": 0, "buildings": 0, "waterways": 0}
        for feature in features:
            if not isinstance(feature, dict):
                raise ValueError(f"{tile_id}: invalid GeoJSON feature object")
            props = feature.get("properties") or {}
            tags = props.get("tags") or props
            counts["roads"] += int("highway" in tags)
            counts["buildings"] += int("building" in tags)
            counts["waterways"] += int("waterway" in tags or tags.get("natural") == "water")
        totals["tiles"] += 1
        totals["features"] += len(features)
        if not features:
            totals["empty_tiles"] += 1
        for key, value in counts.items():
            totals[key] += value
        bbox = tile.get("bbox")
        if (not isinstance(bbox, list) or len(bbox) != 4
            or not all(isinstance(value, (int, float)) for value in bbox)
            or not (-180 <= bbox[0] < bbox[2] <= 180 and -90 <= bbox[1] < bbox[3] <= 90)):
            raise ValueError(f"{tile_id}: invalid geographic bbox")

        tx = math.floor(float(tile["origin_x"]) / tile_size)
        tz = math.floor(float(tile["origin_z"]) / tile_size)
        key = f"{tx},{tz}"
        entry = runtime.get(key)
        if not isinstance(entry, dict):
            raise ValueError(f"{tile_id}: runtime index is missing global cell {key}")
        paths = entry.get("geojson_paths") or ([entry.get("geojson_path")] if entry.get("geojson_path") else [])
        if tile.get("godot_geojson_path") not in paths:
            raise ValueError(f"{tile_id}: source path is missing from runtime cell {key}")
        regions = entry.get("source_regions", [entry.get("region")])
        if plan.get("region") not in regions:
            raise ValueError(f"{tile_id}: runtime cell {key} does not record region {plan.get('region')}")
        state = "EMPTY" if not features else "PASS"
        print(f"{state} {tile_id}: {len(features):,} features; {counts}; {path.stat().st_size:,} bytes")

    print("VALIDATED OSM TILE BATCH:", json.dumps(totals, sort_keys=True))
    if totals["roads"] == 0 or totals["buildings"] == 0:
        print("NOTE: this batch contains no roads or no buildings; empty/rural cells are valid.")
    print("Attribution required: © OpenStreetMap contributors — https://www.openstreetmap.org/copyright")
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"VALIDATION FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)

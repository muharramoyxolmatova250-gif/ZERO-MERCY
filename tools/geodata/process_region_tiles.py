#!/usr/bin/env python3
"""Batch-extract OSM tiles in one Osmium pass, then export each tile to GeoJSON."""
from __future__ import annotations
import argparse, json, subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path, help="Downloaded source .osm.pbf")
    p.add_argument("plan", type=Path, help="Tile plan JSON")
    p.add_argument("--start", type=int, default=0)
    p.add_argument("--count", type=int, default=32)
    p.add_argument("--force", action="store_true")
    a = p.parse_args()
    if not a.source.is_file():
        p.error(f"Source PBF not found: {a.source}")
    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    tiles = plan.get("tiles", [])
    if not isinstance(tiles, list):
        p.error("Plan has no tiles array.")
    if a.start < 0 or a.count < 1:
        p.error("--start must be >=0 and --count >=1")
    selected = tiles[a.start:a.start + a.count]
    if not selected:
        print("No tile jobs in requested range.")
        return 0

    pending = []
    for tile in selected:
        pbf = ROOT / tile["pbf_output"]
        geo = ROOT / tile["geojson_output"]
        pbf.parent.mkdir(parents=True, exist_ok=True)
        geo.parent.mkdir(parents=True, exist_ok=True)
        if geo.is_file() and geo.stat().st_size > 100 and not a.force:
            print(f"Skip existing {geo}")
            continue
        west, south, east, north = tile["bbox"]
        temp_pbf = pbf.with_name(pbf.stem + ".part.osm.pbf")
        pending.append({"tile": tile, "pbf": pbf, "geo": geo, "temp_pbf": temp_pbf,
                        "extract": {"output": temp_pbf.name,
                                    "bbox": [west, south, east, north],
                                    "description": str(tile["id"])}})

    if pending:
        output_dir = pending[0]["pbf"].parent
        config_path = output_dir / f"{plan.get('region', 'region')}.extracts.json"
        config = {"directory": str(output_dir.resolve()),
                  "extracts": [item["extract"] for item in pending]}
        config_path.write_text(json.dumps(config, indent=2), encoding="utf-8")
        try:
            # Osmium reads the source once per strategy pass, not once per tile.
            run(["osmium", "extract", "--config", str(config_path), "--strategy", "complete_ways", "--verbose", str(a.source), "--overwrite"])
        finally:
            config_path.unlink(missing_ok=True)

    def export_one(item: dict) -> tuple[str, Path, int]:
        tile, pbf, geo, temp_pbf = item["tile"], item["pbf"], item["geo"], item["temp_pbf"]
        if not temp_pbf.is_file() or temp_pbf.stat().st_size < 2:
            raise RuntimeError(f"Osmium did not create tile extract: {temp_pbf}")
        temp_pbf.replace(pbf)
        geo_tmp = geo.with_name(geo.stem + ".part.geojson")
        subprocess.run(["osmium", "export", str(pbf), "-o", str(geo_tmp), "--overwrite"], check=True)
        if not geo_tmp.is_file() or geo_tmp.stat().st_size < 2:
            raise RuntimeError(f"Empty GeoJSON export: {geo_tmp}")
        # Empty FeatureCollections are legitimate for uninhabited land cells.
        data = json.loads(geo_tmp.read_text(encoding="utf-8"))
        if data.get("type") != "FeatureCollection" or not isinstance(data.get("features"), list):
            raise RuntimeError(f"Invalid GeoJSON FeatureCollection: {geo_tmp}")
        geo_tmp.replace(geo)
        return str(tile["id"]), geo, len(data["features"])

    completed = 0
    if pending:
        # The expensive PBF extraction remains a single Osmium pass; independent
        # GeoJSON conversions run concurrently to reduce per-tile overhead.
        with ThreadPoolExecutor(max_workers=min(4, len(pending))) as pool:
            futures = [pool.submit(export_one, item) for item in pending]
            for future in as_completed(futures):
                tile_id, geo, feature_count = future.result()
                completed += 1
                print(f"[{completed}/{len(pending)}] {tile_id} -> {geo} ({feature_count} features)")
    print(f"Batch complete: {completed} new tiles; {len(selected) - len(pending)} already present.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

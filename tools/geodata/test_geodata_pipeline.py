#!/usr/bin/env python3
"""Smoke-test the geographic tile planner without downloading map data."""
from __future__ import annotations
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANNER = ROOT / "tools" / "geodata" / "plan_region_tiles.py"
sys.path.insert(0, str(ROOT / "tools" / "geodata"))
from build_global_manifest import build_catalog

def main() -> int:
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        plan_path = root / "tiny-plan.json"
        index_path = root / "tiny-index.json"
        subprocess.run([
            sys.executable, str(PLANNER), "--region", "test",
            "--bbox", "10", "10", "10.1", "10.1",
            "--tile-deg", "0.05", "--anchor", "10.05", "10.05",
            "--output", str(plan_path), "--index-output", str(index_path),
        ], check=True)
        plan = json.loads(plan_path.read_text(encoding="utf-8"))
        index = json.loads(index_path.read_text(encoding="utf-8"))
        assert plan["tile_count"] == 4, plan["tile_count"]
        assert len([key for key in index if not key.startswith("_")]) == 4
        assert index["_tile_size_m"] > 100
        coords = [tuple(map(int, key.split(","))) for key in index if not key.startswith("_")]
        assert len(set(coords)) == 4, coords
        for tile in plan["tiles"]:
            west, south, east, north = tile["bbox"]
            assert west < east and south < north
            assert tile["godot_geojson_path"].startswith("res://")
        print("PASS: planner creates 4 valid geographic jobs and 4 runtime index entries.")
    catalogue = build_catalog({
        "features": [{
            "properties": {
                "id": "uzbekistan", "name": "Uzbekistan", "parent": "asia",
                "urls": {"pbf": "https://download.geofabrik.de/asia/uzbekistan/uzbekistan-latest.osm.pbf"}
            }
        }]
    })
    assert catalogue["regions"][0]["pbf_url"] == "https://download.geofabrik.de/asia/uzbekistan-latest.osm.pbf"
    print("PASS: Geofabrik Uzbekistan extract URL is normalized to the live download endpoint.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Smoke-test the geographic tile planner without downloading map data."""
from __future__ import annotations
import json, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLANNER = ROOT / "tools" / "geodata" / "plan_region_tiles.py"

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
        for tile in plan["tiles"]:
            west, south, east, north = tile["bbox"]
            assert west < east and south < north
            assert tile["godot_geojson_path"].startswith("res://")
        print("PASS: planner creates 4 valid geographic jobs and 4 runtime index entries.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

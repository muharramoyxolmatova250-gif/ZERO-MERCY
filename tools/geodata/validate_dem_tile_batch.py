#!/usr/bin/env python3
"""Validate cropped ETOPO float32 height tiles and their geographic metadata."""
from __future__ import annotations
import argparse, json, math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("plan", type=Path)
    p.add_argument("--start", type=int, default=0)
    p.add_argument("--count", type=int, default=None)
    a = p.parse_args()
    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    tiles = plan.get("tiles", [])
    selected = tiles[a.start:] if a.count is None else tiles[a.start:a.start + a.count]
    if not selected:
        raise ValueError("Selected DEM batch is empty.")
    for tile in selected:
        height_path = ROOT / tile["dem_height_path"]
        metadata_path = ROOT / tile["dem_metadata_path"]
        if not height_path.is_file() or not metadata_path.is_file():
            raise ValueError(f"{tile['id']}: missing DEM data or metadata.")
        meta = json.loads(metadata_path.read_text(encoding="utf-8"))
        width, height = int(meta.get("width", 0)), int(meta.get("height", 0))
        if width < 3 or height < 3:
            raise ValueError(f"{tile['id']}: DEM dimensions are too small.")
        expected = width * height * 4
        if height_path.stat().st_size != expected:
            raise ValueError(f"{tile['id']}: expected {expected} float32 bytes, got {height_path.stat().st_size}.")
        if meta.get("projection") != "global_equirectangular":
            raise ValueError(f"{tile['id']}: DEM projection does not match global world grid.")
        for key, value in zip(("west", "south", "east", "north"), tile["bbox"]):
            if abs(float(meta[key]) - float(value)) > 1e-6:
                raise ValueError(f"{tile['id']}: DEM {key} does not match OSM tile bbox.")
        if abs(float(meta["origin_x"]) - float(tile["origin_x"])) > 1.0:
            raise ValueError(f"{tile['id']}: DEM x origin does not align with OSM tile.")
        if abs(float(meta["origin_z"]) - float(tile["origin_z"])) > 1.0:
            raise ValueError(f"{tile['id']}: DEM z origin does not align with OSM tile.")
        if not math.isfinite(float(meta["min_elevation_m"])) or not math.isfinite(float(meta["max_elevation_m"])):
            raise ValueError(f"{tile['id']}: DEM elevation range is not finite.")
        print(f"DEM PASS {tile['id']}: {width}x{height}, "
              f"{meta['min_elevation_m']:.1f}..{meta['max_elevation_m']:.1f} m, {expected:,} bytes")
    print(f"VALIDATED DEM BATCH: {len(selected)} tiles")
    print("Source: NOAA ETOPO 2022 15-arc-second global relief model; cite DOI 10.25921/fd45-gt74.")
    return 0

if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"DEM VALIDATION FAILED: {exc}", file=sys.stderr)
        raise SystemExit(1)

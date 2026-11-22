#!/usr/bin/env python3
"""Prepare one small, reproducible OSM tile for the Godot region preview.

Requires osmium-tool. Coordinates use W,S,E,N order.
Example around Andijan:
  python tools/geodata/prepare_osm_region.py data/osm/pbf/uzbekistan-latest.osm.pbf --bbox 72.30 40.75 72.38 40.81 --tile 0,0 --anchor 72.34 40.78

The script clips the regional PBF, exports GeoJSON, and writes/updates a
Godot region tile index. It does not download the source PBF itself.
"""
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TILE_DIR = ROOT / "data" / "osm" / "tiles"
INDEX_PATH = ROOT / "data" / "world" / "region_tiles.json"


def run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, check=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Input OSM .osm.pbf")
    parser.add_argument("--bbox", nargs=4, type=float, required=True, metavar=("WEST", "SOUTH", "EAST", "NORTH"))
    parser.add_argument("--tile", default="0,0", help="Grid key x,z, e.g. 0,0")
    parser.add_argument("--anchor", nargs=2, type=float, default=[72.34, 40.78], metavar=("LON", "LAT"),
                        help="Shared local-world origin longitude/latitude")
    args = parser.parse_args()

    if not args.source.is_file():
        parser.error(f"Input PBF not found: {args.source}")
    if shutil.which("osmium") is None:
        parser.error("osmium-tool is required; install it and add osmium to PATH.")
    west, south, east, north = args.bbox
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        parser.error("bbox must satisfy -180<=west<east<=180 and -90<=south<north<=90")
    try:
        tile_x, tile_z = (int(v) for v in args.tile.split(","))
    except Exception:
        parser.error("--tile must be x,z integer pair, for example 0,0")

    TILE_DIR.mkdir(parents=True, exist_ok=True)
    INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
    stem = f"tile_{tile_x}_{tile_z}"
    clipped = TILE_DIR / f"{stem}.osm.pbf"
    geojson = TILE_DIR / f"{stem}.geojson"

    run(["osmium", "extract", "-b", f"{west},{south},{east},{north}",
         str(args.source), "-o", str(clipped), "--overwrite"])
    run(["osmium", "export", str(clipped), "-o", str(geojson), "--overwrite"])

    center_lon = (west + east) * 0.5
    center_lat = (south + north) * 0.5
    anchor_lon, anchor_lat = args.anchor
    metres_lat = 111320.0
    metres_lon = 111320.0 * math.cos(math.radians(anchor_lat))
    origin_x = (center_lon - anchor_lon) * metres_lon
    origin_z = -(center_lat - anchor_lat) * metres_lat

    if INDEX_PATH.exists():
        index = json.loads(INDEX_PATH.read_text(encoding="utf-8"))
        if not isinstance(index, dict):
            raise ValueError("Existing region tile index is not a JSON object.")
        index.pop("_comment", None)
    else:
        index = {}
    index[f"{tile_x},{tile_z}"] = {
        "geojson_path": f"res://data/osm/tiles/{stem}.geojson",
        "center_lat": center_lat,
        "center_lon": center_lon,
        "origin_x": round(origin_x, 3),
        "origin_z": round(origin_z, 3)
    }
    INDEX_PATH.write_text(json.dumps(index, indent=2), encoding="utf-8")
    print(f"GeoJSON: {geojson}")
    print(f"Updated Godot index: {INDEX_PATH}")
    print("Keep the anchor identical for every tile in this local map. Use small, adjacent bboxes.")
    print("OSM attribution: © OpenStreetMap contributors. Review ODbL before distribution.")


if __name__ == "__main__":
    main()

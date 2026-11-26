#!/usr/bin/env python3
"""Create a lightweight 0.4-degree (405,000-cell) global land mask."""
from __future__ import annotations
import json
from pathlib import Path
from shapely.geometry import Point, shape
from shapely.ops import unary_union
from shapely.prepared import prep

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "data/geodata/world-110m.geojson"
META = ROOT / "data/world/fast_global_grid.json"
MASK = ROOT / "data/world/fast_global_land_mask.bin"
STEP = 0.4
WIDTH = 900
HEIGHT = 450
COUNT = WIDTH * HEIGHT

def main() -> int:
    if not SOURCE.is_file():
        raise SystemExit(f"Natural Earth polygons not found: {SOURCE}")
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    geometries = []
    for feature in data.get("features", []):
        geometry = feature.get("geometry")
        if geometry:
            try:
                geometries.append(shape(geometry))
            except Exception as exc:
                print(f"Skipping invalid feature geometry: {exc}")
    if not geometries:
        raise SystemExit("No usable Natural Earth polygon geometries.")
    land = prep(unary_union(geometries))
    bits = bytearray((COUNT + 7) // 8)
    land_count = 0
    for y in range(HEIGHT):
        lat = -90.0 + (y + 0.5) * STEP
        for x in range(WIDTH):
            lon = -180.0 + (x + 0.5) * STEP
            if land.contains(Point(lon, lat)):
                index = y * WIDTH + x
                bits[index >> 3] |= 1 << (index & 7)
                land_count += 1
    MASK.parent.mkdir(parents=True, exist_ok=True)
    MASK.write_bytes(bits)
    metadata = {
        "schema_version": 1,
        "name": "ZERO MERCY fast global land grid",
        "source": "Natural Earth 1:110m country polygons",
        "resolution_degrees": STEP,
        "columns": WIDTH,
        "rows": HEIGHT,
        "cell_count": COUNT,
        "land_cell_count": land_count,
        "water_cell_count": COUNT - land_count,
        "mask_file": MASK.name,
        "mask_encoding": "row-major bitset; 1=cell center intersects mapped land union, 0=water",
        "mask_bytes": len(bits),
        "bounds": {"west": -180.0, "south": -90.0, "east": 180.0, "north": 90.0},
        "indexing": "index=y*900+x; x=floor((longitude+180)/0.4); y=floor((latitude+90)/0.4)",
        "purpose": "Fast low-detail whole-Earth land/water scaffold. Detailed OSM roads/buildings and DEM elevation remain separate streamed layers.",
        "attribution": "Natural Earth public domain; country geometry source is Natural Earth 1:110m"
    }
    META.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Built {COUNT:,} coarse Earth cells: {land_count:,} land, {COUNT-land_count:,} water; {len(bits):,} mask bytes.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

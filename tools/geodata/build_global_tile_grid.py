#!/usr/bin/env python3
"""Build a compact, deterministic index for the complete 0.1-degree Earth grid.

The 6,480,000 cells are implicit in the grid metadata; two bitsets record which
cells currently have verified OSM GeoJSON and DEM files. No empty per-cell files
are generated.
"""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WIDTH = 3600
HEIGHT = 1800
CELL_COUNT = WIDTH * HEIGHT
BITSET_BYTES = (CELL_COUNT + 7) // 8
STEP = 0.1

def cell_index(lon: float, lat: float) -> int:
    if not (-180.0 <= lon < 180.0 and -90.0 <= lat < 90.0):
        raise ValueError(f"coordinate outside half-open grid: {lon}, {lat}")
    x = min(WIDTH - 1, int(math.floor((lon + 180.0) / STEP + 1e-9)))
    y = min(HEIGHT - 1, int(math.floor((lat + 90.0) / STEP + 1e-9)))
    return y * WIDTH + x

def set_bit(bits: bytearray, index: int) -> None:
    bits[index >> 3] |= 1 << (index & 7)

def build(runtime_path: Path, metadata_path: Path, bitmap_path: Path, root: Path = ROOT) -> dict:
    runtime = json.loads(runtime_path.read_text(encoding="utf-8")) if runtime_path.is_file() else {}
    osm = bytearray(BITSET_BYTES)
    dem = bytearray(BITSET_BYTES)
    osm_count = dem_count = 0
    for key, entry in runtime.items():
        if key.startswith("_") or not isinstance(entry, dict):
            continue
        try:
            idx = cell_index(float(entry["center_lon"]), float(entry["center_lat"]))
        except (KeyError, TypeError, ValueError):
            continue
        paths = entry.get("geojson_paths") or ([entry.get("geojson_path")] if entry.get("geojson_path") else [])
        if any((root / str(p).removeprefix("res://")).is_file()
               and (root / str(p).removeprefix("res://")).stat().st_size > 100 for p in paths):
            if not (osm[idx >> 3] & (1 << (idx & 7))):
                set_bit(osm, idx)
                osm_count += 1
        dem_path = str(entry.get("dem_height_path", "")).removeprefix("res://")
        if dem_path and (root / dem_path).is_file() and (root / dem_path).stat().st_size > 0:
            if not (dem[idx >> 3] & (1 << (idx & 7))):
                set_bit(dem, idx)
                dem_count += 1
    bitmap_path.parent.mkdir(parents=True, exist_ok=True)
    bitmap_path.write_bytes(osm + dem)
    metadata = {
        "schema_version": 1,
        "name": "ZERO MERCY complete Earth tile grid",
        "tile_degrees": STEP,
        "columns": WIDTH,
        "rows": HEIGHT,
        "tile_count": CELL_COUNT,
        "indexing": "row-major; x=floor((longitude+180)/0.1), y=floor((latitude+90)/0.1), index=y*3600+x",
        "bounds": {"west": -180.0, "south": -90.0, "east": 180.0, "north": 90.0},
        "bounds_convention": "west/south inclusive, east/north exclusive",
        "bitmap": {
            "path": bitmap_path.name,
            "encoding": "two consecutive little-endian bitsets; bit 1 means at least one verified source file exists",
            "bytes_per_bitset": BITSET_BYTES,
            "osm_offset": 0,
            "dem_offset": BITSET_BYTES,
        },
        "osm_cells_with_files": osm_count,
        "dem_cells_with_files": dem_count,
        "note": "All cells exist implicitly in this grid. Unset bits mean source data is not yet built; they are not fabricated empty terrain or city files."
    }
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return metadata

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--runtime-index", type=Path, default=ROOT / "data/world/region_tiles.json")
    p.add_argument("--metadata", type=Path, default=ROOT / "data/world/global_tile_grid.json")
    p.add_argument("--bitmap", type=Path, default=ROOT / "data/world/global_tile_presence.bin")
    a = p.parse_args()
    result = build(a.runtime_index, a.metadata, a.bitmap)
    print(f"Global grid indexed: {result['tile_count']:,} cells ({result['columns']}x{result['rows']}); "
          f"OSM files: {result['osm_cells_with_files']:,}; DEM files: {result['dem_cells_with_files']:,}.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

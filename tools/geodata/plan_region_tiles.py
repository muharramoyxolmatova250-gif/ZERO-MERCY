#!/usr/bin/env python3
"""Create OSM tile jobs and merge them into the runtime index."""
from __future__ import annotations
import argparse, json, math
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--region", required=True)
    p.add_argument("--bbox", action="append", nargs=4, type=float,
                   required=True, metavar=("WEST", "SOUTH", "EAST", "NORTH"))
    p.add_argument("--tile-deg", type=float, default=0.05)
    p.add_argument("--anchor", nargs=2, type=float, default=[64.0, 41.0], metavar=("LON", "LAT"))
    p.add_argument("--tile-size-m", type=float, default=None)
    p.add_argument("--global-grid", action="store_true",
                   help="Use a globally aligned equirectangular tile grid shared by all countries.")
    p.add_argument("--output", type=Path)
    p.add_argument("--index-output", type=Path, default=ROOT / "data/world/region_tiles.json")
    p.add_argument("--merge-index", action="store_true")
    a = p.parse_args()
    if not (0.001 <= a.tile_deg <= 1.0):
        p.error("--tile-deg must be between 0.001 and 1.0.")
    for west, south, east, north in a.bbox:
        if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
            p.error(f"Invalid bbox: {[west, south, east, north]}")
    anchor_lon, anchor_lat = a.anchor
    if a.global_grid:
        expected = a.tile_deg * 111320.0
        tile_size_m = a.tile_size_m if a.tile_size_m is not None else expected
        if abs(tile_size_m - expected) > 0.01:
            p.error("Global grid requires tile-size-m = tile-deg * 111320.")
    else:
        tile_size_m = a.tile_size_m if a.tile_size_m is not None else min(
            4000.0, a.tile_deg * 111320.0 * math.cos(math.radians(anchor_lat)) * 0.82)
    if tile_size_m < 100:
        p.error("Tile size must be at least 100 metres.")

    tiles, index = [], {}
    for west, south, east, north in a.bbox:
        gx0, gx1 = math.floor(west / a.tile_deg), math.ceil(east / a.tile_deg)
        gy0, gy1 = math.floor(south / a.tile_deg), math.ceil(north / a.tile_deg)
        for gy in range(gy0, gy1):
            for gx in range(gx0, gx1):
                grid_w, grid_e = gx * a.tile_deg, (gx + 1) * a.tile_deg
                grid_s, grid_n = gy * a.tile_deg, (gy + 1) * a.tile_deg
                if grid_e <= west or grid_w >= east or grid_n <= south or grid_s >= north:
                    continue
                if a.global_grid:
                    w, e, s, n = grid_w, grid_e, grid_s, grid_n
                else:
                    w, e = max(west, grid_w), min(east, grid_e)
                    s, n = max(south, grid_s), min(north, grid_n)
                lat, lon = (s + n) * 0.5, (w + e) * 0.5
                if a.global_grid:
                    ox = (lon - anchor_lon) * 111320.0
                    oz = -(lat - anchor_lat) * 111320.0
                    region_width = (e - w) * 111320.0
                else:
                    ox = (lon - anchor_lon) * 111320.0 * math.cos(math.radians(anchor_lat))
                    oz = -(lat - anchor_lat) * 111320.0
                    region_width = (e - w) * 111320.0 * math.cos(math.radians(lat))
                tx, tz = math.floor(ox / tile_size_m), math.floor(oz / tile_size_m)
                key, tile_id = f"{tx},{tz}", f"{gx}_{gy}"
                entry = {
                    "id": tile_id, "bbox": [round(w, 8), round(s, 8), round(e, 8), round(n, 8)],
                    "center_lat": lat, "center_lon": lon,
                    "origin_x": round(ox, 3), "origin_z": round(oz, 3),
                    "pbf_output": f"data/osm/tiles/{a.region}/{tile_id}.osm.pbf",
                    "geojson_output": f"data/osm/tiles/{a.region}/{tile_id}.geojson",
                    "godot_geojson_path": f"res://data/osm/tiles/{a.region}/{tile_id}.geojson",
                    "region_size_m": round(max(region_width, (n - s) * 111320.0) * 1.08, 3),
                }
                tiles.append(entry)
                indexed = {
                    "geojson_path": entry["godot_geojson_path"],
                    "geojson_paths": [entry["godot_geojson_path"]],
                    "source_regions": [a.region],
                    "center_lat": lat, "center_lon": lon,
                    "origin_x": round(ox, 3), "origin_z": round(oz, 3),
                    "region_size_m": entry["region_size_m"],
                    "tile_id": tile_id, "region": a.region,
                    "projection": "global_equirectangular" if a.global_grid else "local_tangent",
                }
                if key in index:
                    p.error(f"Tile grid collision inside {a.region} at {key}; reduce tile-deg.")
                index[key] = indexed

    plan = {
        "schema_version": 3, "region": a.region,
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "source_bboxes": a.bbox, "tile_degrees": a.tile_deg,
        "tile_size_m": tile_size_m, "anchor_lon": anchor_lon, "anchor_lat": anchor_lat,
        "projection": "global_equirectangular" if a.global_grid else "local_tangent",
        "tile_count": len(tiles), "tiles": tiles,
    }
    output = a.output or ROOT / "data/world/tile_jobs" / f"{a.region}.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    runtime = {
        "_comment": "Globally aligned equirectangular tile index; not a spherical globe projection.",
        "_tile_size_m": tile_size_m, "_anchor_lon": anchor_lon, "_anchor_lat": anchor_lat,
    }
    if a.merge_index and a.index_output.is_file():
        previous = json.loads(a.index_output.read_text(encoding="utf-8"))
        if not isinstance(previous, dict):
            p.error("Existing runtime index must be a JSON object.")
        if (abs(float(previous.get("_tile_size_m", tile_size_m)) - tile_size_m) > 0.01
            or abs(float(previous.get("_anchor_lon", anchor_lon)) - anchor_lon) > 1e-8
            or abs(float(previous.get("_anchor_lat", anchor_lat)) - anchor_lat) > 1e-8):
            p.error("Cannot merge tile indexes with different grid size or anchor.")
        runtime.update({k: v for k, v in previous.items() if not str(k).startswith("_")})

    for key, entry in index.items():
        if key not in runtime:
            runtime[key] = entry
            continue
        previous = runtime[key]
        if previous.get("projection") != entry.get("projection"):
            p.error(f"Projection mismatch at global tile {key}.")
        if (abs(float(previous.get("center_lat", 0.0)) - entry["center_lat"]) > 1e-6
            or abs(float(previous.get("center_lon", 0.0)) - entry["center_lon"]) > 1e-6):
            p.error(f"Geographic tile alignment mismatch at {key}.")
        paths = list(previous.get("geojson_paths") or ([previous["geojson_path"]] if previous.get("geojson_path") else []))
        for path in entry["geojson_paths"]:
            if path not in paths:
                paths.append(path)
        regions = list(previous.get("source_regions", []))
        if a.region not in regions:
            regions.append(a.region)
        previous["geojson_paths"] = paths
        previous["geojson_path"] = paths[0] if paths else ""
        previous["source_regions"] = regions
        previous["region_size_m"] = max(float(previous.get("region_size_m", 0)), entry["region_size_m"])
        runtime[key] = previous

    a.index_output.parent.mkdir(parents=True, exist_ok=True)
    a.index_output.write_text(json.dumps(runtime, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Created {len(tiles)} tile jobs; runtime index now has {len(runtime) - 3} cells.")
    print(f"Grid cell size: {tile_size_m:.1f} m; projection: {plan['projection']}.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

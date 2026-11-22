#!/usr/bin/env python3
"""Rebuild the shared global runtime index from every committed global tile plan."""
from __future__ import annotations
import argparse, json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLAN_DIR = ROOT / "data/world/tile_jobs"
OUT = ROOT / "data/world/region_tiles.json"

def rebuild(plan_dir: Path) -> dict:
    plans = sorted(plan_dir.rglob("*.json"))
    runtime = None
    cells: dict[str, dict] = {}
    for path in plans:
        try:
            plan = json.loads(path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if plan.get("projection") != "global_equirectangular":
            continue
        tile_size = float(plan["tile_size_m"])
        anchor_lon, anchor_lat = float(plan["anchor_lon"]), float(plan["anchor_lat"])
        if runtime is None:
            runtime = {"_comment": "Rebuilt from global equirectangular tile plans; not a spherical globe projection.",
                       "_tile_size_m": tile_size, "_anchor_lon": anchor_lon, "_anchor_lat": anchor_lat}
        elif (abs(runtime["_tile_size_m"] - tile_size) > 0.01
              or abs(runtime["_anchor_lon"] - anchor_lon) > 1e-8
              or abs(runtime["_anchor_lat"] - anchor_lat) > 1e-8):
            raise ValueError(f"{path}: incompatible global tile grid metadata")
        region = str(plan.get("region", ""))
        for tile in plan.get("tiles", []):
            ox, oz = float(tile["origin_x"]), float(tile["origin_z"])
            key = f"{math.floor(ox / tile_size)},{math.floor(oz / tile_size)}"
            source_path = str(tile["godot_geojson_path"])
            entry = cells.get(key)
            if entry is None:
                cells[key] = {
                    "geojson_path": source_path, "geojson_paths": [source_path],
                    "source_regions": [region], "center_lat": float(tile["center_lat"]),
                    "center_lon": float(tile["center_lon"]), "origin_x": ox, "origin_z": oz,
                    "region_size_m": float(tile["region_size_m"]), "tile_id": str(tile["id"]),
                    "region": region, "projection": "global_equirectangular",
                }
                continue
            if (abs(entry["center_lat"] - float(tile["center_lat"])) > 1e-6
                or abs(entry["center_lon"] - float(tile["center_lon"])) > 1e-6):
                raise ValueError(f"{path}: tile alignment collision at {key}")
            if source_path not in entry["geojson_paths"]:
                entry["geojson_paths"].append(source_path)
            if region not in entry["source_regions"]:
                entry["source_regions"].append(region)
            entry["region_size_m"] = max(entry["region_size_m"], float(tile["region_size_m"]))
    if runtime is None:
        raise ValueError(f"No global equirectangular tile plans found in {plan_dir}")
    runtime.update(cells)
    return runtime

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--plans", type=Path, default=PLAN_DIR)
    p.add_argument("--output", type=Path, default=OUT)
    a = p.parse_args()
    data = rebuild(a.plans)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Rebuilt global runtime index with {len(data) - 3} cells from committed plans.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

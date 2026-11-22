#!/usr/bin/env python3
"""Build cropped ETOPO terrain samples for a bounded batch of global OSM tile jobs."""
from __future__ import annotations
import argparse, json, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOWNLOADER = ROOT / "tools/geodata/download_etopo_tile.py"
CONVERTER = ROOT / "tools/geodata/convert_dem.py"

def run_capture(command: list[str]) -> str:
    print("+", " ".join(command), flush=True)
    result = subprocess.run(command, check=True, text=True, capture_output=True)
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        raise RuntimeError("DEM source downloader did not return a file path.")
    return lines[-1]

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("plan", type=Path)
    p.add_argument("--start", type=int, default=0)
    p.add_argument("--count", type=int, default=8)
    p.add_argument("--source-dir", type=Path, default=ROOT / "data/terrain/source")
    p.add_argument("--max-size", type=int, default=129)
    p.add_argument("--force", action="store_true")
    a = p.parse_args()
    if a.start < 0 or a.count < 1 or a.max_size < 3:
        p.error("--start must be >=0, --count >=1 and --max-size >=3")
    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    if plan.get("projection") != "global_equirectangular":
        p.error("DEM batch requires a global equirectangular tile plan.")
    tiles = plan.get("tiles", [])
    selected = tiles[a.start:a.start + a.count]
    if not selected:
        print("No DEM jobs in requested range.")
        return 0
    built = skipped = 0
    for tile in selected:
        height_rel = tile.get("dem_height_path", "")
        metadata_rel = tile.get("dem_metadata_path", "")
        if not height_rel or not metadata_rel:
            raise ValueError(f"{tile.get('id')}: global DEM output paths are missing from plan.")
        height_path, metadata_path = ROOT / height_rel, ROOT / metadata_rel
        if height_path.is_file() and metadata_path.is_file() and not a.force:
            meta = json.loads(metadata_path.read_text(encoding="utf-8"))
            if height_path.stat().st_size == int(meta["width"]) * int(meta["height"]) * 4:
                print(f"Skip existing DEM tile {tile['id']}")
                skipped += 1
                continue
        bbox = [float(v) for v in tile["bbox"]]
        source = run_capture([
            sys.executable, str(DOWNLOADER), "--bbox", *map(str, bbox),
            "--output-dir", str(a.source_dir),
        ])
        command = [
            sys.executable, str(CONVERTER), source,
            "--bbox", *map(str, bbox),
            "--output", str(height_path), "--metadata", str(metadata_path),
            "--anchor-lon", str(plan["anchor_lon"]), "--anchor-lat", str(plan["anchor_lat"]),
            "--global-grid", "--clamp-sea-level", "--max-size", str(a.max_size),
        ]
        subprocess.run(command, check=True)
        meta = json.loads(metadata_path.read_text(encoding="utf-8"))
        expected = int(meta["width"]) * int(meta["height"]) * 4
        if height_path.stat().st_size != expected:
            raise RuntimeError(f"{tile['id']}: DEM float32 byte count does not match metadata.")
        built += 1
        print(f"DEM PASS {tile['id']}: {meta['width']}x{meta['height']} samples, "
              f"{meta['min_elevation_m']:.1f}..{meta['max_elevation_m']:.1f} m")
    print(f"DEM batch complete: {built} built, {skipped} reused.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

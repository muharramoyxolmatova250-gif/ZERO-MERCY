#!/usr/bin/env python3
"""Build cropped ETOPO terrain samples for a bounded batch of global OSM tile jobs."""
from __future__ import annotations
import argparse, json, subprocess, sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONVERTER = ROOT / "tools/geodata/convert_dem.py"
# One ETOPO source TIFF can cover many adjacent 0.1-degree cells. Download each
# distinct source once, then crop independent outputs concurrently.
from download_etopo_tile import source_tile_name, download

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("plan", type=Path)
    p.add_argument("--start", type=int, default=0)
    p.add_argument("--count", type=int, default=64)
    p.add_argument("--source-dir", type=Path, default=ROOT / "data/terrain/source")
    p.add_argument("--max-size", type=int, default=129)
    p.add_argument("--force", action="store_true")
    p.add_argument("--workers", type=int, default=4)
    a = p.parse_args()
    if a.start < 0 or a.count < 1 or a.max_size < 3 or a.workers < 1:
        p.error("--start >=0, --count >=1, --max-size >=3 and --workers >=1 are required")
    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    if plan.get("projection") != "global_equirectangular":
        p.error("DEM batch requires a global equirectangular tile plan.")
    tiles = plan.get("tiles", [])
    selected = tiles[a.start:a.start + a.count]
    if not selected:
        print("No DEM jobs in requested range.")
        return 0

    pending = []
    source_bboxes = {}
    skipped = 0
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
        source_name = source_tile_name(*bbox)
        source_bboxes.setdefault(source_name, bbox)
        pending.append((tile, height_path, metadata_path, source_name))

    sources = {}
    for source_name, bbox in source_bboxes.items():
        sources[source_name] = download(*bbox, a.source_dir)

    def convert_one(job):
        tile, height_path, metadata_path, source_name = job
        height_path.parent.mkdir(parents=True, exist_ok=True)
        metadata_path.parent.mkdir(parents=True, exist_ok=True)
        bbox = [float(v) for v in tile["bbox"]]
        command = [
            sys.executable, str(CONVERTER), str(sources[source_name]),
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
        return tile["id"], meta

    built = 0
    with ThreadPoolExecutor(max_workers=min(a.workers, len(pending) or 1)) as pool:
        futures = [pool.submit(convert_one, job) for job in pending]
        for future in as_completed(futures):
            tile_id, meta = future.result()
            built += 1
            print(f"DEM PASS {tile_id}: {meta['width']}x{meta['height']} samples, "
                  f"{meta['min_elevation_m']:.1f}..{meta['max_elevation_m']:.1f} m")
    print(f"DEM batch complete: {built} built, {skipped} reused; "
          f"{len(sources)} unique source TIFFs, {min(a.workers, len(pending) or 1)} conversion workers.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

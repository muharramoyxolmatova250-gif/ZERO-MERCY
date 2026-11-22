#!/usr/bin/env python3
"""Download the NOAA ETOPO 2022 15-arc-second source tile covering a geographic bbox."""
from __future__ import annotations
import argparse, math, time, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "https://www.ngdc.noaa.gov/mgg/global/relief/ETOPO2022/data/15s/15s_surface_elev_gtif/"

def source_tile_name(west: float, south: float, east: float, north: float) -> str:
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        raise ValueError("bbox must be a non-wrapping WGS84 rectangle")
    north_edge = max(-90, min(90, math.ceil((north - 1e-10) / 15.0) * 15))
    west_edge = max(-180, min(165, math.floor((west + 1e-10) / 15.0) * 15))
    lat_prefix = "N" if north_edge >= 0 else "S"
    lon_prefix = "E" if west_edge >= 0 else "W"
    return f"ETOPO_2022_v1_15s_{lat_prefix}{abs(north_edge):02d}{lon_prefix}{abs(west_edge):03d}_surface.tif"

def download(west: float, south: float, east: float, north: float,
             output_dir: Path, attempts: int = 5) -> Path:
    filename = source_tile_name(west, south, east, north)
    target = output_dir / filename
    output_dir.mkdir(parents=True, exist_ok=True)
    if target.is_file() and target.stat().st_size > 1_000_000:
        print(f"Using cached ETOPO source tile {target}")
        return target
    url = BASE + filename
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    temporary = target.with_name(target.stem + ".part.tif")
    last_error = None
    for attempt in range(attempts):
        try:
            print(f"Downloading {filename} (attempt {attempt + 1}/{attempts})...")
            with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as out:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    out.write(chunk)
            if temporary.stat().st_size < 1_000_000:
                raise RuntimeError("ETOPO tile is unexpectedly small.")
            with temporary.open("rb") as source:
                signature = source.read(4)
            if signature not in (b"II*\x00", b"MM\x00*"):
                raise RuntimeError("Downloaded file is not a TIFF.")
            temporary.replace(target)
            print(f"Saved {target} ({target.stat().st_size:,} bytes)")
            return target
        except Exception as exc:
            last_error = exc
            temporary.unlink(missing_ok=True)
            if attempt + 1 < attempts:
                delay = min(45, 4 * (2 ** attempt))
                print(f"ETOPO download failed ({exc}); retrying in {delay}s...")
                time.sleep(delay)
    raise RuntimeError(f"Could not download ETOPO tile {filename}: {last_error}")

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bbox", nargs=4, type=float, required=True,
                   metavar=("WEST", "SOUTH", "EAST", "NORTH"))
    p.add_argument("--output-dir", type=Path, default=ROOT / "data/terrain/source")
    a = p.parse_args()
    result = download(*a.bbox, a.output_dir)
    print(result)
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

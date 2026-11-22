#!/usr/bin/env python3
"""Download Copernicus DEM GLO-30 COG tiles for a geographic bounding box.

Example (Andijan / eastern Uzbekistan):
  python tools/geodata/download_copernicus_dem.py --bbox 72.0 40.0 73.5 41.0

Coordinates are: west south east north. Each requested tile is 1x1 degree.
The public AWS bucket is unauthenticated; GLO-30 Public has a few unreleased
tiles, so missing tiles are reported and skipped. Requires no AWS credentials.
"""
from __future__ import annotations

import argparse
import math
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "dem" / "copernicus-glo30"
BASE = "https://copernicus-dem-30m.s3.amazonaws.com"


def coord_token(value: int, positive: str, negative: str, width: int) -> str:
    return f"{positive if value >= 0 else negative}{abs(value):0{width}d}_00"


def tile_stem(lat: int, lon: int) -> str:
    # Copernicus naming uses 2 digits for latitude and 3 for longitude.
    return f"Copernicus_DSM_COG_10_{coord_token(lat, 'N', 'S', 2)}_{coord_token(lon, 'E', 'W', 3)}_DEM"

def download_tile(lat: int, lon: int) -> bool:
    stem = tile_stem(lat, lon)
    url = f"{BASE}/{stem}/{stem}.tif"
    target = OUT / f"{stem}.tif"
    if target.exists() and target.stat().st_size > 1024:
        print(f"Already present: {target.name}")
        return True
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            if response.status != 200:
                print(f"Unavailable ({response.status}): {stem}")
                return False
            data = response.read()
        if len(data) < 1024:
            print(f"Invalid/empty response: {stem}")
            return False
        OUT.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        print(f"Downloaded {target.name} ({len(data):,} bytes)")
        return True
    except urllib.error.HTTPError as exc:
        print(f"Tile unavailable ({exc.code}): {stem}")
    except Exception as exc:
        print(f"Download failed for {stem}: {exc}")
    return False


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bbox", nargs=4, type=float, metavar=("WEST", "SOUTH", "EAST", "NORTH"), required=True)
    args = parser.parse_args()
    west, south, east, north = args.bbox
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        parser.error("bbox must satisfy -180<=west<east<=180 and -90<=south<north<=90")
    # Tile names refer to the southwest integer-degree corner.
    min_lon, max_lon = math.floor(west), math.ceil(east) - 1
    min_lat, max_lat = math.floor(south), math.ceil(north) - 1
    total = (max_lon - min_lon + 1) * (max_lat - min_lat + 1)
    print(f"Requesting {total} one-degree GLO-30 tiles into {OUT}")
    ok = 0
    for lat in range(min_lat, max_lat + 1):
        for lon in range(min_lon, max_lon + 1):
            ok += int(download_tile(lat, lon))
    print(f"Finished: {ok}/{total} tiles available.")
    print("Source: Copernicus DEM GLO-30 Public. Check the current licence before redistribution.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Download Natural Earth country polygons for ZERO MERCY.

Usage:
  python tools/geodata/download_natural_earth.py --scale 110m
  python tools/geodata/download_natural_earth.py --scale 50m
  python tools/geodata/download_natural_earth.py --scale all

Natural Earth vector data is public domain. See:
https://www.naturalearthdata.com/about/terms-of-use/
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "geodata"
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
FILES = {
    "110m": "ne_110m_admin_0_countries.geojson",
    "50m": "ne_50m_admin_0_countries.geojson",
}
HYDROGRAPHY = {
    "rivers": ("ne_110m_rivers_lake_centerlines.geojson", {"LineString", "MultiLineString"}),
    "lakes": ("ne_110m_lakes.geojson", {"Polygon", "MultiPolygon"}),
    "elevation_points": ("ne_110m_geography_regions_elevation_points.geojson", {"Point"}),
}


def download(scale: str, reuse_existing: bool = False, attempts: int = 5) -> None:
    filename = FILES[scale]
    url = f"{BASE}/{filename}"
    target = OUT / f"world-{scale}.geojson"
    OUT.mkdir(parents=True, exist_ok=True)
    def validate(raw: bytes) -> tuple[int, int]:
        parsed = json.loads(raw)
        features = parsed.get("features", [])
        if parsed.get("type") != "FeatureCollection" or len(features) < 100:
            raise RuntimeError(f"Unexpected or incomplete GeoJSON FeatureCollection from {url}")
        invalid = []
        for index, feature in enumerate(features):
            geometry = feature.get("geometry") or {}
            if geometry.get("type") not in {"Polygon", "MultiPolygon"} or not geometry.get("coordinates"):
                invalid.append(index)
        if invalid:
            raise RuntimeError(f"Country dataset contains {len(invalid)} invalid geometries; first indexes: {invalid[:10]}")
        return len(features), len(raw)

    if reuse_existing and target.is_file():
        count, size = validate(target.read_bytes())
        print(f"Reusing validated {target.relative_to(ROOT)} ({count} map features, {size:,} bytes)")
        return
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    last_error = None
    for attempt in range(attempts):
        try:
            print(f"Downloading {scale} country boundaries (attempt {attempt + 1}/{attempts})...")
            with urllib.request.urlopen(request, timeout=90) as response:
                raw = response.read()
            count, size = validate(raw)
            target.write_bytes(raw)
            print(f"Validated and saved {target.relative_to(ROOT)} ({count} map features, {size:,} bytes)")
            return
        except Exception as exc:
            last_error = exc
            if attempt + 1 < attempts:
                delay = min(30, 3 * (2 ** attempt))
                print(f"Boundary download failed ({exc}); retrying in {delay}s...")
                time.sleep(delay)
    raise RuntimeError(f"Could not download {scale} country boundaries after {attempts} attempts: {last_error}")




def download_hydrography(reuse_existing: bool = False, attempts: int = 5) -> None:
    for layer, (filename, allowed_geometry) in HYDROGRAPHY.items():
        url = f"${BASE}/{filename}"
        target = OUT / f"world-110m-{layer}.geojson"
        def validate(raw: bytes) -> tuple[int, int]:
            parsed = json.loads(raw)
            features = parsed.get("features", [])
            if parsed.get("type") != "FeatureCollection" or not features:
                raise RuntimeError(f"Invalid hydrography FeatureCollection from {url}")
            invalid = [i for i, feature in enumerate(features)
                       if (feature.get("geometry") or {}).get("type") not in allowed_geometry]
            if invalid:
                raise RuntimeError(f"{layer}: invalid geometries at feature indexes {invalid[:10]}")
            return len(features), len(raw)
        if reuse_existing and target.is_file():
            count, size = validate(target.read_bytes())
            print(f"Reusing validated {target.relative_to(ROOT)} ({count} features, {size:,} bytes)")
            continue
        request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
        last_error = None
        for attempt in range(attempts):
            try:
                print(f"Downloading Natural Earth {layer} (attempt {attempt + 1}/{attempts})...")
                with urllib.request.urlopen(request, timeout=90) as response:
                    raw = response.read()
                count, size = validate(raw)
                target.write_bytes(raw)
                print(f"Saved {target.relative_to(ROOT)} ({count} features, {size:,} bytes)")
                break
            except Exception as exc:
                last_error = exc
                if attempt + 1 < attempts:
                    delay = min(30, 3 * (2 ** attempt))
                    print(f"{layer} download failed ({exc}); retrying in {delay}s...")
                    time.sleep(delay)
        else:
            raise RuntimeError(f"Could not download {layer} after {attempts} attempts: {last_error}")

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", choices=["110m", "50m", "all"], default="110m")
    parser.add_argument("--reuse-existing", action="store_true", help="Validate and reuse existing boundary files.")
    parser.add_argument("--hydrography", action="store_true", help="Also download global rivers and lakes.")
    args = parser.parse_args()
    scales = FILES if args.scale == "all" else [args.scale]
    for scale in scales:
        download(scale, reuse_existing=args.reuse_existing)
    if args.hydrography:
        download_hydrography(reuse_existing=args.reuse_existing)
    print("Done. Open scenes/world/earth_globe.tscn in Godot 4.3+ to view the globe.")


if __name__ == "__main__":
    main()

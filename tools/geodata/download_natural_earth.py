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
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "geodata"
BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson"
FILES = {
    "110m": "ne_110m_admin_0_countries.geojson",
    "50m": "ne_50m_admin_0_countries.geojson",
}


def download(scale: str) -> None:
    filename = FILES[scale]
    url = f"{BASE}/{filename}"
    target = OUT / f"world-{scale}.geojson"
    OUT.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    print(f"Downloading {scale} country boundaries...")
    with urllib.request.urlopen(request, timeout=90) as response:
        raw = response.read()
    # Validate before replacing a previously downloaded file.
    parsed = json.loads(raw)
    features = parsed.get("features", [])
    if parsed.get("type") != "FeatureCollection" or len(features) < 100:
        raise RuntimeError(f"Unexpected or incomplete GeoJSON FeatureCollection from {url}")
    invalid = []
    for index, feature in enumerate(features):
        geometry = feature.get("geometry") or {}
        geometry_type = geometry.get("type")
        coordinates = geometry.get("coordinates")
        if geometry_type not in {"Polygon", "MultiPolygon"} or not coordinates:
            invalid.append(index)
    if invalid:
        raise RuntimeError(
            f"Country dataset contains {len(invalid)} invalid geometries; "
            f"first invalid feature indexes: {invalid[:10]}"
        )
    target.write_bytes(raw)
    print(
        f"Validated and saved {target.relative_to(ROOT)} "
        f"({len(features)} map features, {len(raw):,} bytes)"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", choices=["110m", "50m", "all"], default="110m")
    args = parser.parse_args()
    scales = FILES if args.scale == "all" else [args.scale]
    for scale in scales:
        download(scale)
    print("Done. Open scenes/world/earth_globe.tscn in Godot 4.3+ to view the globe.")


if __name__ == "__main__":
    main()

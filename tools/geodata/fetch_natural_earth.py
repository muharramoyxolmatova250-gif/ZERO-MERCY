#!/usr/bin/env python3
"""Fetch Natural Earth 1:110m country boundaries for the ZERO MERCY globe.

The downloaded GeoJSON is a source asset and is intentionally not embedded in
this repository. Natural Earth data is public domain; keep its source metadata.
"""
from __future__ import annotations
import argparse, json, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"
TARGET = ROOT / "data" / "world" / "natural_earth_countries.geojson"

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=TARGET)
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()
    if args.output.exists() and not args.force:
        data = json.loads(args.output.read_text(encoding="utf-8"))
        print(f"Already present: {args.output} ({len(data.get('features', []))} countries/features)")
        return 0
    request = urllib.request.Request(SOURCE, headers={"User-Agent": "ZERO-MERCY-world-map/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        payload = response.read()
    data = json.loads(payload)
    if data.get("type") != "FeatureCollection" or not isinstance(data.get("features"), list):
        raise RuntimeError("Natural Earth source did not return a GeoJSON FeatureCollection.")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(payload)
    print(f"Saved {len(data['features'])} country features to {args.output}")
    print("Source: Natural Earth 1:110m Admin 0 Countries (public domain)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

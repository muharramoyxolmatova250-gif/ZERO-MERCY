#!/usr/bin/env python3
"""Discover and download a Geofabrik OpenStreetMap PBF extract by region ID.

Examples:
  python tools/geodata/download_osm_extract.py --list
  python tools/geodata/download_osm_extract.py --region uzbekistan
  python tools/geodata/download_osm_extract.py --region asia

The index is machine-readable and maintained by Geofabrik. Country/region PBFs
can be large; inspect the selected URL and available disk space before download.
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "osm" / "pbf"
INDEX_URL = "https://download.geofabrik.de/index-v1-nogeom.json"


def fetch_json(url: str):
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return json.loads(response.read())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--region", help="Geofabrik extract ID, e.g. uzbekistan or asia")
    parser.add_argument("--list", action="store_true", help="List matching available extract IDs and names")
    args = parser.parse_args()
    if not args.list and not args.region:
        parser.error("provide --region REGION_ID or --list")

    print("Reading Geofabrik extract index...")
    index = fetch_json(INDEX_URL)
    features = index.get("features", [])
    if args.list:
        for feature in features:
            props = feature.get("properties", {})
            print(f"{props.get('id', '')}\t{props.get('name', '')}")
        return

    matches = [f.get("properties", {}) for f in features
               if str(f.get("properties", {}).get("id", "")).lower() == args.region.lower()]
    if not matches:
        parser.error(f"No Geofabrik extract ID found: {args.region}. Use --list.")
    props = matches[0]
    url = props.get("urls", {}).get("pbf")
    if not url:
        parser.error(f"No public PBF URL available for {args.region}")
    filename = url.rsplit("/", 1)[-1]
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / filename
    if target.exists() and target.stat().st_size > 1024:
        print(f"Already downloaded: {target}")
        return

    print(f"Region: {props.get('name')} ({props.get('id')})")
    print(f"Source: {url}")
    print("Downloading OSM PBF; this may take time and disk space...")
    request = urllib.request.Request(url, headers={"User-Agent": "ZERO-MERCY-geodata/1.0"})
    temporary = target.with_suffix(target.suffix + ".part")
    try:
        with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as out:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out.write(chunk)
        if temporary.stat().st_size < 1024:
            raise RuntimeError("Downloaded file is unexpectedly small.")
        temporary.replace(target)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    print(f"Saved: {target} ({target.stat().st_size:,} bytes)")
    print("Attribution required: © OpenStreetMap contributors. See OSM ODbL terms.")


if __name__ == "__main__":
    main()

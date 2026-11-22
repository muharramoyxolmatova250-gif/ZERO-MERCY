#!/usr/bin/env python3
"""Build a machine-readable global OSM extract catalogue.

The catalogue is generated from Geofabrik's official no-geometry index. It
records downloadable regional PBFs; it does not download the planet by default.
Use --download to fetch selected extracts after checking disk space.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX_URL = "https://download.geofabrik.de/index-v1-nogeom.json"
OUT = ROOT / "data" / "world" / "global_regions.json"
PBF_DIR = ROOT / "data" / "osm" / "pbf"
USER_AGENT = "ZERO-MERCY-world-builder/1.0"


def read_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.loads(response.read())


def safe_id(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "_", value).strip("_")


def build_catalog(index: dict) -> dict:
    features = index.get("features", [])
    if not isinstance(features, list):
        raise ValueError("Geofabrik index has no FeatureCollection features array.")
    entries = []
    for feature in features:
        props = feature.get("properties", {})
        urls = props.get("urls", {})
        pbf = urls.get("pbf")
        if not pbf:
            continue
        region_id = str(props.get("id", "")).strip()
        if not region_id:
            continue
        entries.append({
            "id": region_id,
            "name": str(props.get("name", region_id)),
            "parent": props.get("parent"),
            "iso3166_1": props.get("iso3166-1:alpha2", []),
            "iso3166_2": props.get("iso3166-2", []),
            "pbf_url": pbf,
            "updates_url": urls.get("updates"),
            "estimated_size_bytes": props.get("pbf_file_size"),
        })
    entries.sort(key=lambda item: (item["name"].casefold(), item["id"]))
    return {
        "schema_version": 1,
        "source": INDEX_URL,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "attribution": "© OpenStreetMap contributors",
        "license": "Open Database License (ODbL) 1.0",
        "regions": entries,
    }


def download(entry: dict, force: bool = False) -> Path:
    PBF_DIR.mkdir(parents=True, exist_ok=True)
    filename = safe_id(entry["id"].replace("/", "_")) + ".osm.pbf"
    target = PBF_DIR / filename
    if target.exists() and target.stat().st_size > 1024 and not force:
        print(f"Already present: {target}")
        return target
    request = urllib.request.Request(entry["pbf_url"], headers={"User-Agent": USER_AGENT})
    temporary = target.with_suffix(target.suffix + ".part")
    print(f"Downloading {entry['name']} ({entry['id']})")
    print(f"Source: {entry['pbf_url']}")
    try:
        with urllib.request.urlopen(request, timeout=180) as response, temporary.open("wb") as out:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                out.write(chunk)
        if temporary.stat().st_size < 1024:
            raise RuntimeError("Downloaded PBF is unexpectedly small.")
        temporary.replace(target)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    print(f"Saved {target} ({target.stat().st_size:,} bytes)")
    return target


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT, help="JSON catalogue output path")
    parser.add_argument("--list", action="store_true", help="Print all catalogue region IDs and names")
    parser.add_argument("--region", action="append", default=[], help="Exact Geofabrik region ID; repeatable")
    parser.add_argument("--download", action="store_true", help="Download the selected --region entries")
    parser.add_argument("--force", action="store_true", help="Replace existing PBF files")
    args = parser.parse_args()

    print("Fetching Geofabrik global extract index...")
    catalog = build_catalog(read_json(INDEX_URL))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Catalogue saved: {args.output} ({len(catalog['regions'])} downloadable entries)")

    by_id = {entry["id"]: entry for entry in catalog["regions"]}
    if args.list:
        for entry in catalog["regions"]:
            codes = ",".join(entry["iso3166_1"]) if entry["iso3166_1"] else "-"
            print(f"{entry['id']}\t{entry['name']}\t{codes}")
    if args.region:
        missing = [region for region in args.region if region not in by_id]
        if missing:
            print("Unknown region IDs: " + ", ".join(missing), file=sys.stderr)
            return 2
        for region in args.region:
            entry = by_id[region]
            print(f"Selected: {entry['name']} — {entry['pbf_url']}")
            if args.download:
                download(entry, args.force)
    elif args.download:
        parser.error("--download requires at least one --region ID. Planet-scale downloads are never implicit.")

    print("Attribution required: © OpenStreetMap contributors — https://www.openstreetmap.org/copyright")
    print("Review ODbL 1.0 obligations before redistributing derived databases.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

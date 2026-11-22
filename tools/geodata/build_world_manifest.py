#!/usr/bin/env python3
"""Build a reproducible catalogue of worldwide Geofabrik OSM extracts.

This does NOT download the planet. It fetches the public catalogue and writes
a small manifest containing continent/country/subregion PBF URLs. Download
individual regions later with download_osm_extract.py after checking storage.
"""
from __future__ import annotations

import argparse
import json
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX_URL = "https://download.geofabrik.de/index-v1-nogeom.json"
OUTPUT = ROOT / "data" / "osm" / "geofabrik_world_manifest.json"
CONTINENTS = {
    "africa", "asia", "australia-oceania", "central-america",
    "europe", "north-america", "south-america", "antarctica",
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    request = urllib.request.Request(
        INDEX_URL,
        headers={"User-Agent": "ZERO-MERCY-world-map-pipeline/1.0"},
    )
    with urllib.request.urlopen(request, timeout=90) as response:
        source = json.loads(response.read())

    regions = []
    for feature in source.get("features", []):
        props = feature.get("properties", {})
        region_id = str(props.get("id", "")).strip()
        urls = props.get("urls", {})
        pbf = urls.get("pbf")
        if not region_id or not pbf:
            continue
        parts = region_id.split("/")
        continent = parts[0] if parts else ""
        regions.append({
            "id": region_id,
            "name": str(props.get("name", region_id)),
            "parent": str(props.get("parent", "")),
            "continent": continent,
            "is_continent": region_id in CONTINENTS,
            "pbf_url": pbf,
            "updated": props.get("updated"),
        })

    regions.sort(key=lambda item: (item["continent"], item["id"]))
    result = {
        "schema_version": 1,
        "source": INDEX_URL,
        "source_license": "OpenStreetMap ODbL 1.0",
        "attribution": "© OpenStreetMap contributors",
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "region_count": len(regions),
        "continent_ids": sorted(CONTINENTS),
        "regions": regions,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(regions)} worldwide extract entries to {args.output}")
    print("This is a download catalogue only; no geographic data was downloaded.")
    print("Choose manageable country/region PBFs. Do not fetch every continent blindly.")


if __name__ == "__main__":
    main()

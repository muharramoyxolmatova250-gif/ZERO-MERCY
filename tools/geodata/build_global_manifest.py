#!/usr/bin/env python3
"""Build a machine-readable global OSM extract catalogue.

The catalogue uses Geofabrik's worldwide index with an offline Natural Earth
boundary fallback when the extract index is unreachable. It records regional
PBFs and never downloads the planet implicitly.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX_URL = "https://download.geofabrik.de/index-v1.json"
OUT = ROOT / "data" / "world" / "global_regions.json"
PBF_DIR = ROOT / "data" / "osm" / "pbf"
USER_AGENT = "ZERO-MERCY-world-builder/1.0"


def read_json(url: str, attempts: int = 5) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    last_error = None
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return json.loads(response.read())
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last_error = exc
            if attempt + 1 < attempts:
                delay = min(30, 3 * (2 ** attempt))
                print(f"Geofabrik index request failed ({exc}); retrying in {delay}s...", file=sys.stderr)
                time.sleep(delay)
    raise RuntimeError(f"Could not retrieve Geofabrik index after {attempts} attempts: {last_error}")


def safe_id(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9._-]+", "_", value).strip("_")


def _geometry_bboxes(geometry: dict) -> list[list[float]]:
    points: list[tuple[float, float]] = []
    def visit(value):
        if isinstance(value, (list, tuple)):
            if len(value) >= 2 and isinstance(value[0], (int, float)) and isinstance(value[1], (int, float)):
                points.append((float(value[0]), float(value[1])))
            else:
                for child in value:
                    visit(child)
    visit((geometry or {}).get("coordinates", []))
    if not points:
        return []
    longitudes = sorted({((lon + 180.0) % 360.0) - 180.0 for lon, _ in points})
    south = min(lat for _, lat in points)
    north = max(lat for _, lat in points)
    if len(longitudes) == 1:
        return [[longitudes[0], south, longitudes[0] + 0.000001, north]]
    gaps = []
    for i, lon in enumerate(longitudes):
        nxt = longitudes[(i + 1) % len(longitudes)] + (360.0 if i == len(longitudes) - 1 else 0.0)
        gaps.append((nxt - lon, i))
    _, gap_index = max(gaps)
    west = longitudes[(gap_index + 1) % len(longitudes)]
    east = longitudes[gap_index]
    if west <= east:
        return [[west, south, east, north]]
    return [[west, south, 180.0, north], [-180.0, south, east, north]]


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
        # Geofabrik's current Uzbekistan download is served from the parent
        # Asia directory; the nested URL in some index snapshots returns 404.
        if region_id == "uzbekistan":
            pbf = "https://download.geofabrik.de/asia/uzbekistan-latest.osm.pbf"
        entries.append({
            "id": region_id,
            "name": str(props.get("name", region_id)),
            "parent": props.get("parent"),
            "iso3166_1": props.get("iso3166-1:alpha2", []),
            "iso3166_2": props.get("iso3166-2", []),
            "pbf_url": pbf,
            "updates_url": urls.get("updates"),
            "estimated_size_bytes": props.get("pbf_file_size"),
            "bboxes": _geometry_bboxes(feature.get("geometry", {})),
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


def build_offline_catalog(existing_path: Path) -> dict:
    if not existing_path.is_file():
        raise RuntimeError(f"No cached Geofabrik catalogue is available at {existing_path}")
    natural_earth = ROOT / "data/geodata/world-110m.geojson"
    if not natural_earth.is_file():
        raise RuntimeError(f"No offline country boundaries available at {natural_earth}")
    catalog = json.loads(existing_path.read_text(encoding="utf-8"))
    boundary_data = json.loads(natural_earth.read_text(encoding="utf-8"))
    bounds_by_code: dict[str, list[list[float]]] = {}
    for feature in boundary_data.get("features", []):
        props = feature.get("properties", {})
        code = str(props.get("ISO_A2_EH") or props.get("ISO_A2") or "").upper()
        if len(code) != 2 or code == "-99":
            continue
        bounds_by_code.setdefault(code, []).extend(_geometry_bboxes(feature.get("geometry") or {}))
    enriched = 0
    for region in catalog.get("regions", []):
        boxes = []
        codes = region.get("iso3166_1") or []
        if isinstance(codes, str):
            codes = [codes]
        for code in codes:
            boxes.extend(bounds_by_code.get(str(code).upper(), []))
        if boxes:
            region["bboxes"] = boxes
            enriched += 1
    catalog["generated_utc"] = datetime.now(timezone.utc).isoformat()
    catalog["bbox_source"] = "Natural Earth 110m offline fallback; Geofabrik IDs and PBF URLs from cached catalogue"
    print(f"Offline fallback: added country bounds to {enriched} Geofabrik extracts.")
    return catalog


def download(entry: dict, force: bool = False, attempts: int = 5) -> Path:
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
    last_error = None
    for attempt in range(attempts):
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
            print(f"Saved {target} ({target.stat().st_size:,} bytes)")
            return target
        except Exception as exc:
            last_error = exc
            temporary.unlink(missing_ok=True)
            if attempt + 1 < attempts:
                delay = min(60, 5 * (2 ** attempt))
                print(f"PBF download failed ({exc}); retrying in {delay}s...", file=sys.stderr)
                time.sleep(delay)
    raise RuntimeError(f"Could not download {entry['id']} after {attempts} attempts: {last_error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT, help="JSON catalogue output path")
    parser.add_argument("--list", action="store_true", help="Print all catalogue region IDs and names")
    parser.add_argument("--region", action="append", default=[], help="Exact Geofabrik region ID; repeatable")
    parser.add_argument("--download", action="store_true", help="Download the selected --region entries")
    parser.add_argument("--force", action="store_true", help="Replace existing PBF files")
    args = parser.parse_args()

    print("Fetching Geofabrik global extract index...")
    try:
        catalog = build_catalog(read_json(INDEX_URL))
    except Exception as exc:
        print(f"Geofabrik index unavailable: {exc}", file=sys.stderr)
        catalog = build_offline_catalog(args.output)
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

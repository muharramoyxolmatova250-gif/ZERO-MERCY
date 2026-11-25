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


def _ring_bboxes(ring: list) -> list[list[float]]:
    points = [(float(point[0]), float(point[1])) for point in ring
              if isinstance(point, (list, tuple)) and len(point) >= 2
              and isinstance(point[0], (int, float)) and isinstance(point[1], (int, float))]
    if not points:
        return []
    longitudes = sorted({lon % 360.0 for lon, _ in points})
    south = min(lat for _, lat in points)
    north = max(lat for _, lat in points)
    if len(longitudes) == 1:
        lon = longitudes[0]
        signed = lon if lon <= 180.0 else lon - 360.0
        if signed >= 180.0:
            return [[-180.0, south, -179.999999, north]]
        return [[signed, south, min(180.0, signed + 0.000001), north]]
    gaps = []
    for i, lon in enumerate(longitudes):
        nxt = longitudes[(i + 1) % len(longitudes)] + (360.0 if i == len(longitudes) - 1 else 0.0)
        gaps.append((nxt - lon, i))
    _, gap_index = max(gaps)
    west360, east360 = longitudes[(gap_index + 1) % len(longitudes)], longitudes[gap_index]
    west = west360 if west360 <= 180.0 else west360 - 360.0
    east = east360 if east360 <= 180.0 else east360 - 360.0
    if abs(west - 180.0) < 1e-9 and east < 0.0:
        west = -180.0
    if west <= east:
        return [[west, south, east, north]]
    return [[west, south, 180.0, north], [-180.0, south, east, north]]

def _geometry_bboxes(geometry: dict) -> list[list[float]]:
    if not geometry:
        return []
    kind = geometry.get("type")
    coordinates = geometry.get("coordinates")
    polygons = []
    if kind == "Polygon":
        polygons = [coordinates or []]
    elif kind == "MultiPolygon":
        polygons = coordinates or []
    elif kind == "GeometryCollection":
        result = []
        for child in geometry.get("geometries", []):
            result.extend(_geometry_bboxes(child))
        return result
    else:
        return []
    result, seen = [], set()
    for polygon in polygons:
        if not polygon:
            continue
        for bbox in _ring_bboxes(polygon[0]):
            key = tuple(round(value, 7) for value in bbox)
            if key not in seen:
                result.append(bbox)
                seen.add(key)
    return result

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
            codes = [code.strip() for code in codes.split(",")]
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
    temporary = target.with_suffix(target.suffix + ".part")
    print(f"Downloading {entry['name']} ({entry['id']})")
    print(f"Source: {entry['pbf_url']}")
    last_error = None
    for attempt in range(attempts):
        try:
            # Resume interrupted downloads instead of deleting gigabytes on retry.
            offset = temporary.stat().st_size if temporary.exists() and not force else 0
            headers = {"User-Agent": USER_AGENT}
            if offset:
                headers["Range"] = f"bytes={offset}-"
            request = urllib.request.Request(entry["pbf_url"], headers=headers)
            with urllib.request.urlopen(request, timeout=300) as response:
                # Some servers ignore Range; in that case restart cleanly.
                append = offset > 0 and getattr(response, "status", 200) == 206
                if offset and not append:
                    offset = 0
                mode = "ab" if append else "wb"
                with temporary.open(mode) as out:
                    downloaded = offset
                    last_report = downloaded
                    while True:
                        chunk = response.read(4 * 1024 * 1024)
                        if not chunk:
                            break
                        out.write(chunk)
                        downloaded += len(chunk)
                        if downloaded - last_report >= 64 * 1024 * 1024:
                            print(f"Download progress: {downloaded / (1024 * 1024):.0f} MiB", flush=True)
                            last_report = downloaded
            if temporary.stat().st_size < 1024:
                raise RuntimeError("Downloaded PBF is unexpectedly small.")
            temporary.replace(target)
            print(f"Saved {target} ({target.stat().st_size:,} bytes)")
            return target
        except Exception as exc:
            last_error = exc
            partial = temporary.stat().st_size if temporary.exists() else 0
            if attempt + 1 < attempts:
                delay = min(30, 3 * (2 ** attempt))
                print(f"PBF download interrupted ({exc}); keeping {partial:,} bytes and resuming in {delay}s...", file=sys.stderr, flush=True)
                time.sleep(delay)
    raise RuntimeError(f"Could not download {entry['id']} after {attempts} attempts: {last_error}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=OUT, help="JSON catalogue output path")
    parser.add_argument("--list", action="store_true", help="Print all catalogue region IDs and names")
    parser.add_argument("--region", action="append", default=[], help="Exact Geofabrik region ID; repeatable")
    parser.add_argument("--download", action="store_true", help="Download the selected --region entries")
    parser.add_argument("--force", action="store_true", help="Replace existing PBF files")
    parser.add_argument("--offline-catalog", action="store_true", help="Reuse the committed Geofabrik catalogue and enrich it with offline boundaries; do not request the live index")
    args = parser.parse_args()

    if args.offline_catalog:
        print("Using committed Geofabrik catalogue; skipping live index request.")
        catalog = build_offline_catalog(args.output)
    else:
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

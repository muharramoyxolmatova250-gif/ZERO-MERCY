#!/usr/bin/env python3
"""Build a compact 0.1-degree tile-bbox queue around OSM cities, towns and villages."""
from __future__ import annotations
import argparse, json, math, subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PLACE_FILTER = "nwr/place=city,town,village,hamlet"

def _centroid(geometry: dict) -> tuple[float, float] | None:
    kind = geometry.get("type")
    coordinates = geometry.get("coordinates", [])
    if kind == "Point" and len(coordinates) >= 2:
        return float(coordinates[0]), float(coordinates[1])
    if kind == "Polygon" and coordinates:
        ring = coordinates[0]
    elif kind == "MultiPolygon" and coordinates and coordinates[0]:
        ring = coordinates[0][0]
    else:
        return None
    points = [(float(p[0]), float(p[1])) for p in ring if isinstance(p, list) and len(p) >= 2]
    if not points:
        return None
    return (sum(x for x, _ in points) / len(points), sum(y for _, y in points) / len(points))

def _population(value) -> int:
    digits = "".join(ch for ch in str(value or "") if ch.isdigit())
    return int(digits) if digits else 0

def _radius(place: str, population: int) -> float:
    if place == "city":
        if population >= 1_000_000: return 0.35
        if population >= 300_000: return 0.25
        if population >= 100_000: return 0.18
        return 0.12
    if place == "town":
        if population >= 50_000: return 0.12
        if population >= 10_000: return 0.09
        return 0.06
    if place == "village":
        return 0.035
    return 0.02

def build_bboxes(features: list, region_bboxes: list[list[float]]) -> tuple[list[list[float]], Counter]:
    result, seen, counts = [], set(), Counter()
    for feature in features:
        if not isinstance(feature, dict):
            continue
        props = feature.get("properties") or {}
        tags = props.get("tags") or props
        place = str(tags.get("place", "")).lower()
        if place not in {"city", "town", "village", "hamlet"}:
            continue
        point = _centroid(feature.get("geometry") or {})
        if point is None:
            continue
        lon, lat = point
        if not (-180 <= lon <= 180 and -90 <= lat <= 90):
            continue
        population = _population(tags.get("population"))
        radius = _radius(place, population)
        lon_radius = min(1.5, radius / max(0.2, abs(math.cos(math.radians(lat)))))
        matched = False
        for west, south, east, north in region_bboxes:
            if not (west - 1e-6 <= lon <= east + 1e-6 and south - 1e-6 <= lat <= north + 1e-6):
                continue
            bbox = [max(west, lon - lon_radius), max(south, lat - radius),
                    min(east, lon + lon_radius), min(north, lat + radius)]
            if bbox[0] >= bbox[2] or bbox[1] >= bbox[3]:
                continue
            key = tuple(round(v, 5) for v in bbox)
            if key not in seen:
                result.append(bbox)
                seen.add(key)
            matched = True
        if matched:
            counts[place] += 1
    if not result:
        # A tiny fallback sample keeps isolated territories discoverable without
        # expanding every empty square of a continent into millions of tile jobs.
        for west, south, east, north in region_bboxes:
            cx, cy = (west + east) * 0.5, (south + north) * 0.5
            radius_x = min(0.04, (east - west) * 0.25)
            radius_y = min(0.04, (north - south) * 0.25)
            if radius_x > 0 and radius_y > 0:
                result.append([cx - radius_x, cy - radius_y, cx + radius_x, cy + radius_y])
        counts["fallback"] = len(result)
    return result, counts

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path)
    p.add_argument("--queue", type=Path, default=ROOT / "data/world/global_country_queue.json")
    p.add_argument("--region-id", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--force", action="store_true")
    a = p.parse_args()
    if a.output.is_file() and not a.force:
        existing = json.loads(a.output.read_text(encoding="utf-8"))
        if existing.get("region_id") == a.region_id and existing.get("bboxes"):
            print(f"Reusing {len(existing['bboxes'])} urban tile bounds for {a.region_id}.")
            return 0
    queue = json.loads(a.queue.read_text(encoding="utf-8"))
    item = next((x for x in queue.get("countries", []) if x.get("id") == a.region_id), None)
    if item is None:
        p.error(f"Unknown country/territory extract ID: {a.region_id}")
    temp_dir = ROOT / "data/osm/tmp/places"
    temp_dir.mkdir(parents=True, exist_ok=True)
    safe = a.region_id.replace("/", "_")
    filtered = temp_dir / f"{safe}.places.osm.pbf"
    exported = temp_dir / f"{safe}.places.geojson"
    subprocess.run(["osmium", "tags-filter", str(a.source), PLACE_FILTER,
                    "-o", str(filtered), "--overwrite"], check=True)
    subprocess.run(["osmium", "export", str(filtered), "-o", str(exported), "--overwrite"], check=True)
    data = json.loads(exported.read_text(encoding="utf-8"))
    features = data.get("features", [])
    bboxes, counts = build_bboxes(features, item.get("bboxes", []))
    result = {
        "schema_version": 1, "region_id": a.region_id,
        "source_pbf": a.source.name, "place_feature_count": len(features),
        "selected_place_counts": dict(counts), "tile_bbox_count": len(bboxes),
        "bboxes": bboxes,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{a.region_id}: {sum(counts.values())} selected populated places -> {len(bboxes)} tile bounds.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

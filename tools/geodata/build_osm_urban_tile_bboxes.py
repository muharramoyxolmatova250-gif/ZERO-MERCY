#!/usr/bin/env python3
"""Build unique global grid cells around OSM cities, towns, villages and hamlets."""
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
    return sum(x for x, _ in points) / len(points), sum(y for _, y in points) / len(points)

def _population(value) -> int:
    digits = "".join(ch for ch in str(value or "") if ch.isdigit())
    return int(digits) if digits else 0

def _radius(place: str, population: int) -> float:
    if place == "city":
        if population >= 1_000_000: return 0.25
        if population >= 300_000: return 0.18
        if population >= 100_000: return 0.12
        return 0.08
    if place == "town":
        if population >= 50_000: return 0.06
        if population >= 10_000: return 0.04
        return 0.025
    if place == "village":
        return 0.005
    return 0.002

def build_bboxes(features: list, region_bboxes: list[list[float]],
                 tile_deg: float = 0.1) -> tuple[list[list[float]], Counter, list[dict]]:
    cells: set[tuple[int, int]] = set()
    counts = Counter()
    settlements: list[dict] = []
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
        matching_regions = [box for box in region_bboxes
                            if box[0] - 1e-6 <= lon <= box[2] + 1e-6
                            and box[1] - 1e-6 <= lat <= box[3] + 1e-6]
        if not matching_regions:
            continue
        population = _population(tags.get("population"))
        radius = _radius(place, population)
        home_gx = math.floor(min(179.999999, lon) / tile_deg)
        home_gy = math.floor(min(89.999999, lat) / tile_deg)
        raw_id = str(feature.get("id") or tags.get("@id") or props.get("@id") or "")
        settlement_id = raw_id or f"{place}:{round(lat, 5)}:{round(lon, 5)}"
        settlements.append({
            "id": settlement_id, "name": str(tags.get("name", props.get("name", ""))),
            "place": place, "population": population, "lon": lon, "lat": lat,
            "home_tile_id": f"{home_gx}_{home_gy}", "region_id": str(props.get("region_id", "")),
        })
        lon_radius = min(1.5, radius / max(0.2, abs(math.cos(math.radians(lat)))))
        gx0 = math.floor((lon - lon_radius) / tile_deg)
        gx1 = math.ceil((lon + lon_radius) / tile_deg) - 1
        gy0 = math.floor((lat - radius) / tile_deg)
        gy1 = math.ceil((lat + radius) / tile_deg) - 1
        added = False
        for gy in range(gy0, gy1 + 1):
            for gx in range(gx0, gx1 + 1):
                west, east = gx * tile_deg, (gx + 1) * tile_deg
                south, north = gy * tile_deg, (gy + 1) * tile_deg
                if east <= -180 or west >= 180 or north <= -90 or south >= 90:
                    continue
                if any(east > box[0] and west < box[2] and north > box[1] and south < box[3]
                       for box in matching_regions):
                    cells.add((gx, gy))
                    added = True
        if added:
            counts[place] += 1
    if not cells:
        for west, south, east, north in region_bboxes:
            lon = (west + east) * 0.5
            lat = (south + north) * 0.5
            cells.add((math.floor(lon / tile_deg), math.floor(lat / tile_deg)))
        counts["fallback"] = len(cells)
    bboxes = []
    start_gx = math.floor(72.3 / tile_deg)
    # Player spawns 12 m south of the anchor, in the lower-latitude row.
    start_gy = math.floor((40.7 - 1e-6) / tile_deg)
    ordered_cells = sorted(cells, key=lambda item: (
        abs(item[0] - start_gx) + abs(item[1] - start_gy),
        abs(item[0] - start_gx), item[1], item[0]
    ))
    for gx, gy in ordered_cells:
        west = max(-180.0, gx * tile_deg)
        east = min(180.0, (gx + 1) * tile_deg)
        south = max(-90.0, gy * tile_deg)
        north = min(90.0, (gy + 1) * tile_deg)
        if west < east and south < north:
            bboxes.append([west, south, east, north])
    settlements.sort(key=lambda item: (
        {"city": 0, "town": 1, "village": 2, "hamlet": 3}.get(item["place"], 4),
        -int(item["population"]), item["name"].casefold(), item["id"]
    ))
    return bboxes, counts, settlements

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path)
    p.add_argument("--queue", type=Path, default=ROOT / "data/world/global_country_queue.json")
    p.add_argument("--region-id", required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--tile-deg", type=float, default=0.1)
    p.add_argument("--force", action="store_true")
    a = p.parse_args()
    if not (0.001 <= a.tile_deg <= 1.0):
        p.error("--tile-deg must be between 0.001 and 1.0")
    if a.output.is_file() and not a.force:
        existing = json.loads(a.output.read_text(encoding="utf-8"))
        if (existing.get("region_id") == a.region_id
                and abs(float(existing.get("tile_deg", -1)) - a.tile_deg) < 1e-9
                and existing.get("bboxes") and "settlements" in existing
                and existing.get("priority_anchor") == {"lon": 72.3, "lat": 40.7}):
            print(f"Reusing {len(existing['bboxes'])} unique populated-place cells for {a.region_id}.")
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
    bboxes, counts, settlements = build_bboxes(features, item.get("bboxes", []), a.tile_deg)
    for settlement in settlements:
        settlement["region_id"] = a.region_id
    result = {
        "schema_version": 4, "region_id": a.region_id, "tile_deg": a.tile_deg,
        "priority_anchor": {"lon": 72.3, "lat": 40.7},
        "source_pbf": a.source.name, "place_feature_count": len(features),
        "selected_place_counts": dict(counts), "tile_cell_count": len(bboxes),
        "settlement_count": len(settlements), "bboxes": bboxes, "settlements": settlements,
    }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{a.region_id}: {sum(counts.values())} selected populated places -> {len(bboxes)} unique grid cells.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

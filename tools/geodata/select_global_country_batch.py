#!/usr/bin/env python3
"""Select the next bounded country tile batch for the scheduled world builder."""
from __future__ import annotations
import argparse, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QUEUE = ROOT / "data/world/global_country_queue.json"
STATE = ROOT / "data/world/global_build_state.json"

def initial_state() -> dict:
    return {"schema_version": 1, "current_region_id": None,
            "next_tile_by_region": {}, "completed_regions": []}

def select_batch(queue: dict, state: dict, region_id: str = "",
                 tile_start: str = "", tile_count: int = 64) -> dict:
    countries = queue.get("countries", [])
    by_id = {item["id"]: item for item in countries}
    offsets = state.get("next_tile_by_region", {})
    completed = set(state.get("completed_regions", []))
    if region_id:
        if region_id not in by_id:
            raise ValueError(f"Unknown country extract: {region_id}")
        chosen = by_id[region_id]
        start = int(tile_start) if tile_start.strip() else int(offsets.get(region_id, 0))
    else:
        # Round-robin across the worldwide country queue: each verified batch
        # moves to the next unfinished country instead of exhausting one country.
        last_region = (state.get("last_batch") or {}).get("region_id")
        start_index = next((i + 1 for i, item in enumerate(countries)
                            if item["id"] == last_region), 0)
        ordered = countries[start_index:] + countries[:start_index]
        chosen = next((item for item in ordered
                       if item["id"] not in completed), None)
        if chosen is None:
            return {"has_work": False}
        start = int(offsets.get(chosen["id"], 0))
    if start < 0 or tile_count < 1:
        raise ValueError("Tile start must be non-negative and tile count must be positive.")
    return {"has_work": True, "region_id": chosen["id"],
            "safe_region": chosen["id"].replace("/", "_"),
            "tile_start": start, "tile_count": tile_count}

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--region-id", default="")
    p.add_argument("--tile-start", default="")
    p.add_argument("--tile-count", type=int, default=64)
    p.add_argument("--queue", type=Path, default=QUEUE)
    p.add_argument("--state", type=Path, default=STATE)
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    queue = json.loads(a.queue.read_text(encoding="utf-8"))
    state = json.loads(a.state.read_text(encoding="utf-8")) if a.state.is_file() else initial_state()
    result = select_batch(queue, state, a.region_id, a.tile_start, a.tile_count)
    lines = [f"has_work={str(result['has_work']).lower()}"]
    if result["has_work"]:
        lines += [f"{key}={result[key]}" for key in ("region_id", "safe_region", "tile_start", "tile_count")]
    else:
        print("All queued country extracts have been processed.")
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with a.output.open("a", encoding="utf-8") as out:
        out.write("\n".join(lines) + "\n")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

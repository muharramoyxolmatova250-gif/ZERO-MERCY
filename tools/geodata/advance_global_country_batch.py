#!/usr/bin/env python3
"""Advance persistent country/tile progress after a validated batch."""
from __future__ import annotations
import argparse, json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STATE = ROOT / "data/world/global_build_state.json"

def advance_state(state: dict, region_id: str, tile_start: int,
                  processed_count: int, total_tiles: int) -> dict:
    state.setdefault("schema_version", 1)
    offsets = state.setdefault("next_tile_by_region", {})
    completed = set(state.setdefault("completed_regions", []))
    next_tile = min(total_tiles, tile_start + processed_count)
    offsets[region_id] = next_tile
    # Clear the active region after every batch so the selector advances
    # round-robin to another country on the next run.
    state["current_region_id"] = None
    if next_tile >= total_tiles:
        completed.add(region_id)
        offsets.pop(region_id, None)
    else:
        completed.discard(region_id)
    state["completed_regions"] = sorted(completed)
    state["last_updated_utc"] = datetime.now(timezone.utc).isoformat()
    state["last_batch"] = {"region_id": region_id, "start": tile_start,
                           "processed": processed_count, "total_tiles": total_tiles}
    return state

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--region-id", required=True)
    p.add_argument("--tile-start", required=True, type=int)
    p.add_argument("--tile-count", required=True, type=int)
    p.add_argument("--plan", type=Path, required=True)
    p.add_argument("--state", type=Path, default=STATE)
    a = p.parse_args()
    plan = json.loads(a.plan.read_text(encoding="utf-8"))
    total = int(plan.get("tile_count", 0))
    processed = max(0, min(a.tile_count, total - a.tile_start))
    state = json.loads(a.state.read_text(encoding="utf-8")) if a.state.is_file() else {
        "schema_version": 1, "current_region_id": None,
        "next_tile_by_region": {}, "completed_regions": []}
    updated = advance_state(state, a.region_id, a.tile_start, processed, total)
    a.state.parent.mkdir(parents=True, exist_ok=True)
    a.state.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"{a.region_id}: processed {processed} of {total} tiles; next={updated['next_tile_by_region'].get(a.region_id, 'complete')}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

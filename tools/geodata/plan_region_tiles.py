#!/usr/bin/env python3
"""Create a deterministic geographic tile plan for one downloaded OSM extract.

Example:
  python tools/geodata/plan_region_tiles.py --region uzbekistan --bbox 55.9 37.1 73.2 45.6 --tile-deg 0.05 --anchor 64.0 41.0
This writes a tile job manifest. It does not download or fabricate map data.
"""
from __future__ import annotations
import argparse, json, math
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "data" / "world" / "tile_jobs"

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--region", required=True)
    p.add_argument("--bbox", nargs=4, required=True, type=float, metavar=("WEST","SOUTH","EAST","NORTH"))
    p.add_argument("--tile-deg", type=float, default=0.05)
    p.add_argument("--anchor", nargs=2, type=float, default=[64.0, 41.0], metavar=("LON","LAT"))
    p.add_argument("--output", type=Path)
    a = p.parse_args()
    west,south,east,north = a.bbox
    if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
        p.error("Invalid geographic bbox.")
    if not (0.001 <= a.tile_deg <= 1.0):
        p.error("--tile-deg must be between 0.001 and 1.0 for this local-projection pipeline.")
    anchor_lon,anchor_lat = a.anchor
    x0 = math.floor(west / a.tile_deg); x1 = math.ceil(east / a.tile_deg)
    y0 = math.floor(south / a.tile_deg); y1 = math.ceil(north / a.tile_deg)
    tiles = []
    for y in range(y0,y1):
        for x in range(x0,x1):
            w=max(west,x*a.tile_deg); e=min(east,(x+1)*a.tile_deg)
            s=max(south,y*a.tile_deg); n=min(north,(y+1)*a.tile_deg)
            if e <= w or n <= s: continue
            clat=(s+n)*0.5; clon=(w+e)*0.5
            mx=111320.0*math.cos(math.radians(anchor_lat))
            ox=(clon-anchor_lon)*mx; oz=-(clat-anchor_lat)*111320.0
            tile_id=f"{x}_{y}"
            tiles.append({
                "id":tile_id,"bbox":[round(w,8),round(s,8),round(e,8),round(n,8)],
                "center_lat":clat,"center_lon":clon,
                "origin_x":round(ox,3),"origin_z":round(oz,3),
                "pbf_output":f"data/osm/tiles/{a.region}/{tile_id}.osm.pbf",
                "geojson_output":f"data/osm/tiles/{a.region}/{tile_id}.geojson",
                "godot_geojson_path":f"res://data/osm/tiles/{a.region}/{tile_id}.geojson"
            })
    result={"schema_version":1,"region":a.region,"created_utc":datetime.now(timezone.utc).isoformat(),
            "source_bbox":[west,south,east,north],"tile_degrees":a.tile_deg,
            "anchor_lon":anchor_lon,"anchor_lat":anchor_lat,"tile_count":len(tiles),"tiles":tiles}
    output=a.output or OUT/f"{a.region}.json"
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(f"Wrote {len(tiles)} tile jobs: {output}")
    print("Note: tile origins share one local tangent anchor; do not use this projection for continental-scale rendering.")
    return 0
if __name__=="__main__":
    raise SystemExit(main())

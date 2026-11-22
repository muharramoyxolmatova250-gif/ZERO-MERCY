#!/usr/bin/env python3
"""Create geographic tile jobs AND the Godot region_streamer index.

Example:
 python tools/geodata/plan_region_tiles.py --region uzbekistan --bbox 55.9 37.1 73.2 45.6 --tile-deg 0.05 --anchor 64.0 41.0
"""
from __future__ import annotations
import argparse, json, math
from datetime import datetime, timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/"data"/"world"/"tile_jobs"

def main()->int:
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--region",required=True)
 p.add_argument("--bbox",nargs=4,required=True,type=float,metavar=("WEST","SOUTH","EAST","NORTH"))
 p.add_argument("--tile-deg",type=float,default=0.05)
 p.add_argument("--anchor",nargs=2,type=float,default=[64.0,41.0],metavar=("LON","LAT"))
 p.add_argument("--tile-size-m",type=float,default=4000.0)
 p.add_argument("--output",type=Path)
 p.add_argument("--index-output",type=Path,default=ROOT/"data"/"world"/"region_tiles.json")
 a=p.parse_args()
 west,south,east,north=a.bbox
 if not(-180<=west<east<=180 and -90<=south<north<=90): p.error("Invalid geographic bbox.")
 if not(0.001<=a.tile_deg<=1.0): p.error("--tile-deg must be between 0.001 and 1.0.")
 if a.tile_size_m<100: p.error("--tile-size-m must be at least 100 metres.")
 anchor_lon,anchor_lat=a.anchor
 x0=math.floor(west/a.tile_deg); x1=math.ceil(east/a.tile_deg)
 y0=math.floor(south/a.tile_deg); y1=math.ceil(north/a.tile_deg)
 tiles=[]; index={}; collisions=[]
 for gy in range(y0,y1):
  for gx in range(x0,x1):
   w=max(west,gx*a.tile_deg); e=min(east,(gx+1)*a.tile_deg)
   s=max(south,gy*a.tile_deg); n=min(north,(gy+1)*a.tile_deg)
   if e<=w or n<=s: continue
   clat=(s+n)*0.5; clon=(w+e)*0.5
   ox=(clon-anchor_lon)*111320.0*math.cos(math.radians(anchor_lat))
   oz=-(clat-anchor_lat)*111320.0
   tx=math.floor(ox/a.tile_size_m); tz=math.floor(oz/a.tile_size_m)
   key=f"{tx},{tz}"
   tile_id=f"{gx}_{gy}"
   entry={"id":tile_id,"grid_x":tx,"grid_z":tz,"bbox":[round(w,8),round(s,8),round(e,8),round(n,8)],
    "center_lat":clat,"center_lon":clon,"origin_x":round(ox,3),"origin_z":round(oz,3),
    "pbf_output":f"data/osm/tiles/{a.region}/{tile_id}.osm.pbf",
    "geojson_output":f"data/osm/tiles/{a.region}/{tile_id}.geojson",
    "godot_geojson_path":f"res://data/osm/tiles/{a.region}/{tile_id}.geojson"}
   tiles.append(entry)
   if key in index: collisions.append((key,index[key]["id"],tile_id))
   index[key]={"geojson_path":entry["godot_geojson_path"],"center_lat":clat,"center_lon":clon,
    "origin_x":round(ox,3),"origin_z":round(oz,3),"tile_id":tile_id,"region":a.region}
 if collisions:
  sample=", ".join(f"{k}:{one}/{two}" for k,one,two in collisions[:8])
  p.error(f"Tile grid collision(s) at tile-size {a.tile_size_m:g}m ({sample}). Increase --tile-size-m or reduce --tile-deg.")
 plan={"schema_version":2,"region":a.region,"created_utc":datetime.now(timezone.utc).isoformat(),
  "source_bbox":[west,south,east,north],"tile_degrees":a.tile_deg,"tile_size_m":a.tile_size_m,
  "anchor_lon":anchor_lon,"anchor_lat":anchor_lat,"tile_count":len(tiles),"tiles":tiles}
 output=a.output or OUT/f"{a.region}.json"
 output.parent.mkdir(parents=True,exist_ok=True)
 output.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 index_doc={"_comment":f"Generated tile index for {a.region}. Player coordinates must use the same local anchor/projection.",
  "_region":a.region,"_tile_size_m":a.tile_size_m,"_anchor_lon":anchor_lon,"_anchor_lat":anchor_lat,**index}
 a.index_output.parent.mkdir(parents=True,exist_ok=True)
 a.index_output.write_text(json.dumps(index_doc,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(f"Wrote {len(tiles)} tile jobs: {output}")
 print(f"Wrote Godot runtime index ({len(index)} tiles): {a.index_output}")
 print("IMPORTANT: keep the player in this same local anchor coordinate frame; this is not a planet-scale projection.")
 return 0
if __name__=="__main__": raise SystemExit(main())

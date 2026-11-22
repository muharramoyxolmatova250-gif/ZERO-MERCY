#!/usr/bin/env python3
"""Create tile jobs and the runtime index consumed by Godot's region streamer."""
from __future__ import annotations
import argparse,json,math
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main()->int:
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument("--region",required=True)
 p.add_argument("--bbox",nargs=4,required=True,type=float,metavar=("WEST","SOUTH","EAST","NORTH"))
 p.add_argument("--tile-deg",type=float,default=0.05)
 p.add_argument("--anchor",nargs=2,type=float,default=[64.0,41.0],metavar=("LON","LAT"))
 p.add_argument("--tile-size-m",type=float,default=None)
 p.add_argument("--output",type=Path)
 p.add_argument("--index-output",type=Path,default=ROOT/"data"/"world"/"region_tiles.json")
 a=p.parse_args()
 west,south,east,north=a.bbox
 if not(-180<=west<east<=180 and -90<=south<north<=90): p.error("Invalid bbox.")
 if not (0.001 <= a.tile_deg <= 1.0): p.error("Invalid --tile-deg; expected 0.001..1.0.")
 if a.tile_size_m is not None and a.tile_size_m < 100: p.error("Invalid --tile-size-m; expected >=100 metres.")
 anchor_lon,anchor_lat=a.anchor
 # Pick a square runtime grid cell smaller than the narrowest east-west tile spacing.
 tile_size_m = a.tile_size_m if a.tile_size_m is not None else min(4000.0, a.tile_deg * 111320.0 * math.cos(math.radians(anchor_lat)) * 0.82)
 if tile_size_m < 100.0: p.error("Computed tile size is too small; set --tile-size-m explicitly.")
 tiles=[]; index={}; x0=math.floor(west/a.tile_deg); x1=math.ceil(east/a.tile_deg)
 y0=math.floor(south/a.tile_deg); y1=math.ceil(north/a.tile_deg)
 for gy in range(y0,y1):
  for gx in range(x0,x1):
   w=max(west,gx*a.tile_deg); e=min(east,(gx+1)*a.tile_deg)
   s=max(south,gy*a.tile_deg); n=min(north,(gy+1)*a.tile_deg)
   if e<=w or n<=s: continue
   lat=(s+n)*0.5; lon=(w+e)*0.5
   ox=(lon-anchor_lon)*111320.0*math.cos(math.radians(anchor_lat))
   oz=-(lat-anchor_lat)*111320.0
   tx=math.floor(ox/tile_size_m); tz=math.floor(oz/tile_size_m)
   key=f"{tx},{tz}"; tile_id=f"{gx}_{gy}"
   if key in index: p.error(f"Grid collision at {key}; adjust --tile-size-m or --tile-deg.")
   entry={"id":tile_id,"bbox":[round(w,8),round(s,8),round(e,8),round(n,8)],
    "center_lat":lat,"center_lon":lon,"origin_x":round(ox,3),"origin_z":round(oz,3),
    "pbf_output":f"data/osm/tiles/{a.region}/{tile_id}.osm.pbf",
    "geojson_output":f"data/osm/tiles/{a.region}/{tile_id}.geojson",
    "godot_geojson_path":f"res://data/osm/tiles/{a.region}/{tile_id}.geojson"}
   tiles.append(entry)
   index[key]={"geojson_path":entry["godot_geojson_path"],"center_lat":lat,"center_lon":lon,
    "origin_x":round(ox,3),"origin_z":round(oz,3),"tile_id":tile_id,"region":a.region}
 plan={"schema_version":2,"region":a.region,"created_utc":datetime.now(timezone.utc).isoformat(),
  "source_bbox":[west,south,east,north],"tile_degrees":a.tile_deg,"tile_size_m":tile_size_m,
  "anchor_lon":anchor_lon,"anchor_lat":anchor_lat,"tile_count":len(tiles),"tiles":tiles}
 output=a.output or ROOT/"data"/"world"/"tile_jobs"/f"{a.region}.json"
 output.parent.mkdir(parents=True,exist_ok=True)
 output.write_text(json.dumps(plan,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 runtime={"_comment":f"Generated for {a.region}; coordinates use this shared local anchor.",
  "_tile_size_m":tile_size_m,"_anchor_lon":anchor_lon,"_anchor_lat":anchor_lat,**index}
 a.index_output.parent.mkdir(parents=True,exist_ok=True)
 a.index_output.write_text(json.dumps(runtime,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
 print(f"Created {len(tiles)} jobs and Godot runtime index: {a.index_output}")
 print(f"Runtime grid cell size: {tile_size_m:.1f} m. Use a player spawn in the same local anchor frame; this is a regional projection, not a globe projection.")
 return 0
if __name__=="__main__": raise SystemExit(main())

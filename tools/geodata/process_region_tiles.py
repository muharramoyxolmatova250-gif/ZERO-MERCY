#!/usr/bin/env python3
"""Clip and export all tiles from a plan created by plan_region_tiles.py.

Requires osmium-tool. Run in batches using --start/--count to control disk and CPU.
"""
from __future__ import annotations
import argparse, json, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def run(cmd:list[str])->None:
    print("+"," ".join(cmd),flush=True)
    subprocess.run(cmd,check=True)

def main()->int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("source",type=Path,help="Downloaded source .osm.pbf")
    p.add_argument("plan",type=Path,help="Tile plan JSON")
    p.add_argument("--start",type=int,default=0)
    p.add_argument("--count",type=int,default=100)
    p.add_argument("--force",action="store_true")
    a=p.parse_args()
    if not a.source.is_file(): p.error(f"Source PBF not found: {a.source}")
    plan=json.loads(a.plan.read_text(encoding="utf-8"))
    tiles=plan.get("tiles",[])
    if not isinstance(tiles,list): p.error("Plan has no tiles array.")
    if a.start<0 or a.count<1: p.error("--start must be >=0 and --count >=1")
    selected=tiles[a.start:a.start+a.count]
    if not selected:
        print("No tile jobs in requested range."); return 0
    completed=0
    for tile in selected:
        west,south,east,north=tile["bbox"]
        pbf=ROOT/tile["pbf_output"]; geo=ROOT/tile["geojson_output"]
        pbf.parent.mkdir(parents=True,exist_ok=True); geo.parent.mkdir(parents=True,exist_ok=True)
        if geo.exists() and geo.stat().st_size>100 and not a.force:
            print(f"Skip existing {geo}"); completed+=1; continue
        temp=pbf.with_name(pbf.stem+".part.osm.pbf")
        run(["osmium","extract","-b",f"{west},{south},{east},{north}",str(a.source),"-o",str(temp),"--overwrite"])
        temp.replace(pbf)
        geo_tmp=geo.with_name(geo.stem+".part.geojson")
        run(["osmium","export",str(pbf),"-o",str(geo_tmp),"--overwrite"])
        if geo_tmp.stat().st_size<2: raise RuntimeError(f"Empty GeoJSON export: {geo_tmp}")
        geo_tmp.replace(geo)
        completed+=1
        print(f"[{completed}/{len(selected)}] {tile['id']} -> {geo}")
    print(f"Batch complete: {completed} tiles processed or already present.")
    return 0
if __name__=="__main__":
    raise SystemExit(main())

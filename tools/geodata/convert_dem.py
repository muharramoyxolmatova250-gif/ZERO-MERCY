#!/usr/bin/env python3
"""Convert a georeferenced DEM GeoTIFF into a compact ZERO MERCY terrain tile."""
from __future__ import annotations
import argparse, json
from pathlib import Path
import numpy as np
import rasterio
from rasterio.enums import Resampling

def main() -> int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("source",type=Path)
    p.add_argument("--output",type=Path,required=True,help="Output .f32 file")
    p.add_argument("--metadata",type=Path,required=True,help="Output JSON metadata")
    p.add_argument("--max-size",type=int,default=257)
    a=p.parse_args()
    if a.max_size<3: p.error("--max-size must be at least 3")
    with rasterio.open(a.source) as ds:
        scale=min(1.0,(a.max_size-1)/max(ds.width-1,ds.height-1))
        width=max(3,round(ds.width*scale)); height=max(3,round(ds.height*scale))
        values=ds.read(1,out_shape=(height,width),resampling=Resampling.bilinear).astype("float32")
        nodata=ds.nodata
        if nodata is not None: values[values==nodata]=np.nan
        valid=np.isfinite(values)
        if not valid.any(): raise SystemExit("DEM has no valid elevation samples")
        sea=float(np.nanmin(values))
        values=np.where(valid,values,sea).astype("<f4")
        a.output.parent.mkdir(parents=True,exist_ok=True)
        a.metadata.parent.mkdir(parents=True,exist_ok=True)
        values.tofile(a.output)
        bounds=ds.bounds
        meta={"width":width,"height":height,"min_elevation_m":float(values.min()),
          "max_elevation_m":float(values.max()),"west":bounds.left,"south":bounds.bottom,
          "east":bounds.right,"north":bounds.top,"crs":str(ds.crs),"format":"little-endian-float32"}
        a.metadata.write_text(json.dumps(meta,indent=2)+"\n",encoding="utf-8")
    print(f"Exported {width}x{height} DEM samples to {a.output}")
    return 0
if __name__=="__main__": raise SystemExit(main())

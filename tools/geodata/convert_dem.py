#!/usr/bin/env python3
"""Convert a full DEM or a cropped geographic DEM tile to Godot float32 terrain."""
from __future__ import annotations
import argparse, json, math
from pathlib import Path
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import transform_bounds
from rasterio.windows import Window, from_bounds

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("source", type=Path)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--metadata", type=Path, required=True)
    p.add_argument("--max-size", type=int, default=257)
    p.add_argument("--anchor-lon", type=float, default=64.0)
    p.add_argument("--anchor-lat", type=float, default=41.0)
    p.add_argument("--metres-per-unit", type=float, default=1.0)
    p.add_argument("--bbox", nargs=4, type=float, metavar=("WEST", "SOUTH", "EAST", "NORTH"))
    p.add_argument("--global-grid", action="store_true",
                   help="Use the same flat equirectangular metres as the global OSM tile planner.")
    p.add_argument("--clamp-sea-level", action="store_true",
                   help="Clamp negative bathymetry and missing samples to sea level.")
    a = p.parse_args()
    if a.max_size < 3 or a.metres_per_unit <= 0:
        p.error("max-size must be >=3 and metres-per-unit must be >0")
    if a.global_grid and a.bbox is None:
        p.error("--global-grid requires --bbox")
    with rasterio.open(a.source) as ds:
        if ds.crs is None:
            raise SystemExit("DEM has no CRS; assign/reproject it before conversion.")
        if a.bbox is not None:
            west, south, east, north = a.bbox
            if not (-180 <= west < east <= 180 and -90 <= south < north <= 90):
                p.error("--bbox must be a valid non-wrapping WGS84 rectangle")
            source_bounds = transform_bounds("EPSG:4326", ds.crs, west, south, east, north, densify_pts=21)
            try:
                window = from_bounds(*source_bounds, transform=ds.transform)
                window = window.intersection(Window(0, 0, ds.width, ds.height))
            except Exception as exc:
                raise SystemExit(f"DEM source does not overlap requested bbox: {exc}")
            if window.width <= 0 or window.height <= 0:
                raise SystemExit("DEM source does not overlap requested bbox.")
            window = window.round_offsets().round_lengths()
            source_width, source_height = int(window.width), int(window.height)
            if source_width < 1 or source_height < 1:
                raise SystemExit("Requested DEM crop contains no source pixels.")
            scale = min(1.0, (a.max_size - 1) / max(source_width - 1, source_height - 1))
            width = max(3, round(source_width * scale))
            height = max(3, round(source_height * scale))
            values = ds.read(1, window=window, out_shape=(height, width),
                             resampling=Resampling.bilinear).astype("float32")
        else:
            west, south, east, north = transform_bounds(ds.crs, "EPSG:4326", *ds.bounds, densify_pts=21)
            if east <= west or north <= south:
                raise SystemExit("DEM geographic bounds are invalid.")
            scale = min(1.0, (a.max_size - 1) / max(ds.width - 1, ds.height - 1))
            width = max(3, round(ds.width * scale))
            height = max(3, round(ds.height * scale))
            values = ds.read(1, out_shape=(height, width), resampling=Resampling.bilinear).astype("float32")
        if ds.nodata is not None:
            values[values == ds.nodata] = np.nan
        valid = np.isfinite(values)
        if not valid.any():
            raise SystemExit("DEM has no valid elevation samples")
        sea_level = 0.0 if a.clamp_sea_level else float(np.nanmin(values))
        if a.clamp_sea_level:
            values = np.where(valid, np.maximum(values, 0.0), 0.0)
        else:
            values = np.where(valid, values, sea_level)
        values = values.astype("<f4")
        center_lat = (south + north) * 0.5
        center_lon = (west + east) * 0.5
        if a.global_grid:
            width_m = (east - west) * 111320.0
            depth_m = (north - south) * 111320.0
            origin_x = (center_lon - a.anchor_lon) * 111320.0
            origin_z = -(center_lat - a.anchor_lat) * 111320.0
        else:
            width_m = (east - west) * 111320.0 * math.cos(math.radians(center_lat))
            depth_m = (north - south) * 111132.0
            origin_x = (center_lon - a.anchor_lon) * 111320.0 * math.cos(math.radians(a.anchor_lat))
            origin_z = -(center_lat - a.anchor_lat) * 111132.0
        a.output.parent.mkdir(parents=True, exist_ok=True)
        a.metadata.parent.mkdir(parents=True, exist_ok=True)
        values.tofile(a.output)
        meta = {
            "width": width, "height": height,
            "min_elevation_m": float(values.min()), "max_elevation_m": float(values.max()),
            "west": west, "south": south, "east": east, "north": north,
            "center_lat": center_lat, "center_lon": center_lon,
            "origin_x": origin_x, "origin_z": origin_z,
            "horizontal_width_m": width_m, "horizontal_depth_m": depth_m,
            "metres_per_unit": a.metres_per_unit, "anchor_lon": a.anchor_lon, "anchor_lat": a.anchor_lat,
            "crs": str(ds.crs), "format": "little-endian-float32",
            "projection": "global_equirectangular" if a.global_grid else "local_tangent",
            "source": a.source.name, "sea_level_clamped": a.clamp_sea_level,
        }
        a.metadata.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {width}x{height} DEM samples at local origin ({origin_x:.1f}, {origin_z:.1f}).")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

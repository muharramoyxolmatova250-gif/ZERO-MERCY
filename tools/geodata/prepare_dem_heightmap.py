#!/usr/bin/env python3
"""Convert one Copernicus GeoTIFF tile into a normalized 16-bit heightmap.

Requires GDAL command-line tools (gdalinfo and gdal_translate).
Example:
  python tools/geodata/prepare_dem_heightmap.py data/dem/copernicus-glo30/TILE.tif

The output PNG is a normalized heightmap. Its matching JSON stores the
source elevation range and georeferencing needed to restore metre heights.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path


def run(command: list[str]) -> str:
    result = subprocess.run(command, check=True, capture_output=True, text=True)
    return result.stdout


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Input GeoTIFF")
    parser.add_argument("--size", type=int, default=513, help="Output grid width/height (default: 513)")
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()

    if args.size < 3 or args.size > 4097:
        parser.error("--size must be between 3 and 4097")
    if not args.source.is_file():
        parser.error(f"Input does not exist: {args.source}")
    for tool in ("gdalinfo", "gdal_translate"):
        if shutil.which(tool) is None:
            parser.error(f"{tool} was not found. Install GDAL and add its command-line tools to PATH.")

    output_dir = args.output_dir or args.source.parent / "prepared"
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = args.source.stem
    png_path = output_dir / f"{stem}_{args.size}.png"
    json_path = output_dir / f"{stem}_{args.size}.json"

    info = json.loads(run(["gdalinfo", "-json", str(args.source)]))
    band = info.get("bands", [{}])[0]
    minimum = band.get("minimum")
    maximum = band.get("maximum")
    if minimum is None or maximum is None:
        stats = json.loads(run(["gdalinfo", "-json", "-stats", str(args.source)]))
        band = stats.get("bands", [{}])[0]
        minimum, maximum = band.get("minimum"), band.get("maximum")
    if minimum is None or maximum is None or maximum <= minimum:
        raise RuntimeError("Could not determine a valid elevation range from the source raster.")

    run([
        "gdal_translate", "-q", "-of", "PNG", "-ot", "UInt16",
        "-outsize", str(args.size), str(args.size),
        "-scale", str(minimum), str(maximum), "0", "65535",
        str(args.source), str(png_path),
    ])
    metadata = {
        "source": str(args.source),
        "source_product": "Copernicus DEM GLO-30 Public",
        "width": args.size,
        "height": args.size,
        "encoding": "unsigned 16-bit normalized PNG",
        "elevation_min_m": minimum,
        "elevation_max_m": maximum,
        "geotransform": info.get("geoTransform"),
        "coordinate_system": info.get("coordinateSystem", {}).get("wkt"),
        "vertical_reference": "EGM2008",
        "restore_formula": "elevation_m = elevation_min_m + (pixel / 65535) * (elevation_max_m - elevation_min_m)",
    }
    json_path.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Heightmap: {png_path}")
    print(f"Metadata:  {json_path}")
    print(f"Elevation range: {minimum:.2f} m to {maximum:.2f} m")


if __name__ == "__main__":
    main()

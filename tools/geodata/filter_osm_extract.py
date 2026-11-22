#!/usr/bin/env python3
"""Split an OSM PBF into useful ZERO MERCY feature extracts using osmium-tool.

Install osmium-tool first. Example:
  python tools/geodata/filter_osm_extract.py data/osm/pbf/uzbekistan-latest.osm.pbf

Outputs separate PBFs for roads, buildings, places, waterways, and landuse.
These are still vector source data; conversion to tiled game meshes is a later step.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

FILTERS = {
    "roads": ["w/highway"],
    "buildings": ["w/building"],
    "places": ["nwr/place"],
    "waterways": ["w/waterway"],
    "landuse": ["w/landuse", "w/natural"],
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Input .osm.pbf extract")
    parser.add_argument("--output-dir", type=Path, default=None)
    args = parser.parse_args()
    if not args.source.is_file():
        parser.error(f"Input PBF does not exist: {args.source}")
    if shutil.which("osmium") is None:
        parser.error("osmium command not found. Install osmium-tool and add it to PATH.")

    out_dir = args.output_dir or args.source.parent / (args.source.stem + "-filtered")
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, expressions in FILTERS.items():
        target = out_dir / f"{name}.osm.pbf"
        command = ["osmium", "tags-filter", str(args.source), *expressions, "-o", str(target), "--overwrite"]
        print("Filtering", name, "...")
        subprocess.run(command, check=True)
        print("Saved", target)
    print("Filtering complete. Inspect output sizes and attribution before using derived data.")


if __name__ == "__main__":
    main()

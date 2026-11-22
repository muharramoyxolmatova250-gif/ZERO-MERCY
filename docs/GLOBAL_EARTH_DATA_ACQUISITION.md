# Global Earth data acquisition

## Country polygons for the 3D globe

Run:

    python tools/geodata/download_natural_earth.py --scale 110m

For more detail:

    python tools/geodata/download_natural_earth.py --scale 50m

The downloader validates the GeoJSON FeatureCollection before saving it to data/geodata/world-<scale>.geojson. The globe scene defaults to world-110m.geojson. Natural Earth data is public domain; retain attribution in the game credits.

## Roads, buildings, rivers and land use

Build the official Geofabrik regional catalogue:

    python tools/geodata/build_global_manifest.py --list

Select a region only after checking disk space:

    python tools/geodata/build_global_manifest.py --region asia/uzbekistan --download

Use the exact ID printed by --list if the identifier differs. A regional PBF must then be clipped into tile jobs and converted to GeoJSON with the tools in tools/geodata/. OSM-derived data requires attribution to © OpenStreetMap contributors and compliance with ODbL 1.0:
https://www.openstreetmap.org/copyright

Do not download every continent blindly. Regional extracts can be multi-gigabyte; the full world data set is much larger.

## Elevation

Obtain a licensed georeferenced DEM GeoTIFF for each region and convert it:

    python tools/geodata/convert_dem.py source_dem.tif --output data/terrain/tile.f32 --metadata data/terrain/tile.json

The resulting metadata includes geographic bounds and anchor-relative placement. The Godot DEM loader creates the mesh and optional collision. Copernicus DEM access conditions differ by product and user category; verify the current product terms before use:
https://documentation.v1.dataspace.copernicus.eu/APIs/SentinelHub/Data/DEM.html

## Acceptance criteria

A geographic region is only complete after:
1. Source data is downloaded and its source/license recorded.
2. Roads, buildings, waterways, boundaries and elevation are converted.
3. Tiles align in the same local coordinate frame and seams are checked.
4. The region is loaded and visually inspected in Godot.
5. Collision, memory, streaming and frame time are profiled on target hardware.

The repository contains import pipelines and smoke-test fixtures. It does not currently contain a complete planet-wide set of processed source data.

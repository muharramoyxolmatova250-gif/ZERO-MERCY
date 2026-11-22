# DEM terrain import

Install Python packages: \`pip install rasterio numpy\`.

Convert a licensed/georeferenced DEM GeoTIFF:

\`\`\`bash
python tools/geodata/convert_dem.py source_dem.tif --output data/terrain/tile.f32 --metadata data/terrain/tile.json --max-size 257
\`\`\`

Attach \`scripts/world/dem_terrain_tile.gd\` to a Node3D and set its metadata and float32 file paths. The script validates dimensions and byte count before constructing a mesh. Input elevation units are metres; set \`vertical_scale\` to match the game's world scale.

This is a terrain import pipeline, not a downloaded global elevation dataset. Obtain DEM tiles from a suitable source (for example Copernicus DEM) and review the source's attribution and use terms before redistribution.

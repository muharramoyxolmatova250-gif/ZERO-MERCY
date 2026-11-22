# OpenStreetMap roads, buildings and settlements

## Data source

ZERO MERCY uses regional OpenStreetMap extracts distributed by Geofabrik:
- Machine-readable catalogue: https://download.geofabrik.de/index-v1-nogeom.json
- Technical documentation: https://download.geofabrik.de/technical.html
- OSM copyright and licence: https://www.openstreetmap.org/copyright

Geofabrik's catalogue lists region IDs and public PBF download URLs. Extracts are normally updated daily. OSM data is licensed under ODbL 1.0. Provide clear attribution (© OpenStreetMap contributors), and assess ODbL share-alike obligations for any publicly distributed derivative database. Read the current licence and attribution rules before shipping.

## Step A — discover region IDs

```bash
python tools/geodata/download_osm_extract.py --list
```

## Step B — download a country extract

```bash
python tools/geodata/download_osm_extract.py --region uzbekistan
```

Change the ID to another exact ID printed by `--list`. Country extracts can be large; check available storage first. The script downloads the public PBF into `data/osm/pbf/`.

## Step C — separate features

Install `osmium-tool` from https://osmcode.org/osmium-tool/ and run:

```bash
python tools/geodata/filter_osm_extract.py data/osm/pbf/uzbekistan-latest.osm.pbf
```

It creates separate PBFs for:
- Road/highway ways
- Building ways
- Place nodes, ways and relations
- Waterway ways
- Landuse and natural ways

This first filter is intentionally conservative. It preserves source OSM objects in PBF format; it does not yet convert them to Godot meshes or prove every feature is valid for game use.

## Next conversion milestone

Use GDAL/OGR or a dedicated OSM parser to transform filtered PBF features into spatially indexed region tiles. Simplify linework by LOD, triangulate building footprints, preserve tags needed for classification, and keep neighboring tile borders seam-safe. Avoid loading an entire country or the planet into one Godot scene.

## Data policy

Do not use public Nominatim or Overpass endpoints for bulk planet-scale extraction. Use regional extracts and respect provider capacity and licence terms. Never present OSM coverage as complete: mapping density varies by region.

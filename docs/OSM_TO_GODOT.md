# OSM to Godot region preview

This stage turns an exported regional OpenStreetMap GeoJSON file into simple 3D geometry inside Godot.

## 1. Download and filter a region

```bash
python tools/geodata/download_osm_extract.py --region uzbekistan
python tools/geodata/filter_osm_extract.py data/osm/pbf/uzbekistan-latest.osm.pbf
```

## 2. Export a small area to GeoJSON

Install osmium-tool, then export the source PBF or a clipped regional PBF:

```bash
osmium export data/osm/pbf/uzbekistan-latest.osm.pbf -o data/osm/uzbekistan.geojson
```

For a first preview, use a small regional extract or clip to a few kilometres around the chosen centre before export. Whole-country GeoJSON may be very large and the Godot preview loads its FeatureCollection into memory.

## 3. Open the Godot preview

Open `scenes/world/osm_region.tscn`. In the Inspector set:
- `geojson_path`: the exported GeoJSON file under `res://`.
- `region_center_lat` and `region_center_lon`: the centre of the chosen small region.
- `max_features`: cap the number of features processed in the first preview.

The script renders road linework as flat strips, waterways as blue strips, and building footprints as simple extruded blocks. It reads OSM tags when present. It is deliberately a simple prototype: no terrain draping, bridge/tunnel elevation, multipolygon holes, relation assembly, texture atlases, or streaming yet.

## Coordinate and scale limits

The preview uses a local equirectangular approximation around the configured centre. It is suitable only for relatively small regions; distortion grows with distance and latitude. It is not a substitute for a proper projected GIS tile pipeline.

## Next production steps

- Clip source PBFs to deterministic region tiles before GeoJSON conversion.
- Reproject each tile into a local metric CRS and preserve exact tile bounds.
- Build seam-safe road meshes and building meshes in worker processes.
- Add terrain draping, bridges, tunnels, water polygons, and feature LOD.
- Load/unload tiles asynchronously around the player.

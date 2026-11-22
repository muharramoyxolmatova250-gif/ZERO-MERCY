# Geographic tile planning and batch processing

These tools turn a downloaded regional OSM PBF into reproducible small GeoJSON tiles for the Godot importer.

## 1. Download a region explicitly

```bash
python tools/geodata/build_global_manifest.py --region uzbekistan --download
```

## 2. Plan tiles

Example bounding box for Uzbekistan (west, south, east, north):

```bash
python tools/geodata/plan_region_tiles.py --region uzbekistan --bbox 55.9 37.1 73.2 45.6 --tile-deg 0.05 --anchor 64.0 41.0
```

The tile plan is saved to `data/world/tile_jobs/uzbekistan.json`. The 0.05-degree grid is deliberately small to keep each GeoJSON chunk manageable. At high latitudes, degree tiles have different ground widths; this is a starter regional projection, not a global globe projection.

## 3. Process bounded batches

Install osmium-tool and run:

```bash
python tools/geodata/process_region_tiles.py data/osm/pbf/uzbekistan.osm.pbf data/world/tile_jobs/uzbekistan.json --start 0 --count 100
```

Continue with subsequent ranges (100–199, 200–299, etc.). Existing GeoJSON tiles are skipped unless `--force` is supplied. PBF and GeoJSON outputs are generated from the supplied source file; the scripts do not create synthetic geographic features.

## Output and next integration step

Each tile entry contains its bounding box, center, shared-anchor local origin and Godot GeoJSON resource path. The next integration task is to generate a Godot tile index from the plan and attach the region streamer to the active player scene. The current region importer is a local preview: multipolygon holes, terrain elevation draping, globe curvature, threaded streaming and production LOD are not yet complete.

OSM attribution: © OpenStreetMap contributors. Review ODbL 1.0 obligations before distributing derived databases.

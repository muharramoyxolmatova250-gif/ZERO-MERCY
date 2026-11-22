# Runtime integration: regional Earth streaming

The main game scene creates an Earth region streamer after spawning Dara. The streamer reads `res://data/world/region_tiles.json`, loads nearby OSM region scenes, and unloads distant ones. The main scene limits instantiation to one region per frame.

## Generate a region index

```bash
python tools/geodata/build_global_manifest.py --region uzbekistan --download
python tools/geodata/plan_region_tiles.py --region uzbekistan --bbox 55.9 37.1 73.2 45.6 --tile-deg 0.05 --anchor 64.0 41.0 --tile-size-m 4000
python tools/geodata/process_region_tiles.py data/osm/pbf/uzbekistan.osm.pbf data/world/tile_jobs/uzbekistan.json --start 0 --count 100
```

The player and region tiles must share the same local geographic anchor. The player currently spawns near the local origin of the cyberpunk prototype. Use the same anchor for the generated tile index before exploring the downloaded region.

## Scope

This is a regional streaming foundation, not a completed Earth globe. The OSM renderer is still a first-pass geometry importer. Terrain/elevation, globe curvature, threaded parsing, robust multipolygon holes, collision batching, production LOD, all-country datasets and authored building interiors remain unfinished.

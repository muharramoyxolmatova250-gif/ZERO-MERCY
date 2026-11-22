# ZERO MERCY — Global Earth data pipeline

## Worldwide catalogue and country queue

The catalogue uses Geofabrik's full `index-v1.json` to obtain country boundary geometry. It stores compact bounding rectangles rather than the full source polygons. Dateline-crossing extents are split into two rectangles.

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_country_queue.py
python tests/test_global_country_queue.py
```

The queue contains downloadable country-level extracts with ISO-3166-1 codes. Combined extracts retain every code they cover.

## Shared global tile grid

All country extracts use the same equirectangular tile grid, anchored at longitude 72.3°, latitude 40.7° (the ZERO MERCY starting-world origin). A tile crossing a national boundary can contain several GeoJSON source files. The runtime index keeps every source path and the region streamer loads them together, rather than replacing one country's tile with another.

Use `.github/workflows/build-global-country-tiles.yml` with a country `region_id`, tile width and bounded tile range. The workflow resolves all bounding-box parts automatically, downloads only the selected country's PBF, plans globally aligned cells, processes the requested batch, validates the exports and merges their paths into `data/world/region_tiles.json`.

The Andijan workflow is a four-tile smoke test on the same shared grid. It is not the world-data target.

## Current technical boundary

The shared grid is a flat equirectangular coordinate frame, not a spherical globe-native streaming system. It is a foundation for global geographic coverage, not yet seamless planetary traversal. Globe movement, elevation/terrain, coastlines and landcover, rivers/lakes, LOD, detailed cyberpunk city dressing and performance qualification remain separate engineering tasks.

OpenStreetMap-derived data requires attribution **© OpenStreetMap contributors** and compliance with ODbL 1.0: https://www.openstreetmap.org/copyright.

# ZERO MERCY — Global Earth data pipeline

## Worldwide catalogue and country queue

The catalogue uses Geofabrik's full `index-v1.json` to obtain country boundary geometry. If that index is unreachable, the builder retries and then enriches the cached Geofabrik extract catalogue with the committed Natural Earth 110m boundaries. Dateline-crossing extents are split into two rectangles.

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_country_queue.py
python tests/test_global_country_queue.py
python tests/test_global_tile_grid.py
python tests/test_global_build_state.py
```

The queue contains downloadable country-level extracts with ISO-3166-1 codes. Combined extracts retain every code they cover.

## Shared global tile grid and automatic progress

All country extracts use the same equirectangular tile grid, anchored at longitude 72.3°, latitude 40.7° (the ZERO MERCY starting-world origin). A tile crossing a national boundary can contain several GeoJSON source files. The runtime index keeps every source path and the region streamer loads them together. It can be regenerated from all committed tile plans with `python tools/geodata/rebuild_global_runtime_index.py`, so a regional smoke test cannot permanently erase global coverage.

The scheduled workflow `.github/workflows/build-global-country-tiles.yml` runs every six hours. It selects the next unfinished country automatically, downloads or restores its PBF, plans globally aligned cells, processes a bounded tile batch, validates it, advances `data/world/global_build_state.json`, and commits the verified result. It resumes the same country on the next run until all its tiles are processed, then moves to the next country. Manual dispatch can target a specific `region_id` or let the queue choose the next one.

The Andijan workflow is a four-tile smoke test on the same shared grid. It is not the world-data target.

## Current technical boundary

The shared grid is a flat equirectangular coordinate frame, not a spherical globe-native streaming system. It is a foundation for global geographic coverage, not yet seamless planetary traversal. Globe movement, elevation/terrain, coastlines and landcover, rivers/lakes, LOD, detailed cyberpunk city dressing and performance qualification remain separate engineering tasks.

OpenStreetMap-derived data requires attribution **© OpenStreetMap contributors** and compliance with ODbL 1.0: https://www.openstreetmap.org/copyright.

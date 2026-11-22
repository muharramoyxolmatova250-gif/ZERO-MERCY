# ZERO MERCY — Global Earth data pipeline

The global queue is generated from Geofabrik's official worldwide extract index:

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_country_queue.py
```

The queue retains one shallowest downloadable extract per ISO-3166-1 country code and includes the catalogue's geographic bounding box. Aggregate continent extracts and nested regional duplicates are excluded.

## Country batch workflow

Use `.github/workflows/build-global-country-tiles.yml`. Supply a country extract ID from `data/world/global_country_queue.json`, tile width, and a bounded tile range. The workflow resolves that country's bounds automatically, downloads only its PBF, plans tiles in a shared world coordinate frame, merges the runtime tile index, processes the requested batch, validates outputs and commits verified data.

Run successive batches by increasing `tile_start`. Large countries require many runs; the PBF itself may exceed GitHub runner disk or time limits. The old Andijan workflow is only a small smoke test.

## Remaining world-scale engineering

This pipeline is for real OSM roads, building footprints and waterways. It is not a finished planet: spherical globe streaming, elevation/terrain coverage, coastlines, landcover, rivers/lakes, global LOD, detailed interiors and performance qualification still require implementation. The current regional streamer uses a flat shared coordinate grid; a globe-native tile selector is required before using it for seamless travel across the entire spherical Earth.

OpenStreetMap-derived data requires attribution **© OpenStreetMap contributors** and compliance with ODbL 1.0: https://www.openstreetmap.org/copyright.

# ZERO MERCY — Global Earth data pipeline

## Country-level worldwide queue

Refresh the official Geofabrik extract catalogue and derive one non-overlapping country-level extract per ISO-3166-1 code:

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_country_queue.py
```

The queue is written to `data/world/global_country_queue.json`. It chooses the shallowest downloadable extract for each country code to avoid downloading a country and all nested subdivisions redundantly.

## Process country data in bounded batches

GitHub Actions workflow `.github/workflows/build-global-country-tiles.yml` is the global production entry point. Run it with a country `region_id` from the queue, geographic bounds (`west,south,east,north`), tile width and a bounded tile range. Each run downloads only that country's PBF, plans geographic tiles, processes the requested batch, validates the GeoJSON and runtime index, then commits verified output.

Use small geographic bounds and repeat the workflow with successive `tile_start` values. Large countries require many batches. The older Andijan workflow remains a small smoke-test fixture, not the global data pipeline.

## Current technical boundaries

This workflow builds real OSM vector tiles (roads, building footprints and waterways) for the selected bounds. It does not by itself create a complete Earth game. Global elevation/terrain, coastlines and landcover, antimeridian-safe globe rendering, per-layer LOD, robust cross-region streaming, authored interiors, cyberpunk city dressing and performance qualification remain separate engineering work. A successful regional batch is not proof of global coverage.

## Licensing

Geofabrik extracts derive from OpenStreetMap. Display **© OpenStreetMap contributors** and link to https://www.openstreetmap.org/copyright. Review ODbL 1.0 attribution and share-alike obligations before distributing derived databases.

# ZERO MERCY — Global map data pipeline

## What is now automated

`tools/geodata/build_global_manifest.py` fetches Geofabrik's official machine-readable index and writes `data/world/global_regions.json`. The index lists available regional extracts and their PBF URLs, parent IDs and ISO country/administrative codes.

Generate or refresh the catalogue:

```bash
python tools/geodata/build_global_manifest.py
```

List every downloadable region:

```bash
python tools/geodata/build_global_manifest.py --list
```

Download one country/region after checking free disk space:

```bash
python tools/geodata/build_global_manifest.py --region uzbekistan --download
```

Download multiple explicit extracts:

```bash
python tools/geodata/build_global_manifest.py --region france --region japan --download
```

The script deliberately refuses to download everything implicitly. The current Geofabrik index lists very large continent extracts (multi-gigabyte each); a full planet-scale raw download can require substantial storage, processing time and memory. Choose regional extracts and process them in batches.

## Convert selected PBF data

Install `osmium-tool`, then filter a downloaded PBF:

```bash
python tools/geodata/filter_osm_extract.py data/osm/pbf/uzbekistan.osm.pbf
```

Create a small preview region with the existing clip/export tool:

```bash
python tools/geodata/prepare_osm_region.py data/osm/pbf/uzbekistan.osm.pbf --bbox 72.30 40.75 72.38 40.81 --tile 0,0 --anchor 72.34 40.78
```

The current Godot OSM importer creates first-pass roads, building extrusions and waterways from GeoJSON. It is a regional preview and does not yet handle full multipolygon building holes, terrain draping, full road junction topology, global projection, threaded tile generation or production LOD/streaming. Generated cyberpunk buildings should be used only as visual filler where real footprints are absent.

## Batch validation

Every processed batch should be validated before it is committed or added to the runtime index:

```bash
python tools/geodata/validate_osm_tile_batch.py \
  data/world/tile_jobs/andijan.json \
  --start 0 --count 4 \
  --index data/world/region_tiles.json
```

The validator checks each exported GeoJSON FeatureCollection, verifies non-empty geometry features and road/building coverage, checks the geographic bounding boxes, and confirms that the Godot runtime index includes the planned region tiles. The Andijan GitHub Actions workflow runs this validator automatically before committing generated data. A passing validation confirms data integrity for that batch only; it does not prove global geographic coverage or runtime performance.

## Required production milestones

1. Fetch selected country extracts in batches; keep source URLs, timestamps, checksums and licences in the catalogue.
2. Clip into consistent geographic tiles and convert to indexed vector/mesh chunks.
3. Build global terrain from a suitable elevation source; OSM does not supply a complete global elevation model.
4. Build water, landcover, roads, buildings and place-name layers with per-layer LOD.
5. Add asynchronous worker threads, cache budgets, persistent region state and graceful low-memory fallback.
6. Add authored interiors, props, traffic, pedestrians and cyberpunk set dressing. OpenStreetMap building footprints do not provide all interior geometry or textures.
7. Validate coverage and performance region by region before claiming the Earth map is complete.

## Licensing and attribution

Geofabrik distributes OpenStreetMap extracts under ODbL 1.0. Display clear attribution: **© OpenStreetMap contributors** with a link to https://www.openstreetmap.org/copyright. Review attribution and share-alike requirements for any publicly distributed derived database. Do not assume that all imagery, textures, terrain or third-party assets are covered by OSM's licence.

## First playable real-data region: Andijan / Asaka

The automated workflow `.github/workflows/build-andijan-osm-tiles.yml` downloads the Uzbekistan Geofabrik PBF, creates four adjacent 0.1-degree geographic tiles covering 72.2–72.4°E and 40.6–40.8°N, and exports roads, building footprints and waterways to `data/osm/tiles/andijan/`.

Verified first-region source coverage:
- 4 GeoJSON tiles
- 223,211 OSM features total
- 12,087 road features
- 204,187 building features
- 79 waterway features

Each tile carries its physical ground extent so the Godot region scene can size its base plane to the actual geographic tile. The runtime index uses a shared 72.3°E, 40.7°N local anchor and an 8 km grid.

Source data is © OpenStreetMap contributors, ODbL 1.0. This is the first regional dataset, not global building coverage. The largest tile is about 55 MB as GeoJSON; production-scale streaming still needs geometry batching, progressive detail, memory budgets and more performance testing.
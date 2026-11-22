# ZERO MERCY — Global Earth data pipeline

## Worldwide country and settlement catalogue

The global catalogue uses Geofabrik's downloadable extracts and Natural Earth 110m country geometry. If the full Geofabrik geometry index is unreachable, the builder enriches the cached extract catalogue with Natural Earth country bounds. Countries without a dedicated extract are covered by clipped continent-parent extracts.

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_country_queue.py
python tests/test_global_country_queue.py
python tests/test_global_tile_grid.py
python tests/test_global_build_state.py
python tests/test_etopo_tile_index.py
python tests/test_osm_urban_tile_bboxes.py
```

The current queue covers 204 ISO-3166 codes with 195 extract jobs, including five supplemental parent extracts. The exact queue is regenerated from the source catalogue rather than hand-maintained.

## Populated-place detail tiles

A country extract is not expanded into every 0.1-degree cell in its bounding rectangle. The pipeline first filters OSM `place=city,town,village,hamlet` features, then creates clipped detail bounds around each settlement. Large cities receive a wider detail radius; towns, villages and hamlets receive smaller radii. Isolated territories with no place features receive only a small fallback sample. This avoids spending years building empty desert, ocean and mountain cells while preserving a worldwide settlement-first streaming plan.

The shared world grid is globally aligned at 0.1-degree cells, anchored at longitude 72.3°, latitude 40.7°. Country extracts that overlap the same cell share one runtime index entry and retain all source GeoJSON paths. The index can be reconstructed from saved plans with:

```bash
python tools/geodata/rebuild_global_runtime_index.py
```

## Automatic OSM and terrain processing

The workflow `.github/workflows/build-global-country-tiles.yml` runs hourly and after a successful Earth catalogue build. It resumes the next unfinished country and processes eight cells per batch:

1. Download or restore the selected country/parent OSM PBF
2. Extract city, town, village and hamlet bounds
3. Plan globally aligned OSM cells around those places
4. Extract OSM cells in a single Osmium multi-extract pass
5. Download the NOAA ETOPO 2022 15-arc-second source tile(s) for each cell
6. Crop and resample the DEM to float32 terrain samples aligned to the OSM cell
7. Validate OSM GeoJSON, DEM dimensions, geographic bounds and shared runtime-index paths
8. Advance persistent progress and commit only the game-ready GeoJSON/DEM tiles

Large source PBF and ETOPO GeoTIFF files are cached build inputs and are not committed. The game loads the generated DEM mesh and collision alongside the OSM cell; roads and building footprints are draped over sampled terrain elevations.

## Global overview and detailed terrain

The Earth overview uses Natural Earth country polygons, major rivers, lakes and elevation-point mountain markers. The ETOPO pipeline adds actual terrain relief for generated detailed cells. The OSM tiles add roads, buildings and waterways around populated places. The world overview therefore covers all continents and countries, while detailed city-scale OSM/DEM coverage grows incrementally around settlements rather than precomputing every square kilometre.

The current world grid is a flat equirectangular gameplay projection, not yet a globe-native continuous planetary coordinate system. Seamless spherical traversal, higher-resolution terrain layers, detailed city interiors and performance qualification remain separate work.

## Attribution and licensing

- OpenStreetMap-derived data: **© OpenStreetMap contributors**, https://www.openstreetmap.org/copyright. Review ODbL 1.0 attribution and share-alike obligations.
- NOAA ETOPO 2022 global relief model: DOI **10.25921/fd45-gt74**.
- Natural Earth vector geography is public domain.

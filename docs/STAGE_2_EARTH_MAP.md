# ZERO MERCY — Stage 2: Real Earth geography foundation

Status: **Stage 2 foundation implementation complete.** This stage adds the geographic coordinate foundation, a standalone spherical Earth scene, country polygon rendering, and repeatable source-data/tile preparation tools. It does not claim that all global street/building/terrain data is already downloaded or that the entire planet is playable.

## What is implemented

- `scripts/world/earth_coordinates.gd`: Earth-centred coordinate conversion, local regional projection helpers, geographic tile keys and bounds.
- `scenes/world/earth_globe.tscn` + `scripts/world/earth_globe.gd`: 3D ocean sphere, country land polygons and glowing border lines from Natural Earth GeoJSON.
- `tools/geodata/download_natural_earth.py`: downloads 110m or 50m Natural Earth country boundary GeoJSON and validates it before saving.
- `tools/geodata/build_global_manifest.py`: builds a catalogue of regional OpenStreetMap PBF extracts.
- `tools/geodata/plan_region_tiles.py`: divides a selected region into geographic tile jobs and writes the runtime index.
- `tools/geodata/process_region_tiles.py`: clips selected PBF data and exports GeoJSON batches.
- `scripts/world/osm_region.gd` + `scripts/world/region_streamer.gd`: first-pass regional roads/building footprints/waterway rendering and distance-based tile loading.

## Generate the Earth overview data

Run from the repository root:

```bash
python tools/geodata/download_natural_earth.py --scale 110m
```

For more detailed country outlines (larger file and heavier processing):

```bash
python tools/geodata/download_natural_earth.py --scale 50m
```

Then open `scenes/world/earth_globe.tscn` in Godot 4.3+. The country GeoJSON is generated locally under `data/geodata/` and is not committed as a large generated asset.

## Prepare detailed regional map data

Install `osmium-tool`, then:

```bash
python tools/geodata/build_global_manifest.py
python tools/geodata/build_global_manifest.py --region uzbekistan --download
python tools/geodata/plan_region_tiles.py --region uzbekistan --bbox 55.9 37.1 73.2 45.6 --tile-deg 0.05 --anchor 64 41
python tools/geodata/process_region_tiles.py data/osm/pbf/uzbekistan.osm.pbf data/world/tile_jobs/uzbekistan.json --start 0 --count 100
```

The regional pipeline is intentionally batched: do not download or process every planet extract at once. Confirm available storage and network capacity first.

## Data provenance and licensing

- Natural Earth country boundaries: public domain; source and terms are linked from the downloader.
- OpenStreetMap extracts: © OpenStreetMap contributors, ODbL 1.0. Keep visible attribution and review share-alike requirements for redistributed derived databases.
- OSM footprints do not provide building interiors, full terrain elevation, complete land cover or all hydrography.

## Automated checks

GitHub Actions runs the planner smoke test, then imports the Godot project headlessly and launches the main scene for a short smoke test. The workflow result must be checked in the Actions tab; adding the workflow does not itself prove a successful run.

## Remaining work (not falsely marked complete)

- Download and process selected global/continent/country datasets; validate coverage and missing areas.
- Integrate elevation/DEM, detailed coastlines, rivers/lakes, land cover and administrative levels.
- Replace first-pass local tangent projection with robust globe-to-local tile transforms and dateline/polar handling.
- Add multipolygon holes, topology fixes, road junctions, tile LOD, batching, asynchronous generation and memory budgets.
- Integrate globe selection into the gameplay world and verify seamless travel from globe overview to ground-level regions.
- Run Godot editor/runtime checks and profile real hardware.

**Completion boundary:** Stage 2's data/rendering foundation and repeatable pipeline are implemented. The complete, detailed, seamless, fully playable Earth is not yet finished; that requires downloading, processing and validating the actual regional source datasets plus the remaining systems above.

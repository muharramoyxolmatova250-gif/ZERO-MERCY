# Prepare a real OSM tile for Godot

This is the reproducible data-preparation step that connects a regional PBF extract to the Godot region scene and tile index.

## 1. Download the Uzbekistan source extract

```bash
python tools/geodata/download_osm_extract.py --region uzbekistan
```

The PBF can be large. Check available disk space first.

## 2. Install osmium-tool

Install the official `osmium-tool` package for your operating system: https://osmcode.org/osmium-tool/

## 3. Clip and export a small Andijan-area test tile

```bash
python tools/geodata/prepare_osm_region.py data/osm/pbf/uzbekistan-latest.osm.pbf --bbox 72.30 40.75 72.38 40.81 --tile 0,0 --anchor 72.34 40.78
```

The script:
- clips the source PBF to the requested west/south/east/north bounding box;
- exports that small extract to GeoJSON;
- writes the GeoJSON into `data/osm/tiles/`;
- updates `data/world/region_tiles.json` with its centre and local-world origin.

Repeat for neighboring bboxes, assigning adjacent tile keys such as `1,0` or `0,1`. Keep the same `--anchor` for every tile in the same local map. The streamer uses a 2,000 m tile grid by default; choose bbox dimensions and tile_size consistently before creating multiple tiles.

## 4. Connect the streamer

In Godot, create a Node3D for the streamer, attach `scripts/world/region_streamer.gd`, set the target to the player, and assign `scenes/world/osm_region.tscn` as its region scene. Set `tile_index_path` to `res://data/world/region_tiles.json`.

The example bbox is a small test region only. It is not an authoritative boundary for the city and its feature coverage depends on OSM mapping. The scripts have not been run in this repository environment; run the commands locally and check the output before opening the scene.

## Coordinate note

The prototype converts lon/lat to a local equirectangular approximation around a shared anchor. It is suitable for a compact local test area, not for country-scale or planet-scale coordinates. A production pipeline needs projected regional coordinates, exact tile bounds, clipping buffers, seam-safe geometry, and terrain height sampling.

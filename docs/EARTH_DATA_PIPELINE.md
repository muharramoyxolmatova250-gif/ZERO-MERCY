# ZERO MERCY — Earth geodata pipeline

## Stage 1: global country geometry (implemented)

The first globe uses Natural Earth Admin 0 country/map-unit polygons:
- 110m: small, fast global overview dataset.
- 50m: more detailed global overview for later zoom levels.
- Source mirror: https://github.com/nvkelso/natural-earth-vector
- Official data portal: https://www.naturalearthdata.com/downloads/
- License: Natural Earth vector/raster data is public domain:
  https://www.naturalearthdata.com/about/terms-of-use/

Download:
```bash
python tools/geodata/download_natural_earth.py --scale 110m
python tools/geodata/download_natural_earth.py --scale 50m
```

The files are written to `data/geodata/`. They are generated data and are not committed by default.

Open `scenes/world/earth_globe.tscn` in Godot 4.3+ to view the globe. The current renderer builds country polygon meshes on a spherical surface and draws neon border lines. It is a first-pass visualization, not production cartography: polygon holes, antimeridian edge cases, disputed-boundary styling, and high-detail coastlines need dedicated handling.

## Stage 2: higher-detail administrative geography

Add Natural Earth 10m country and Admin-1 state/province layers for close-range map context. Keep the 110m/50m/10m tiers separate and choose by camera distance.

## Stage 3: elevation and physical geography

Add tiled DEM sources (for example Copernicus DEM or NASA SRTM where coverage is available), plus rivers, lakes, land cover, and coastlines. Convert source rasters to game-ready tiles outside the runtime. Never load a planet-wide heightmap into one scene.


## Stage 3: real elevation tiles (downloader added)

The repository includes a regional Copernicus DEM GLO-30 downloader:
```bash
python tools/geodata/download_copernicus_dem.py --bbox 72.0 40.0 73.5 41.0
```
The example downloads one-degree tiles intersecting a small test area near Andijan, Uzbekistan. Tiles are written to `data/dem/copernicus-glo30/`. Do not download the whole planet in one run.

See [COPERNICUS_DEM.md](COPERNICUS_DEM.md) for source, tile naming, licensing, and the next conversion steps. GLO-30 is a Digital Surface Model (DSM), not bare-earth terrain; ocean tiles are not included. Missing/unreleased 30 m tiles are reported and skipped. The downloader has been added to the repository but has not yet been run against the live bucket or tested locally.


## Stage 4: roads, buildings, settlements, waterways (pipeline added)

Regional OpenStreetMap extract tooling is now in the repository:
- `tools/geodata/download_osm_extract.py` discovers Geofabrik region IDs and downloads the chosen PBF.
- `tools/geodata/filter_osm_extract.py` separates road, building, place, waterway, and landuse/natural features with `osmium-tool`.
- Full instructions and ODbL attribution notes: [OPENSTREETMAP_PIPELINE.md](OPENSTREETMAP_PIPELINE.md).

Start with one country/region and check available disk space. OSM coverage is uneven, and these scripts only download/filter source data; they do not yet generate finished Godot roads, buildings, or NPC-ready city scenes. Do not bulk-query public Nominatim/Overpass services.

## Stage 4: roads, buildings, and settlements (production conversion still pending)

Use country/region extracts from OpenStreetMap. OSM data is licensed under ODbL; attribution and share-alike obligations apply. Review the current OSM attribution and ODbL guidance before distributing derived databases:
https://www.openstreetmap.org/copyright
https://www.geofabrik.de/data/download.html

Import OSM PBF files offline, filter by feature tags, simplify geometry by level of detail, and generate spatially indexed region bundles. Do not scrape or request the entire planet from the public Nominatim or Overpass services.


## Stage 5: first OSM-to-Godot 3D preview (code added)

A Godot region prototype now lives at `scenes/world/osm_region.tscn` with script `scripts/world/osm_region.gd`. It reads a small regional GeoJSON FeatureCollection and creates:
- road strips from OSM `highway` line features;
- simple extruded building footprints;
- blue waterway strips.

See [OSM_TO_GODOT.md](OSM_TO_GODOT.md) for export and scene setup. This preview uses a local equirectangular coordinate approximation and is intended for a small region only. It is not yet terrain-draped, seam-safe, optimized, or streamed. Godot runtime validation is still pending.

## Stage 6: planet streaming

Partition the globe into deterministic spatial cells (initial prototype: latitude/longitude tiles; production: cube-sphere or another seam-safe scheme). Load nearby cells asynchronously, retain a small neighbor ring, cancel stale jobs, and unload distant cells. Terrain, roads, buildings, and NPC simulation should have separate streaming budgets.

## Validation checklist

- [ ] Download 110m data and verify FeatureCollection.
- [ ] Open the globe scene in Godot 4.3+.
- [ ] Confirm country polygons and border lines render without errors.
- [ ] Compare against the source map for dateline and island defects.
- [ ] Add automated mesh tests before increasing detail.
- [ ] Add DEM tiles and region streaming only after the global base is stable.

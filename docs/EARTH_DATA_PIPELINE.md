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

## Stage 4: roads, buildings, and settlements

Use country/region extracts from OpenStreetMap. OSM data is licensed under ODbL; attribution and share-alike obligations apply. Review the current OSM attribution and ODbL guidance before distributing derived databases:
https://www.openstreetmap.org/copyright
https://www.geofabrik.de/data/download.html

Import OSM PBF files offline, filter by feature tags, simplify geometry by level of detail, and generate spatially indexed region bundles. Do not scrape or request the entire planet from the public Nominatim or Overpass services.

## Stage 5: planet streaming

Partition the globe into deterministic spatial cells (initial prototype: latitude/longitude tiles; production: cube-sphere or another seam-safe scheme). Load nearby cells asynchronously, retain a small neighbor ring, cancel stale jobs, and unload distant cells. Terrain, roads, buildings, and NPC simulation should have separate streaming budgets.

## Validation checklist

- [ ] Download 110m data and verify FeatureCollection.
- [ ] Open the globe scene in Godot 4.3+.
- [ ] Confirm country polygons and border lines render without errors.
- [ ] Compare against the source map for dateline and island defects.
- [ ] Add automated mesh tests before increasing detail.
- [ ] Add DEM tiles and region streaming only after the global base is stable.

# Worldwide geographic tile plan

## Goal

The world is partitioned by geographic coordinates so the data pipeline can build and validate local map cells without creating one planet-sized scene.

## Current source catalogue

Run:

```bash
python tools/geodata/build_world_manifest.py
```

This reads Geofabrik's public machine-readable index and writes
`data/osm/geofabrik_world_manifest.json`. The catalogue includes continent,
country and subregion PBF URLs where provided. It does not download any PBF.

Then inspect an exact region ID and download only that region:

```bash
python tools/geodata/download_osm_extract.py --list
python tools/geodata/download_osm_extract.py --region uzbekistan
```

The global OSM planet is extremely large. The OSM wiki describes the current
planet PBF as tens of gigabytes compressed and over two terabytes uncompressed;
Geofabrik's continent extracts are also multi-gigabyte. Build the world
incrementally by continent/country, with storage checks and resumable downloads.
Sources: https://wiki.openstreetmap.org/wiki/Planet.osm and
https://download.geofabrik.de/technical.html

## Tile coordinate convention

- Geographic source coordinates are WGS84 longitude/latitude in degrees.
- Use small local tangent-plane patches for geometry generation only.
- Keep the original WGS84 bounds and source IDs in each generated tile manifest.
- Use a globe/cube-sphere or geocentric placement for planetary positioning.
- Never treat one local equirectangular projection as valid across the globe.
- Split antimeridian-crossing features before writing tile geometry.
- Preserve cross-tile ways/relations and duplicate a small edge margin to avoid seams.

## Data layers per tile

1. Terrain elevation and landform.
2. Coastlines, lakes and rivers.
3. Roads and paths by functional class.
4. Building footprints, height/levels and building type tags.
5. Place names and administrative boundaries.
6. Vegetation and land cover.

## Runtime rendering tiers

- Planet view: low-detail Natural Earth polygons and simplified terrain.
- Continent/country view: 10m boundaries and medium terrain tiles.
- City view: OSM roads/buildings and streamed terrain.
- Street view: detailed building facades, props, interiors and authored assets.

Real OSM building footprints are not complete everywhere. Procedural cyberpunk
buildings are a visual fallback, not a claim that every generated structure is
a real-world building.

## Licensing

Display `© OpenStreetMap contributors` attribution and review ODbL 1.0
requirements, including share-alike obligations for qualifying derived
databases, before publishing game data. Geofabrik extracts are daily snapshots;
they are not a guarantee that every road or building exists in the source.

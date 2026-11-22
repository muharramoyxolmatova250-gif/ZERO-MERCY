# Earth data pipeline

The intended world is assembled from licensed source datasets and converted into small region packages. It must not be built as one enormous scene.

## Data layers

| Layer | Candidate source | Purpose |
|---|---|---|
| Country boundaries / coastlines | Natural Earth | Global low/medium-detail outlines and country polygons |
| Roads / buildings / places | OpenStreetMap extracts, such as Geofabrik | Detailed transport network, structures and settlements |
| Elevation | Copernicus DEM or NASA SRTM where coverage is suitable | Terrain height |
| Rivers / lakes | OpenStreetMap and suitable public hydrography datasets | Water features |
| Land cover / vegetation | Properly licensed global land-cover datasets | Forests and biome placement |

## Pipeline stages

1. Download a small test region first; record source, date, resolution and license.
2. Validate and normalize coordinate reference systems.
3. Clip source features to a fixed geographic tile grid.
4. Convert elevation samples to heightmaps or mesh tiles.
5. Simplify vector geometry by level of detail.
6. Generate Godot resources and a region manifest.
7. Load nearby tiles asynchronously and unload distant tiles safely.
8. Test seams, scale, memory, performance and attribution.

## Important constraints

- Natural Earth is appropriate for broad global geography, not detailed street-level accuracy.
- OpenStreetMap is licensed under ODbL. Attribution is required and share-alike obligations may apply to derived databases; review the current terms before distribution.
- Elevation datasets have coverage, resolution and usage conditions. SRTM does not cover the polar regions.
- Country borders and coastlines are vector features; they do not provide terrain elevation.
- Data availability does not grant rights to redistribute every third-party building model, texture or photograph.
- Never claim the whole Earth is complete until all regions have been generated and tested.

## Initial test region
Start with one small area (for example, a few city blocks), then one country-sized region. Only expand after the pipeline produces repeatable, validated output.

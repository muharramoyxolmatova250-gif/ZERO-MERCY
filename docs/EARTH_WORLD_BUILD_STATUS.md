# Earth-scale world build status

ZERO MERCY's target is a complete Earth-scale world. The repository contains the beginnings of that pipeline, but it does not yet contain the finished planet or all real buildings.

## Shared coordinate foundation

`scripts/world/earth_coordinates.gd` provides WGS84-style Earth-centered coordinates, local tangent-plane conversion, one-degree geographic tile keys, and tile bounds. The local tangent helper is intended for small regional geometry; it is not a replacement for a globe projection at continental scale.

## Procedural cyberpunk district fallback

`scripts/world/procedural_city.gd` creates deterministic block layouts, roads, varied building heights, neon roof crowns, and optional collision. It is a visual filler for areas where licensed footprint data is missing. It must not be described as the actual buildings of a real city.

## Real-world data required for completeness

- Global coastlines, country boundaries and administrative regions: Natural Earth.
- Real road/building footprints and place names: regional OpenStreetMap extracts with ODbL attribution and compliance.
- Terrain: licensed DEM tiles such as Copernicus GLO-30 where coverage exists.
- Rivers, lakes and land cover: suitable licensed hydrography and land-cover datasets.
- Detailed interiors, furniture, props, traffic and local signage: separately authored or licensed assets.

## Quality and streaming requirements

Use distance-based LODs, instancing/batching, collision only near the player, asynchronous tile generation, memory budgets, and region state persistence. A 9K render target is a high-end aspiration, not a guarantee; texture resolution, geometry density, and effects must scale to hardware.

## Current limitation

The coordinate and procedural-district scripts are foundations only. No worldwide building database has been downloaded, converted, streamed, or validated. The project must not be called a completed Earth map until every target region has data coverage and automated/runtime checks.

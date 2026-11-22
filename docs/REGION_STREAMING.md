# Region streaming prototype

`scripts/world/region_streamer.gd` loads region scenes around a target Node3D and unloads regions outside a larger radius. It uses a JSON tile index and limits scene additions per frame to reduce frame spikes.

## Setup in Godot

1. Add a Node3D named `RegionStreamer` to the world scene.
2. Attach `scripts/world/region_streamer.gd`.
3. Set `target_path` to the player Node3D.
4. Set `region_scene` to `scenes/world/osm_region.tscn`.
5. Set `tile_index_path` to `res://data/world/region_tiles.json`.
6. Set `tile_size_m` to match the tile width used by the preprocessing pipeline.
7. Ensure every GeoJSON path in the index exists in the Godot project.

The sample index contains placeholder paths and illustrative tile centres; it is a schema example, not a ready-to-play map. The OSM region script uses a local geographic centre to convert coordinates. Tile geometry and the tile origin must be generated consistently by the preprocessing pipeline; do not mix unrelated coordinate origins.

## Current limitations

- The streamer is distance-based and frame-budgeted, not yet threaded.
- It supports a local planar tile grid, not seamless globe-scale cube-sphere cells.
- The current OSM region preview creates one mesh per feature and is not suitable for dense metropolitan production data without batching/LOD.
- Terrain height sampling, seam stitching, collision generation, cache eviction, cancellation, NPC simulation budgets, and save-state handoff are not implemented.
- The sample index does not contain real tile data.

This is a foundation for a later tested streaming system, not proof of planet-scale streaming performance.

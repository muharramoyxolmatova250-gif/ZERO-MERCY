# ZERO MERCY — Distance LOD assets

## Purpose
`scripts/world/distance_lod.gd` is a reusable distance-based visual switcher for world props, buildings, vehicles and landmark meshes. It selects one of three authored variants rather than pretending to generate lower-poly meshes automatically.

## Setup in Godot
1. Create a Node3D asset root and attach `distance_lod.gd`.
2. Add three visual child nodes: a detailed near mesh, a medium-detail mesh and a far silhouette/impostor.
3. Assign the player/camera Node3D to `target_path`.
4. Assign each child to the matching variant path.
5. Tune `near_distance`, `mid_distance` and `update_interval` for the asset scale.

Only one configured variant is visible at a time. If a variant path is left empty, that tier has no visible representation; assign all three for continuous coverage. The script checks distance on a configurable interval to avoid doing the work every frame.

## Important limits
- This is a runtime switcher, not an automatic mesh decimator or impostor baker.
- The project still needs actual authored low/medium/high meshes and material variants.
- It does not yet control collision shapes, shadow casting, occlusion or texture mip streaming.
- Validate scene paths and performance in the Godot editor on target hardware before treating the feature as production-ready.

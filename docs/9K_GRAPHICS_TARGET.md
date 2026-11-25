# ZERO MERCY — 9K graphics target

## Current verified project baseline

The checked-in `project.godot` declares Godot 4.3, the `forward_plus` desktop
renderer and the `mobile` renderer fallback. The project window viewport is
1920×1080. Forward+ unlocks more advanced 3D rendering features, but this is
**not** a 9K renderer setup.

## What 9K means for this project

The cinematic output target is 9216×5184 (9K-class). This is a production
target, not the default player resolution and not a claim that the current
build renders at 9K. Rendering every frame at that size can require very large
amounts of GPU memory and bandwidth. The game must never force this resolution
on a player's monitor.

## Added runtime quality profiles

`scripts/rendering/graphics_profile_manager.gd` defines four runtime presets:

- Performance — reduced 3D scale and no anti-aliasing.
- High — balanced anti-aliasing and native 3D scale.
- Ultra — higher MSAA, temporal AA where exposed by the active renderer.
- Cinematic 9K target — highest requested quality values, while retaining the
  player's actual display resolution.

The manager checks whether each Viewport property exists before setting it.
This matters because renderer capabilities differ. Unsupported settings are
reported as warnings instead of causing a property access failure.

The manager is attached by `scripts/main.gd` and applies the High preset at
startup. The renderer was switched to Forward+ to enable the next lighting and
material work. Existing scenes and shaders still require an in-editor runtime
compatibility pass; no such pass is claimed by this commit.

## Required production work before calling the game 9K-ready

1. Evaluate a Forward+ renderer migration on a dedicated branch and test every
   existing material, shader, environment, particle system and post-process.
2. Build cinematic lighting, physically based materials, high-resolution
   source textures and authored cyberpunk assets. 8K/16K textures should be
   used selectively; loading them everywhere is wasteful.
3. Add distance-based mesh LOD, texture mipmaps, occlusion culling, impostors
   and GPU/CPU profiling.
4. Stream the Earth by region: unload distant cells, asynchronously load nearby
   cells, and keep memory budgets per platform.
5. Add scalable shadow, reflection, volumetric fog and global-illumination
   settings supported by the selected renderer and target hardware.
6. Profile at 1080p, 1440p, 4K and finally the 9K-class target. Set performance
   budgets and fallback presets before shipping.

## Important status

These commits switch the project to Forward+, attach the runtime quality
manager, and enable ambient occlusion, screen-space indirect lighting,
volumetric fog and directional shadows in the startup environment. They do not
add 9K textures, finished cinematic assets, ray tracing, or a verified 9K
frame-rate. The project has not yet been launched in the Godot editor for a
runtime compatibility or performance test.


## District geometry LOD foundation

The procedural district now assigns camera-distance visibility ranges to generated building geometry, facade details and neon accents. Small neon elements fade out at shorter distances; medium details and large building shells remain visible farther away. This reduces distant draw work without removing collision bodies. Procedural building materials also use stronger metallic response and a subtle clearcoat for polished cyberpunk surfaces. These are geometry-level visibility bands, not authored replacement meshes: dedicated low-poly LOD meshes and impostors are still required for a finished large-world production pipeline.

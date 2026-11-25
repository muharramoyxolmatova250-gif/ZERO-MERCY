# ZERO MERCY — AAA Visual Quality Standard

## Direction

ZERO MERCY is a **3D, photorealistic cyberpunk open-world game**. The visual target is premium AAA presentation: believable materials, coherent scale, natural motion, cinematic lighting, dense but readable environments, and consistent art direction.

The game must not look like a primitive blockout, toy-like scene, random neon collection, or low-detail procedural demo. Cyberpunk styling is expressed through believable architecture, signage, practical lights, technology, weather, and lived-in streets—not by covering every surface in glowing colors.

## Non-negotiable visual rules

- Keep the world fully 3D. Do not replace the game with a 2D presentation.
- Use real-world proportions and physically plausible materials (PBR).
- Buildings need authored silhouettes, facade depth, windows, entrances, roof equipment, weathering, and readable ground-floor detail. Repeated primitive boxes are blockout tools only.
- Use restrained neon accents. Emissive signs must illuminate nearby surfaces and remain legible without clipping the image.
- Wet surfaces need roughness variation, puddle placement, and reflections that respond to nearby lights; avoid mirror-like roads everywhere.
- Lighting must preserve dark detail and highlight detail. Avoid crushed blacks, blown-out neon, excessive bloom, and oversaturated color.
- Add believable atmosphere: fog, rain, cloud cover, wind response, and time-of-day changes where supported.
- Characters, vehicles, props, and animation must share the same scale, material response, and visual quality.
- Use LODs, occlusion culling, texture streaming, and world streaming so visual quality remains practical in a large open world.

## Rendering and resolution target

- Primary renderer: Godot Forward+.
- The **9K-class target** is 9216 × 5120 output capability, not a claim that the current project renders natively at 9K.
- Never force 9K on every player's display. Select output resolution based on monitor and GPU capability; use scalable render resolution and quality settings.
- Quality tiers should scale shadows, reflections, anti-aliasing, volumetrics, texture quality, and render scale without changing the art direction.
- Cinematic 9K is an aspirational high-end target and requires suitable hardware, high-resolution source assets, memory, and profiling.

## Production acceptance checklist

A visual feature is not complete merely because a script or shader exists. Verify it in a running Godot build and inspect representative screenshots at gameplay distance and close range.

- [ ] No visible placeholder cubes or untextured blockout buildings in finished areas.
- [ ] No obvious texture stretching, tiling, z-fighting, or broken material assignments.
- [ ] Day, night, rain, and wet-road lighting remain readable and coherent.
- [ ] Reflections and shadows are stable and performance-tested.
- [ ] LOD transitions are not distracting.
- [ ] NPCs, traffic, and environment assets look like they belong in one world.
- [ ] Test on target hardware at native display resolution before advertising a quality tier.
- [ ] Run the project and capture visual evidence before marking the graphics milestone complete.

## Current status

This document defines the target and acceptance criteria. It does **not** certify that the current repository already meets AAA or native 9K quality. Existing procedural shaders and graphics profiles are implementation foundations; the project still needs high-quality source assets, scene integration, runtime validation, visual review, and performance profiling.

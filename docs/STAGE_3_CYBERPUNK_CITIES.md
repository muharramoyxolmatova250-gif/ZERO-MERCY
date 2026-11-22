# Stage 3 — Cyberpunk city foundation

Implemented:
- Seeded multi-block district layout with intersecting neon road grids.
- Repeated building footprints with variable tower heights and dark metallic materials.
- Facade window lights, rooftop structures and neon roof trims.
- Optional collision for building shells.
- A reusable standalone scene at \`scenes/world/cyberpunk_district.tscn\`.

This is a procedural cyberpunk district generator, not a replica of every real-world city. Actual city street/building placement still depends on licensed and processed OSM tiles. Interiors, traffic simulation, crowds, NPC schedules, signage language, detailed props and production LOD remain later tasks.


## Main gameplay integration

`scripts/main.gd` now instantiates the seeded district generator as `NeoCityDistrict` during startup. The standalone scene is also available for editor placement. This remains a procedural prototype: production city-scale performance, instanced/batched geometry, real mapped street layouts, interiors, traffic, NPC crowds, and full LOD are not complete.

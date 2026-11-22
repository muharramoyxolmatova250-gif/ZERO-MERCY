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


## Automated acceptance smoke test

GitHub Actions runs the district scene headlessly and checks that procedural geometry is generated. Facade window instances use MultiMesh. This is a structural smoke test, not a performance benchmark or a visual acceptance test on target PCs. Real mapped city coverage, interiors, traffic, NPCs, advanced LOD and production art remain outside this stage foundation.


## Enterable lobby shell update

- Tower shells are assembled from separate wall panels instead of a single opaque solid box.
- The front opening remains clear at pedestrian height; side walls, rear wall and roof retain the building silhouette.
- Lobby floors, reception counters, holographic directories and neon lights are generated inside the shell.
- Automated smoke tests count the hollow shell panels alongside lobby lights.

This creates accessible ground-floor lobby space in the procedural district. It does not yet provide unique furnished interiors on every upper floor or elevators.

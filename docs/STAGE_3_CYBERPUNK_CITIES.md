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


## Global-world simulation foundation (new)

- Local district population target now scales to 50 visible citizen agents at the default five-block setting; the smoke test confirms the spawned count.
- Citizen agents now keep lightweight needs (energy, hunger, social and curiosity), choose utility-scored goals, use phones during selected stops, and retain a short event/decision memory.
- City traffic target increased to 20 electric vehicles; the smoke test confirms all 20 spawn and move.
- A global background population model tracks 18 city hubs across multiple continents and local-time work, commute, social and rest cohorts. At the default setting it represents 216,000 residents as aggregate cohorts, not 216,000 individually rendered or independently thinking NPCs.
- A global airline prototype defines 14 airport hubs across multiple countries and runs 12 cyberpunk flight records with passenger counts. The current aircraft meshes are local sky visuals; airport terminals, runway operations, accurate globe-following flight paths, boarding, and passenger travel between streamed regions remain future integration work.
- The environment uses a dark metallic/neon palette for generated citizens, vehicles and aircraft.

These are simulation foundations, not a finished planet-scale life simulator or GTA-level autonomous AI. Advanced pathfinding, interaction, jobs/buildings, family relationships, births/aging, individual long-term schedules, and streaming of populated real-world cities remain incomplete.

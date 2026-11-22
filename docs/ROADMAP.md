# ZERO MERCY — Development Roadmap

The full vision is a long-term target. Each stage must become testable before the next one is treated as complete.

## Vision
- Cyberpunk re-imagining of the whole Earth.
- Dara / Soya as the protagonist; story choices affect the world.
- Dense cities, rural settlements, wilderness, oceans, mountains and roads.
- NPCs with routines, relationships, work, education and life stages.
- Diegetic phones, social feeds, news and television as simulated game systems.
- Driving, traversal and combat with original mechanics and a distinctive identity.
- A long branching campaign (approximately 70 hours is a design goal, not a current measured runtime).

## Milestones

### 0 — Project foundation (started)
- [x] Godot 4 project and main scene
- [x] Procedural neon city-block prototype
- [x] Basic third-person movement and camera
- [ ] Run and validate in Godot editor on target hardware

### 1 — Character and controls
- Replace capsule prototype with a production-quality Dara character.
- Create a proper skeleton, animation state machine and interaction system.
- Add accessibility and remappable controls.

### 2 — Earth data pipeline
- Import country polygons and coastlines.
- Process elevation tiles and hydrography.
- Import roads, buildings and settlements by region.
- Preserve attribution and source-license metadata.

### 3 — Planet-scale world
- Define a geographic tile grid and coordinate reference strategy.
- Convert source data into streamed Godot region assets.
- Add distance-based loading, unloading, caching and LOD.
- Validate seams, coordinates, memory use and traversal between regions.

### 4 — Cyberpunk locations
- Establish modular building, street, signage, lighting and interior kits.
- Create authored hero districts and procedural supporting districts.
- Add weather, day/night cycle and ambient city activity.

### 5 — Simulation
- Build NPC schedules and lightweight population simulation.
- Add persistent identities, relationships and selected life events.
- Simulate phone, social, news and TV content locally as game features.

### 6 — Vehicles and action
- Prototype vehicle physics and handling.
- Build original combat, enemy AI and stealth systems.
- Add missions, save/load and player progression.

### 7 — Story and polish
- Implement Dara's branching narrative and consequences.
- Performance profiling, streaming stress tests, accessibility and QA.
- Add scalable graphics presets; 9K is a high-end target, not a universal guarantee.

## Definition of done
A milestone is complete only when its feature exists in the repository, runs in the target engine, has been tested, and its limitations are documented.

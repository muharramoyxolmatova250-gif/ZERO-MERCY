# ZERO MERCY

**An ambitious cyberpunk open-world project built with Godot 4.**

ZERO MERCY is planned as a planet-scale open-world game set on a cyberpunk version of Earth. The 9K target is an aspirational high-end mode; actual resolution and frame rate depend on hardware.

## Current development stage

Stage 1 — Core Game Foundation implementation is complete. Stage 2 — Real Earth geography foundation is implemented: a standalone globe scene, Natural Earth country-boundary downloader, WGS84-style coordinate helpers, and a regional OSM tile pipeline are in the repository. It includes a third-person controller, player health and stamina, a basic hitscan weapon, a live HUD, a data-driven prologue objective chain, a local save manager and a procedural cyberpunk blockout city.

**Verification note:** Stage 1 implementation is complete; automated Godot 4.3 headless validation and an end-to-end playtest are still required before runtime correctness is certified. The protagonist is currently a capsule blockout, not the final character model. See [docs/STAGE_1_CORE_FOUNDATION.md](docs/STAGE_1_CORE_FOUNDATION.md) for the acceptance checklist and known limitations.

## Run it

1. Install Godot 4.3 or newer.
2. Clone this repository and open the folder containing `project.godot`.
3. Press F5 to run the project.

Controls:
- `W A S D` — move
- Mouse — look around
- `Shift` — sprint (consumes stamina)
- `Space` — jump
- `E` — inspect the signal beacon when nearby
- Left mouse button — fire
- `R` — reload
- `Esc` — release the mouse; click to capture again

## 10-stage production roadmap

1. Core game foundation
2. Real Earth geography
3. Cyberpunk cities and infrastructure
4. Graphics, lighting and atmosphere
5. Living NPC simulation
6. Vehicles and connected-world devices
7. Combat and enemy AI
8. Main story and campaign
9. Integration, optimization and QA
10. Final release candidate

Each stage is announced as complete only after its implementation and acceptance checks are finished. A commit alone is not proof of runtime correctness.

## Project principles

- Stream Earth in regions rather than loading the entire planet at once.
- Keep quality scalable for different PCs.
- Use properly licensed and attributed geographic data.
- Never present placeholders as finished systems or real online services.

Stage 2 is a foundation, not a claim that all global street/building/terrain data has been downloaded or that seamless planet-wide gameplay is complete. See [docs/STAGE_2_EARTH_MAP.md](docs/STAGE_2_EARTH_MAP.md), [docs/ROADMAP.md](docs/ROADMAP.md), [docs/STAGE_1_CORE_FOUNDATION.md](docs/STAGE_1_CORE_FOUNDATION.md), and [docs/GLOBAL_TILE_PIPELINE.md](docs/GLOBAL_TILE_PIPELINE.md).


## World production progress

- Stage 2: Earth geography foundation includes a globe renderer, country-boundary source downloader, WGS84-style coordinate helpers, regional OSM preparation/streaming, and a DEM elevation import pipeline. Actual worldwide datasets are not bundled; full detailed Earth coverage, seamless globe-to-ground travel, and runtime validation remain open.
- Stage 3: A seeded cyberpunk district generator is integrated into the main gameplay scene, with neon road grids, variable-height towers, facade lights, rooftop details, and optional building collision. This is a visual foundation, not a finished city simulation or AAA environment.
- See [Stage 2 Earth map](docs/STAGE_2_EARTH_MAP.md), [DEM terrain import](docs/DEM_TERRAIN_IMPORT.md), and [Stage 3 cyberpunk cities](docs/STAGE_3_CYBERPUNK_CITIES.md).

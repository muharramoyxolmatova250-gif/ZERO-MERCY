# ZERO MERCY

**An ambitious cyberpunk open-world project built with Godot 4.**

ZERO MERCY is planned as a planet-scale open-world game set on a cyberpunk version of Earth. The 9K target is an aspirational high-end mode; actual resolution and frame rate depend on hardware.

## Current development stage

Stage 1 — Core Game Foundation has been implemented in the repository. It includes a third-person controller, player health and stamina, a basic hitscan weapon, a live HUD, a data-driven prologue objective chain, a local save manager and a procedural cyberpunk blockout city.

**Important:** Stage 1 still requires a Godot 4.3+ editor/runtime validation pass. The protagonist is currently a capsule blockout, not the final character model. See [docs/STAGE_1_CORE_FOUNDATION.md](docs/STAGE_1_CORE_FOUNDATION.md) for the acceptance checklist and known limitations.

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

See [docs/ROADMAP.md](docs/ROADMAP.md), [docs/STAGE_1_CORE_FOUNDATION.md](docs/STAGE_1_CORE_FOUNDATION.md), and [docs/GLOBAL_TILE_PIPELINE.md](docs/GLOBAL_TILE_PIPELINE.md).

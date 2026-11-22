# ZERO MERCY

**An ambitious cyberpunk open-world project built with Godot 4.**

ZERO MERCY is planned as a planet-scale open-world game set on a cyberpunk version of Earth. The project is being developed in clear, testable stages. The 9K target is an aspirational maximum-quality mode; actual resolution and frame rate will depend on the player's hardware.

## Current status

This repository now contains the first playable foundation:
- Godot 4 project configuration and a main scene.
- A procedural neon city-block prototype.
- A basic third-person player controller.
- A documented roadmap and Earth-data pipeline plan.

This is an early prototype, not a finished game. Accurate global geography, production character art, advanced NPC simulation, vehicles, combat, story missions, and large-scale streaming remain future milestones.

## Run it

1. Install **Godot 4.3 or newer**.
2. Clone or download this repository.
3. Open the folder containing `project.godot` in Godot.
4. Press **F6** to run the current scene, or **F5** to run the project.

Controls:
- `W A S D` — move
- Mouse — look around
- `Shift` — sprint
- `Space` — jump
- `Esc` — release the mouse

## Project principles

- Build and test one milestone at a time.
- Stream the planet in regions; never load all Earth geometry at once.
- Keep high-end visual settings scalable for weaker PCs.
- Use properly licensed and attributed geographic data.
- Do not present placeholder systems as finished or real online services.

See [docs/ROADMAP.md](docs/ROADMAP.md) for the long-term plan and [docs/EARTH_DATA.md](docs/EARTH_DATA.md) for geography ingestion notes.

## Real Earth geography prototype

The next milestone adds a Natural Earth GeoJSON downloader and a Godot globe scene. To generate the data locally:

```bash
python tools/geodata/download_natural_earth.py --scale 110m
```

Then open `scenes/world/earth_globe.tscn` in Godot 4.3+. For a more detailed global dataset, use `--scale 50m`. Generated GeoJSON files are not committed; see [docs/EARTH_DATA_PIPELINE.md](docs/EARTH_DATA_PIPELINE.md) for sources, licensing, limitations, and the next terrain/OSM/streaming stages.

## First local Earth map test scene

A small integration scene is available at `scenes/world/earth_test_world.tscn`. It includes a temporary WASD player and a configured region streamer. Follow [docs/FIRST_EARTH_MAP_TEST.md](docs/FIRST_EARTH_MAP_TEST.md) and [docs/ANDIJAN_TEST_REGION.md](docs/ANDIJAN_TEST_REGION.md) to prepare a small OSM GeoJSON tile and run the scene with F6 in Godot. The scene has not yet been validated in the Godot editor.

## Story and progression foundations

The repository also includes data-driven mission objectives, branching dialogue, and versioned local saves. See [docs/STORY_SYSTEMS.md](docs/STORY_SYSTEMS.md). A short prologue mission and dialogue sample are included as data; they are not yet connected to a finished mission HUD, cinematic sequence, or complete campaign.

## Integrated prologue gameplay slice (code committed; editor validation pending)

The main cyberpunk city scene now instantiates:
- the existing third-person player;
- a mission HUD connected to the MissionManager autoload;
- a signal beacon that advances the first objective when the player enters its area and presses `E`;
- a rescue zone that completes the final prologue objective when entered;
- local save writing after mission completion.

### Prologue route

1. Walk to the signal beacon in the city.
2. Enter its area to register reaching the old market.
3. Press `E` to inspect the beacon.
4. Walk to the marked rescue zone to complete the escort objective.
5. Mission completion is written through SaveManager to a local JSON save.

Controls: WASD move, mouse look, Shift sprint, Space jump, E interact, Esc release mouse.

This is a small integrated gameplay slice, not the full ZERO MERCY campaign. It does not yet contain the final Dara character, cinematic story, combat, vehicles, life simulation, global Earth world, online phone/social systems, or the requested ~70-hour campaign. No Godot editor/runtime test has been performed in this environment; run it in Godot 4 and resolve any parse/runtime issues before treating it as verified.

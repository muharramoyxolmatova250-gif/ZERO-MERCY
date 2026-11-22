# First local Earth map test

A small test world scene is provided at `scenes/world/earth_test_world.tscn`. It contains a simple player controller and a configured region streamer.

## Prepare the first tile

Follow [ANDIJAN_TEST_REGION.md](ANDIJAN_TEST_REGION.md). After running the preparation script, confirm the GeoJSON path written in `data/world/region_tiles.json` exists under the project folder.

Important: the example bbox in that guide is a regional preview area, not a 2 km tile. For this scene's default 2,000 m tile grid, make neighboring test bboxes approximately 2 km wide/high and align their centres with the shared anchor and tile grid. Alternatively, change `tile_size_m` and all tile-index origins consistently.

## Open and run

1. Open the project in Godot 4.
2. Open `scenes/world/earth_test_world.tscn`.
3. Press F6 to run the current scene.
4. Use WASD to move, Shift to sprint, mouse to look, Escape to release the mouse, and click to recapture it.

If no prepared GeoJSON exists, the streamer will show an empty test area and emit a warning. The player capsule is a temporary test controller, not Dara's final character.

## Validation status

The scene and scripts have been committed, but this repository change has not been run in the Godot editor yet. Treat this as an integration candidate until you run it and inspect the Output panel for parse/runtime errors.

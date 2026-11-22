# ZERO MERCY — Stage 1: Core Game Foundation

Status: implementation committed; Godot editor/runtime verification is still required.

## Included
- Godot 4 project settings and the main gameplay scene.
- Third-person player controller with mouse-look, walk, sprint, jump and cursor release/re-capture.
- Player vitals: health, damage, healing and a death state.
- Sprint stamina with drain, delay and regeneration.
- Hitscan weapon with range, damage, magazine, reserve ammunition and reload.
- HUD displaying mission objective, health, stamina and ammunition.
- Data-driven prologue objective flow, interaction beacon, rescue-zone trigger and versioned local save manager.
- Procedural cyberpunk blockout environment and a training target for the first combat loop.

## Controls
- W/A/S/D: move
- Mouse: look
- Shift: sprint (uses stamina)
- Space: jump
- E: inspect the nearby signal beacon
- Left mouse: fire
- R: reload
- Esc: release mouse; click to capture it again

## Acceptance checklist
- [x] Main scene references the player, HUD, mission beacon, rescue zone and training target.
- [x] Player exposes health, stamina, ammunition and death signals for UI/gameplay integration.
- [x] HUD binds to player signals and mission-manager signals.
- [x] Mission progression is data-driven and completion writes a local save.
- [x] Core controls and actions are documented.
- [ ] Open in Godot 4.3+ and confirm there are no parser/import errors.
- [ ] Run the prologue end-to-end and confirm beacon/rescue collision areas trigger in the expected order.
- [ ] Confirm mouse capture, movement, sprint, jump, firing, reload and save/load on target hardware.

## Honest scope boundary
This is a playable-foundation implementation, not a finished AAA character or full game. Dara is still represented by a capsule blockout; there is no final rig, animation set, audio, respawn flow, accessibility menu or remappable-controls screen. The editor/runtime acceptance checks above must be performed before this stage can be called fully verified. No claim of 9K rendering or final-art quality is made.

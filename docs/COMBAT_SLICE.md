# ZERO MERCY — First Combat Slice

## Included

- A training enemy scene instantiated in the main cyberpunk city.
- Enemy health initialized from an exported maximum-health value.
- A player raycast weapon that checks physics hits.
- Damage is applied only to nodes in the `damageable` group.
- A 12-round magazine, 60 reserve rounds, 34 damage per hit, and a fire-rate cooldown.
- Reloading with the R key.
- The target is removed when health reaches zero.

## Controls

- Mouse: aim
- Left mouse button: fire while the mouse is captured
- R: reload
- Esc: release mouse capture
- WASD: move
- Shift: sprint
- Space: jump

## Current limitations

This is a foundation, not a finished shooter system. Enemy AI, player health, weapon models, muzzle flashes, hit reactions, audio, recoil, ammunition HUD, weapon switching, and balancing remain to be implemented. No Godot runtime validation is claimed yet.

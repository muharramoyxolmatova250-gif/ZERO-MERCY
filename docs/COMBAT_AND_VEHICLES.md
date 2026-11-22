# Combat and vehicle foundations

## Health component
Attach `scripts/combat/health_component.gd` as a child named `HealthComponent` to a CharacterBody3D or other target. It exposes damage, healing, health signals, and a one-time death signal.

## Hitscan weapon
Attach `scripts/combat/hitscan_weapon.gd` under the player camera or player node and set `camera_path` to the active Camera3D. Define input actions `fire` and `reload` in Project Settings. Targets need a child named `HealthComponent` or an `apply_damage(amount)` method. This is a basic raycast weapon foundation; it has no recoil, reload animation, muzzle flash, audio, projectile ballistics, hit reactions, or anti-cheat.

## Vehicle controller
Attach `scripts/vehicles/arcade_vehicle_controller.gd` to a VehicleBody3D with correctly positioned VehicleWheel3D children. Define `vehicle_accelerate`, `vehicle_reverse`, `vehicle_left`, `vehicle_right`, and `vehicle_handbrake` input actions. Tune wheel friction, suspension, mass, centre of mass, and force values in Godot. VehicleBody3D is a starting point, not Forza-level handling.

These scripts are standalone foundations and are not yet integrated into the main scene or validated in Godot.

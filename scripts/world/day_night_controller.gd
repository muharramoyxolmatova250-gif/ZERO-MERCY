extends Node
## Drives the scene lighting from GameSession's shared 24-hour clock.
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _update_elapsed := 0.0

func _ready() -> void:
 var world_env := get_parent().get_node_or_null("WorldEnvironment") as WorldEnvironment
 _sun = get_parent().get_node_or_null("GlobalSun") as DirectionalLight3D
 if world_env != null:
  _environment = world_env.environment
  if _environment != null and _environment.sky != null:
   _sky_material = _environment.sky.sky_material as ProceduralSkyMaterial
 if has_node("/root/GameSession"):
  GameSession.session_clock_changed.connect(_on_clock_changed)
  _apply_time(GameSession.day_time_hours)

func _on_clock_changed(hour: float) -> void:
 _apply_time(hour)

func _apply_time(hour: float) -> void:
 var daylight := clampf(sin((hour - 6.0) / 12.0 * PI), 0.0, 1.0)
 var twilight := 1.0 - absf(daylight * 2.0 - 1.0)
 if is_instance_valid(_sun):
  _sun.rotation_degrees.x = -8.0 - daylight * 62.0
  _sun.light_energy = lerpf(0.035, 1.15, daylight)
  _sun.light_color = Color(0.48, 0.58, 0.9).lerp(Color(1.0, 0.78, 0.58), twilight * 0.55)
 if _environment != null:
  _environment.ambient_light_energy = lerpf(0.16, 0.8, daylight)
  _environment.volumetric_fog_density = lerpf(0.012, 0.0035, daylight)
 if _sky_material != null:
  _sky_material.sky_top_color = Color(0.004, 0.008, 0.028).lerp(Color(0.12, 0.32, 0.62), daylight)
  _sky_material.sky_horizon_color = Color(0.035, 0.012, 0.065).lerp(Color(0.82, 0.48, 0.3), twilight * 0.65 + daylight * 0.35)

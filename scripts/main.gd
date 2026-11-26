extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/mission_hud.tscn")
const BEACON_SCENE := preload("res://scenes/world/mission_beacon.tscn")
const RESCUE_SCENE := preload("res://scenes/world/rescue_zone.tscn")
const ENEMY_SCENE := preload("res://scenes/combat/training_enemy.tscn")
const REGION_SCENE := preload("res://scenes/world/osm_region.tscn")
const STREAMER_SCRIPT := preload("res://scripts/world/region_streamer.gd")
const LIFE_SIM_SCRIPT := preload("res://scripts/world/world_life_sim.gd")
const PHONE_UI_SCRIPT := preload("res://scripts/ui/phone_ui.gd")
const MISSION_DIRECTOR_SCRIPT := preload("res://scripts/story/mission_objective_director.gd")
const DIALOGUE_UI_SCRIPT := preload("res://scripts/ui/dialogue_ui.gd")
const GRAPHICS_PROFILE_SCRIPT := preload("res://scripts/rendering/graphics_profile_manager.gd")
var _graphics_profile: Node
const EARTH_OVERVIEW_SCENE := preload("res://scenes/world/earth_overview.tscn")
var _earth_overview: Node3D
var _player: CharacterBody3D
var rng := RandomNumberGenerator.new()
var _autosave_elapsed := 0.0
const AUTOSAVE_INTERVAL := 30.0

func _ready() -> void:
 rng.randomize()
 _start_graphics_profile()
 _build_environment()
 _start_world_life_simulation()
 _build_city()
 var player := PLAYER_SCENE.instantiate() as CharacterBody3D
 player.name = "Dara"
 player.position = Vector3(0, 1.2, 12)
 _player = player
 add_child(player)
 SaveManager.restore_player_state(player)
 _start_region_streaming()
 _start_global_world_simulation()
 _start_society_simulation()
 _start_phone_ui()
 _start_dialogue_ui()
 _start_mission_objective_director()
 add_child(HUD_SCENE.instantiate())
 var beacon := BEACON_SCENE.instantiate()
 beacon.position = Vector3(0, 0, -8)
 add_child(beacon)
 var rescue_zone := RESCUE_SCENE.instantiate()
 rescue_zone.position = Vector3(15, 0, -25)
 add_child(rescue_zone)
 # A parked prototype coupe provides the first drivable vehicle.
 var coupe_scene := load("res://scenes/vehicles/cyber_coupe.tscn") as PackedScene
 if coupe_scene != null:
  var coupe := coupe_scene.instantiate()
  coupe.name = "SovereignCyberCoupe"
  coupe.position = Vector3(5.0, 0.15, 5.0)
  add_child(coupe)
 # A second drivable vehicle: cyber motorcycle.
 var bike_scene := load("res://scenes/vehicles/cyber_bike.tscn") as PackedScene
 if bike_scene != null:
  var bike := bike_scene.instantiate()
  bike.name = "DaraCyberBike"
  bike.position = Vector3(-5.0, 0.15, 5.0)
  add_child(bike)
 # Ambient traffic proxies animate along the distant boulevard.
 var traffic := Node3D.new()
 traffic.name = "AmbientTrafficSimulation"
 traffic.set_script(load("res://scripts/vehicles/ambient_traffic.gd"))
 add_child(traffic)
 # Wanted-level dispatcher spawns police backup as offences escalate.
 var police_dispatch := Node3D.new()
 police_dispatch.name = "PoliceDispatch"
 police_dispatch.set_script(load("res://scripts/police/police_dispatch.gd"))
 add_child(police_dispatch)
 # Initial hostile patrol: three enemies enter from a loose formation.
 # Each unit runs its own perception, pursuit and attack logic.
 var patrol_positions := [
  Vector3(0, 0, -18),
  Vector3(-6.5, 0, -23),
  Vector3(6.5, 0, -25)
 ]
 for index in range(patrol_positions.size()):
  var enemy := ENEMY_SCENE.instantiate()
  enemy.name = "HostilePatrol_%02d" % (index + 1)
  enemy.position = patrol_positions[index]
  add_child(enemy)





func _start_dialogue_ui() -> void:
 var dialogue_ui := CanvasLayer.new()
 dialogue_ui.name = "DialogueUI"
 dialogue_ui.set_script(DIALOGUE_UI_SCRIPT)
 add_child(dialogue_ui)

func _start_mission_objective_director() -> void:
 var director := Node3D.new()
 director.name = "MissionObjectiveDirector"
 director.set_script(MISSION_DIRECTOR_SCRIPT)
 add_child(director)

func _start_phone_ui() -> void:
 var phone := CanvasLayer.new()
 phone.name = "DaraPhone"
 phone.set_script(PHONE_UI_SCRIPT)
 add_child(phone)

func _start_world_life_simulation() -> void:
 var life_sim := Node.new()
 life_sim.name = "WorldLifeSimulation"
 life_sim.set_script(LIFE_SIM_SCRIPT)
 add_child(life_sim)

func _start_region_streaming() -> void:
 var streamer := Node3D.new()
 streamer.name = "EarthRegionStreamer"
 streamer.set_script(STREAMER_SCRIPT)
 streamer.set("target_path", NodePath("../Dara"))
 streamer.set("tile_index_path", "res://data/world/region_tiles.json")
 streamer.set("region_scene", REGION_SCENE)
 streamer.set("tile_size_m", 4000.0)
 streamer.set("load_radius", 1)
 streamer.set("unload_radius", 2)
 streamer.set("max_operations_per_frame", 1)
 add_child(streamer)

func _start_graphics_profile() -> void:
 _graphics_profile = Node.new()
 _graphics_profile.name = "GraphicsProfileManager"
 _graphics_profile.set_script(GRAPHICS_PROFILE_SCRIPT)
 add_child(_graphics_profile)
 _graphics_profile.call("apply_preset", 2) # Ultra quality; 9K target remains an explicit hardware-dependent mode.

func _build_environment() -> void:
 var world_env := WorldEnvironment.new()
 var environment := Environment.new()
 environment.background_mode = Environment.BG_SKY
 var sky := Sky.new()
 var sky_mat := ProceduralSkyMaterial.new()
 sky_mat.sky_top_color = Color(0.008, 0.012, 0.045)
 sky_mat.sky_horizon_color = Color(0.12, 0.018, 0.09)
 sky_mat.ground_bottom_color = Color(0.008, 0.008, 0.018)
 sky_mat.ground_horizon_color = Color(0.025, 0.012, 0.04)
 sky.sky_material = sky_mat
 environment.sky = sky
 environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.ambient_light_color = Color(0.22, 0.25, 0.42)
 environment.ambient_light_energy = 0.65
 environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.glow_enabled = true
 environment.glow_intensity = 0.45
 # Forward+ cinematic lighting features. Keep expensive GI disabled until
 # authored world geometry and performance budgets are ready.
 environment.ssao_enabled = true
 environment.ssao_radius = 2.0
 environment.ssao_intensity = 1.1
 environment.ssil_enabled = true
 environment.ssil_radius = 4.0
 environment.ssil_intensity = 0.7
 # Screen-space reflections add readable reflections to wet roads and glass.
 environment.ssr_enabled = true
 environment.ssr_max_steps = 64
 environment.ssr_fade_in = 0.15
 environment.ssr_fade_out = 2.0
 environment.ssr_depth_tolerance = 0.2
 # Cinematic bloom is restrained so emissive signs retain texture and shape.
 environment.glow_bloom = 0.12
 environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
 # Filmic exposure and saturation preserve detail in bright neon and dark streets.
 environment.adjustment_enabled = true
 environment.adjustment_brightness = 1.0
 environment.adjustment_contrast = 1.08
 environment.adjustment_saturation = 1.12
 environment.volumetric_fog_enabled = true
 environment.volumetric_fog_density = 0.006
 environment.volumetric_fog_length = 180.0
 environment.volumetric_fog_detail_spread = 2.0
 world_env.environment = environment
 add_child(world_env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -28, 0)
 sun.light_color = Color(0.35, 0.42, 0.8)
 sun.light_energy = 0.25
 sun.shadow_enabled = true
 sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
 add_child(sun)

func _build_city() -> void:
 # Use the actual global runtime index at the player's spawn cell. Do not hard-code
 # a country or a tile ID: the same startup must work as the global build advances.
 if _has_starting_world_tile():
  return
 var district := Node3D.new()
 district.name = "NeoCityDistrictFallback"
 district.set_script(load("res://scripts/world/procedural_city.gd"))
 add_child(district)


func _has_starting_world_tile() -> bool:
 var index_path := "res://data/world/region_tiles.json"
 if not FileAccess.file_exists(index_path):
  return false
 var file := FileAccess.open(index_path, FileAccess.READ)
 if file == null:
  return false
 var parsed: Variant = JSON.parse_string(file.get_as_text())
 if typeof(parsed) != TYPE_DICTIONARY:
  return false
 var tile_size := maxf(100.0, float(parsed.get("_tile_size_m", 11132.0)))
 # Dara's initial spawn is (0, 12) in the global equirectangular world frame.
 var cell_x := floori(0.0 / tile_size)
 var cell_z := floori(12.0 / tile_size)
 var entry: Variant = parsed.get(str(cell_x) + "," + str(cell_z), {})
 if typeof(entry) != TYPE_DICTIONARY:
  return false
 var paths: Array = entry.get("geojson_paths", [])
 if paths.is_empty() and str(entry.get("geojson_path", "")) != "":
  paths.append(str(entry["geojson_path"]))
 for path in paths:
  if FileAccess.file_exists(str(path)):
   return true
 return false
func _add_windows(x:float,z:float,h:float,w:float,d:float)->void:
 for row in range(1,int(h/2.4)):
  for col in range(2):
   var wx:=x+(float(col)-0.5)*w*0.55
   var wy:=row*2.2
   var color:=Color(0.0,0.75,1.0) if rng.randf()>0.5 else Color(1.0,0.15,0.45)
   _add_box(Vector3(wx,wy,z-d*0.505),Vector3(0.65,0.9,0.06),color,true)

func _add_box(pos:Vector3,size:Vector3,color:Color,emissive:=false)->void:
 var body:=StaticBody3D.new()
 body.position=pos
 var mesh:=MeshInstance3D.new()
 var box:=BoxMesh.new()
 box.size=size
 mesh.mesh=box
 var material:=StandardMaterial3D.new()
 material.albedo_color=color
 if emissive:
  material.emission_enabled=true
  material.emission=color
  material.emission_energy_multiplier=1.8
 mesh.material_override=material
 body.add_child(mesh)
 var collision:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=size
 collision.shape=shape
 body.add_child(collision)
 add_child(body)

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_F5:
   if is_instance_valid(_player):
    SaveManager.save_player_state(_player)
   get_viewport().set_input_as_handled()
   return
  elif event.keycode == KEY_F9:
   if is_instance_valid(_player):
    SaveManager.restore_player_state(_player)
   get_viewport().set_input_as_handled()
   return
 if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
  if _earth_overview == null:
   _earth_overview = EARTH_OVERVIEW_SCENE.instantiate()
   _earth_overview.name = "EarthMapOverview"
   add_child(_earth_overview)
   if _player != null:
    _player.set_physics_process(false)
    var player_camera := _player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
    if player_camera != null:
     player_camera.current = false
  else:
   _earth_overview.queue_free()
   _earth_overview = null
   if _player != null:
    _player.set_physics_process(true)
    var player_camera := _player.get_node_or_null("CameraPivot/Camera3D") as Camera3D
    if player_camera != null:
     player_camera.current = true


func _start_global_world_simulation() -> void:
 var population := Node3D.new()
 population.name = "GlobalPopulationSimulation"
 population.set_script(load("res://scripts/world/global_population_sim.gd"))
 add_child(population)
 var air_traffic := Node3D.new()
 air_traffic.name = "GlobalAirTraffic"
 air_traffic.set_script(load("res://scripts/world/global_air_traffic.gd"))
 add_child(air_traffic)

func _start_society_simulation() -> void:
 var society := Node.new()
 society.name = "WorldSocietySimulation"
 society.set_script(load("res://scripts/world/world_society_sim.gd"))
 add_child(society)


func _process(delta: float) -> void:
 if not is_instance_valid(_player):
  return
 _autosave_elapsed += delta
 if _autosave_elapsed >= AUTOSAVE_INTERVAL:
  _autosave_elapsed = 0.0
  SaveManager.save_player_state(_player)


func _notification(what: int) -> void:
 if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
  if is_instance_valid(_player):
   SaveManager.save_player_state(_player)

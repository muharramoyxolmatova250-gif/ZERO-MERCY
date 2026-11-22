extends Node3D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/mission_hud.tscn")
const BEACON_SCENE := preload("res://scenes/world/mission_beacon.tscn")
const RESCUE_SCENE := preload("res://scenes/world/rescue_zone.tscn")
const ENEMY_SCENE := preload("res://scenes/combat/training_enemy.tscn")
const REGION_SCENE := preload("res://scenes/world/osm_region.tscn")
const STREAMER_SCRIPT := preload("res://scripts/world/region_streamer.gd")
const LIFE_SIM_SCRIPT := preload("res://scripts/world/world_life_sim.gd")
const EARTH_OVERVIEW_SCENE := preload("res://scenes/world/earth_overview.tscn")
var _earth_overview: Node3D
var _player: CharacterBody3D
var rng := RandomNumberGenerator.new()

func _ready() -> void:
 rng.randomize()
 _build_environment()
 _start_world_life_simulation()
 _build_city()
 var player := PLAYER_SCENE.instantiate() as CharacterBody3D
 player.name = "Dara"
 player.position = Vector3(0, 1.2, 12)
 _player = player
 add_child(player)
 _start_region_streaming()
 _start_global_world_simulation()
 _start_society_simulation()
 add_child(HUD_SCENE.instantiate())
 var beacon := BEACON_SCENE.instantiate()
 beacon.position = Vector3(0, 0, -8)
 add_child(beacon)
 var rescue_zone := RESCUE_SCENE.instantiate()
 rescue_zone.position = Vector3(15, 0, -25)
 add_child(rescue_zone)
 var enemy := ENEMY_SCENE.instantiate()
 enemy.position = Vector3(0, 0, -18)
 add_child(enemy)


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
 world_env.environment = environment
 add_child(world_env)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48, -28, 0)
 sun.light_color = Color(0.35, 0.42, 0.8)
 sun.light_energy = 0.25
 add_child(sun)

func _build_city() -> void:
 # Keep a starter cyberpunk district only until the Uzbekistan settlement catalogue
 # is present; once real OSM settlements stream, avoid stacking two city cores.
 if FileAccess.file_exists("res://data/osm/tiles/uzbekistan/723_407.geojson"):
  return
 var district := Node3D.new()
 district.name = "NeoCityDistrictFallback"
 district.set_script(load("res://scripts/world/procedural_city.gd"))
 add_child(district)
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

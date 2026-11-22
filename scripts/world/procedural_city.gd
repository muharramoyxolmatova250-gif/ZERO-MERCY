extends Node3D
## Seeded cyberpunk district: roads, sidewalks, towers, windows, roof gear and street lights.
@export_range(2, 12, 1) var blocks_per_side := 5
@export var block_spacing := 52.0
@export var road_width := 14.0
@export var seed_value := 20261122
@export var min_building_height := 16.0
@export var max_building_height := 110.0
@export var generate_collision := true
@export var window_step := 3.2
var rng := RandomNumberGenerator.new()
var mats: Array[StandardMaterial3D] = []

func _ready() -> void:
    rng.seed = seed_value
    _materials()
    _roads_and_blocks()

func _materials() -> void:
    for c in [Color(0.018,0.028,0.05),Color(0.035,0.025,0.065),Color(0.045,0.055,0.075),Color(0.065,0.025,0.055)]:
        var m := StandardMaterial3D.new()
        m.albedo_color = c
        m.metallic = 0.72
        m.roughness = 0.34
        mats.append(m)

func _roads_and_blocks() -> void:
    var extent := blocks_per_side * block_spacing
    _box(Vector3(0,-0.3,0),Vector3(extent+road_width,0.5,extent+road_width),Color(0.012,0.018,0.028),false,false)
    for i in range(blocks_per_side+1):
        var p := (float(i)-float(blocks_per_side)*0.5)*block_spacing
        _box(Vector3(p,0.0,0),Vector3(road_width,0.08,extent+road_width),Color(0.02,0.028,0.045),false,false)
        _box(Vector3(0,0.0,p),Vector3(extent+road_width,0.08,road_width),Color(0.02,0.028,0.045),false,false)
        _box(Vector3(p,0.07,0),Vector3(0.16,0.035,extent),Color(0.0,0.7,0.95),true,false)
        _box(Vector3(0,0.07,p),Vector3(extent,0.035,0.16),Color(1.0,0.08,0.38),true,false)
    for x in range(blocks_per_side):
        for z in range(blocks_per_side):
            var center := Vector3((float(x)-float(blocks_per_side-1)*0.5)*block_spacing,0,
                (float(z)-float(blocks_per_side-1)*0.5)*block_spacing)
            _block(center)

func _block(center: Vector3) -> void:
    var count := rng.randi_range(2,4)
    for i in range(count):
        var w := rng.randf_range(10.0,17.0)
        var d := rng.randf_range(10.0,17.0)
        var h := rng.randf_range(min_building_height,max_building_height)
        var px := rng.randf_range(-block_spacing*0.27,block_spacing*0.27)
        var pz := rng.randf_range(-block_spacing*0.27,block_spacing*0.27)
        _building(center+Vector3(px,0,pz),Vector3(w,h,d))

func _building(base: Vector3,size: Vector3) -> void:
    var material := mats[rng.randi_range(0,mats.size()-1)]
    _box(base+Vector3(0,size.y*0.5,0),size,material.albedo_color,false,generate_collision)
    var roof := Color(0.0,0.82,1.0) if rng.randf()>0.5 else Color(1.0,0.08,0.42)
    _box(base+Vector3(0,size.y+0.12,0),Vector3(size.x+0.4,0.24,size.z+0.4),roof,true,false)
    _facade_windows(base,size,roof)
    _roof_detail(base,size,roof)

func _facade_windows(base: Vector3,size: Vector3,accent: Color) -> void:
    var columns := maxi(2,int(size.x/2.8))
    var rows := mini(24,maxi(1,int(size.y/window_step)))
    for side in [-1.0,1.0]:
        for row in range(rows):
            for col in range(columns):
                if rng.randf()<0.22: continue
                var x := (float(col)-float(columns-1)*0.5)*(size.x/float(columns))
                var y := (float(row)+0.5)*window_step
                var c := accent if rng.randf()>0.5 else Color(0.95,0.58,0.2)
                _box(base+Vector3(x,y,side*(size.z*0.5+0.035)),Vector3(0.72,1.15,0.07),c,true,false)

func _roof_detail(base: Vector3,size: Vector3,accent: Color) -> void:
    var roof_y := size.y+0.8
    _box(base+Vector3(0,roof_y,0),Vector3(size.x*0.22,1.4,size.z*0.22),Color(0.025,0.035,0.055),false,false)
    _box(base+Vector3(0,roof_y+0.8,0),Vector3(0.18,1.6,0.18),accent,true,false)
    if rng.randf()>0.5:
        _box(base+Vector3(size.x*0.3,roof_y+0.35,0),Vector3(1.4,0.6,1.4),Color(0.07,0.09,0.12),false,false)

func _box(pos: Vector3,size: Vector3,color: Color,glow: bool,collision: bool) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = 0.62
    m.roughness = 0.4
    if glow:
        m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = 2.2
    instance.material_override = m
    instance.position = pos
    add_child(instance)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        var shape := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = size
        shape.shape = box
        body.add_child(shape)
        add_child(body)

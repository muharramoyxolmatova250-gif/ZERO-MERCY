extends Node3D
## Distance-based visual LOD switcher for a single world asset.
## Add three visual variants as children and assign their NodePaths in the Inspector.
@export var target_path: NodePath
@export var near_variant_path: NodePath
@export var mid_variant_path: NodePath
@export var far_variant_path: NodePath
@export_range(10.0, 2000.0, 5.0) var near_distance := 90.0
@export_range(20.0, 5000.0, 5.0) var mid_distance := 280.0
@export_range(0.05, 2.0, 0.05) var update_interval := 0.25

var _target: Node3D
var _near: Node3D
var _mid: Node3D
var _far: Node3D
var _elapsed := 0.0
var _active_level := -1

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node3D
    _near = get_node_or_null(near_variant_path) as Node3D
    _mid = get_node_or_null(mid_variant_path) as Node3D
    _far = get_node_or_null(far_variant_path) as Node3D
    if near_distance >= mid_distance:
        mid_distance = near_distance + 10.0
    _apply_level(0)

func _process(delta: float) -> void:
    if _target == null:
        return
    _elapsed += delta
    if _elapsed < update_interval:
        return
    _elapsed = 0.0
    var distance_squared := global_position.distance_squared_to(_target.global_position)
    var near_squared := near_distance * near_distance
    var mid_squared := mid_distance * mid_distance
    var next_level := 2
    if distance_squared <= near_squared:
        next_level = 0
    elif distance_squared <= mid_squared:
        next_level = 1
    if next_level != _active_level:
        _apply_level(next_level)

func _apply_level(level: int) -> void:
    _active_level = level
    if _near != null:
        _near.visible = level == 0
    if _mid != null:
        _mid.visible = level == 1
    if _far != null:
        _far.visible = level == 2

func get_active_lod_level() -> int:
    return _active_level

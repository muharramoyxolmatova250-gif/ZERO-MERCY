extends Node3D
## Spawns backup units according to the player's active wanted level.
@export var maximum_units := 5
@export var spawn_radius := 32.0
var _spawned_units: Array[Node3D] = []
var _player: Node3D
var _ui_label: Label

func _ready() -> void:
 var players := get_tree().get_nodes_in_group("player")
 if not players.is_empty():
  _player = players[0] as Node3D
 _build_wanted_ui()

func _build_wanted_ui() -> void:
 var layer := CanvasLayer.new()
 layer.name = "WantedLevelHUD"
 add_child(layer)
 _ui_label = Label.new()
 _ui_label.position = Vector2(24, 80)
 _ui_label.add_theme_font_size_override("font_size", 28)
 _ui_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.12))
 _ui_label.text = ""
 layer.add_child(_ui_label)

func _process(_delta: float) -> void:
 if not is_instance_valid(_player):
  var players := get_tree().get_nodes_in_group("player")
  if not players.is_empty():
   _player = players[0] as Node3D
  return
 var active := Time.get_ticks_msec() < int(_player.get_meta("wanted_until", 0))
 var level := clampi(int(_player.get_meta("wanted_level", 0)), 0, 5) if active else 0
 _ui_label.text = ("POLICE  " + "★".repeat(level)) if level > 0 else ""
 while _spawned_units.size() < level and _spawned_units.size() < maximum_units:
  _spawn_backup(_spawned_units.size())

func _spawn_backup(index: int) -> void:
 var unit := CharacterBody3D.new()
 unit.name = "PoliceBackup_%02d" % (index + 1)
 var angle := TAU * float(index) / float(maximum_units)
 unit.position = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * spawn_radius
 unit.set_script(load("res://scripts/police/police_interceptor.gd"))
 get_tree().current_scene.add_child(unit)
 _spawned_units.append(unit)

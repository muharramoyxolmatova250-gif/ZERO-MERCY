extends Area3D
## A simple mission beacon. Player enters the area to reach the old market,
## then presses E to inspect the signal device.

@export var interaction_text := "Press E to inspect signal beacon"
var player_inside := false
var used := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if player_inside and not used and Input.is_action_just_pressed("interact"):
		used = true
		MissionManager.report_event("interact_beacon")
		print("Signal beacon inspected.")


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = true
		MissionManager.report_event("enter_old_market")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		player_inside = false

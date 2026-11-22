extends Area3D
## Enter this safe zone after inspecting the signal beacon to finish the prologue escort objective.

var triggered := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if triggered or not body.is_in_group("player"):
		return
	triggered = true
	MissionManager.report_event("escort_family_safe")
	print("Family escorted to safety. Prologue objective complete.")

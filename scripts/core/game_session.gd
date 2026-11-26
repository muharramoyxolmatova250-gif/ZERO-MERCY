extends Node
## Central runtime coordinator for ZERO MERCY.
## Owns shared player/session state and broadcasts gameplay events to independent systems.

signal player_registered(player: Node3D)
signal wanted_level_changed(level: int, reason: String)
signal crime_reported(crime_id: String, world_position: Vector3, severity: int)
signal world_event(event_id: String, payload: Dictionary)
signal session_clock_changed(hour: float)

const WANTED_DURATION_MS := 45000
const MAX_WANTED_LEVEL := 5

var player: Node3D
var wanted_level := 0
var wanted_until_ms := 0
var session_elapsed := 0.0
var day_time_hours := 18.0
var time_scale := 1.0
var _clock_emit_timer := 0.0


func _process(delta: float) -> void:
	session_elapsed += delta
	day_time_hours = fposmod(day_time_hours + delta * time_scale / 120.0, 24.0)
	_clock_emit_timer += delta
	if _clock_emit_timer >= 1.0:
		_clock_emit_timer = 0.0
		session_clock_changed.emit(day_time_hours)
	if wanted_level > 0 and Time.get_ticks_msec() >= wanted_until_ms:
		clear_wanted()


func register_player(candidate: Node3D) -> void:
	player = candidate
	player_registered.emit(candidate)
	_sync_wanted_to_player()


func unregister_player(candidate: Node3D) -> void:
	if player == candidate:
		player = null


func report_crime(crime_id: String, world_position: Vector3, severity: int = 1) -> void:
	var safe_severity := clampi(severity, 1, MAX_WANTED_LEVEL)
	var now := Time.get_ticks_msec()
	var active_level := wanted_level if now < wanted_until_ms else 0
	wanted_level = clampi(maxi(active_level, 0) + (1 if active_level > 0 else safe_severity), 1, MAX_WANTED_LEVEL)
	wanted_until_ms = now + WANTED_DURATION_MS
	_sync_wanted_to_player()
	crime_reported.emit(crime_id, world_position, safe_severity)
	wanted_level_changed.emit(wanted_level, crime_id)
	publish_world_event("crime_reported", {
		"crime_id": crime_id,
		"position": world_position,
		"severity": safe_severity,
		"wanted_level": wanted_level
	})


func clear_wanted() -> void:
	wanted_level = 0
	wanted_until_ms = 0
	_sync_wanted_to_player()
	wanted_level_changed.emit(0, "expired")


func publish_world_event(event_id: String, payload: Dictionary = {}) -> void:
	world_event.emit(event_id, payload)


func get_session_clock_text() -> String:
	var hour := floori(day_time_hours)
	var minute := floori((day_time_hours - float(hour)) * 60.0)
	return "%02d:%02d" % [hour, minute]


func _sync_wanted_to_player() -> void:
	if not is_instance_valid(player):
		return
	player.set_meta("wanted_level", wanted_level)
	player.set_meta("wanted_until", wanted_until_ms)

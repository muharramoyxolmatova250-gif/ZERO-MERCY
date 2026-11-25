extends Node
class_name ZeroMercyGraphicsProfile
## Runtime quality profiles for ZERO MERCY.
## The 9K profile is a target configuration, not a promise of native 9K output.

enum Preset {
	PERFORMANCE,
	HIGH,
	ULTRA,
	CINEMATIC_9K,
}

const PROFILES := {
	Preset.PERFORMANCE: {
		"msaa_3d": 0,
		"screen_space_aa": 0,
		"use_taa": false,
		"scaling_3d_scale": 0.75,
	},
	Preset.HIGH: {
		"msaa_3d": 1,
		"screen_space_aa": 1,
		"use_taa": false,
		"scaling_3d_scale": 1.0,
	},
	Preset.ULTRA: {
		"msaa_3d": 2,
		"screen_space_aa": 1,
		"use_taa": true,
		"scaling_3d_scale": 1.0,
	},
	Preset.CINEMATIC_9K: {
		"msaa_3d": 3,
		"screen_space_aa": 1,
		"use_taa": true,
		"scaling_3d_scale": 1.0,
	},
}

var active_preset: int = Preset.HIGH
var unsupported_settings: Array[String] = []

func apply_preset(preset: int, target_viewport: Viewport = null) -> bool:
	if not PROFILES.has(preset):
		push_warning("ZERO MERCY: unknown graphics preset.")
		return false

	var viewport_to_configure := target_viewport
	if viewport_to_configure == null:
		viewport_to_configure = get_viewport()
	if viewport_to_configure == null:
		push_warning("ZERO MERCY: no Viewport available for graphics setup.")
		return false

	unsupported_settings.clear()
	var profile: Dictionary = PROFILES[preset]
	for property_name in profile:
		if _has_property(viewport_to_configure, property_name):
			viewport_to_configure.set(property_name, profile[property_name])
		else:
			unsupported_settings.append(property_name)

	active_preset = preset
	if not unsupported_settings.is_empty():
		push_warning(
			"ZERO MERCY: renderer does not expose these quality settings: "
			+ ", ".join(unsupported_settings)
		)
	return unsupported_settings.is_empty()

func get_preset_name(preset: int = -1) -> String:
	var selected := active_preset if preset < 0 else preset
	match selected:
		Preset.PERFORMANCE:
			return "Performance"
		Preset.HIGH:
			return "High"
		Preset.ULTRA:
			return "Ultra"
		Preset.CINEMATIC_9K:
			return "Cinematic 9K target"
		_:
			return "Unknown"

func get_9k_target_resolution() -> Vector2i:
	# 9K-class target (9216 x 5184); do not force this on the player's display.
	return Vector2i(9216, 5184)

func _has_property(object: Object, property_name: String) -> bool:
	for property_info in object.get_property_list():
		if String(property_info.name) == property_name:
			return true
	return false

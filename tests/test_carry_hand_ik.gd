extends SceneTree

const CarryHandIK = preload("res://scripts/player/carry_hand_ik.gd")

func _initialize() -> void:
	_test_reach_clamping()
	_test_elbow_geometry()
	_test_degenerate_lengths()
	_test_normalization_fallback()
	quit()

func _test_reach_clamping() -> void:
	var shoulder := Vector3.ZERO
	var target := Vector3(5.0, 0.0, 0.0)
	var wrist: Vector3 = CarryHandIK.clamp_reach_target(shoulder, target, 0.4, 0.4)
	assert(wrist.distance_to(shoulder) <= 0.8)
	assert(wrist.distance_to(shoulder) > 0.7)

func _test_elbow_geometry() -> void:
	var shoulder := Vector3.ZERO
	var wrist := Vector3(0.5, 0.0, 0.0)
	var elbow: Vector3 = CarryHandIK.solve_elbow(shoulder, wrist, 0.4, 0.4, Vector3.UP)
	assert(is_equal_approx(shoulder.distance_to(elbow), 0.4))
	assert(is_equal_approx(elbow.distance_to(wrist), 0.4))

func _test_degenerate_lengths() -> void:
	assert(not CarryHandIK.validate_segment_lengths(0.0, 0.4))
	assert(CarryHandIK.validate_segment_lengths(0.4, 0.4))
	assert(CarryHandIK.get_elbow_flex(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0.0, 0.4) == 0.0)

func _test_normalization_fallback() -> void:
	var result: Vector3 = CarryHandIK.safe_normalize(Vector3.ZERO, Vector3.DOWN)
	assert(result.is_equal_approx(Vector3.DOWN))

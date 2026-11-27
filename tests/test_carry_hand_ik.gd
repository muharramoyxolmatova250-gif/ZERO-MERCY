extends SceneTree

const CarryHandIK = preload("res://scripts/player/carry_hand_ik.gd")

func _initialize() -> void:
	_test_reach_clamping()
	_test_elbow_geometry()
	_test_degenerate_lengths()
	_test_normalization_fallback()
	_test_reach_ratio()
	_test_segment_projection()
	_test_segment_distance()
	_test_chain_straightness()
	_test_bend_direction()
	_test_reach_comfort()
	_test_target_clamp_amount()
	_test_max_min_reach()
	_test_joint_balance()
	_test_wrist_direction()
	_test_solution_points()
	_test_closest_reachable_point()
	_test_direction_plane_projection()
	_test_target_distance_weight()
	_test_angle_limits()
	_test_orientation_finite()
	_test_lower_basis_finite()
	_test_upper_basis_finite()
	_test_solution_quality()
	_test_invalid_solver_lengths()
	_test_solution_lengths()
	_test_solution_directions()
	_test_constrained_solver()
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

func _test_reach_ratio() -> void:
	assert(is_equal_approx(CarryHandIK.get_reach_ratio(Vector3.ZERO, Vector3(0.4, 0.0, 0.0), 0.4, 0.4), 0.5))

func _test_segment_projection() -> void:
	var point := CarryHandIK.project_point_on_segment(Vector3(0.5, 2.0, 0.0), Vector3.ZERO, Vector3.RIGHT)
	assert(point.is_equal_approx(Vector3(0.5, 0.0, 0.0)))

func _test_segment_distance() -> void:
	assert(is_equal_approx(CarryHandIK.get_point_segment_distance(Vector3(0.5, 2.0, 0.0), Vector3.ZERO, Vector3.RIGHT), 2.0))

func _test_chain_straightness() -> void:
	assert(CarryHandIK.get_chain_straightness(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), Vector3.RIGHT) > 0.99)

func _test_bend_direction() -> void:
	var bend := CarryHandIK.get_chain_bend_direction(Vector3.ZERO, Vector3(0.5, 1.0, 0.0), Vector3.RIGHT)
	assert(bend.dot(Vector3.UP) > 0.99)

func _test_reach_comfort() -> void:
	assert(CarryHandIK.get_reach_comfort(Vector3.ZERO, Vector3(0.2, 0.0, 0.0), 0.4, 0.4) > 0.9)

func _test_target_clamp_amount() -> void:
	assert(is_equal_approx(CarryHandIK.get_target_clamp_amount(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), Vector3.RIGHT), 1.0))

func _test_max_min_reach() -> void:
	assert(CarryHandIK.get_max_reach(0.4, 0.4) > CarryHandIK.get_min_reach(0.4, 0.4))

func _test_joint_balance() -> void:
	assert(is_equal_approx(CarryHandIK.get_joint_balance(0.4, 0.4), 1.0))
	assert(CarryHandIK.get_joint_balance(0.2, 0.4) < 1.0)

func _test_wrist_direction() -> void:
	var direction := CarryHandIK.get_wrist_to_target_direction(Vector3.ZERO, Vector3.RIGHT)
	assert(direction.is_equal_approx(Vector3.RIGHT))

func _test_constrained_solver() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.4, 0.4, Vector3.UP)
	assert(bool(result.get("valid", false)))
	assert(CarryHandIK.get_solution_is_valid(result))

func _test_solution_directions() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.4, 0.4, Vector3.UP)
	var directions: Dictionary = CarryHandIK.get_limb_directions(result)
	assert((directions["upper"] as Vector3).length() > 0.99)

func _test_solution_lengths() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.4, 0.4, Vector3.UP)
	var lengths: Vector2 = CarryHandIK.get_solution_segment_lengths(result)
	assert(absf(lengths.x - 0.4) < 0.001)
	assert(absf(lengths.y - 0.4) < 0.001)

func _test_invalid_solver_lengths() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3.RIGHT, 0.0, 0.4, Vector3.UP)
	assert(not bool(result.get("valid", true)))

func _test_solution_points() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.4, 0.4, Vector3.UP)
	assert(CarryHandIK.get_joint_positions(result).size() == 3)

func _test_solution_quality() -> void:
	var result: Dictionary = CarryHandIK.solve_with_constraints(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.4, 0.4, Vector3.UP)
	assert(CarryHandIK.get_solution_quality(result, Vector3(0.5, 0.0, 0.0)) > 0.9)

func _test_upper_basis_finite() -> void:
	var basis: Basis = CarryHandIK.get_upper_segment_basis(Vector3.ZERO, Vector3.UP)
	assert(basis.is_finite())

func _test_lower_basis_finite() -> void:
	var basis: Basis = CarryHandIK.get_lower_segment_basis(Vector3.ZERO, Vector3.RIGHT)
	assert(basis.is_finite())

func _test_orientation_finite() -> void:
	var basis: Basis = CarryHandIK.get_chain_orientation(Vector3.ZERO, Vector3.FORWARD)
	assert(basis.is_finite())

func _test_angle_limits() -> void:
	var result: Dictionary = CarryHandIK.get_joint_angle_limit(4.0, -1.0, 1.0)
	assert(is_equal_approx(float(result["angle"]), 1.0))
	assert(bool(result["was_clamped"]))

func _test_target_distance_weight() -> void:
	var weight := CarryHandIK.get_target_distance_weight(Vector3.ZERO, Vector3(0.5, 0.0, 0.0), 0.0, 1.0)
	assert(weight > 0.4 and weight < 0.6)

func _test_direction_plane_projection() -> void:
	var direction := CarryHandIK.project_direction_on_plane(Vector3(1.0, 1.0, 0.0), Vector3.UP)
	assert(absf(direction.y) < 0.001)

func _test_closest_reachable_point() -> void:
	var point := CarryHandIK.get_closest_reachable_point(Vector3.ZERO, Vector3(4.0, 0.0, 0.0), 0.4, 0.4)
	assert(point.length() < 0.8)

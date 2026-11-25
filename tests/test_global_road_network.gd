extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_global_road_network.gd

const RoadNetworkScript = preload("res://scripts/world/global_road_network.gd")

func _initialize() -> void:
    var network = RoadNetworkScript.new()
    root.add_child(network)

    assert(network.add_road_segment(&"A", &"B", Vector3(0, 0, 0), Vector3(100, 0, 0), true, 100.0))
    assert(network.add_road_segment(&"B", &"C", Vector3(100, 0, 0), Vector3(200, 0, 0), true, 100.0))
    assert(network.add_road_segment(&"A", &"C", Vector3(0, 0, 0), Vector3(200, 0, 0), true, 10.0))

    var route: PackedVector3Array = network.find_route(&"A", &"C")
    assert(route.size() == 3, "Fast road route should prefer A -> B -> C.")
    assert(is_equal_approx(network.get_route_length(route), 200.0))
    assert(network.find_nearest_node(Vector3(5, 0, 0), 20.0) == &"A")

    network.remove_road_node(&"B")
    route = network.find_route(&"A", &"C")
    assert(route.size() == 2, "After removing B, direct A -> C route should remain.")
    assert(network.find_route(&"missing", &"C").is_empty())

    network.clear_network()
    assert(network.find_route(&"A", &"C").is_empty())
    print("GlobalRoadNetwork tests passed.")
    quit(0)

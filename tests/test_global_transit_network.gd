extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_global_transit_network.gd

const TransitScript = preload("res://scripts/world/global_transit_network.gd")

func _initialize() -> void:
    var transit = TransitScript.new()
    root.add_child(transit)

    assert(transit.register_hub(&"city_a_airport", "City A Airport", &"airport", &"region_a", Vector3.ZERO))
    assert(transit.register_hub(&"city_b_airport", "City B Airport", &"airport", &"region_b", Vector3(1000, 0, 0)))
    assert(transit.register_hub(&"central_station", "Central Station", &"station", &"region_a", Vector3(50, 0, 0)))

    assert(transit.register_service(&"flight_ab", &"air", [&"city_a_airport", &"city_b_airport"], 120, 60, 360, 1200))
    assert(transit.register_service(&"express_rail", &"rail", [&"central_station", &"city_b_airport"], 240, 30, 300, 1320))

    var flights: Array[Dictionary] = transit.get_services_between(&"city_a_airport", &"city_b_airport", &"air")
    assert(flights.size() == 1)
    assert(flights[0]["service_id"] == &"flight_ab")
    assert(transit.get_next_departure_minute(&"flight_ab", 370) == 420)
    assert(transit.get_next_departure_minute(&"flight_ab", 1210) == -1)

    assert(transit.set_service_enabled(&"flight_ab", false))
    assert(transit.get_services_between(&"city_a_airport", &"city_b_airport").is_empty())
    assert(not transit.register_service(&"bad_service", &"air", [&"unknown", &"city_b_airport"], 60))

    transit.clear_network()
    assert(transit.hubs.is_empty())
    assert(transit.services.is_empty())
    print("GlobalTransitNetwork tests passed.")
    quit(0)

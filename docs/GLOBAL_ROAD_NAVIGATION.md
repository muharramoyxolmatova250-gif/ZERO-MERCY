# Global road navigation

## Added modules
- `scripts/world/global_road_network.gd`: directed weighted road graph with stable node IDs, bidirectional or one-way segments, nearest-node lookup, Dijkstra route search weighted by estimated travel time, route length, and node removal.
- `scripts/world/road_route_follower.gd`: reusable waypoint follower for vehicles.
- `tests/test_global_road_network.gd`: headless smoke tests for route selection, nearest-node lookup, removal and clearing.

## Data contract
Road importers should call `add_road_segment(from_id, to_id, from_position, to_position, bidirectional, speed_limit_kph)`. Node IDs should be deterministic and include a region/source prefix so adjacent streamed regions can share boundary nodes.

## Current limitations
This is a navigation foundation, not a populated real-world road dataset. No OpenStreetMap or other licensed map extract is bundled. The graph currently uses a simple Dijkstra implementation suitable for prototype/small networks; large global graphs need spatial indexing, region partitioning, A* or contraction hierarchies, persistence and incremental streaming. The route follower is a basic waypoint prototype and does not yet implement lane geometry, steering physics, collision avoidance, traffic signals or vehicle-specific restrictions.

## Verification
The test script is committed but has not been executed in a Godot runtime in this environment. Run:
`godot --headless --path . --script res://tests/test_global_road_network.gd`

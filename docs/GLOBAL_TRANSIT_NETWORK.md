# Global transit network foundation

## Implemented
- Stable-ID hub registry for airports, railway/metro stations, ports and terminals.
- Service registry for metro, rail, air, bus and ferry routes.
- Ordered stop lists and forward-direction service lookup.
- Daily departure calculation using first/last departure and headway.
- Service enable/disable controls.
- Headless smoke test at `tests/test_global_transit_network.gd`.

## Important boundaries
This is a simulation/data foundation only. It does not contain real airport or station records, airline timetables, live flight tracking, ticketing, train physics, passenger AI or a real-world licensed transport dataset. Import verified data before presenting actual places or schedules in-game.

## Test
Run from the project root with Godot 4:
`godot --headless --path . --script res://tests/test_global_transit_network.gd`

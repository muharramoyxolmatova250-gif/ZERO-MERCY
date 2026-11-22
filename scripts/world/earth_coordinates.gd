class_name EarthCoordinates
extends RefCounted
## Shared WGS84 helpers for Earth-scale map tiles and local region conversion.

const EARTH_RADIUS_M := 6378137.0
const TILE_DEGREES := 1.0

static func lat_lon_to_ecef(latitude_deg: float, longitude_deg: float, altitude_m: float = 0.0) -> Vector3:
	var lat := deg_to_rad(clampf(latitude_deg, -90.0, 90.0))
	var lon := deg_to_rad(wrapf(longitude_deg, -180.0, 180.0))
	var radius := EARTH_RADIUS_M + altitude_m
	return Vector3(
		-radius * cos(lat) * cos(lon),
		radius * sin(lat),
		radius * cos(lat) * sin(lon)
	)

static func ecef_to_lat_lon(position: Vector3) -> Vector2:
	var radius := position.length()
	if radius < 0.001:
		return Vector2.ZERO
	var latitude := rad_to_deg(asin(clampf(position.y / radius, -1.0, 1.0)))
	var longitude := rad_to_deg(atan2(position.z, -position.x))
	return Vector2(latitude, longitude)

static func lat_lon_to_local(latitude_deg: float, longitude_deg: float, center_lat_deg: float, center_lon_deg: float) -> Vector2:
	var metres_per_degree_lat := 111132.0
	var metres_per_degree_lon := 111320.0 * cos(deg_to_rad(center_lat_deg))
	return Vector2(
		(longitude_deg - center_lon_deg) * metres_per_degree_lon,
		-(latitude_deg - center_lat_deg) * metres_per_degree_lat
	)

static func tile_for_lat_lon(latitude_deg: float, longitude_deg: float) -> Vector2i:
	var lat := clampf(latitude_deg, -89.999999, 89.999999)
	var lon := wrapf(longitude_deg, -180.0, 180.0)
	return Vector2i(floori(lon), floori(lat))

static func tile_key(tile: Vector2i) -> String:
	return str(tile.x) + "," + str(tile.y)

static func tile_bounds(tile: Vector2i) -> Rect2:
	return Rect2(Vector2(tile.x, tile.y), Vector2(TILE_DEGREES, TILE_DEGREES))

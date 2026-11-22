class_name EarthCoordinates
extends RefCounted
## WGS84 geodetic helpers for Earth-scale map tiles and local regional conversion.

const WGS84_A := 6378137.0
const WGS84_F := 1.0 / 298.257223563
const WGS84_E2 := WGS84_F * (2.0 - WGS84_F)
const WGS84_B := WGS84_A * (1.0 - WGS84_F)
const TILE_DEGREES := 1.0

static func lat_lon_to_ecef(latitude_deg: float, longitude_deg: float, altitude_m: float = 0.0) -> Vector3:
	var lat := deg_to_rad(clampf(latitude_deg, -90.0, 90.0))
	var lon := deg_to_rad(wrapf(longitude_deg, -180.0, 180.0))
	var sin_lat := sin(lat)
	var n := WGS84_A / sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
	return Vector3(
		-(n + altitude_m) * cos(lat) * cos(lon),
		(n * (1.0 - WGS84_E2) + altitude_m) * sin(lat),
		(n + altitude_m) * cos(lat) * sin(lon)
	)

static func ecef_to_lat_lon(position: Vector3) -> Vector2:
	var p := Vector2(position.x, position.z).length()
	if p < 0.001 and absf(position.y) < 0.001:
		return Vector2.ZERO
	var longitude := rad_to_deg(atan2(position.z, -position.x))
	if p < 0.001:
		return Vector2(90.0 if position.y >= 0.0 else -90.0, longitude)
	var theta := atan2(position.y * WGS84_A, p * WGS84_B)
	var ep2 := (WGS84_A * WGS84_A - WGS84_B * WGS84_B) / (WGS84_B * WGS84_B)
	var latitude := atan2(
		position.y + ep2 * WGS84_B * pow(sin(theta), 3.0),
		p - WGS84_E2 * WGS84_A * pow(cos(theta), 3.0)
	)
	return Vector2(rad_to_deg(latitude), wrapf(longitude, -180.0, 180.0))

static func lat_lon_to_local(latitude_deg: float, longitude_deg: float, center_lat_deg: float, center_lon_deg: float) -> Vector2:
	var center_lat := deg_to_rad(clampf(center_lat_deg, -89.9999, 89.9999))
	var sin_lat := sin(center_lat)
	var denom := sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
	var prime_vertical := WGS84_A / denom
	var meridian := WGS84_A * (1.0 - WGS84_E2) / pow(denom, 3.0)
	var delta_lon := wrapf(longitude_deg - center_lon_deg + 180.0, 0.0, 360.0) - 180.0
	var delta_lat := latitude_deg - center_lat_deg
	return Vector2(deg_to_rad(delta_lon) * prime_vertical * cos(center_lat), -deg_to_rad(delta_lat) * meridian)

static func local_to_lat_lon(local_position: Vector2, center_lat_deg: float, center_lon_deg: float) -> Vector2:
	var center_lat := deg_to_rad(clampf(center_lat_deg, -89.9999, 89.9999))
	var sin_lat := sin(center_lat)
	var denom := sqrt(1.0 - WGS84_E2 * sin_lat * sin_lat)
	var prime_vertical := WGS84_A / denom
	var meridian := WGS84_A * (1.0 - WGS84_E2) / pow(denom, 3.0)
	var latitude := center_lat_deg - rad_to_deg(local_position.y / meridian)
	var longitude_scale := maxf(0.000001, prime_vertical * cos(center_lat))
	var longitude := center_lon_deg + rad_to_deg(local_position.x / longitude_scale)
	return Vector2(latitude, wrapf(longitude, -180.0, 180.0))

static func tile_for_lat_lon(latitude_deg: float, longitude_deg: float) -> Vector2i:
	var lat := clampf(latitude_deg, -89.999999, 89.999999)
	var lon := wrapf(longitude_deg, -180.0, 180.0)
	return Vector2i(floori(lon), floori(lat))

static func tile_key(tile: Vector2i) -> String:
	return str(tile.x) + "," + str(tile.y)

static func tile_bounds(tile: Vector2i) -> Rect2:
	return Rect2(Vector2(tile.x, tile.y), Vector2(TILE_DEGREES, TILE_DEGREES))

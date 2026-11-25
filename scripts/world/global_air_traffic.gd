extends Node3D
## Global airline timetable with stylized local aircraft. Flight routes retain real airport coordinates.
@export_range(1,32,1) var visible_aircraft_count:=12
const AIRPORTS:= [
 {"code":"TAS","city":"Tashkent","country":"Uzbekistan","lat":41.2579,"lon":69.2812},
 {"code":"IST","city":"Istanbul","country":"Türkiye","lat":41.2753,"lon":28.7519},
 {"code":"DXB","city":"Dubai","country":"UAE","lat":25.2532,"lon":55.3657},
 {"code":"LHR","city":"London","country":"UK","lat":51.47,"lon":-0.4543},
 {"code":"CDG","city":"Paris","country":"France","lat":49.0097,"lon":2.5479},
 {"code":"JFK","city":"New York","country":"USA","lat":40.6413,"lon":-73.7781},
 {"code":"LAX","city":"Los Angeles","country":"USA","lat":33.9416,"lon":-118.4085},
 {"code":"HND","city":"Tokyo","country":"Japan","lat":35.5494,"lon":139.7798},
 {"code":"ICN","city":"Seoul","country":"South Korea","lat":37.4602,"lon":126.4407},
 {"code":"SIN","city":"Singapore","country":"Singapore","lat":1.3644,"lon":103.9915},
 {"code":"GRU","city":"Sao Paulo","country":"Brazil","lat":-23.4356,"lon":-46.4731},
 {"code":"SYD","city":"Sydney","country":"Australia","lat":-33.9399,"lon":151.1753},
 {"code":"CAI","city":"Cairo","country":"Egypt","lat":30.1219,"lon":31.4056},
 {"code":"BOM","city":"Mumbai","country":"India","lat":19.0896,"lon":72.8656},
 {"code":"DOH","city":"Doha","country":"Qatar","lat":25.2731,"lon":51.6081},
 {"code":"DEL","city":"New Delhi","country":"India","lat":28.5562,"lon":77.1000},
 {"code":"BKK","city":"Bangkok","country":"Thailand","lat":13.6900,"lon":100.7501},
 {"code":"HKG","city":"Hong Kong","country":"China","lat":22.3080,"lon":113.9185},
 {"code":"MEX","city":"Mexico City","country":"Mexico","lat":19.4363,"lon":-99.0721},
 {"code":"YYZ","city":"Toronto","country":"Canada","lat":43.6777,"lon":-79.6248},
 {"code":"ORD","city":"Chicago","country":"USA","lat":41.9742,"lon":-87.9073},
 {"code":"SFO","city":"San Francisco","country":"USA","lat":37.6213,"lon":-122.3790},
 {"code":"MAD","city":"Madrid","country":"Spain","lat":40.4983,"lon":-3.5676},
 {"code":"FRA","city":"Frankfurt","country":"Germany","lat":50.0379,"lon":8.5622},
 {"code":"JNB","city":"Johannesburg","country":"South Africa","lat":-26.1367,"lon":28.2410},
 {"code":"NBO","city":"Nairobi","country":"Kenya","lat":-1.3192,"lon":36.9278},
 {"code":"AKL","city":"Auckland","country":"New Zealand","lat":-37.0082,"lon":174.7850},
 {"code":"PER","city":"Perth","country":"Australia","lat":-31.9403,"lon":115.9670},
 {"code":"RUH","city":"Riyadh","country":"Saudi Arabia","lat":24.9576,"lon":46.6988},
 {"code":"ALA","city":"Almaty","country":"Kazakhstan","lat":43.3521,"lon":77.0405},
 {"code":"SKD","city":"Samarkand","country":"Uzbekistan","lat":39.7005,"lon":66.9838},
 {"code":"AZN","city":"Andijan","country":"Uzbekistan","lat":40.7277,"lon":72.2947}
]
var flights:Array[Dictionary]=[]
var _planes:Array[Node3D]=[]
var _rng:=RandomNumberGenerator.new()
var completed_flights:=0
var _anchor_lat:=40.7
var _anchor_lon:=72.3
func _ready()->void:
 _load_world_anchor()
 _rng.randomize()
 for i in range(visible_aircraft_count):
  var a:=i%AIRPORTS.size()
  var b:=(a+_rng.randi_range(1,AIRPORTS.size()-1))%AIRPORTS.size()
  var from:Dictionary=AIRPORTS[a]
  var to:Dictionary=AIRPORTS[b]
  flights.append({"flight_id":"ZM"+str(100+i),"origin":from.code,"destination":to.code,"origin_city":from.city,"destination_city":to.city,"origin_country":from.country,"destination_country":to.country,"from_lat":from.lat,"from_lon":from.lon,"to_lat":to.lat,"to_lon":to.lon,"progress":_rng.randf(),"passengers":_rng.randi_range(90,340),"status":"in_flight"})
  var plane:=_make_plane(i)
  _planes.append(plane)
  add_child(plane)
  _position_plane(i)
func _process(delta:float)->void:
 for i in range(flights.size()):
  var f:Dictionary=flights[i]
  var duration:=_duration(f)
  var p:=float(f.progress)+delta/duration
  if p>=1.0:
   _complete_flight(i)
   f=flights[i]
   p=0.0
  f.progress=p
  flights[i]=f
  _position_plane(i)
func complete_flight(flight_index: int) -> bool:
 if flight_index < 0 or flight_index >= flights.size():
  return false
 _complete_flight(flight_index)
 return true


func _complete_flight(flight_index: int) -> void:
 var f: Dictionary = flights[flight_index]
 var old_origin := str(f.origin)
 var old_destination := str(f.destination)
 var old_from_lat := float(f.from_lat)
 var old_from_lon := float(f.from_lon)
 var old_origin_city := str(f.origin_city)
 var old_destination_city := str(f.destination_city)
 var old_origin_country := str(f.origin_country)
 var old_destination_country := str(f.destination_country)
 f.origin = old_destination
 f.destination = old_origin
 f.origin_city = old_destination_city
 f.destination_city = old_origin_city
 f.origin_country = old_destination_country
 f.destination_country = old_origin_country
 f.from_lat = float(f.to_lat)
 f.from_lon = float(f.to_lon)
 f.to_lat = old_from_lat
 f.to_lon = old_from_lon
 f.progress = 0.0
 f.status = "returning"
 flights[flight_index] = f
 completed_flights += 1
 _position_plane(flight_index)

func _airport_by_code(code: String) -> Dictionary:
 for airport in AIRPORTS:
  if str(airport.get("code", "")) == code:
   return airport
 return {}


func _duration(f:Dictionary)->float:
 var a:=Vector2(float(f.from_lon),float(f.from_lat))
 var b:=Vector2(float(f.to_lon),float(f.to_lat))
 var d:=a.distance_to(b)*111000.0
 return maxf(90.0,d/230.0)
func _position_plane(i:int)->void:
 if i < 0 or i >= flights.size() or i >= _planes.size():
  return
 var f:Dictionary=flights[i]
 var p:=clampf(float(f.progress),0.0,1.0)
 var start:=_world_position(float(f.from_lat),float(f.from_lon),float(i))
 var finish:=_world_position(float(f.to_lat),float(f.to_lon),float(i))
 var route:=finish-start
 var altitude:=maxf(18.0,route.length()*0.035)
 var aircraft_position:=start.lerp(finish,p)+Vector3.UP*(sin(p*PI)*altitude)
 _planes[i].global_position=aircraft_position
 if route.length_squared()>0.001:
  _planes[i].look_at(aircraft_position+route.normalized(),Vector3.UP)


func _load_world_anchor()->void:
 var path:="res://data/world/region_tiles.json"
 if not FileAccess.file_exists(path):
  return
 var file:=FileAccess.open(path,FileAccess.READ)
 if file==null:
  return
 var data:Variant=JSON.parse_string(file.get_as_text())
 if typeof(data)==TYPE_DICTIONARY:
  _anchor_lat=float(data.get("_anchor_lat",_anchor_lat))
  _anchor_lon=float(data.get("_anchor_lon",_anchor_lon))


func _world_position(latitude:float,longitude:float,flight_index:float)->Vector3:
 # Match RegionStreamer global_equirectangular projection exactly.
 var x:=(longitude-_anchor_lon)*111320.0
 var z:=-(latitude-_anchor_lat)*111320.0
 var altitude:=100.0+fposmod(flight_index,5.0)*16.0
 return Vector3(x,altitude,z)
func _make_plane(i:int)->Node3D:
 var plane:=Node3D.new()
 plane.name="Cyberliner_"+str(i)
 plane.add_to_group("world_aircraft")
 var hull_mat:=StandardMaterial3D.new()
 hull_mat.albedo_color=Color(0.012,0.025,0.055)
 hull_mat.metallic=0.92
 hull_mat.roughness=0.16
 var neon:=StandardMaterial3D.new()
 neon.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 neon.albedo_color=Color(0.0,0.82,1.0)
 neon.emission_enabled=true
 neon.emission=Color(0.0,0.72,1.0)
 neon.emission_energy_multiplier=2.4
 var hull:=MeshInstance3D.new()
 var hm:=BoxMesh.new()
 hm.size=Vector3(1.5,1.3,13.0)
 hull.mesh=hm
 hull.material_override=hull_mat
 plane.add_child(hull)
 var nose:=MeshInstance3D.new()
 var nose_mesh:=SphereMesh.new()
 nose_mesh.radius=0.72
 nose_mesh.height=2.4
 nose.mesh=nose_mesh
 nose.scale=Vector3(0.72,0.72,1.0)
 nose.position=Vector3(0.0,0.0,-6.7)
 nose.material_override=hull_mat
 plane.add_child(nose)
 var tail_fin:=MeshInstance3D.new()
 var tail_mesh:=BoxMesh.new()
 tail_mesh.size=Vector3(0.38,2.4,2.5)
 tail_fin.mesh=tail_mesh
 tail_fin.position=Vector3(0.0,1.1,5.0)
 tail_fin.material_override=hull_mat
 plane.add_child(tail_fin)
 var tail_wing:=MeshInstance3D.new()
 var tail_wing_mesh:=BoxMesh.new()
 tail_wing_mesh.size=Vector3(7.0,0.28,1.8)
 tail_wing.mesh=tail_wing_mesh
 tail_wing.position=Vector3(0.0,0.25,5.0)
 tail_wing.material_override=hull_mat
 plane.add_child(tail_wing)
 for engine_x in [-4.5,4.5]:
  var engine:=MeshInstance3D.new()
  var engine_mesh:=CylinderMesh.new()
  engine_mesh.top_radius=0.48
  engine_mesh.bottom_radius=0.62
  engine_mesh.height=2.8
  engine.mesh=engine_mesh
  engine.rotation.x=PI*0.5
  engine.position=Vector3(engine_x,-0.48,-0.15)
  engine.material_override=hull_mat
  plane.add_child(engine)
  var exhaust:=MeshInstance3D.new()
  var exhaust_mesh:=CylinderMesh.new()
  exhaust_mesh.top_radius=0.28
  exhaust_mesh.bottom_radius=0.28
  exhaust_mesh.height=0.12
  exhaust.mesh=exhaust_mesh
  exhaust.rotation.x=PI*0.5
  exhaust.position=Vector3(engine_x,-0.48,1.32)
  exhaust.material_override=neon
  plane.add_child(exhaust)
 var wings:=MeshInstance3D.new()
 var wm:=BoxMesh.new()
 wm.size=Vector3(17.0,0.35,3.0)
 wings.mesh=wm
 wings.position.z=0.8
 wings.material_override=hull_mat
 plane.add_child(wings)
 for x in [-7.0,7.0]:
  var lamp:=MeshInstance3D.new()
  var lm:=BoxMesh.new()
  lm.size=Vector3(0.5,0.16,0.5)
  lamp.mesh=lm
  lamp.position=Vector3(x,0.25,0.8)
  lamp.material_override=neon
  plane.add_child(lamp)
 return plane
func get_flight_snapshot()->Dictionary:
 return {"airport_count":AIRPORTS.size(),"active_flights":flights.size(),"completed_flights":completed_flights,"countries_connected":AIRPORTS.size()}

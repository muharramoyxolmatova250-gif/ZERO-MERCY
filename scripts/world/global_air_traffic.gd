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
 {"code":"BOM","city":"Mumbai","country":"India","lat":19.0896,"lon":72.8656}
]
var flights:Array[Dictionary]=[]
var _planes:Array[Node3D]=[]
var _rng:=RandomNumberGenerator.new()
var completed_flights:=0
func _ready()->void:
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
   p=0.0
   completed_flights+=1
   var old_origin:=str(f.origin)
   var old_destination:=str(f.destination)
   var old_from_lat:=float(f.from_lat)
   var old_from_lon:=float(f.from_lon)
   var old_origin_city:=str(f.origin_city)
   var old_destination_city:=str(f.destination_city)
   var old_origin_country:=str(f.origin_country)
   var old_destination_country:=str(f.destination_country)
   f.origin=old_destination
   f.destination=old_origin
   f.origin_city=old_destination_city
   f.destination_city=old_origin_city
   f.origin_country=old_destination_country
   f.destination_country=old_origin_country
   f.from_lat=float(f.to_lat)
   f.from_lon=float(f.to_lon)
   f.to_lat=old_from_lat
   f.to_lon=old_from_lon
  f.progress=p
  flights[i]=f
  _position_plane(i)
func _duration(f:Dictionary)->float:
 var a:=Vector2(float(f.from_lon),float(f.from_lat))
 var b:=Vector2(float(f.to_lon),float(f.to_lat))
 var d:=a.distance_to(b)*111000.0
 return maxf(90.0,d/230.0)
func _position_plane(i:int)->void:
 var f:Dictionary=flights[i]
 var p:=float(f.progress)
 var start:=Vector3(-190.0+float(i%4)*120.0,100.0+float(i%5)*16.0,-150.0+float(i/4)*100.0)
 var finish:=Vector3(190.0-float(i%4)*120.0,112.0+float(i%5)*16.0,150.0-float(i/4)*100.0)
 _planes[i].position=start.lerp(finish,p)+Vector3(0.0,sin(p*PI)*38.0,0.0)
 _planes[i].look_at(_planes[i].position+(finish-start),Vector3.UP)
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

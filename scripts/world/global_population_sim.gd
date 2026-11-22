extends Node3D
## Global background population cohorts; not thousands of expensive scene nodes.
@export_range(1000,250000,1000) var residents_per_hub := 100000
@export_range(1.0,60.0,1.0) var tick_seconds := 5.0
const HUBS := [
 ["Tashkent","Uzbekistan",41.2579,69.2812],["Tokyo","Japan",35.6762,139.6503],
 ["Seoul","South Korea",37.5665,126.978],["Shanghai","China",31.2304,121.4737],
 ["Singapore","Singapore",1.3521,103.8198],["Dubai","UAE",25.2048,55.2708],
 ["Istanbul","Türkiye",41.0082,28.9784],["London","United Kingdom",51.5072,-0.1276],
 ["Paris","France",48.8566,2.3522],["New York","United States",40.7128,-74.006],
 ["Los Angeles","United States",34.0522,-118.2437],["Sao Paulo","Brazil",-23.5505,-46.6333],
 ["Sydney","Australia",-33.8688,151.2093],["Cairo","Egypt",30.0444,31.2357],
 ["Mumbai","India",19.076,72.8777],["Mexico City","Mexico",19.4326,-99.1332],
 ["Johannesburg","South Africa",-26.2041,28.0473],["Toronto","Canada",43.6532,-79.3832]
]
var cohorts:Array[Dictionary]=[]
var represented_residents:=0
var simulation_ticks:=0
var active_workers:=0
var active_commuters:=0
var active_socializing:=0
var _timer:=0.0
func _ready()->void:
 for hub in HUBS:
  cohorts.append({"city":hub[0],"country":hub[1],"lat":hub[2],"lon":hub[3],"population_reference":0,"residents":residents_per_hub,"workers":int(residents_per_hub*0.46),"students":int(residents_per_hub*0.18),"families":int(residents_per_hub*0.24),"commuting":0,"socializing":0,"resting":0,"local_time":0})
  represented_residents+=residents_per_hub
 _simulate()
func _process(delta:float)->void:
 _timer+=delta
 if _timer>=tick_seconds:
  _timer=0.0
  _simulate()
func _simulate()->void:
 simulation_ticks+=1
 active_workers=0
 active_commuters=0
 active_socializing=0
 var utc:=int(Time.get_time_dict_from_system().get("hour",12))
 for i in range(cohorts.size()):
  var h:Dictionary=cohorts[i]
  var local_hour:=posmod(utc+int(round(float(h.lon)/15.0)),24)
  h["local_time"]=local_hour
  var commute:=0.24 if local_hour in [7,8,17,18] else (0.04 if local_hour>=9 and local_hour<17 else 0.0)
  var social:=0.05 if local_hour>=18 and local_hour<23 else 0.015
  h["commuting"]=int(int(h.workers)*commute)
  h["socializing"]=int(int(h.residents)*social)
  h["resting"]=int(int(h.residents)*(0.68 if local_hour<6 or local_hour>=22 else 0.18))
  active_workers+=int(h.workers)-int(h.commuting)
  active_commuters+=int(h.commuting)
  active_socializing+=int(h.socializing)
  cohorts[i]=h
func get_world_population_snapshot()->Dictionary:
 return {"city_hubs":cohorts.size(),"represented_residents":represented_residents,"active_workers":active_workers,"commuting":active_commuters,"socializing":active_socializing,"ticks":simulation_ticks}

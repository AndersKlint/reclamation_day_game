extends Node3D

const CityCar = preload("res://game/demo/city/city_car.gd")
const CarAssets = preload("res://game/demo/city/car_assets.gd")
const CityLayout = preload("res://game/demo/city/city_layout.gd")
const TrafficIntersections = preload("res://game/demo/city/traffic_intersections.gd")

const MOVING_CAR_COUNT: int = 64
const MAX_TRAFFIC_ROUTES: int = 4
const START_CLEARANCE: float = 9.0
const ACTOR_METHODS: Array[StringName] = [&"configure_car", &"configure_traffic", &"configure_intersections", &"set_active"]
const REGION_METHODS: Array[StringName] = [
	&"get_traffic_routes",
	&"ground_position",
	&"get_zone_at",
	&"_register_target",
]

var _region: Node3D
var _player: CharacterBody3D
var _moving: Array[Node3D] = []
var _configured: bool = false
var _active: bool = false
var _intersections: RefCounted

func _physics_process(delta: float) -> void:
	if _active and is_instance_valid(_player) and bool(_player.get(&"gameplay_enabled")):
		_intersections.tick(delta)

func configure(region: Node3D, player: CharacterBody3D) -> void:
	if _configured:
		push_warning("CityTraffic.configure ignored: already configured for this run")
		return
	if not _validate_actor():
		return
	if not _validate_region(region):
		return
	if player == null:
		push_error("CityTraffic.configure requires a player")
		return
	_region = region
	_player = player
	_intersections = TrafficIntersections.new()
	_intersections.configure(_region)
	_configured = true
	_spawn_moving()

func start() -> void:
	if not _configured:
		push_error("CityTraffic.start called before configure")
		return
	if _active:
		return
	_active = true
	_set_active(true)

func stop() -> void:
	if not _configured or not _active:
		return
	_active = false
	_set_active(false)
	_intersections.clear()

func _set_active(enabled: bool) -> void:
	for car: Node3D in _moving:
		if is_instance_valid(car):
			car.call(&"set_active", enabled)

func _spawn_moving() -> void:
	var raw: Array = _region.call(&"get_traffic_routes")
	var routes: Array[PackedVector3Array] = []
	for entry in raw:
		var route: PackedVector3Array = entry
		if route.size() < 2:
			continue
		routes.append(route)
		if routes.size() >= MAX_TRAFFIC_ROUTES:
			break
	if routes.is_empty():
		push_error("CityTraffic found no usable traffic routes")
		return
	var slots_per_route: int = int(ceil(float(MOVING_CAR_COUNT) / float(routes.size())))
	var starts: PackedVector3Array = PackedVector3Array()
	for i: int in MOVING_CAR_COUNT:
		var route_index: int = i % routes.size()
		var slot: int = int(floor(float(i) / float(routes.size())))
		var route: PackedVector3Array = routes[route_index]
		var length: float = _route_length(route)
		if length <= 0.001:
			continue
		var start_distance: float = length * (float(slot) + float(route_index) / float(routes.size())) / float(slots_per_route)
		var placement: Transform3D = _route_placement(route, start_distance)
		var found: bool = false
		for attempt: int in int(ceil(length / START_CLEARANCE)):
			placement = _route_placement(route, start_distance + float(attempt) * START_CLEARANCE)
			if _start_is_clear(placement.origin, starts):
				found = true
				break
		if not found:
			continue
		var variant: int = CarAssets.TAXI if i % 3 == 0 else (i % CarAssets.CIVILIAN_COUNT)
		var car: Node3D = _add_car(variant, placement, route)
		if car == null:
			continue
		starts.append(placement.origin)
		car.call(&"configure_traffic", _player)
		car.call(&"configure_intersections", _intersections)
		_intersections.register(car, route)
		car.call(&"set_active", false)
		_moving.append(car)
	if _moving.size() != MOVING_CAR_COUNT:
		push_warning("CityTraffic placed %d of %d moving cars" % [_moving.size(), MOVING_CAR_COUNT])

func _route_length(route: PackedVector3Array) -> float:
	var length: float = 0.0
	for i: int in route.size():
		length += route[i].distance_to(route[(i + 1) % route.size()])
	return length

func _route_placement(route: PackedVector3Array, distance: float) -> Transform3D:
	var remaining: float = fposmod(distance, _route_length(route))
	for i: int in route.size():
		var start: Vector3 = route[i]
		var end: Vector3 = route[(i + 1) % route.size()]
		var length: float = start.distance_to(end)
		if length <= 0.001:
			continue
		if remaining < length:
			var direction: Vector3 = end - start
			var yaw: float = atan2(-direction.x, -direction.z)
			return Transform3D(Basis(Vector3.UP, yaw), start.lerp(end, remaining / length))
		remaining -= length
	return Transform3D(Basis.IDENTITY, route[0])

func _start_is_clear(point: Vector3, starts: PackedVector3Array) -> bool:
	var inverse: Basis = _region.global_transform.basis.inverse()
	var radius: float = Vector2(CityCar.FIT_BOUNDS.x, CityCar.FIT_BOUNDS.z).length() * 0.5 * sqrt(2.0) + 0.95
	var extent: Vector2 = Vector2(
		Vector3(inverse.x.x, inverse.y.x, inverse.z.x).length(),
		Vector3(inverse.x.z, inverse.y.z, inverse.z.z).length()
	) * radius + Vector2.ONE * CityLayout.ROAD_HALF
	var local: Vector3 = _region.to_local(point)
	for x: float in CityLayout.X_STREETS:
		for z: float in CityLayout.Z_STREETS:
			if absf(local.x - x) <= extent.x and absf(local.z - z) <= extent.y:
				return false
	for existing: Vector3 in starts:
		if Vector2(point.x - existing.x, point.z - existing.z).length_squared() < START_CLEARANCE * START_CLEARANCE:
			return false
	return true

func _add_car(variant: int, placement: Transform3D, route: PackedVector3Array) -> Node3D:
	placement.origin = _region.call(&"ground_position", placement.origin)
	var car: Node3D = CityCar.new() as Node3D
	if car == null:
		push_error("CityTraffic could not instantiate CityCar")
		return null
	car.set(&"ground_position", Callable(_region, &"ground_position"))
	car.set_meta(&"zone", _region.call(&"get_zone_at", placement.origin))
	car.call(&"configure_car", variant, route)
	car.call(&"set_active", false)
	if not car.has_node("Drainable"):
		push_error("CityCar.configure_car did not create a Drainable")
		car.free()
		return null
	# Region registration attaches the car and wires drain counting exactly once.
	_region.call(&"_register_target", car)
	# Placement follows attachment so the region transform is applied.
	car.global_transform = placement
	car.reset_physics_interpolation()
	return car

func _validate_actor() -> bool:
	var probe: Node3D = CityCar.new() as Node3D
	if probe == null:
		push_error("CityTraffic requires a Node3D CityCar")
		return false
	var has_ground: bool = false
	for property: Dictionary in probe.get_property_list():
		if String(property["name"]) == "ground_position":
			has_ground = true
			break
	if not has_ground:
		push_error("CityTraffic requires CityCar.ground_position")
		probe.free()
		return false
	var methods: Dictionary = {}
	var script: Script = probe.get_script()
	for method: Dictionary in script.get_script_method_list():
		methods[String(method["name"])] = true
	for method: StringName in ACTOR_METHODS:
		if not methods.has(String(method)):
			push_error("CityTraffic requires CityCar.%s()" % method)
			probe.free()
			return false
	probe.free()
	return true

func _validate_region(region: Node3D) -> bool:
	if region == null:
		push_error("CityTraffic.configure requires a region")
		return false
	if not region.is_node_ready():
		push_error("CityTraffic.configure requires a ready region")
		return false
	if region.get_node_or_null("Targets") == null:
		push_error("CityTraffic requires region.Targets")
		return false
	for method: StringName in REGION_METHODS:
		if not region.has_method(method):
			push_error("CityTraffic requires region.%s()" % method)
			return false
	return true

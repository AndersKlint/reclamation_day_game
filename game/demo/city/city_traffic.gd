extends Node3D

const CityCar = preload("res://game/demo/city/city_car.gd")
const CarAssets = preload("res://game/demo/city/car_assets.gd")
const CityLayout = preload("res://game/demo/city/city_layout.gd")

const MOVING_CAR_COUNT: int = 8
const MAX_TRAFFIC_ROUTES: int = 4
const STAGING_POLICE_COUNT: int = 3
const TAXI_COUNT: int = 6
const ACTOR_METHODS: Array[StringName] = [&"configure_car", &"configure_traffic", &"set_active"]
const REGION_METHODS: Array[StringName] = [
	&"get_city_parking",
	&"get_traffic_routes",
	&"ground_position",
	&"get_zone_at",
	&"_register_target",
]

var _region: Node3D
var _player: CharacterBody3D
var _parked: Array[Node3D] = []
var _moving: Array[Node3D] = []
var _configured: bool = false
var _active: bool = false

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
	_configured = true
	_spawn_parked()
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

func _set_active(enabled: bool) -> void:
	for car: Node3D in _parked:
		if is_instance_valid(car):
			car.call(&"set_active", enabled)
	for car: Node3D in _moving:
		if is_instance_valid(car):
			car.call(&"set_active", enabled)

func _spawn_parked() -> void:
	var raw: Array = _region.call(&"get_city_parking")
	var parking: Array[Transform3D] = []
	parking.assign(raw)
	if parking.is_empty():
		push_error("CityTraffic found no city parking transforms")
		return
	var variants: Array[int] = _parked_variants(parking)
	for i: int in parking.size():
		var car: Node3D = _add_car(variants[i], parking[i], PackedVector3Array())
		if car != null:
			_parked.append(car)
	if _parked.size() != parking.size():
		push_warning("CityTraffic placed %d of %d parked cars" % [_parked.size(), parking.size()])

func _parked_variants(parking: Array[Transform3D]) -> Array[int]:
	var variants: Array[int] = []
	variants.resize(parking.size())
	variants.fill(-1)
	var used: Dictionary = {}
	# Keep police around the staging block and downtown instead of scattering them.
	var police_targets: Array[Vector2] = []
	for i: int in STAGING_POLICE_COUNT:
		police_targets.append(CityLayout.block_center(2, 1))
	police_targets.append(CityLayout.block_center(2, 2))
	for target: Vector2 in police_targets:
		if used.size() >= parking.size():
			break
		var index: int = _nearest_parking(parking, target, used)
		if index < 0:
			continue
		variants[index] = CarAssets.POLICE
		used[index] = true
	var remaining: Array[int] = []
	for i: int in parking.size():
		if variants[i] < 0:
			remaining.append(i)
	var taxi_total: int = mini(TAXI_COUNT, remaining.size())
	for i: int in taxi_total:
		var pick: int = int(floor(float(i) * float(remaining.size()) / float(taxi_total)))
		variants[remaining[pick]] = CarAssets.TAXI
	var civilian: int = 0
	for i: int in parking.size():
		if variants[i] >= 0:
			continue
		variants[i] = civilian % CarAssets.CIVILIAN_COUNT
		civilian += 1
	return variants

func _nearest_parking(parking: Array[Transform3D], target: Vector2, used: Dictionary) -> int:
	var best: int = -1
	var best_distance: float = INF
	for i: int in parking.size():
		if used.has(i):
			continue
		var local: Vector3 = _region.to_local(parking[i].origin)
		var offset: Vector2 = Vector2(local.x, local.z) - target
		var distance: float = offset.length_squared()
		if distance < best_distance:
			best_distance = distance
			best = i
	return best

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
	for i: int in MOVING_CAR_COUNT:
		var route_index: int = i % routes.size()
		var slot: int = int(floor(float(i) / float(routes.size())))
		var route: PackedVector3Array = routes[route_index]
		var count: int = route.size()
		# Routes share waypoints; stagger starts per route and per slot to avoid overlap.
		var base: int = (route_index * count) / MAX_TRAFFIC_ROUTES
		var spacing: int = maxi(1, count / slots_per_route)
		var waypoint: int = (base + slot * spacing) % count
		var point: Vector3 = route[waypoint]
		var next: Vector3 = route[(waypoint + 1) % count]
		var direction: Vector3 = next - point
		direction.y = 0.0
		var yaw: float = 0.0
		if not direction.is_zero_approx():
			yaw = atan2(-direction.x, -direction.z)
		var placement: Transform3D = Transform3D(Basis(Vector3.UP, yaw), point)
		var variant: int = CarAssets.TAXI if i % 3 == 0 else (i % CarAssets.CIVILIAN_COUNT)
		var car: Node3D = _add_car(variant, placement, route)
		if car == null:
			continue
		car.call(&"configure_traffic", _player)
		car.call(&"set_active", false)
		_moving.append(car)
	if _moving.size() != MOVING_CAR_COUNT:
		push_warning("CityTraffic placed %d of %d moving cars" % [_moving.size(), MOVING_CAR_COUNT])

func _add_car(variant: int, placement: Transform3D, route: PackedVector3Array) -> Node3D:
	var car: Node3D = CityCar.new() as Node3D
	if car == null:
		push_error("CityTraffic could not instantiate CityCar")
		return null
	car.set(&"ground_position", Callable(_region, &"ground_position"))
	car.set_meta(&"zone", _region.call(&"get_zone_at", placement.origin))
	car.call(&"configure_car", variant, route)
	if not car.has_node("Drainable"):
		push_error("CityCar.configure_car did not create a Drainable")
		car.free()
		return null
	# Region registration attaches the car and wires drain counting exactly once.
	_region.call(&"_register_target", car)
	# Placement follows attachment so the region transform is applied.
	car.global_transform = placement
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

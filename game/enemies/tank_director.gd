extends Node3D

const TankScene: PackedScene = preload("res://game/enemies/tank.tscn")

const CHECK_INTERVAL: float = 0.5
const CITY_LIMIT: int = 1
const DOWNTOWN_LIMIT: int = 2
const MIN_SPAWN_DISTANCE: float = 20.0
const MAX_SPAWN_DISTANCE: float = 120.0
const RETIRE_DISTANCE: float = 180.0
const SPAWN_COOLDOWN: float = 12.0
const ZONE_ENTRY_GRACE: float = 5.0
const HEAVY_LOCAL_Z: float = -580.0
const TANK_SIZE: Vector3 = Vector3(3.0, 1.6, 6.0)
# Query floats above the road so terrain contact cannot reject a valid spawn.
const CLEARANCE_LIFT: float = 0.15
const CLEARANCE_MASK: int = 1 | 2 | 4 | 16

var active: bool = false
var _region: Node3D
var _player: CharacterBody3D
var _routes: Array[PackedVector3Array] = []
var _tanks: Array[CharacterBody3D] = []
var _zone: StringName = &""
var _zone_grace_left: float = 0.0
var _spawn_left: float = 0.0
var _check_left: float = 0.0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(region: Node3D, player: CharacterBody3D) -> void:
	stop()
	_region = region
	_player = player
	_cache_routes()

func start() -> void:
	if active or not is_instance_valid(_region) or not is_instance_valid(_player):
		return
	if float(_player.get("health")) <= 0.0:
		return
	if _routes.is_empty():
		_cache_routes()
	_random.randomize()
	_zone = &""
	_zone_grace_left = 0.0
	_spawn_left = 0.0
	_check_left = 0.0
	active = true

func stop() -> void:
	active = false
	_zone = &""
	_zone_grace_left = 0.0
	_spawn_left = 0.0
	_check_left = 0.0
	for tank: CharacterBody3D in _tanks:
		if is_instance_valid(tank) and not tank.is_queued_for_deletion():
			tank.call(&"stop")
			tank.call(&"cancel_attack")
			if not _tank_depleted(tank):
				tank.queue_free()
	_tanks.clear()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_region) or not is_instance_valid(_player):
		stop()
		return
	if float(_player.get("health")) <= 0.0:
		stop()
		return
	if get_tree().paused or not bool(_player.get("gameplay_enabled")):
		_cancel_attacks()
		return
	if not bool(_region.get("navigation_ready")):
		return
	_check_left += delta
	if _check_left < CHECK_INTERVAL:
		return
	var elapsed: float = _check_left
	_check_left = 0.0
	_tick(elapsed)

func _tick(elapsed: float) -> void:
	if _routes.is_empty():
		_cache_routes()
	var zone: StringName = _region.call(&"get_zone_at", _player.global_position)
	if zone != _zone:
		_zone = zone
		_zone_grace_left = ZONE_ENTRY_GRACE
		_spawn_left = 0.0
	_zone_grace_left = maxf(0.0, _zone_grace_left - elapsed)
	_spawn_left = maxf(0.0, _spawn_left - elapsed)
	_cleanup(zone)
	var limit: int = _limit_for(zone)
	if limit <= 0:
		return
	_trim_to_limit(limit)
	if _zone_grace_left > 0.0 or _spawn_left > 0.0 or _tanks.size() >= limit:
		return
	_try_spawn(zone)

func _limit_for(zone: StringName) -> int:
	match zone:
		&"city":
			return CITY_LIMIT
		&"downtown":
			return DOWNTOWN_LIMIT
		_:
			return 0

func _cleanup(zone: StringName) -> void:
	var in_encounter: bool = zone == &"city" or zone == &"downtown"
	for index: int in range(_tanks.size() - 1, -1, -1):
		var tank: CharacterBody3D = _tanks[index]
		if not is_instance_valid(tank) or tank.is_queued_for_deletion() or _tank_depleted(tank):
			_tanks.remove_at(index)
			continue
		if not in_encounter or _edge_distance(tank.global_position) > RETIRE_DISTANCE:
			_retire_tank(tank)
			_tanks.remove_at(index)

func _trim_to_limit(limit: int) -> void:
	while _tanks.size() > limit:
		var farthest: int = -1
		var farthest_distance: float = -1.0
		for index: int in _tanks.size():
			var tank: CharacterBody3D = _tanks[index]
			var distance: float = _edge_distance(tank.global_position)
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = index
		if farthest < 0:
			return
		_retire_tank(_tanks[farthest])
		_tanks.remove_at(farthest)

func _try_spawn(zone: StringName) -> void:
	var heavy: bool = zone == &"downtown" and _tanks.size() == 1 and not _has_heavy()
	var candidates: Array[Vector2i] = _candidates(zone, heavy)
	if candidates.is_empty():
		return
	_shuffle(candidates)
	for candidate: Vector2i in candidates:
		var route: PackedVector3Array = _routes[candidate.x]
		var point: Vector3 = route[candidate.y]
		var next: Vector3 = route[(candidate.y + 1) % route.size()]
		var direction: Vector3 = Vector3(next.x - point.x, 0.0, next.z - point.z)
		if direction.length_squared() < 0.01:
			continue
		var basis: Basis = Basis(Vector3.UP, atan2(-direction.x, -direction.z))
		if not _clearance(point, basis):
			continue
		_spawn(route, candidate.y, point, basis, heavy)
		return

func _candidates(zone: StringName, heavy: bool) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for route_index: int in _routes.size():
		var route: PackedVector3Array = _routes[route_index]
		for point_index: int in route.size():
			var point: Vector3 = route[point_index]
			if StringName(_region.call(&"get_zone_at", point)) != zone:
				continue
			if heavy and _region.to_local(point).z > HEAVY_LOCAL_Z:
				continue
			var distance: float = _edge_distance(point)
			if distance < MIN_SPAWN_DISTANCE or distance > MAX_SPAWN_DISTANCE:
				continue
			candidates.append(Vector2i(route_index, point_index))
	return candidates

func _spawn(route: PackedVector3Array, point_index: int, point: Vector3, basis: Basis, heavy: bool) -> void:
	var sliced: PackedVector3Array = _slice_route(route, point_index)
	var tank: CharacterBody3D = TankScene.instantiate() as CharacterBody3D
	if tank == null:
		return
	tank.configure(_player, _region, sliced, heavy)
	tank.set_meta(&"tank_heavy", heavy)
	add_child(tank)
	tank.global_transform = Transform3D(basis, point)
	tank.reset_physics_interpolation()
	tank.call(&"start")
	_tanks.append(tank)
	_spawn_left = SPAWN_COOLDOWN

func _slice_route(route: PackedVector3Array, start: int) -> PackedVector3Array:
	var sliced: PackedVector3Array = PackedVector3Array()
	var count: int = route.size()
	for step: int in count:
		sliced.append(route[(start + step) % count])
	return sliced

func _clearance(point: Vector3, basis: Basis) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = TANK_SIZE
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(basis, point + Vector3.UP * (TANK_SIZE.y * 0.5 + CLEARANCE_LIFT))
	query.collision_mask = CLEARANCE_MASK
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _edge_distance(position: Vector3) -> float:
	if not is_instance_valid(_player):
		return INF
	var surface: Vector3 = position
	if _player.has_method(&"get_combat_target"):
		surface = _player.call(&"get_combat_target", position) as Vector3
	var offset: Vector3 = position - surface
	offset.y = 0.0
	return offset.length()

func _has_heavy() -> bool:
	for tank: CharacterBody3D in _tanks:
		if bool(tank.get_meta(&"tank_heavy", false)):
			return true
	return false

func _tank_depleted(tank: CharacterBody3D) -> bool:
	var drainable: Area3D = tank.get(&"drainable") as Area3D
	return is_instance_valid(drainable) and bool(drainable.get(&"is_collapsed"))

func _retire_tank(tank: CharacterBody3D) -> void:
	if not is_instance_valid(tank) or tank.is_queued_for_deletion():
		return
	tank.call(&"cancel_attack")
	tank.call(&"stop")
	tank.queue_free()

func _cancel_attacks() -> void:
	for tank: CharacterBody3D in _tanks:
		if is_instance_valid(tank) and not tank.is_queued_for_deletion():
			tank.call(&"cancel_attack")

func _cache_routes() -> void:
	_routes.clear()
	if not is_instance_valid(_region) or not _region.has_method(&"get_tank_routes"):
		return
	var routes: Array = _region.call(&"get_tank_routes")
	for route in routes:
		if route is PackedVector3Array and (route as PackedVector3Array).size() >= 2:
			_routes.append((route as PackedVector3Array).duplicate())

func _shuffle(items: Array[Vector2i]) -> void:
	for index: int in range(items.size() - 1, 0, -1):
		var swap_index: int = _random.randi_range(0, index)
		var value: Vector2i = items[index]
		items[index] = items[swap_index]
		items[swap_index] = value

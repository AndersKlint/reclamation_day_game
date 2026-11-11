extends Node3D

const Civilian = preload("res://game/humans/civilian.gd")
const CivilianAudio = preload("res://game/humans/civilian_audio.gd")
const CIVILIAN: PackedScene = preload("res://game/humans/civilian.tscn")
const MODELS: Array[PackedScene] = [
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/office_worker.glb"),
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/young_man.glb"),
]
const INITIAL_DISTRICTS: Dictionary = {&"village": 12, &"city": 512, &"downtown": 512}
const SPAWN_BATCH: int = 4
const SPAWN_ATTEMPTS: int = 12
const PLAN_SCAN: int = 192
const PLAN_BATCH: int = 8
const PLAN_INTERVAL: float = 0.05
const MAX_PATH_QUERIES: int = 2
const PLAN_SAMPLES: int = 24
const CELL_SIZE: float = 32.0
const MIN_FLEE_GAIN: float = 5.0
const POINT_PROJECTION_TOLERANCE: float = 0.75

var _region: Node3D
var _player: CharacterBody3D
var _active: bool = false
var _spawned: bool = false
var _spawn_queue: Array[Dictionary] = []
var _spawn_cursor: int = 0
var _spawn_counts: Dictionary = {&"village": 0, &"city": 0, &"downtown": 0}
var _spawn_cells: Dictionary = {}
var _point_cells: Dictionary = {}
var _routes: Array[PackedVector3Array] = []
var _people: Array[Civilian] = []
var _cursor: int = 0
var _model_cursor: int = 0
var _budget_left: float = 0.0
var _path_queries_left: int = 0
var _clearance: CapsuleShape3D = CapsuleShape3D.new()
var _ground_position: Callable
var _audio: CivilianAudio

func configure(region: Node3D, player: CharacterBody3D) -> void:
	_region = region
	_player = player
	_ground_position = Callable(region, "ground_position") if is_instance_valid(region) and region.has_method("ground_position") else Callable()
	_clearance.radius = 0.45
	_clearance.height = 1.8
	_audio = CivilianAudio.new()
	_audio.name = "CivilianScreams"
	add_child(_audio)

func start() -> void:
	_active = true
	_budget_left = 0.0

func stop() -> void:
	_active = false
	_audio.stop_all()
	for person: Civilian in _people:
		if _is_live(person):
			person.stop()

func _physics_process(delta: float) -> void:
	if not _active or not is_instance_valid(_player) or not bool(_player.get("gameplay_enabled")):
		return
	if not bool(_region.get("navigation_ready")):
		return
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	if not _spawned:
		_prepare_spawn_queue()
	if _spawn_cursor < _spawn_queue.size():
		_spawn_step(map)
	_budget_left -= delta
	if _budget_left > 0.0 or _people.is_empty():
		return
	_budget_left = PLAN_INTERVAL
	_path_queries_left = MAX_PATH_QUERIES
	var candidates: Array[Civilian] = []
	for index: int in mini(PLAN_SCAN, _people.size()):
		_cursor = (_cursor + 1) % _people.size()
		var person: Civilian = _people[_cursor]
		if _is_live(person) and person.active and person.plan_due:
			candidates.append(person)
	candidates.sort_custom(_plan_priority)
	for index: int in mini(PLAN_BATCH, candidates.size()):
		var person: Civilian = candidates[index]
		if person.state == Civilian.State.FLEE:
			if _path_queries_left > 0:
				_plan_flee(person, map)
		elif not person.pedestrian_route.is_empty():
			_plan_stroll(person)
		elif _path_queries_left > 0:
			_plan_village_stroll(person, map)

func _plan_priority(a: Civilian, b: Civilian) -> bool:
	var a_flee: bool = a.state == Civilian.State.FLEE
	var b_flee: bool = b.state == Civilian.State.FLEE
	if a_flee != b_flee:
		return a_flee
	return a.global_position.distance_squared_to(_player.global_position) < b.global_position.distance_squared_to(_player.global_position)

func _prepare_spawn_queue() -> void:
	_spawned = true
	_routes = _region.call("get_pedestrian_routes")
	var points: Array = _region.call("get_pedestrian_points")
	for point: Vector3 in points:
		if _region.call("get_zone_at", point) == &"village":
			_spawn_queue.append({"point": point, "route": -1, "index": 0})
	var longest: int = 0
	for route: PackedVector3Array in _routes:
		longest = maxi(longest, route.size())
	for index: int in longest:
		for route_index: int in _routes.size():
			if index < _routes[route_index].size():
				_spawn_queue.append({"point": _routes[route_index][index], "route": route_index, "index": index})

func _spawn_step(map: RID) -> void:
	var spawned: int = 0
	var attempts: int = 0
	while attempts < SPAWN_ATTEMPTS and spawned < SPAWN_BATCH and _spawn_cursor < _spawn_queue.size():
		var entry: Dictionary = _spawn_queue[_spawn_cursor]
		_spawn_cursor += 1
		attempts += 1
		var point: Vector3 = entry["point"]
		var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
		if projected.distance_to(point) > POINT_PROJECTION_TOLERANCE:
			continue
		var zone: StringName = _region.call("get_zone_at", projected)
		if not INITIAL_DISTRICTS.has(zone) or not _clear(projected):
			continue
		entry["point"] = projected
		var cell: Vector2i = _cell(projected)
		if not _point_cells.has(cell):
			_point_cells[cell] = []
		(_point_cells[cell] as Array).append(entry)
		if int(_spawn_counts[zone]) >= int(INITIAL_DISTRICTS[zone]):
			continue
		if not _safe_spawn(projected):
			continue
		_spawn_at(entry)
		_spawn_counts[zone] = int(_spawn_counts[zone]) + 1
		spawned += 1
	if _spawn_cursor == _spawn_queue.size():
		for zone: StringName in INITIAL_DISTRICTS:
			if int(_spawn_counts[zone]) < int(INITIAL_DISTRICTS[zone]):
				push_warning("Civilian %s spawns: %d / %d clear points" % [zone, int(_spawn_counts[zone]), int(INITIAL_DISTRICTS[zone])])
		_spawn_queue.clear()
		_spawn_cursor = 0

func _spawn_at(entry: Dictionary) -> void:
	var point: Vector3 = entry["point"]
	var person: Civilian = CIVILIAN.instantiate() as Civilian
	person.configure_remains(get_parent() as Node3D, _ground_position)
	person.scream_pool = _audio
	_assign_route(person, entry)
	add_child(person)
	person.global_position = point + Vector3.UP * 0.08
	person.reset_physics_interpolation()
	person.configure(_player, MODELS[_model_cursor % MODELS.size()])
	_model_cursor += 1
	_people.append(person)
	var cell: Vector2i = _spawn_cell(point)
	if not _spawn_cells.has(cell):
		_spawn_cells[cell] = []
	(_spawn_cells[cell] as Array).append(point)

func _assign_route(person: Civilian, entry: Dictionary) -> void:
	var route_index: int = int(entry["route"])
	person.pedestrian_route = _routes[route_index] if route_index >= 0 else PackedVector3Array()
	person.route_cursor = int(entry["index"])

func _clear(point: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = _clearance_query(point)
	query.collision_mask = 5
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _clearance_query(point: Vector3) -> PhysicsShapeQueryParameters3D:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.05)
	query.collision_mask = 1
	return query

func _safe_spawn(point: Vector3) -> bool:
	if _flat_distance(point, _player.global_position) < _player_radius() + 20.0:
		return false
	var cell: Vector2i = _spawn_cell(point)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			var nearby: Array = _spawn_cells.get(cell + Vector2i(x, z), [])
			for other: Vector3 in nearby:
				if _flat_distance(point, other) < 2.0:
					return false
	return true

func _plan_stroll(person: Civilian) -> void:
	var route: PackedVector3Array = person.pedestrian_route
	var nearest: int = person.route_cursor
	var distance: float = INF
	for index: int in route.size():
		var candidate_distance: float = _flat_distance(person.global_position, route[index])
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = index
	if distance > 1.5:
		person.accept_path(PackedVector3Array())
		return
	var path: PackedVector3Array = PackedVector3Array()
	var previous: Vector3 = person.global_position
	var direction: int = person.route_direction
	for step: int in range(1, 9):
		var target: Vector3 = route[posmod(nearest + step * direction, route.size())]
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(_player.global_position, previous, target)
		if _flat_distance(closest, _player.global_position) < _player_radius() + 0.5:
			break
		var query: PhysicsShapeQueryParameters3D = _clearance_query(previous)
		query.motion = target - previous
		var fractions: PackedFloat32Array = get_world_3d().direct_space_state.cast_motion(query)
		if fractions[0] < 1.0:
			person.route_direction = -direction
			break
		path.append(target)
		previous = target
	person.route_cursor = nearest
	person.accept_path(path)

func _local_candidates(origin: Vector3) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var cell: Vector2i = _cell(origin)
	for x: int in range(-1, 2):
		for z: int in range(-1, 2):
			var bucket: Array = _point_cells.get(cell + Vector2i(x, z), [])
			if bucket.is_empty():
				continue
			var start: int = randi() % bucket.size()
			for offset: int in mini(3, bucket.size()):
				candidates.append(bucket[(start + offset) % bucket.size()])
	return candidates

func _plan_flee(person: Civilian, map: RID) -> void:
	var origin: Vector3 = person.global_position
	var safety: float = _flat_distance(origin, _player.global_position)
	var candidates: Array[Dictionary] = _local_candidates(origin)
	var best: Dictionary = {}
	var best_gain: float = MIN_FLEE_GAIN
	for index: int in mini(PLAN_SAMPLES, candidates.size()):
		var entry: Dictionary = candidates[index]
		var target: Vector3 = entry["point"]
		if origin.distance_to(target) > 45.0:
			continue
		var gain: float = _flat_distance(target, _player.global_position) - safety
		if gain > best_gain:
			best = entry
			best_gain = gain
	if best.is_empty():
		person.accept_path(PackedVector3Array())
		return
	_path_queries_left -= 1
	var target: Vector3 = best["point"]
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, origin, target, true)
	if not _safe_path(path, origin, target, true):
		person.accept_path(PackedVector3Array())
		return
	_assign_route(person, best)
	person.accept_path(path)

func _plan_village_stroll(person: Civilian, map: RID) -> void:
	var candidates: Array[Dictionary] = _local_candidates(person.global_position)
	for entry: Dictionary in candidates:
		if int(entry["route"]) >= 0:
			continue
		var target: Vector3 = entry["point"]
		var distance: float = target.distance_to(person.global_position)
		if distance < 3.0 or distance > 22.0:
			continue
		_path_queries_left -= 1
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, person.global_position, target, true)
		person.accept_path(path if _safe_path(path, person.global_position, target, false) else PackedVector3Array())
		return
	person.accept_path(PackedVector3Array())

func _safe_path(path: PackedVector3Array, origin: Vector3, target: Vector3, fleeing: bool) -> bool:
	if path.size() < 2 or path.size() > 64 or path[-1].distance_to(target) >= 1.0:
		return false
	var safety: float = _flat_distance(origin, _player.global_position)
	var radius: float = _player_radius()
	var length: float = 0.0
	for index: int in range(1, path.size()):
		var previous: Vector3 = path[index - 1]
		var next: Vector3 = path[index]
		length += previous.distance_to(next)
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(_player.global_position, previous, next)
		var segment_distance: float = _flat_distance(closest, _player.global_position)
		if fleeing and safety < radius:
			if segment_distance + 0.01 < _flat_distance(previous, _player.global_position):
				return false
		elif segment_distance < radius + (0.0 if fleeing else 0.5):
			return false
	return length < origin.distance_to(target) * 2.0

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.z / CELL_SIZE))

func _spawn_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / 2.0), floori(point.z / 2.0))

func _is_live(person: Civilian) -> bool:
	return is_instance_valid(person) and not person.is_queued_for_deletion()

func _player_radius() -> float:
	if is_instance_valid(_player) and _player.has_method("get_combat_radius"):
		var radius: float = float(_player.call("get_combat_radius"))
		return maxf(0.0, radius) if is_finite(radius) else 0.0
	return 0.0

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

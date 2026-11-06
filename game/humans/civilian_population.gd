extends Node3D

const Civilian = preload("res://game/humans/civilian.gd")
const CIVILIAN: PackedScene = preload("res://game/humans/civilian.tscn")
const MODELS: Array[PackedScene] = [
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/office_worker.glb"),
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/young_man.glb"),
]
const ACTIVE_LIMIT: int = 32
const INITIAL_DISTRICTS: Dictionary = {&"village": 8, &"city": 14, &"downtown": 6}
const PEDESTRIAN_ZONES: Array[StringName] = [&"village", &"city", &"downtown"]
const MIN_SPAWN_DISTANCE: float = 14.0
const MIN_FLEE_GAIN: float = 5.0
const MAX_LOCAL_SPAWN_DISTANCE: float = 90.0
const RECYCLE_DISTANCE: float = 140.0
const RECYCLE_INTERVAL: float = 0.75
const RECYCLE_BATCH: int = 3
const SPAWN_ATTEMPTS: int = 32
const SPAWN_BATCH: int = 6
const PLAN_SAMPLES: int = 24
const MAX_PATH_QUERIES: int = 4
const PLAN_INTERVAL: float = 0.05
const POINT_PROJECTION_TOLERANCE: float = 1.5

var _region: Node3D
var _player: CharacterBody3D
var _active: bool = false
var _spawned: bool = false
var _points_by_zone: Dictionary = {}
var _spawn_queue: Array[Vector3] = []
var _spawn_target: int = 0
var _people: Array[Civilian] = []
var _cursor: int = 0
var _model_cursor: int = 0
var _budget_left: float = 0.0
var _recycle_left: float = 0.0
var _clearance: CapsuleShape3D = CapsuleShape3D.new()
var _ground_position: Callable

func configure(region: Node3D, player: CharacterBody3D) -> void:
	_region = region
	_player = player
	_ground_position = Callable(region, "ground_position") if is_instance_valid(region) and region.has_method("ground_position") else Callable()
	_clearance.radius = 0.45
	_clearance.height = 1.8

func start() -> void:
	_active = true
	_budget_left = 0.0
	_recycle_left = 0.0

func stop() -> void:
	_active = false
	for person: Civilian in _people:
		if is_instance_valid(person):
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
		_spawn(map)
		return
	if not _spawn_queue.is_empty() and _people.size() < _spawn_target:
		_spawn_step()
		return
	_budget_left -= delta
	_recycle_left -= delta
	if _recycle_left <= 0.0:
		_recycle_left = RECYCLE_INTERVAL
		_recycle_distant()
	if _budget_left > 0.0 or _people.is_empty():
		return
	_budget_left = PLAN_INTERVAL
	for index: int in _people.size():
		_cursor = (_cursor + 1) % _people.size()
		var person: Civilian = _people[_cursor]
		if _is_live(person) and person.active and person.plan_due:
			_plan(person, map)
			break

func _spawn(map: RID) -> void:
	_spawned = true
	_prepare_points(map)
	if _points_by_zone.is_empty():
		push_warning("Civilian population has no navigation-projected pedestrian points")
		return
	_spawn_queue.clear()
	_spawn_target = 0
	for zone: StringName in INITIAL_DISTRICTS:
		var target_count: int = int(INITIAL_DISTRICTS[zone])
		_spawn_target += target_count
		var points: Array = _points_by_zone.get(zone, [])
		if points.is_empty():
			continue
		var count: int = mini(points.size(), target_count)
		for index: int in count:
			var source: int = int(float(index) * float(points.size()) / float(count))
			_spawn_queue.append(points[source])
	_spawn_step()

func _spawn_step() -> void:
	var spawned: int = 0
	while spawned < SPAWN_BATCH and not _spawn_queue.is_empty() and _people.size() < _spawn_target:
		var point: Vector3 = _spawn_queue.pop_front()
		if not _safe_live_position(point):
			continue
		if not _clear(point):
			continue
		_spawn_at(point)
		spawned += 1
	if _people.size() >= _spawn_target:
		_spawn_queue.clear()
	elif _spawn_queue.is_empty() and _people.size() < 16:
		push_warning("Civilian population has only %d clear pedestrian spawns" % _people.size())

func _prepare_points(map: RID) -> void:
	_points_by_zone.clear()
	var points: Array = _region.call("get_pedestrian_points")
	for point: Vector3 in points:
		var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
		if projected.distance_to(point) > POINT_PROJECTION_TOLERANCE:
			continue
		var zone: StringName = _region.call("get_zone_at", projected)
		if not PEDESTRIAN_ZONES.has(zone):
			continue
		if not _points_by_zone.has(zone):
			_points_by_zone[zone] = []
		var bucket: Array = _points_by_zone[zone]
		bucket.append(projected)

func _spawn_at(point: Vector3) -> void:
	var person: Civilian = CIVILIAN.instantiate() as Civilian
	person.configure_remains(get_parent() as Node3D, _ground_position)
	add_child(person)
	person.global_position = point + Vector3.UP * 0.08
	person.reset_physics_interpolation()
	person.configure(_player, MODELS[_model_cursor % MODELS.size()])
	_model_cursor += 1
	_people.append(person)

func _clear(point: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.05)
	query.collision_mask = 5
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _recycle_distant() -> void:
	_prune()
	if _people.is_empty():
		return
	var district: StringName = _local_district()
	if district == &"":
		return
	var recycled: int = 0
	for index: int in range(_people.size() - 1, -1, -1):
		if recycled >= RECYCLE_BATCH:
			break
		var person: Civilian = _people[index]
		if not _is_live(person):
			continue
		if person.global_position.distance_to(_player.global_position) <= RECYCLE_DISTANCE:
			continue
		if not person.can_recycle():
			continue
		var point: Vector3 = _local_spawn_point(district)
		if not point.is_finite():
			continue
		person.stop()
		_people.remove_at(index)
		person.queue_free()
		_spawn_at(point)
		recycled += 1

func _local_spawn_point(district: StringName) -> Vector3:
	var points: Array = _points_by_zone.get(district, [])
	if points.is_empty():
		return Vector3.INF
	for attempt: int in mini(points.size(), SPAWN_ATTEMPTS):
		var point: Vector3 = points[randi() % points.size()]
		var distance: float = point.distance_to(_player.global_position)
		if distance < MIN_SPAWN_DISTANCE or distance > MAX_LOCAL_SPAWN_DISTANCE:
			continue
		if not _safe_live_position(point):
			continue
		if not _clear(point):
			continue
		return point
	return Vector3.INF

func _local_district() -> StringName:
	var zone: StringName = _region.call("get_zone_at", _player.global_position)
	if _has_points(zone):
		return zone
	if zone == &"downtown" and _has_points(&"city"):
		return &"city"
	if _has_points(&"village"):
		return &"village"
	for candidate: StringName in PEDESTRIAN_ZONES:
		if _has_points(candidate):
			return candidate
	return &""

func _person_district(person: Civilian) -> StringName:
	var zone: StringName = _region.call("get_zone_at", person.global_position)
	if _has_points(zone):
		return zone
	return &"village" if _has_points(&"village") else _local_district()

func _has_points(zone: StringName) -> bool:
	return _points_by_zone.has(zone) and not (_points_by_zone[zone] as Array).is_empty()

func _prune() -> void:
	for index: int in range(_people.size() - 1, -1, -1):
		if not _is_live(_people[index]):
			_people.remove_at(index)

func _is_live(person: Civilian) -> bool:
	return is_instance_valid(person) and not person.is_queued_for_deletion()

func _plan(person: Civilian, map: RID) -> void:
	var fleeing: bool = person.state == Civilian.State.FLEE
	var origin: Vector3 = person.global_position
	var player_position: Vector3 = _player.global_position
	var player_radius: float = _player_radius()
	var safety: float = _flat_distance(origin, player_position)
	var district: StringName = _person_district(person)
	var points: Array = _points_by_zone.get(district, [])
	var best: PackedVector3Array = PackedVector3Array()
	var best_score: float = -INF
	if points.is_empty():
		person.accept_path(best)
		return
	var start: int = randi() % points.size()
	var examined: int = 0
	var queries: int = 0
	for offset: int in points.size():
		if examined >= PLAN_SAMPLES or queries >= MAX_PATH_QUERIES:
			break
		var target: Vector3 = points[(start + offset) % points.size()]
		examined += 1
		var travel: float = origin.distance_to(target)
		if travel < 3.0 or travel > 45.0:
			continue
		if not fleeing:
			target = NavigationServer3D.map_get_closest_point(map, origin.move_toward(target, randf_range(4.0, 8.0)))
			travel = origin.distance_to(target)
			if travel < 3.0 or not _clear(target):
				continue
		var gain: float = _flat_distance(target, player_position) - safety
		if fleeing and gain < MIN_FLEE_GAIN:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, origin, target, true)
		queries += 1
		if path.size() < 2 or path[-1].distance_to(target) >= 1.0:
			continue
		var safe: bool = true
		var length: float = 0.0
		for i: int in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
			var previous_distance: float = _flat_distance(path[i - 1], player_position)
			var next_distance: float = _flat_distance(path[i], player_position)
			var closest: Vector3 = Geometry3D.get_closest_point_to_segment(player_position, path[i - 1], path[i])
			var segment_distance: float = _flat_distance(closest, player_position)
			if fleeing:
				if safety < player_radius:
					if segment_distance + 0.01 < previous_distance:
						safe = false
						break
				elif segment_distance < player_radius:
					safe = false
					break
			elif segment_distance < player_radius + 0.5:
				safe = false
				break
		var score: float = gain - length * 0.15 if fleeing else -length
		if safe and length < travel * 2.0 and score > best_score:
			best = path
			best_score = score
	person.accept_path(best)

func _player_radius() -> float:
	if is_instance_valid(_player) and _player.has_method("get_combat_radius"):
		var radius: float = float(_player.call("get_combat_radius"))
		return maxf(0.0, radius) if is_finite(radius) else 0.0
	return 0.0

func _safe_live_position(point: Vector3) -> bool:
	return _flat_distance(point, _player.global_position) >= _player_radius() + MIN_SPAWN_DISTANCE

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

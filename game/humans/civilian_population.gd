extends Node3D

const Civilian = preload("res://game/humans/civilian.gd")
const CIVILIAN: PackedScene = preload("res://game/humans/civilian.tscn")
const MODELS: Array[PackedScene] = [
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/office_worker.glb"),
	preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/People/young_man.glb"),
]

var _region: Node3D
var _player: CharacterBody3D
var _active: bool = false
var _spawned: bool = false
var _lanes: Array[Vector3] = []
var _people: Array[Civilian] = []
var _cursor: int = 0
var _budget_left: float = 0.0
var _clearance: CapsuleShape3D = CapsuleShape3D.new()

func configure(region: Node3D, player: CharacterBody3D) -> void:
	_region = region
	_player = player
	_clearance.radius = 0.45
	_clearance.height = 1.8

func start() -> void:
	_active = true

func stop() -> void:
	_active = false
	for person: Civilian in _people:
		if is_instance_valid(person):
			person.stop()

func _physics_process(delta: float) -> void:
	if not _active or not bool(_region.get("navigation_ready")):
		return
	var map: RID = get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return
	if not _spawned:
		_spawn(map)
		return
	_budget_left -= delta
	if _budget_left > 0.0 or _people.is_empty():
		return
	_budget_left = 0.05
	for index: int in _people.size():
		_cursor = (_cursor + 1) % _people.size()
		var person: Civilian = _people[_cursor]
		if is_instance_valid(person) and not person.is_queued_for_deletion() and person.plan_due:
			_plan(person, map)
			break

func _spawn(map: RID) -> void:
	_spawned = true
	for z: float in [-30.0, -46.0, -70.0, -86.0, -112.0, -132.0, -148.0]:
		_add_lane(Vector2(0.0, z), map)
		_add_lane(Vector2(-94.0, z), map)
		_add_lane(Vector2(95.0, z), map)
	for z: float in [-58.0, -100.0, -156.0]:
		for x: float in [-80.0, -58.0, -38.0, -16.0, 16.0, 38.0, 58.0, 80.0]:
			_add_lane(Vector2(x, z), map)
	var candidates: Array[Vector3] = _lanes.duplicate()
	candidates.shuffle()
	for point: Vector3 in candidates:
		if _people.size() >= 18:
			break
		if not _clear(point):
			continue
		var person: Civilian = CIVILIAN.instantiate() as Civilian
		add_child(person)
		person.global_position = point + Vector3.UP * 0.08
		person.configure(_player, MODELS[_people.size() % MODELS.size()])
		_people.append(person)
	if _people.size() < 16:
		push_warning("Village civilian population has only %d clear lane spawns" % _people.size())

func _add_lane(point: Vector2, map: RID) -> void:
	var local: Vector3 = Vector3(point.x, float(_region.call("ground_height", point.x, point.y)), point.y)
	var world: Vector3 = _region.to_global(local)
	var projected: Vector3 = NavigationServer3D.map_get_closest_point(map, world)
	if projected.distance_to(world) <= 1.0 and _region.call("get_zone_at", projected) == &"village" and _clear(projected):
		_lanes.append(projected)

func _clear(point: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _clearance
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.05)
	query.collision_mask = 5
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _plan(person: Civilian, map: RID) -> void:
	var fleeing: bool = person.state == Civilian.State.FLEE
	var origin: Vector3 = person.global_position
	var safety: float = origin.distance_to(_player.global_position)
	var best: PackedVector3Array = PackedVector3Array()
	var best_score: float = -INF
	var candidates: Array[Vector3] = _lanes.duplicate()
	candidates.shuffle()
	var queries: int = 0
	for target: Vector3 in candidates:
		var travel: float = origin.distance_to(target)
		if travel < 3.0 or travel > 45.0:
			continue
		if not fleeing:
			target = NavigationServer3D.map_get_closest_point(map, origin.move_toward(target, randf_range(4.0, 8.0)))
			travel = origin.distance_to(target)
			if travel < 3.0 or not _clear(target):
				continue
		var gain: float = target.distance_to(_player.global_position) - safety
		if fleeing and gain < 5.0:
			continue
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, origin, target, true)
		queries += 1
		if path.size() >= 2 and path[-1].distance_to(target) < 1.0:
			var safe: bool = true
			var length: float = 0.0
			for i: int in range(1, path.size()):
				length += path[i - 1].distance_to(path[i])
				var closest: Vector3 = Geometry3D.get_closest_point_to_segment(_player.global_position, path[i - 1], path[i])
				if fleeing and closest.distance_to(_player.global_position) < safety - 1.0:
					safe = false
			var first: Vector3 = path[1] - origin
			var away: Vector3 = origin - _player.global_position
			first.y = 0.0
			away.y = 0.0
			if fleeing and first.dot(away) < 0.0:
				safe = false
			var score: float = gain - length * 0.15 if fleeing else -length
			if safe and length < travel * 2.0 and score > best_score:
				best = path
				best_score = score
		if queries >= 4:
			break
	person.accept_path(best)

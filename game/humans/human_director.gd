extends Node3D

signal tier_changed(tier: int)
signal human_spawned(human: CharacterBody3D)

const HumanScene: PackedScene = preload("res://game/humans/human.tscn")

@export_range(1, 30) var maximum_active: int = 16
@export_range(1, 30) var early_population: int = 4
@export var initial_delay: float = 8.0
@export var initial_field_delay: float = 22.0
@export var early_spawn_interval: float = 7.0
@export var late_spawn_interval: float = 4.5
@export_range(0.0, 1.0) var ranged_progress_threshold: float = 0.3
@export_range(0.0, 1.0) var ranged_fraction: float = 0.5
@export var minimum_spawn_distance: float = 15.0
@export var spawn_spacing: float = 2.0
@export var maximum_spawn_distance: float = 50.0
@export var zone_entry_delay: float = 2.5
@export var home_leash: float = 65.0
@export_group("Ranged")
@export var ranged_speed: float = 3.0
@export var ranged_range: float = 16.0
@export var ranged_damage: float = 13.0
@export var ranged_windup: float = 1.4
@export var ranged_cooldown: float = 3.8
@export var ranged_impact_radius: float = 1.8
@export var ranged_capacity: float = 22.0
@export var ranged_required_size: float = 1.8
@export_group("City")
@export var city_population: int = 12
@export_range(0.0, 1.0) var city_ranged_fraction: float = 0.85
@export var city_speed: float = 3.2
@export var city_range: float = 20.0
@export var city_damage: float = 15.0
@export var city_windup: float = 1.5
@export var city_cooldown: float = 3.2
@export var city_impact_radius: float = 2.0
@export var city_capacity: float = 26.0
@export_group("Downtown")
@export var downtown_population: int = 16
@export_range(0.0, 1.0) var downtown_ranged_fraction: float = 1.0
@export var downtown_speed: float = 3.4
@export var downtown_range: float = 24.0
@export var downtown_damage: float = 18.0
@export var downtown_windup: float = 1.7
@export var downtown_cooldown: float = 2.8
@export var downtown_impact_radius: float = 2.2
@export var downtown_capacity: float = 32.0

var active: bool = false
var tier: int = 0
var _balancer: CharacterBody3D
var _spawn_points: Array[Node3D] = []
var _humans: Array[CharacterBody3D] = []
var _spawn_left: float = 0.0
var _next_spawn: int = 0
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
var _region: Node3D
var _ground_position: Callable
var _zone: StringName = &""
var _progress_tier: int = 0
var _zone_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure_region(region: Node3D) -> void:
	_region = region
	_zone = &""
	_zone_time = 0.0

func configure(balancer: CharacterBody3D, spawn_points: Array[Node3D], ground_position: Callable) -> void:
	stop()
	_balancer = balancer
	_spawn_points.assign(spawn_points)
	_ground_position = ground_position
	_next_spawn = 0

func set_progress(drained: float, initial: float) -> void:
	var progress: float = clampf(drained / initial, 0.0, 1.0) if initial > 0.0 else 0.0
	_progress_tier = 1 if progress >= ranged_progress_threshold else 0
	if _region != null:
		return
	_set_tier(_progress_tier)

func _set_tier(next_tier: int) -> void:
	if next_tier != tier:
		tier = next_tier
		tier_changed.emit(tier)

func start() -> void:
	if active or not is_instance_valid(_balancer) or _spawn_points.is_empty():
		return
	if float(_balancer.get("health")) <= 0.0:
		return
	_random.randomize()
	_spawn_left = initial_delay
	_zone = &""
	_zone_time = 0.0
	active = true

func stop() -> void:
	active = false
	_spawn_left = 0.0
	for human: CharacterBody3D in _humans:
		if is_instance_valid(human):
			human.stop()
			if not human.drainable.is_depleted:
				human.queue_free()
	_humans.clear()

func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(_balancer) or float(_balancer.get("health")) <= 0.0:
		stop()
		return
	if get_tree().paused or not bool(_balancer.get("gameplay_enabled")):
		for human: CharacterBody3D in _humans:
			if is_instance_valid(human):
				human.cancel_attack()
		return
	if _region != null:
		if not bool(_region.get("navigation_ready")):
			return
		var next_zone: StringName = _region.call("get_zone_at", _balancer.global_position)
		if next_zone != _zone:
			var first_field_entry: bool = _zone == &"" and next_zone == &"field"
			_zone = next_zone
			_zone_time = 0.0
			_spawn_left = initial_field_delay if first_field_entry else zone_entry_delay
		_zone_time += delta
		_set_tier(_tier_for_zone(_zone))
	for index: int in range(_humans.size() - 1, -1, -1):
		if not is_instance_valid(_humans[index]) or _humans[index].is_queued_for_deletion():
			_humans.remove_at(index)
	_spawn_left -= delta
	var limit: int = _population_limit()
	if _spawn_left > 0.0 or _humans.size() >= limit:
		return
	_spawn_left = late_spawn_interval if tier >= 1 else early_spawn_interval
	_spawn_human()

func _tier_for_zone(zone: StringName) -> int:
	match zone:
		&"approach":
			return 1
		&"village":
			return 2
		&"city":
			return 3
		&"downtown":
			return 4
		_:
			return 0

func _population_limit() -> int:
	var limit: int = maximum_active if tier == 1 else mini(early_population, maximum_active)
	if _region == null:
		return limit
	match tier:
		3:
			return mini(city_population, maximum_active)
		4:
			return mini(downtown_population, maximum_active)
	limit = mini(mini(maximum_active, 10), (7 + _progress_tier if tier == 2 else (4 + _progress_tier if tier == 1 else 2 + _progress_tier)))
	if _zone_time > 30.0:
		limit = mini(limit + 1, mini(maximum_active, 10))
	return limit

func _spawn_human() -> void:
	for step: int in _spawn_points.size():
		var index: int = (_next_spawn + step) % _spawn_points.size()
		var point: Node3D = _spawn_points[index]
		if not is_instance_valid(point):
			continue
		if not _spawn_clear_of_player(point.global_position):
			continue
		var spawn_position: Vector3 = point.global_position
		if _region != null:
			if StringName(point.get_meta(&"zone", &"")) != _zone:
				continue
			spawn_position.y = float(_region.call("ground_height", spawn_position.x, spawn_position.z))
			var map: RID = get_world_3d().get_navigation_map()
			if NavigationServer3D.map_get_iteration_id(map) == 0:
				return
			var grounded: Vector3 = NavigationServer3D.map_get_closest_point(map, spawn_position)
			if grounded.distance_to(spawn_position) > 1.5:
				continue
			var edge_target: Vector3 = _combat_target(grounded)
			edge_target.y = float(_region.call("ground_height", edge_target.x, edge_target.z))
			var destination: Vector3 = NavigationServer3D.map_get_closest_point(map, edge_target)
			if destination.distance_to(edge_target) > 1.5:
				continue
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, grounded, destination, true)
			if path.is_empty() or path[path.size() - 1].distance_to(destination) > 3.0:
				continue
			var path_length: float = 0.0
			for path_index: int in range(1, path.size()):
				path_length += path[path_index - 1].distance_to(path[path_index])
			var direct_distance: float = grounded.distance_to(destination)
			if path_length > minf(maximum_spawn_distance * 1.8, direct_distance * 1.8 + 12.0):
				continue
			spawn_position = grounded + Vector3.UP * 0.1
			if _surface_distance(spawn_position) > maximum_spawn_distance or _surface_distance(point.global_position) > home_leash:
				continue
			if not _spawn_clear_of_player(spawn_position) or not _inside_world_bounds(spawn_position):
				continue
			var shape: CapsuleShape3D = CapsuleShape3D.new()
			shape.radius = 0.4
			shape.height = 1.8
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = spawn_position + Vector3.UP * 0.95
			query.collision_mask = 1 | 2 | 4
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				continue
		var occupied: bool = false
		for existing: CharacterBody3D in _humans:
			if is_instance_valid(existing) and not existing.is_queued_for_deletion() and existing.global_position.distance_to(point.global_position) < spawn_spacing:
				occupied = true
				break
		if occupied:
			continue
		var human: CharacterBody3D = HumanScene.instantiate() as CharacterBody3D
		var ranged_chance: float = ranged_fraction
		if tier == 2:
			ranged_chance = 0.7
		elif tier == 3:
			ranged_chance = city_ranged_fraction
		elif tier == 4:
			ranged_chance = downtown_ranged_fraction
		if tier >= 1 and _random.randf() < ranged_chance:
			_configure_ranged(human)
		human.configure(_balancer)
		human.configure_remains(get_parent() as Node3D, _ground_position)
		if _region != null:
			human.configure_region(_region, _zone, spawn_position)
			human.home_leash = home_leash
		add_child(human)
		human.global_position = spawn_position
		human.reset_physics_interpolation()
		_humans.append(human)
		_next_spawn = (index + 1) % _spawn_points.size()
		human_spawned.emit(human)
		return

func _configure_ranged(human: CharacterBody3D) -> void:
	human.ranged = true
	human.required_size = ranged_required_size
	match tier:
		3:
			human.movement_speed = city_speed
			human.attack_range = city_range
			human.damage = city_damage
			human.windup = city_windup
			human.cooldown = city_cooldown
			human.impact_radius = city_impact_radius
			human.life_capacity = city_capacity
		4:
			human.movement_speed = downtown_speed
			human.attack_range = downtown_range
			human.damage = downtown_damage
			human.windup = downtown_windup
			human.cooldown = downtown_cooldown
			human.impact_radius = downtown_impact_radius
			human.life_capacity = downtown_capacity
		_:
			human.movement_speed = ranged_speed
			human.attack_range = ranged_range
			human.damage = ranged_damage
			human.windup = ranged_windup
			human.cooldown = ranged_cooldown
			human.impact_radius = ranged_impact_radius
			human.life_capacity = ranged_capacity

func _spawn_clear_of_player(position: Vector3) -> bool:
	if not is_instance_valid(_balancer):
		return false
	var surface: Vector3 = position
	if _balancer.has_method(&"get_combat_target"):
		surface = _balancer.call(&"get_combat_target", position) as Vector3
	var offset: Vector3 = position - surface
	offset.y = 0.0
	return offset.length() >= minimum_spawn_distance

func _combat_target(position: Vector3) -> Vector3:
	if _balancer.has_method(&"get_combat_target"):
		return _balancer.call(&"get_combat_target", position) as Vector3
	return _balancer.global_position

func _surface_distance(position: Vector3) -> float:
	var offset: Vector3 = position - _combat_target(position)
	offset.y = 0.0
	return offset.length()

func _inside_world_bounds(position: Vector3) -> bool:
	if _region == null or not _region.has_method(&"get_world_bounds"):
		return true
	var bounds: Rect2 = _region.call(&"get_world_bounds") as Rect2
	return bounds.grow(-1.0).has_point(Vector2(position.x, position.z))

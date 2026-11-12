extends Node3D

const Balancer = preload("res://game/balancer/balancer.gd")
const EXPLOSION: PackedScene = preload("res://game/enemies/tank_explosion.tscn")
const SPEED: float = 24.0
const LIFETIME: float = 5.0
const RADIUS: float = 0.25
const OBSTACLE_MASK: int = 1 | 16
const RETURN_HIT_DISTANCE: float = 1.5
const RETURN_TARGET_HEIGHT: float = 1.8

var _player: CharacterBody3D
var _shooter: Node3D
var _direction: Vector3
var _damage: float
var _blast_radius: float
var _age: float = 0.0
var _excluded: Array[RID] = []
var _shape: SphereShape3D = SphereShape3D.new()
var _impacted: bool = false
var _returning: bool = false

func configure(player: CharacterBody3D, origin: Vector3, direction: Vector3, damage: float, blast_radius: float, shooter: Node3D) -> void:
	_player = player
	_shooter = shooter
	_direction = direction.normalized()
	_damage = damage
	_blast_radius = blast_radius
	_excluded = [shooter.get_rid()]
	_shape.radius = RADIUS
	global_position = origin
	if not _direction.is_zero_approx():
		look_at(origin + _direction, Vector3.FORWARD if absf(_direction.y) > 0.99 else Vector3.UP)
	reset_physics_interpolation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and not _returning:
		queue_free()

func _physics_process(delta: float) -> void:
	if _impacted or is_queued_for_deletion():
		return
	if _returning:
		_process_return(delta)
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		queue_free()
		return
	if not bool(_player.get("gameplay_enabled")) or float(_player.get("health")) <= 0.0:
		queue_free()
		return
	var step: float = minf(delta, maxf(0.0, LIFETIME - _age))
	_age += step
	var start: Vector3 = global_position
	var motion: Vector3 = _direction * SPEED * step
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, start)
	query.collision_mask = OBSTACLE_MASK
	query.exclude = _excluded
	query.collide_with_areas = true
	query.margin = 0.001
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var world_fraction: float = 1.0
	var world_hit: bool = not space.intersect_shape(query, 1).is_empty()
	if world_hit:
		world_fraction = 0.0
	else:
		query.motion = motion
		var fractions: PackedFloat32Array = space.cast_motion(query)
		world_hit = fractions[0] < 1.0
		world_fraction = fractions[0]
	var end: Vector3 = start + motion * world_fraction
	var player_fraction: float = _player_hit_fraction(start, end)
	if player_fraction < 1.0:
		global_position = start.lerp(end, player_fraction)
		if _player.has_method(&"try_reflect_projectile") and bool(_player.call(&"try_reflect_projectile")):
			_begin_reflection_return()
			return
		_explode()
		return
	global_position = end
	if world_hit:
		_explode()
	elif _age >= LIFETIME:
		queue_free()

func _player_hit_fraction(start: Vector3, end: Vector3) -> float:
	var radius: float = float(_player.call("get_combat_radius"))
	var height: float = Balancer.COMBAT_HEIGHT_PER_SIZE * float(_player.get("size"))
	var bottom: Vector3 = _player.global_position + Vector3.UP * radius
	var top: Vector3 = _player.global_position + Vector3.UP * maxf(radius, height - radius)
	var points: PackedVector3Array = Geometry3D.get_closest_points_between_segments(start, end, bottom, top)
	if points[0].distance_squared_to(points[1]) > (radius + RADIUS) * (radius + RADIUS):
		return 1.0
	var low: float = 0.0
	var high: float = 1.0
	for _iteration: int in range(16):
		var middle: float = (low + high) * 0.5
		var prefix: PackedVector3Array = Geometry3D.get_closest_points_between_segments(start, start.lerp(end, middle), bottom, top)
		if prefix[0].distance_squared_to(prefix[1]) <= (radius + RADIUS) * (radius + RADIUS):
			high = middle
		else:
			low = middle
	return high

func _begin_reflection_return() -> void:
	_returning = true
	if not _shooter_valid():
		queue_free()

func _shooter_valid() -> bool:
	return is_instance_valid(_shooter) and _shooter.is_inside_tree() and not _shooter.is_queued_for_deletion()

func _process_return(delta: float) -> void:
	if not _shooter_valid():
		queue_free()
		return
	var target: Vector3 = _shooter.global_position + Vector3.UP * RETURN_TARGET_HEIGHT
	var offset: Vector3 = target - global_position
	if offset.length() <= RETURN_HIT_DISTANCE:
		_shooter.call(&"receive_reflected_projectile", _player)
		queue_free()
		return
	_direction = offset.normalized()
	global_position += _direction * minf(SPEED * delta, offset.length())
	look_at(global_position + _direction, Vector3.FORWARD if absf(_direction.y) > 0.99 else Vector3.UP)

func _explode() -> void:
	if _impacted:
		return
	_impacted = true
	var target: Vector3 = _player.call("get_combat_target", global_position)
	if global_position.distance_to(target) <= _blast_radius:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, target, OBSTACLE_MASK, _excluded)
		query.collide_with_areas = true
		query.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_player.call("take_damage", _damage)
	var effect: Node3D = EXPLOSION.instantiate() as Node3D
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.configure(_blast_radius)
	queue_free()

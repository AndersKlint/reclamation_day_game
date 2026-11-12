extends Node3D

const Balancer = preload("res://game/balancer/balancer.gd")
const PoliceAudio = preload("res://game/humans/police_audio.gd")
const SPEED: float = 24.0
const LIFETIME: float = 1.4
const RADIUS: float = 0.04
const FLYBY_DISTANCE: float = 1.8
const RETURN_HIT_DISTANCE: float = 0.5
const RETURN_TARGET_HEIGHT: float = 1.0

var _balancer: CharacterBody3D
var _shooter: Node3D
var _direction: Vector3
var _damage: float
var _age: float = 0.0
var _closest_miss: float = INF
var _flyby_position: Vector3
var _returning: bool = false

@onready var _flash: MeshInstance3D = $Flash

func configure(balancer: CharacterBody3D, origin: Vector3, direction: Vector3, damage: float, shooter: Node3D) -> void:
	_balancer = balancer
	_shooter = shooter
	_direction = direction
	_damage = damage
	global_position = origin
	look_at(origin + direction, Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP)
	_flash.top_level = true
	_flash.global_position = origin
	reset_physics_interpolation()
	_flash.reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion():
		return
	if _returning:
		_process_return(delta)
		return
	if not is_instance_valid(_balancer) or not _balancer.is_inside_tree():
		queue_free()
		return
	if not bool(_balancer.get(&"gameplay_enabled")) or float(_balancer.get(&"health")) <= 0.0:
		queue_free()
		return
	var step: float = minf(delta, LIFETIME - _age)
	_age += step
	_flash.visible = _age < 0.07
	var start: Vector3 = global_position
	var end: Vector3 = start + _direction * SPEED * step
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, end, 1)
	query.hit_from_inside = true
	var cover: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not cover.is_empty():
		end = cover["position"] as Vector3
	var radius: float = float(_balancer.call(&"get_combat_radius"))
	var height: float = Balancer.COMBAT_HEIGHT_PER_SIZE * float(_balancer.get(&"size"))
	var bottom: Vector3 = _balancer.global_position + Vector3.UP * radius
	var top: Vector3 = _balancer.global_position + Vector3.UP * maxf(radius, height - radius)
	var points: PackedVector3Array = Geometry3D.get_closest_points_between_segments(start, end, bottom, top)
	var separation: float = points[0].distance_to(points[1])
	if separation <= radius + RADIUS:
		var low: float = 0.0
		var high: float = 1.0
		for _iteration: int in range(12):
			var middle: float = (low + high) * 0.5
			var prefix: PackedVector3Array = Geometry3D.get_closest_points_between_segments(start, start.lerp(end, middle), bottom, top)
			if prefix[0].distance_to(prefix[1]) <= radius + RADIUS:
				high = middle
			else:
				low = middle
		var impact: Vector3 = start.lerp(end, high)
		if cover.is_empty() or start.distance_squared_to(impact) < start.distance_squared_to(end):
			if _balancer.has_method(&"try_reflect_projectile") and bool(_balancer.call(&"try_reflect_projectile")):
				global_position = impact
				_begin_reflection_return()
				return
			_balancer.call(&"take_damage", _damage)
			queue_free()
			return
	var clearance: float = separation - radius
	if clearance > RADIUS and clearance < _closest_miss:
		_closest_miss = clearance
		_flyby_position = points[0]
	global_position = end
	if not cover.is_empty() or _age >= LIFETIME:
		_finish_miss()
		return
	if _closest_miss <= FLYBY_DISTANCE:
		var end_axis: Vector3 = Geometry3D.get_closest_point_to_segment(end, bottom, top)
		var end_offset: Vector3 = end - end_axis
		if end_offset.dot(_direction) > 0.0 and end_offset.length() > radius + FLYBY_DISTANCE:
			_finish_miss()

func _begin_reflection_return() -> void:
	_returning = true
	_flash.visible = false
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
		_shooter.call(&"receive_reflected_projectile", _balancer)
		queue_free()
		return
	_direction = offset.normalized()
	global_position += _direction * minf(SPEED * delta, offset.length())
	look_at(global_position + _direction, Vector3.FORWARD if absf(_direction.y) > 0.99 else Vector3.UP)

func _finish_miss() -> void:
	if _closest_miss <= FLYBY_DISTANCE:
		PoliceAudio.play_flyby(get_parent(), _flyby_position)
	queue_free()

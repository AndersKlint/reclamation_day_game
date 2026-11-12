extends CharacterBody3D

const TankAssets = preload("res://game/enemies/tank_assets.gd")
const TankPursuit = preload("res://game/enemies/tank_pursuit.gd")
const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const DEPLETION_SCRIPT = preload("res://game/draining/depletion_effect.gd")
const Drainable = preload("res://game/draining/drainable.gd")
const WorldModel = preload("res://game/world/world_model.gd")
const SHELL: PackedScene = preload("res://game/enemies/tank_shell.tscn")
const CANNON_SOUNDS: Array[AudioStream] = [
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_01.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_02.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_03.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_04.wav"),
]
const MUZZLE_HEIGHT: float = 1.9
const MUZZLE_FORWARD: float = 2.6
const WORLD_LAYER: int = 1
const CAR_LAYER: int = 16
const OBSTACLE_MASK: int = WORLD_LAYER | CAR_LAYER
const AGGRO_HYSTERESIS: float = 10.0

enum State { PATROL, WINDUP }

@export var movement_speed: float = 4.0
@export var turn_rate: float = 0.6
@export var acceleration: float = 2.5
@export var waypoint_reach: float = 6.0
@export var obstacle_lookahead: float = 7.0
@export var home_leash: float = 14.0
@export var attack_range: float = 55.0
@export var damage: float = 26.0
@export var windup: float = 2.0
@export var cooldown: float = 6.5
@export var impact_radius: float = 4.5

var state: State = State.PATROL
var _player: CharacterBody3D
var _region: Node3D
var _route: PackedVector3Array = PackedVector3Array()
var _heavy: bool = false
var _active: bool = false
var _stun_left: float = 0.0
var _depleted: bool = false
var _waypoint: int = 1
var _windup_left: float = 0.0
var _cooldown_left: float = 1.5
var _aim: Vector3
var _aim_committed: bool = false
var _committed_direction: Vector3 = Vector3.ZERO
var _engaged: bool = false
var _returning: bool = false
var _return_target: Vector3
var _pursuit: TankPursuit = TankPursuit.new()
var _pursuit_path: PackedVector3Array = PackedVector3Array()
var _pursuit_waypoint: int = 0
var _repath_left: float = 0.0
var _shells: Array[Node3D] = []
var _route_check_left: float = 0.0
var _route_started: bool = false
var _ground_position: Callable
@onready var drainable: Drainable = $Drainable
@onready var _visual: Node3D = $Visual
@onready var _fire_voice: AudioStreamPlayer3D = $CannonShot

func configure(player: CharacterBody3D, region: Node3D, route: PackedVector3Array, heavy: bool = false) -> void:
	_player = player
	_region = region
	_route = route.duplicate()
	_heavy = heavy
	if _route.size() > 1 and _route[0].is_equal_approx(_route[_route.size() - 1]):
		_route.remove_at(_route.size() - 1)
	_apply_variant()

func start() -> void:
	_active = true
	state = State.PATROL
	_cooldown_left = maxf(_cooldown_left, 1.5)

func stop() -> void:
	_active = false
	_engaged = false
	_returning = false
	_pursuit_path.clear()
	cancel_attack()
	_clear_shells()
	velocity = Vector3.ZERO
	if is_instance_valid(_fire_voice):
		_fire_voice.stop()

func cancel_attack() -> void:
	state = State.PATROL
	_windup_left = 0.0
	_aim_committed = false
	_committed_direction = Vector3.ZERO
	_cooldown_left = maxf(_cooldown_left, 1.0)
	velocity = Vector3.ZERO

func apply_stun(seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0.0 or _depleted or is_queued_for_deletion():
		return
	_stun_left = maxf(_stun_left, seconds)
	cancel_attack()

func receive_reflected_projectile(collector: Node3D) -> void:
	if _depleted or is_queued_for_deletion() or not is_inside_tree() or not is_instance_valid(drainable):
		return
	if drainable.is_queued_for_deletion() or drainable.is_collapsed:
		return
	if not is_instance_valid(collector):
		return
	var grant_rewards: bool = not collector.has_method(&"can_reward_reflection") or bool(collector.call(&"can_reward_reflection", drainable))
	drainable.force_collapse(collector, grant_rewards)

func receive_drain_burst(requested_amount: float, source_volume: float, collector: Node3D) -> void:
	if not is_finite(requested_amount) or requested_amount <= 0.0 or not is_finite(source_volume) or source_volume <= 0.0:
		return
	if _depleted or is_queued_for_deletion() or not is_inside_tree() or not is_instance_valid(drainable):
		return
	if drainable.is_queued_for_deletion() or drainable.is_collapsed or not drainable.can_drain(source_volume):
		return
	if not is_instance_valid(collector) or collector.is_queued_for_deletion() or not collector.is_inside_tree():
		return
	if not collector.has_method(&"gain_life") or not bool(collector.get("gameplay_enabled")):
		return
	var health: Variant = collector.get("health")
	if not (health is float or health is int):
		return
	if not is_finite(float(health)) or float(health) <= 0.0:
		return
	var actual: float = drainable.drain(requested_amount, source_volume, collector)
	if not is_finite(actual) or actual <= 0.0:
		return
	collector.call(&"gain_life", actual)
	var healing: float = drainable.healing_for(actual)
	if healing > 0.0 and collector.has_method(&"request_healing"):
		collector.call(&"request_healing", healing)

func is_engaged() -> bool:
	if not _active or _depleted or not is_instance_valid(_player):
		return false
	if float(_player.get("health")) <= 0.0:
		return false
	return state == State.WINDUP or (_engaged and _target_distance() <= _pursuit.aggro_radius + AGGRO_HYSTERESIS)

func _clear_shells() -> void:
	for shell: Node3D in _shells:
		if is_instance_valid(shell):
			shell.queue_free()
	_shells.clear()

func _exit_tree() -> void:
	_clear_shells()

func _apply_variant() -> void:
	if not _heavy:
		return
	movement_speed = 3.2
	turn_rate = 0.42
	acceleration = 2.0
	attack_range = 62.0
	damage = 44.0
	windup = 2.2
	cooldown = 7.5
	impact_radius = 6.0

func _ready() -> void:
	add_to_group(&"shockwave_enemies")
	drainable.emission_offset = Vector3(0.0, 1.4, 0.0)
	drainable.emission_radius = 1.6
	drainable.collapsed.connect(_on_collapsed)
	var drain_shape: SphereShape3D = SphereShape3D.new()
	drain_shape.radius = 2.4
	($Drainable/CollisionShape3D as CollisionShape3D).shape = drain_shape
	_ground_position = Callable(_region, "ground_position") if _region != null and _region.has_method("ground_position") else Callable()
	_pursuit.configure(_region)
	TankAssets.build(_visual, _heavy)
	drainable.drain_speed_multiplier /= 20.0
	drainable.configure_volume(WorldModel.bounds(_visual).size * global_basis.get_scale().abs())
	var health_bar := preload("res://game/ui/enemy_health_bar.gd").new()
	add_child(health_bar)
	health_bar.configure(drainable, WorldModel.bounds(_visual).end.y + 0.5)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_attack()
		_clear_shells()

func _physics_process(delta: float) -> void:
	if _depleted or not _active or is_queued_for_deletion():
		return
	if not is_instance_valid(_player) or float(_player.get("health")) <= 0.0:
		stop()
		return
	if not bool(_player.get("gameplay_enabled")):
		cancel_attack()
		_clear_shells()
		return
	if _stun_left > 0.0:
		_stun_left = maxf(0.0, _stun_left - delta)
		_drive(Vector3.ZERO, delta)
		return
	if not _route_started:
		_start_route()
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	if state == State.WINDUP:
		_process_windup(delta)
	else:
		_process_patrol(delta)

func _process_windup(delta: float) -> void:
	var tracking_time: float = minf(delta, maxf(0.0, _windup_left - maxf(0.05, windup) * 0.5))
	if not _aim_committed:
		_aim = _ground_point(_player.global_position)
		_face(_aim - global_position, tracking_time, turn_rate)
	_windup_left = maxf(0.0, _windup_left - delta)
	if not _aim_committed and _windup_left <= maxf(0.05, windup) * 0.5:
		var origin: Vector3 = _muzzle_position()
		var offset: Vector3 = _aim - origin
		var pitch: float = atan2(offset.y, _flat(offset).length())
		_committed_direction = -global_basis.z.normalized() * cos(pitch) + Vector3.UP * sin(pitch)
		_aim_committed = true
	_drive(Vector3.ZERO, delta)
	if _windup_left <= 0.0:
		_resolve_attack()

func _process_patrol(delta: float) -> void:
	_update_engagement()
	if _engaged:
		_process_pursuit(delta)
		return
	if _returning:
		if _pursuit_path.is_empty():
			_repath_left -= delta
			if _repath_left <= 0.0:
				_repath_left = 1.0
				_pursuit_path = _pursuit.path_to(global_position, _return_target, Callable(), _clear_approach)
				_pursuit_waypoint = 0
			_drive(Vector3.ZERO, delta)
			return
		_follow_pursuit_path(delta)
		if _pursuit_waypoint >= _pursuit_path.size():
			_returning = false
		return
	_route_check_left -= delta
	if _route_check_left <= 0.0:
		_route_check_left = 0.5
		_check_leash()
	if _can_attack():
		_begin_attack()
		return
	_follow_route(delta)

func _target_distance() -> float:
	var target: Vector3 = _player.call("get_combat_target", global_position)
	return _flat(target - global_position).length()

func _update_engagement() -> void:
	var distance: float = _target_distance()
	if not _engaged and distance <= _pursuit.aggro_radius:
		_engaged = true
		_returning = false
		_repath_left = 0.0
	elif _engaged and distance > _pursuit.aggro_radius + AGGRO_HYSTERESIS:
		_engaged = false
		_start_route()
		if not _route.is_empty():
			_return_target = _route[_waypoint]
			_pursuit_path = _pursuit.path_to(global_position, _return_target, Callable(), _clear_approach)
			_pursuit_waypoint = 0
			_repath_left = 1.0
			_returning = true

func _process_pursuit(delta: float) -> void:
	var target: Vector3 = _player.call("get_combat_target", global_position)
	if _flat(target - global_position).length() <= attack_range and _has_line_of_sight(target):
		if _cooldown_left <= 0.0:
			_begin_attack()
		else:
			_face(target - global_position, delta, turn_rate)
			_drive(Vector3.ZERO, delta)
		return
	if _clear_approach(target):
		_steer_pursuit(_flat(target - global_position), delta)
		return
	_repath_left -= delta
	if _repath_left <= 0.0:
		_repath_left = 1.0
		_pursuit_path = _pursuit.path_to(global_position, target, _road_line_of_sight, _clear_approach)
		_pursuit_waypoint = 0
	_follow_pursuit_path(delta)

func _follow_pursuit_path(delta: float) -> void:
	while _pursuit_waypoint < _pursuit_path.size() and _flat(_pursuit_path[_pursuit_waypoint] - global_position).length() <= 2.0:
		_pursuit_waypoint += 1
	if _pursuit_waypoint >= _pursuit_path.size():
		_drive(Vector3.ZERO, delta)
		return
	var offset: Vector3 = _flat(_pursuit_path[_pursuit_waypoint] - global_position)
	_steer_pursuit(offset, delta)

func _steer_pursuit(offset: Vector3, delta: float) -> void:
	if offset.is_zero_approx():
		_drive(Vector3.ZERO, delta)
		return
	_face(offset, delta, turn_rate)
	var forward: Vector3 = _flat(-global_basis.z).normalized()
	var speed: float = movement_speed if forward.dot(offset.normalized()) > 0.95 else 0.0
	if speed > 0.0 and _forward_blocked(forward):
		speed = 0.0
	_drive(forward * speed, delta)

func _clear_approach(target: Vector3) -> bool:
	var destination: Vector3 = _ground_point(target)
	var offset: Vector3 = _flat(destination - global_position)
	if offset.is_zero_approx():
		return false
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(3.4, 1.6, 6.4)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, atan2(-offset.x, -offset.z)), global_position + Vector3.UP * 0.95)
	query.motion = destination - global_position
	query.collision_mask = OBSTACLE_MASK
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var fractions: PackedFloat32Array = space.cast_motion(query)
	return fractions[0] >= 1.0

func _can_attack() -> bool:
	if _cooldown_left > 0.0 or not is_instance_valid(_player):
		return false
	var target: Vector3 = _player.call("get_combat_target", global_position)
	if _flat(target - global_position).length() > attack_range:
		return false
	return _has_line_of_sight(target)

func _begin_attack() -> void:
	_aim_committed = false
	_committed_direction = Vector3.ZERO
	_aim = _ground_point(_player.global_position)
	_windup_left = maxf(0.05, windup)
	state = State.WINDUP
	velocity = Vector3.ZERO

func _follow_route(delta: float) -> void:
	if _route.size() < 2:
		_drive(Vector3.ZERO, delta)
		return
	var offset: Vector3 = _flat(_route[_waypoint] - global_position)
	var guard: int = 0
	while offset.length() <= waypoint_reach and guard < _route.size():
		_waypoint = (_waypoint + 1) % _route.size()
		offset = _flat(_route[_waypoint] - global_position)
		guard += 1
	if offset.is_zero_approx():
		_drive(Vector3.ZERO, delta)
		return
	_face(offset, delta, turn_rate)
	var forward: Vector3 = _flat(-global_transform.basis.z).normalized()
	var alignment: float = forward.dot(offset.normalized())
	var speed: float = movement_speed * clampf((alignment - 0.35) / 0.5, 0.0, 1.0)
	if speed > 0.0 and _forward_blocked(forward):
		speed = 0.0
	_drive(forward * speed, delta)

func _drive(horizontal: Vector3, delta: float) -> void:
	velocity.x = move_toward(velocity.x, horizontal.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, horizontal.z, acceleration * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	move_and_slide()

func _face(direction: Vector3, delta: float, rate: float) -> void:
	var flat: Vector3 = _flat(direction)
	if flat.is_zero_approx():
		return
	rotation.y = rotate_toward(rotation.y, atan2(-flat.x, -flat.z), rate * delta)

func _forward_blocked(forward: Vector3) -> bool:
	if test_move(global_transform, forward * obstacle_lookahead):
		return true
	for height: float in [0.9, 2.0]:
		var origin: Vector3 = global_position + Vector3.UP * height
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + forward * obstacle_lookahead, OBSTACLE_MASK, [get_rid()])
		query.collide_with_areas = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false

func _has_line_of_sight(target: Vector3) -> bool:
	return _line_of_sight(_muzzle_position(), target)

func _muzzle_position() -> Vector3:
	return global_position + Vector3.UP * MUZZLE_HEIGHT - global_transform.basis.z * MUZZLE_FORWARD

func _road_line_of_sight(position: Vector3, target: Vector3) -> bool:
	return _line_of_sight(position + Vector3.UP * MUZZLE_HEIGHT, target)

func _line_of_sight(origin: Vector3, target: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target, OBSTACLE_MASK, [get_rid()])
	query.collide_with_areas = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _check_leash() -> void:
	var count: int = _route.size()
	if count < 2:
		return
	var nearest_segment: int = 0
	var nearest_distance: float = INF
	for index: int in count:
		var start: Vector3 = _route[index]
		var segment: Vector3 = _flat(_route[(index + 1) % count] - start)
		var offset: Vector3 = _flat(global_position - start)
		var length_squared: float = segment.length_squared()
		var t: float = clampf(offset.dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0001 else 0.0
		var distance: float = _flat(global_position - (start + segment * t)).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_segment = index
	if nearest_distance > home_leash:
		_waypoint = (nearest_segment + 1) % count

func _resolve_attack() -> void:
	state = State.PATROL
	_windup_left = 0.0
	_cooldown_left = cooldown
	var origin: Vector3 = _muzzle_position()
	var direction: Vector3 = _committed_direction
	_aim_committed = false
	_committed_direction = Vector3.ZERO
	var shell: Node3D = SHELL.instantiate() as Node3D
	get_parent().add_child(shell)
	shell.configure(_player, origin, direction, damage, impact_radius, self)
	_shells = _shells.filter(func(existing: Node3D) -> bool: return is_instance_valid(existing))
	_shells.append(shell)
	_fire_voice.global_position = origin
	_fire_voice.stream = CANNON_SOUNDS.pick_random()
	_fire_voice.pitch_scale = randf_range(0.92, 1.0)
	_fire_voice.play()

func _start_route() -> void:
	_route_started = true
	var count: int = _route.size()
	if count < 2:
		_waypoint = 0
		return
	var nearest_segment: int = 0
	var nearest_distance: float = INF
	for index: int in count:
		var start: Vector3 = _route[index]
		var segment: Vector3 = _flat(_route[(index + 1) % count] - start)
		var offset: Vector3 = _flat(global_position - start)
		var length_squared: float = segment.length_squared()
		var t: float = clampf(offset.dot(segment) / length_squared, 0.0, 1.0) if length_squared > 0.0001 else 0.0
		var distance: float = _flat(global_position - (start + segment * t)).length()
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_segment = index
	_waypoint = (nearest_segment + 1) % count

func _ground_point(point: Vector3) -> Vector3:
	if _region != null:
		if _region.has_method("ground_position"):
			var result: Variant = _region.call("ground_position", point)
			if result is Vector3 and (result as Vector3).is_finite():
				return result
		if _region.has_method("ground_height"):
			var height: float = float(_region.call("ground_height", point.x, point.z))
			if is_finite(height):
				return Vector3(point.x, height, point.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 8.0, point - Vector3.UP * 30.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3) if not hit.is_empty() else point

func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)

func _on_collapsed() -> void:
	if _depleted:
		return
	_depleted = true
	stop()
	collision_layer = 0
	collision_mask = 0
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)
	_create_wreck.call_deferred()

func _create_wreck() -> void:
	var parent: Node = _region if is_instance_valid(_region) and _region.is_inside_tree() else get_parent()
	if parent != null:
		var effect: Node3D = DEPLETION_EFFECT.instantiate() as Node3D
		effect.process_mode = Node.PROCESS_MODE_PAUSABLE
		parent.add_child(effect)
		effect.global_transform = Transform3D(Basis.IDENTITY, global_position)
		effect.style = DEPLETION_SCRIPT.Style.RUBBLE
		effect.configure_reward(drainable.take_collapse_life(), drainable.collector, drainable.healing_per_life)
		_visual.reparent(effect, true)
		effect.configure(_visual, TankAssets.size_for(_heavy), _ground_position)
		effect.start()
	queue_free()

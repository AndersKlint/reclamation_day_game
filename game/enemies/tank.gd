extends CharacterBody3D

const TankAssets = preload("res://game/enemies/tank_assets.gd")
const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const DEPLETION_SCRIPT = preload("res://game/draining/depletion_effect.gd")
const CANNON_SOUNDS: Array[AudioStream] = [
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_01.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_02.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_03.wav"),
	preload("res://available-assets/sfx/prosoundcollection/Gamemaster Audio - Pro Sound Collection v1.3 - 16bit 48k/Guns_Weapons/Guns/gun_tank_cannon_turret_shot_04.wav"),
]
const WARN_COLOR: Color = Color("ffc24b")
const WARN_HOT_COLOR: Color = Color("ff5948")
const WARN_ALPHA: float = 0.5
const MUZZLE_HEIGHT: float = 1.9
const MUZZLE_FORWARD: float = 2.6
const IMPACT_DELAY: float = 0.22
const WORLD_LAYER: int = 1
const CAR_LAYER: int = 16
const OBSTACLE_MASK: int = WORLD_LAYER | CAR_LAYER

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
@export var life_capacity: float = 300.0
@export var required_size: float = 6.0

var state: State = State.PATROL
var _player: CharacterBody3D
var _region: Node3D
var _route: PackedVector3Array = PackedVector3Array()
var _heavy: bool = false
var _active: bool = false
var _depleted: bool = false
var _waypoint: int = 1
var _windup_left: float = 0.0
var _cooldown_left: float = 1.5
var _aim: Vector3
var _impact_left: float = 0.0
var _impact_pending: bool = false
var _route_check_left: float = 0.0
var _route_started: bool = false
var _warning_material: StandardMaterial3D
var _ground_position: Callable
@onready var drainable: Area3D = $Drainable
@onready var _visual: Node3D = $Visual
@onready var _warning: MeshInstance3D = $Warning
@onready var _fire_voice: AudioStreamPlayer3D = $CannonShot
@onready var _impact_voice: AudioStreamPlayer3D = $CannonImpact

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
	cancel_attack()
	velocity = Vector3.ZERO
	if is_instance_valid(_fire_voice):
		_fire_voice.stop()
	if is_instance_valid(_impact_voice):
		_impact_voice.stop()

func cancel_attack() -> void:
	state = State.PATROL
	_windup_left = 0.0
	_impact_pending = false
	_cooldown_left = maxf(_cooldown_left, 1.0)
	if is_instance_valid(_warning):
		_warning.visible = false

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
	life_capacity = 650.0
	required_size = 12.0

func _ready() -> void:
	drainable.capacity = life_capacity
	drainable.remaining_capacity = life_capacity
	drainable.required_size = required_size
	drainable.emission_offset = Vector3(0.0, 1.4, 0.0)
	drainable.emission_radius = 1.6
	drainable.depleted.connect(_on_depleted)
	var drain_shape: SphereShape3D = SphereShape3D.new()
	drain_shape.radius = 2.4
	($Drainable/CollisionShape3D as CollisionShape3D).shape = drain_shape
	_ground_position = Callable(_region, "ground_position") if _region != null and _region.has_method("ground_position") else Callable()
	_warning_material = StandardMaterial3D.new()
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_material.albedo_color = Color(WARN_COLOR, WARN_ALPHA)
	_warning.material_override = _warning_material
	_warning.top_level = true
	_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warning.visible = false
	var disc: CylinderMesh = _warning.mesh.duplicate() as CylinderMesh
	disc.top_radius = impact_radius
	disc.bottom_radius = impact_radius
	_warning.mesh = disc
	TankAssets.build(_visual, _heavy)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_attack()

func _physics_process(delta: float) -> void:
	if _depleted or not _active or is_queued_for_deletion():
		return
	if not is_instance_valid(_player) or float(_player.get("health")) <= 0.0:
		stop()
		return
	if not bool(_player.get("gameplay_enabled")):
		cancel_attack()
		return
	if not _route_started:
		_start_route()
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	_tick_impact(delta)
	if state == State.WINDUP:
		_process_windup(delta)
	else:
		_process_patrol(delta)

func _process_windup(delta: float) -> void:
	_windup_left = maxf(0.0, _windup_left - delta)
	var color: Color = WARN_HOT_COLOR if _windup_left < windup * 0.35 else WARN_COLOR
	_warning_material.albedo_color = Color(color, WARN_ALPHA)
	_face(_aim - global_position, delta, turn_rate * 3.0)
	_drive(Vector3.ZERO, delta)
	if _windup_left <= 0.0:
		_resolve_attack()

func _process_patrol(delta: float) -> void:
	_route_check_left -= delta
	if _route_check_left <= 0.0:
		_route_check_left = 0.5
		_check_leash()
	if _can_attack():
		_begin_attack()
		return
	_follow_route(delta)

func _can_attack() -> bool:
	if _cooldown_left > 0.0 or not is_instance_valid(_player):
		return false
	var target: Vector3 = _player.call("get_combat_target", global_position)
	if _flat(target - global_position).length() > attack_range:
		return false
	return _has_line_of_sight(target)

func _begin_attack() -> void:
	var target: Vector3 = _player.call("get_combat_target", global_position)
	_aim = _ground_point(target)
	_warning.global_position = _aim + Vector3.UP * 0.06
	_warning.visible = true
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
	for height: float in [0.9, 2.0]:
		var origin: Vector3 = global_position + Vector3.UP * height
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + forward * obstacle_lookahead, OBSTACLE_MASK, [get_rid()])
		query.collide_with_areas = true
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false

func _has_line_of_sight(target: Vector3) -> bool:
	var origin: Vector3 = global_position + Vector3.UP * MUZZLE_HEIGHT - global_transform.basis.z * MUZZLE_FORWARD
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
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
	_warning.visible = false
	_fire_voice.global_position = global_position + Vector3.UP * MUZZLE_HEIGHT
	_fire_voice.stream = CANNON_SOUNDS.pick_random()
	_fire_voice.pitch_scale = randf_range(0.92, 1.0)
	_fire_voice.play()
	_impact_left = IMPACT_DELAY
	_impact_pending = true
	if _player_hit():
		_player.call("take_damage", damage)

func _player_hit() -> bool:
	if not is_instance_valid(_player) or not bool(_player.get("gameplay_enabled")) or float(_player.get("health")) <= 0.0:
		return false
	var impact_target: Vector3 = _player.call("get_combat_target", _aim)
	if _flat(impact_target - _aim).length() > impact_radius:
		return false
	var range_target: Vector3 = _player.call("get_combat_target", global_position)
	if _flat(range_target - global_position).length() > attack_range:
		return false
	return _has_line_of_sight(impact_target)

func _tick_impact(delta: float) -> void:
	if not _impact_pending:
		return
	_impact_left -= delta
	if _impact_left > 0.0:
		return
	_impact_pending = false
	_impact_voice.global_position = _aim
	_impact_voice.stream = CANNON_SOUNDS.pick_random()
	_impact_voice.pitch_scale = randf_range(0.68, 0.8)
	_impact_voice.play()

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

func _on_depleted() -> void:
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
		_visual.reparent(effect, true)
		effect.configure(_visual, TankAssets.size_for(_heavy), _ground_position)
		effect.start()
	queue_free()

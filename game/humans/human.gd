extends CharacterBody3D

const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const DEPLETION_SCRIPT = preload("res://game/draining/depletion_effect.gd")
const Drainable = preload("res://game/draining/drainable.gd")
const BODY_SIZE: Vector3 = Vector3(0.7, 1.8, 0.7)

@export var ranged: bool = false
@export var movement_speed: float = 3.7
@export var attack_range: float = 2.3
@export var damage: float = 9.0
@export var windup: float = 0.85
@export var cooldown: float = 2.4
@export var impact_radius: float = 1.8
@export var life_capacity: float = 16.0
@export var required_size: float = 1.0
@export var steering_lookahead: float = 1.8

var _balancer: CharacterBody3D
var _active: bool = false
var _windup_left: float = 0.0
var _cooldown_left: float = 1.0
var _aim: Vector3
var _attack_impact_radius: float = 1.8
var _steering_side: float = 1.0
var _avoidance_left: float = 0.0
var _avoidance_direction: Vector3 = Vector3.ZERO
var home_zone: StringName = &"field"
var home_position: Vector3
var home_leash: float = 65.0
var _region: Node3D
var _target_left: float = 0.0
var _returning: bool = false
var _warning_material: StandardMaterial3D
var _remains_parent: Node3D
var _ground_position: Callable
@onready var drainable: Area3D = $Drainable
@onready var _warning: MeshInstance3D = $Warning
@onready var _navigation: NavigationAgent3D = $NavigationAgent3D
@onready var _visual: Node3D = $Visual

func configure_region(region: Node3D, zone: StringName, home: Vector3) -> void:
	_region = region
	home_zone = zone
	home_position = home

func configure(balancer: CharacterBody3D) -> void:
	_balancer = balancer
	_active = true

func configure_remains(remains_parent: Node3D, ground_position: Callable) -> void:
	_remains_parent = remains_parent
	_ground_position = ground_position

func _ready() -> void:
	drainable.capacity = life_capacity
	drainable.remaining_capacity = life_capacity
	drainable.required_size = Drainable.gate_to_size(required_size)
	drainable.emission_offset = Vector3(0.0, 1.0, 0.0)
	drainable.emission_radius = 0.4
	drainable.depleted.connect(_on_depleted)
	_visual.configure(ranged)
	_warning_material = StandardMaterial3D.new()
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.albedo_color = Color("ffc24b")
	_warning.material_override = _warning_material
	_warning.top_level = true
	_warning.visible = false
	var disc: CylinderMesh = _warning.mesh.duplicate() as CylinderMesh
	disc.top_radius = impact_radius
	disc.bottom_radius = impact_radius
	_warning.mesh = disc
	_steering_side = -1.0 if get_instance_id() % 2 == 0 else 1.0

func stop() -> void:
	_active = false
	cancel_attack()

func cancel_attack() -> void:
	_windup_left = 0.0
	_cooldown_left = maxf(_cooldown_left, 0.8)
	velocity = Vector3.ZERO
	if is_instance_valid(_warning):
		_warning.visible = false

func _physics_process(delta: float) -> void:
	if not _active or is_queued_for_deletion():
		return
	if not is_instance_valid(_balancer) or float(_balancer.get("health")) <= 0.0:
		stop()
		return
	if not bool(_balancer.get("gameplay_enabled")):
		cancel_attack()
		return
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	var target: Vector3 = _combat_target(global_position + Vector3.UP * 1.3)
	var offset: Vector3 = target - global_position
	offset.y = 0.0
	if _region != null and (_combat_distance_to_home() > home_leash or global_position.distance_to(home_position) > home_leash):
		if not _returning:
			_target_left = 0.0
		_returning = true
		cancel_attack()
	if _windup_left > 0.0:
		if not _target_available():
			cancel_attack()
			return
		_windup_left = maxf(0.0, _windup_left - delta)
		_warning_material.albedo_color = Color("ff5948") if _windup_left < windup * 0.4 else Color("ffc24b")
		_move(Vector3.ZERO, delta)
		if _windup_left <= 0.0:
			_resolve_attack()
		return
	var distance: float = offset.length()
	if _region != null:
		if _returning:
			_windup_left = 0.0
			_warning.visible = false
			if global_position.distance_to(home_position) < 2.0:
				stop()
				queue_free()
				return
			_move(_navigate(home_position, delta) * movement_speed, delta)
			return
	if distance <= _effective_attack_range() and _cooldown_left <= 0.0 and _target_available() and _has_line_of_sight(target):
		var aim_point: Vector3 = _combat_target(global_position)
		_aim = Vector3(aim_point.x, _ground_height(aim_point) + 0.06, aim_point.z)
		_attack_impact_radius = impact_radius + _melee_growth_reach()
		var disc: CylinderMesh = _warning.mesh as CylinderMesh
		disc.top_radius = _attack_impact_radius
		disc.bottom_radius = _attack_impact_radius
		_warning.global_position = _aim
		_warning.visible = true
		_windup_left = maxf(0.05, windup)
		_move(Vector3.ZERO, delta)
		return
	var direction: Vector3 = offset.normalized()
	if ranged and _has_line_of_sight(target):
		if distance < attack_range * 0.45:
			direction = -direction
		elif distance < attack_range * 0.8:
			direction = Vector3.ZERO
	if _region != null and not direction.is_zero_approx():
		var destination: Vector3 = _balancer.global_position
		if ranged and direction.dot(offset) < 0.0:
			destination = global_position + direction * 9.0
			destination.y = _ground_height(destination)
		direction = _navigate(destination, delta)
	else:
		direction = _steer(direction, delta)
	_move(direction * movement_speed, delta)

func _navigate(destination: Vector3, delta: float) -> Vector3:
	var map: RID = _navigation.get_navigation_map()
	if not bool(_region.get("navigation_ready")) or NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.ZERO
	_target_left -= delta
	if _target_left <= 0.0:
		_navigation.target_position = destination
		_target_left = 0.35
	var next: Vector3 = _navigation.get_next_path_position()
	if _navigation.is_navigation_finished():
		return Vector3.ZERO
	var direction: Vector3 = next - global_position
	direction.y = 0.0
	return direction.normalized()

func _ground_height(point: Vector3) -> float:
	if _region != null:
		return float(_region.call("ground_height", point.x, point.z))
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5.0, point - Vector3.UP * 20.0, 1)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else point.y

func _move(horizontal: Vector3, delta: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	var facing: Vector3 = _balancer.global_position - global_position if _windup_left > 0.0 else horizontal
	facing.y = 0.0
	if not facing.is_zero_approx():
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 10.0))
	_visual.update_pose(horizontal, _windup_left > 0.0, delta)

func _steer(direction: Vector3, delta: float) -> Vector3:
	if direction.is_zero_approx():
		return direction
	_avoidance_left = maxf(0.0, _avoidance_left - delta)
	if _avoidance_left > 0.0 and not test_move(global_transform, _avoidance_direction * steering_lookahead):
		return _avoidance_direction
	if not test_move(global_transform, direction * steering_lookahead):
		return direction
	for angle: float in [45.0, 90.0, 135.0, -45.0, -90.0, -135.0, 180.0]:
		var candidate: Vector3 = direction.rotated(Vector3.UP, deg_to_rad(angle * _steering_side))
		if not test_move(global_transform, candidate * steering_lookahead):
			_avoidance_direction = candidate
			_avoidance_left = 1.3
			return candidate
	return Vector3.ZERO

func _has_line_of_sight(target: Vector3) -> bool:
	var origin: Vector3 = global_position + Vector3.UP * 1.3
	var destination: Vector3 = target + Vector3.UP * 0.25
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, destination, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _combat_target(from_position: Vector3) -> Vector3:
	if is_instance_valid(_balancer) and _balancer.has_method(&"get_combat_target"):
		return _balancer.call(&"get_combat_target", from_position) as Vector3
	return _balancer.global_position if is_instance_valid(_balancer) else from_position

func _target_available() -> bool:
	return is_instance_valid(_balancer) and _balancer.is_inside_tree() and _balancer.is_visible_in_tree()

func _melee_growth_reach() -> float:
	return 0.0

func _combat_distance_to_home() -> float:
	var target: Vector3 = _combat_target(home_position)
	var offset: Vector3 = home_position - target
	offset.y = 0.0
	return offset.length()

func _effective_attack_range() -> float:
	return attack_range + _melee_growth_reach()

func _resolve_attack() -> void:
	_warning.visible = false
	_cooldown_left = cooldown
	if not _active or not _target_available():
		return
	if not bool(_balancer.get("gameplay_enabled")) or float(_balancer.get("health")) <= 0.0:
		return
	var footprint: Vector3 = _combat_target(_aim)
	var offset: Vector3 = footprint - _aim
	offset.y = 0.0
	var reach_target: Vector3 = _combat_target(global_position + Vector3.UP * 1.3)
	var reach: Vector3 = reach_target - global_position
	reach.y = 0.0
	if offset.length() <= _attack_impact_radius and reach.length() <= _effective_attack_range() and _has_line_of_sight(reach_target):
		_balancer.call("take_damage", damage)

func _on_depleted() -> void:
	stop()
	collision_layer = 0
	collision_mask = 0
	for node: Node in _visual.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()
	_create_remains.call_deferred()

func _create_remains() -> void:
	if is_instance_valid(_remains_parent) and _remains_parent.is_inside_tree():
		var effect: Node3D = DEPLETION_EFFECT.instantiate() as Node3D
		effect.process_mode = Node.PROCESS_MODE_PAUSABLE
		_remains_parent.add_child(effect)
		effect.global_transform = Transform3D(Basis.IDENTITY, global_position)
		effect.style = DEPLETION_SCRIPT.Style.HUMANOID
		effect.female_voice = _visual.female_voice
		_visual.reparent(effect, true)
		effect.configure(_visual, BODY_SIZE, _ground_position)
		effect.start()
	queue_free()

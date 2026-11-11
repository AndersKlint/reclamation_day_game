extends CharacterBody3D

signal defeated()
signal consumed()
signal endurance_changed(fraction: float)

const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const DEPLETION_SCRIPT = preload("res://game/draining/depletion_effect.gd")
const FarmerDrainable = preload("res://game/demo/farmer_combat/farmer_drainable.gd")
const FarmerVisual = preload("res://game/demo/farmer_combat/farmer_visual.gd")
const FarmerAudio = preload("res://game/demo/farmer_combat/farmer_audio.gd")

enum State { IDLE, PURSUE, WINDUP, SWING, RECOVERY, RETURN, DEFEATED }
enum AttackType { OVERHEAD, HORIZONTAL }

@export var move_speed: float = 3.0
@export var required_player_volume: float = 0.0
@export var attack_range: float = 2.0
@export_range(0.0, 180.0, 1.0) var attack_arc_degrees: float = 110.0
@export var damage: float = 20.0
@export var windup_seconds: float = 0.8
@export_range(0.0, 1.0, 0.01) var windup_tracking_fraction: float = 0.5
@export var swing_seconds: float = 0.2
@export var recovery_seconds: float = 0.9
@export_range(0.0, 1.0, 0.01) var hit_phase: float = 0.45
@export var horizontal_windup_seconds: float = 1.1
@export var horizontal_swing_seconds: float = 0.55
@export var horizontal_recovery_seconds: float = 1.05
@export_range(180.0, 220.0, 1.0) var horizontal_arc_degrees: float = 200.0

var player: CharacterBody3D
var state: State = State.PURSUE

var _active: bool = false
var _defeated: bool = false
var _state_left: float = 0.0
var _state_duration: float = 0.0
var _swing_direction: Vector3 = Vector3.FORWARD
var _windup_elapsed: float = 0.0
var _facing_committed: bool = false
var _hit_applied: bool = false
var _attack_type: AttackType = AttackType.OVERHEAD
var _next_attack_type: AttackType = AttackType.OVERHEAD
var _sweep_progress: float = 0.0
var _remains_parent: Node3D
var _remains_created: bool = false
var _consumed: bool = false
var _reward_total: float = 0.0
var _absorbed_total: float = 0.0
var _effect: Node3D
var _region: Node3D
var _home_position: Vector3
var _home_leash: float = 65.0
var _returning: bool = false
var _navigation: NavigationAgent3D
var _target_left: float = 0.0
var _field: Node3D
var _field_footprint: Rect2
var _detection_radius: float = 0.0

var endurance: float:
	get:
		return drainable.drain_fraction() if is_instance_valid(drainable) else 0.0

@onready var drainable: FarmerDrainable = $Drainable
@onready var _visual: FarmerVisual = $Visual
@onready var _audio: FarmerAudio = $Audio


func _ready() -> void:
	if not _visual.configure():
		push_error("Farmer visual failed to configure")
	var scale_vector: Vector3 = global_basis.get_scale().abs()
	drainable.required_player_volume = required_player_volume
	drainable.configure_volume(_visual.body_dimensions * scale_vector)
	drainable.emission_offset = Vector3(0.0, 1.1, 0.0)
	drainable.emission_radius = 0.4
	drainable.collapsed.connect(_on_collapsed)
	drainable.drained.connect(_on_drained)


func get_model_height() -> float:
	return _visual.body_dimensions.y * global_basis.get_scale().abs().y


func set_minimum_player_volume(minimum: float) -> void:
	if not is_finite(minimum) or minimum <= 0.0:
		return
	required_player_volume = minimum
	drainable.required_player_volume = minimum


func configure(target_player: CharacterBody3D, remains_parent: Node3D) -> void:
	if _defeated or is_queued_for_deletion():
		return
	player = target_player
	_remains_parent = remains_parent
	_active = true
	state = State.IDLE if _field != null else State.PURSUE
	_state_left = 0.0
	_hit_applied = false
	_next_attack_type = AttackType.OVERHEAD
	_warn_if_source_too_small()
	endurance_changed.emit(endurance)


func configure_region(region: Node3D, home: Vector3, leash: float) -> void:
	_region = region
	_home_position = home
	_home_leash = leash
	_returning = false
	_target_left = 0.0
	if _navigation == null:
		_navigation = NavigationAgent3D.new()
		_navigation.name = "NavigationAgent3D"
		_navigation.path_desired_distance = 0.7
		_navigation.target_desired_distance = 0.7
		_navigation.path_max_distance = 4.0
		_navigation.radius = 0.35
		add_child(_navigation)


func configure_field(field: Node3D, footprint: Rect2, detection_radius: float) -> void:
	if _defeated or is_queued_for_deletion():
		return
	_field = field
	_field_footprint = footprint.abs()
	_detection_radius = maxf(detection_radius, 0.0) if is_finite(detection_radius) else 0.0
	if _active and state != State.IDLE and state != State.RETURN:
		cancel_attack()
		state = State.IDLE


func stop() -> void:
	_active = false
	cancel_attack()
	if is_instance_valid(_visual):
		_visual.update_pose(0.0, 0.0, 0.0, 0.0)


func _physics_process(delta: float) -> void:
	if _defeated or not _active or is_queued_for_deletion():
		return
	if not _player_available():
		stop()
		return
	if not _player_gameplay_enabled():
		cancel_attack()
		_visual.update_pose(0.0, 0.0, 0.0, 0.0)
		return
	if _region != null:
		if not bool(_region.get("navigation_ready")):
			return
		if _field != null:
			_tick_field(delta)
			if state == State.IDLE or state == State.RETURN:
				return
		else:
			if _flat(_combat_target(_home_position) - _home_position).length() > _home_leash or global_position.distance_to(_home_position) > _home_leash:
				if not _returning:
					_target_left = 0.0
				_returning = true
			if _returning:
				cancel_attack()
				if global_position.distance_to(_home_position) < 2.0:
					stop()
					queue_free()
					return
				var direction: Vector3 = _navigate(_home_position, delta)
				_face(direction, delta)
				_move(direction * move_speed, delta)
				_visual.update_pose(0.0 if direction.is_zero_approx() else 1.0, 0.0, 0.0, delta)
				return
	match state:
		State.PURSUE:
			_tick_pursue(delta)
		State.WINDUP:
			_tick_windup(delta)
		State.SWING:
			_tick_swing(delta)
		State.RECOVERY:
			_tick_recovery(delta)


func _tick_pursue(delta: float) -> void:
	var target: Vector3 = _combat_target(global_position)
	var offset: Vector3 = _flat(target - global_position)
	var distance: float = offset.length()
	if distance <= attack_range and _has_line_of_sight(target):
		_begin_windup()
		return
	if distance > attack_range * 0.92 and not offset.is_zero_approx():
		var direction: Vector3 = _navigate(target, delta) if _region != null else offset.normalized()
		_face(direction, delta)
		_move(direction * move_speed, delta)
		_visual.update_pose(1.0, 0.0, 0.0, delta)
		return
	_move(Vector3.ZERO, delta)
	_visual.update_pose(0.0, 0.0, 0.0, delta)


func _tick_field(delta: float) -> void:
	var in_field: bool = _player_in_field()
	if in_field:
		if (state == State.IDLE or state == State.RETURN) and _player_within_detection():
			state = State.PURSUE
			_target_left = 0.0
		if state != State.IDLE and state != State.RETURN:
			return
		_tick_return_home(delta)
		return
	if state != State.IDLE and state != State.RETURN:
		cancel_attack()
	_tick_return_home(delta)


func _tick_return_home(delta: float) -> void:
	if global_position.distance_to(_home_position) < 1.0:
		state = State.IDLE
		_move(Vector3.ZERO, delta)
		_visual.update_pose(0.0, 0.0, 0.0, delta)
		return
	if state != State.RETURN:
		_target_left = 0.0
	state = State.RETURN
	var direction: Vector3 = _navigate(_home_position, delta)
	_face(direction, delta)
	_move(direction * move_speed, delta)
	_visual.update_pose(0.0 if direction.is_zero_approx() else 1.0, 0.0, 0.0, delta)


func _player_in_field() -> bool:
	if _field == null:
		return true
	if not is_instance_valid(_field) or not _player_available():
		return false
	var local: Vector3 = _field.to_local(player.global_position)
	return _field_footprint.has_point(Vector2(local.x, local.z))


func _player_within_detection() -> bool:
	if not _player_available():
		return false
	var target: Vector3 = _combat_target(global_position)
	return _flat(target - global_position).length() <= _detection_radius


func _navigate(destination: Vector3, delta: float) -> Vector3:
	var map: RID = _navigation.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return Vector3.ZERO
	_target_left -= delta
	if _target_left <= 0.0:
		if _has_field():
			destination = _field.to_global(_clamp_footprint(_field.to_local(destination)))
		destination.y = float(_region.call("ground_height", destination.x, destination.z))
		_navigation.target_position = destination
		_target_left = 0.35
	var next: Vector3 = _navigation.get_next_path_position()
	if _has_field():
		next = _field.to_global(_clamp_footprint(_field.to_local(next)))
	if _navigation.is_navigation_finished():
		return Vector3.ZERO
	return _flat(next - global_position).normalized()


func _tick_windup(delta: float) -> void:
	var tracking_duration: float = _state_duration * windup_tracking_fraction
	var tracked_delta: float = clampf(tracking_duration - _windup_elapsed, 0.0, delta)
	if tracked_delta > 0.0:
		_face(_flat(_combat_target(global_position) - global_position), tracked_delta)
	if not _facing_committed and _windup_elapsed + delta >= tracking_duration:
		_commit_facing()
	_windup_elapsed = minf(_windup_elapsed + delta, _state_duration)
	_state_left = maxf(0.0, _state_left - delta)
	var progress: float = 1.0 - _state_left / _state_duration
	_move(Vector3.ZERO, delta)
	if _attack_type == AttackType.HORIZONTAL:
		_visual.update_horizontal_pose(smoothstep(0.0, 1.0, progress), 0.0, 0.0, deg_to_rad(horizontal_arc_degrees), delta)
	else:
		_visual.update_pose(0.0, smoothstep(0.0, 1.0, progress), 0.0, delta)
	if _state_left <= 0.0:
		_begin_swing()


func _tick_swing(delta: float) -> void:
	_state_left = maxf(0.0, _state_left - delta)
	var progress: float = 1.0 - _state_left / _state_duration
	if not _hit_applied:
		if _attack_type == AttackType.HORIZONTAL:
			_apply_horizontal_hit(_sweep_progress, progress)
		elif progress >= hit_phase:
			_apply_hit()
	if not _active or _defeated:
		return
	_sweep_progress = progress
	_move(Vector3.ZERO, delta)
	if _attack_type == AttackType.HORIZONTAL:
		_visual.update_horizontal_pose(1.0, progress, 0.0, deg_to_rad(horizontal_arc_degrees), delta)
	else:
		_visual.update_pose(0.0, 1.0 - progress, progress, delta)
	if _state_left <= 0.0:
		_begin_recovery()


func _tick_recovery(delta: float) -> void:
	_state_left = maxf(0.0, _state_left - delta)
	var progress: float = smoothstep(0.0, 1.0, 1.0 - _state_left / _state_duration)
	_move(Vector3.ZERO, delta)
	if _attack_type == AttackType.HORIZONTAL:
		_visual.update_horizontal_pose(1.0, 1.0, progress, deg_to_rad(horizontal_arc_degrees), delta)
	else:
		_visual.update_pose(0.0, 0.0, 1.0 - progress, delta)
	if _state_left <= 0.0:
		state = State.PURSUE


func _begin_windup() -> void:
	_attack_type = _next_attack_type
	_next_attack_type = AttackType.HORIZONTAL if _attack_type == AttackType.OVERHEAD else AttackType.OVERHEAD
	state = State.WINDUP
	_state_duration = maxf(horizontal_windup_seconds if _attack_type == AttackType.HORIZONTAL else windup_seconds, 0.05)
	_state_left = _state_duration
	_windup_elapsed = 0.0
	_facing_committed = false
	if windup_tracking_fraction <= 0.0:
		_commit_facing()
	_hit_applied = false
	velocity = Vector3.ZERO


func _begin_swing() -> void:
	if not _facing_committed:
		_commit_facing()
	state = State.SWING
	_state_duration = maxf(horizontal_swing_seconds if _attack_type == AttackType.HORIZONTAL else swing_seconds, 0.01)
	_state_left = _state_duration
	_hit_applied = false
	_sweep_progress = 0.0
	velocity = Vector3.ZERO
	_audio.play_swing()


func _commit_facing() -> void:
	_swing_direction = _flat(-_visual.global_basis.z).normalized()
	_facing_committed = true


func _begin_recovery() -> void:
	state = State.RECOVERY
	_state_duration = maxf(horizontal_recovery_seconds if _attack_type == AttackType.HORIZONTAL else recovery_seconds, 0.05)
	_state_left = _state_duration
	velocity = Vector3.ZERO


func _apply_hit() -> void:
	_hit_applied = true
	if _defeated or not _active or not _player_available() or not _player_gameplay_enabled() or not _player_in_field():
		return
	var target: Vector3 = _combat_target(global_position)
	var offset: Vector3 = _flat(target - global_position)
	var distance: float = offset.length()
	if distance > attack_range:
		return
	if distance > 0.001:
		var minimum_dot: float = cos(deg_to_rad(attack_arc_degrees * 0.5))
		if _swing_direction.dot(offset / distance) < minimum_dot:
			return
	if not _has_line_of_sight(target):
		return
	player.call(&"take_damage", damage)


func _apply_horizontal_hit(previous_progress: float, progress: float) -> void:
	if _defeated or not _active or not _player_available() or not _player_gameplay_enabled() or not _player_in_field():
		return
	var target: Vector3 = _combat_target(global_position)
	var offset: Vector3 = _flat(target - global_position)
	var distance: float = offset.length()
	if distance > attack_range or distance <= 0.001:
		return
	var arc: float = deg_to_rad(horizontal_arc_degrees)
	var angle: float = _swing_direction.signed_angle_to(offset / distance, Vector3.UP)
	var start_angle: float = lerpf(-arc * 0.5, arc * 0.5, previous_progress)
	var end_angle: float = lerpf(-arc * 0.5, arc * 0.5, progress)
	if angle < start_angle or angle > end_angle or not _has_line_of_sight(target):
		return
	# One contact attempt lets player invulnerability reject the strike without retrying every frame.
	_hit_applied = true
	player.call(&"take_damage", damage)


func _move(horizontal: Vector3, delta: float) -> void:
	if _field != null and not horizontal.is_zero_approx():
		horizontal = _clamp_field_velocity(horizontal, delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		velocity.y = 0.0
	move_and_slide()


func _face(direction: Vector3, delta: float) -> void:
	var flat: Vector3 = _flat(direction)
	if flat.is_zero_approx():
		return
	var local_direction: Vector3 = global_basis.inverse() * flat
	var desired: float = atan2(-local_direction.x, -local_direction.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, desired, 1.0 - exp(-10.0 * delta))


func cancel_attack() -> void:
	if _defeated:
		state = State.DEFEATED
	elif _field == null:
		state = State.PURSUE
	elif state != State.IDLE and state != State.RETURN:
		state = State.PURSUE
	_state_left = 0.0
	_windup_elapsed = 0.0
	_facing_committed = false
	_hit_applied = false
	velocity = Vector3.ZERO
	if is_instance_valid(_audio):
		_audio.stop_swing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		cancel_attack()


func _player_available() -> bool:
	return is_instance_valid(player) and player.is_inside_tree()


func _player_gameplay_enabled() -> bool:
	if not _player_available():
		return false
	var health: Variant = player.get("health")
	if health is float and float(health) <= 0.0:
		return false
	return bool(player.get("gameplay_enabled"))


func _combat_target(from_position: Vector3) -> Vector3:
	if _player_available() and player.has_method(&"get_combat_target"):
		return player.call(&"get_combat_target", from_position) as Vector3
	return player.global_position if _player_available() else from_position


func _has_line_of_sight(target: Vector3) -> bool:
	var origin: Vector3 = global_position + Vector3.UP * 1.4
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, target, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _warn_if_source_too_small() -> void:
	if not _player_available():
		return
	var source_volume: Variant = player.get("volume")
	var minimum: float = drainable.get_minimum_player_volume()
	if required_player_volume <= 0.0 and source_volume is float and float(source_volume) < minimum:
		push_warning("Farmer drain gate: starting player volume %.3f is below required %.3f" % [float(source_volume), minimum])


func _on_drained(_amount: float) -> void:
	endurance_changed.emit(endurance)


func _on_collapsed() -> void:
	if _defeated:
		return
	_defeated = true
	stop()
	_audio.play_death(get_parent())
	state = State.DEFEATED
	_visual.stop()
	collision_layer = 0
	collision_mask = 0
	for shape: Node in find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).set_deferred("disabled", true)
	defeated.emit()
	_create_remains.call_deferred()


func _create_remains() -> void:
	if _remains_created or is_queued_for_deletion():
		return
	_remains_created = true
	var reward: float = drainable.take_collapse_life()
	var collector: Node3D = drainable.collector
	var parent: Node = _remains_parent if is_instance_valid(_remains_parent) and _remains_parent.is_inside_tree() else get_parent()
	_reward_total = reward
	_absorbed_total = 0.0
	if parent == null or not is_instance_valid(collector) or not collector.is_inside_tree():
		push_warning("Farmer collapse lost its life recipient")
		queue_free()
		return
	_effect = DEPLETION_EFFECT.instantiate() as Node3D
	_effect.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(_effect)
	_effect.global_transform = Transform3D(Basis.IDENTITY, global_position)
	_effect.style = DEPLETION_SCRIPT.Style.HUMANOID
	_effect.female_voice = false
	_effect.configure_reward(reward, collector, drainable.healing_per_life)
	_visual.reparent(_effect, true)
	_effect.configure(_visual, _visual.body_dimensions, Callable())
	_effect.life_absorbed.connect(_on_life_absorbed)
	_effect.start()
	if reward <= 0.0:
		_finish_consumed.call_deferred()


func _on_life_absorbed(amount: float) -> void:
	if _consumed or not is_finite(amount) or amount <= 0.0:
		return
	_absorbed_total += amount
	if _absorbed_total >= _reward_total or is_equal_approx(_absorbed_total, _reward_total):
		_finish_consumed.call_deferred()


func _finish_consumed() -> void:
	if _consumed:
		return
	_consumed = true
	if is_instance_valid(_effect):
		if is_inside_tree():
			get_tree().create_timer(3.0).timeout.connect(_effect.queue_free)
		else:
			_effect.queue_free()
	consumed.emit()
	queue_free()


func _flat(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _clamp_field_velocity(horizontal: Vector3, delta: float) -> Vector3:
	if not _has_field():
		return horizontal
	var next_local: Vector3 = _field.to_local(global_position + horizontal * delta)
	if _field_footprint.has_point(Vector2(next_local.x, next_local.z)):
		return horizontal
	var corrected: Vector3 = _flat(_field.to_global(_clamp_footprint(next_local)) - global_position)
	if corrected.is_zero_approx() or delta <= 0.0:
		return Vector3.ZERO
	return corrected / delta


func _clamp_footprint(local_point: Vector3) -> Vector3:
	local_point.x = clampf(local_point.x, _field_footprint.position.x, _field_footprint.end.x)
	local_point.z = clampf(local_point.z, _field_footprint.position.y, _field_footprint.end.y)
	return local_point


func _has_field() -> bool:
	return _field != null and is_instance_valid(_field)

extends CharacterBody3D

signal growth_changed(life: float, size: float)
signal health_changed(current: float, maximum: float)
signal died()

const COMBAT_RADIUS_PER_SIZE: float = 0.45
const COMBAT_HEIGHT_PER_SIZE: float = 2.2
const PHYSICAL_SIZE_LIMIT: float = 3.0
const Scaling = preload("res://game/draining/drain_scaling.gd")
const WorldModel = preload("res://game/world/world_model.gd")
const PhaseController = preload("res://game/balancer/phase_controller.gd")
const ShockwaveController = preload("res://game/balancer/shockwave_controller.gd")
const MAX_UPGRADE_MULTIPLIER: float = 1_000_000.0
const MAX_ACCUMULATED_MULTIPLIER: float = 1_000_000.0
const MIN_REDUCTION_MULTIPLIER: float = 1.0e-12
const MAX_REDUCTION_MULTIPLIER: float = 1.0e100
const MAX_LIFE: float = 1_000_000_000_000_000_000_000_000_000_000.0
const BANK_PER_TURN_RATE: float = 0.03
const MAX_BANK: float = 0.035
const BANK_RESPONSE: float = 6.0
const MAX_HEALING_PER_SECOND: float = 2.0
const RETURN_CONTACT_TOLERANCE: float = 0.0001
const PHASE_SOLID_LAYER: int = 1 << 5
const PHASE_LANDING_STEP: float = 0.2
const PHASE_LANDING_SAMPLES: int = 64
const PHASE_LANDING_CONTACTS: int = 64
const PHASE_LANDING_REFINEMENT_STEPS: int = 8
const PHASE_LANDING_REFINEMENT_PASSES: int = 4

@export var base_movement_speed: float = 6.0
@export var acceleration: float = 24.0
@export_range(0.01, 1000.0, 0.01, "or_greater") var movement_reference_height: float = 2.31
@export var turning_speed: float = 6.0
@export var base_drain_reach: float = 2.8
@export_range(0.0, 1000.0, 0.001, "or_greater") var drain_rate_per_scale: float = 0.34
@export var max_health: float = 100.0
@export_range(0.1, 1000.0, 0.01) var initial_size: float = 1.0
@export var maximum_size: float = 1000.0
@export var phase_controller: PhaseController
var gameplay_enabled: bool = false
var shockwave_controller: ShockwaveController
var size: float = 1.0
var size_growth_multiplier: float = 1.0
var lock_visible_size: bool = false
var healing_disabled: bool = false
var pacifist: bool = false
var proximity_drain_bonus_percent: float = 0.0
var growth_bonus_retention: float = 1.0
var phase_size_multiplier: float = 1.0
var visible_size: float:
	get:
		return initial_size if lock_visible_size else size
var life: float = 0.0
var base_volume: float = 0.0
var volume: float:
	get:
		return base_volume * size * size * size
var health: float = 100.0
var movement_multiplier: float = 1.0
var reach_multiplier: float = 1.0
var rate_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var damage_taken_multiplier: float = 1.0
var phase_distance_multiplier: float = 1.0
var _volume_drain_active: bool = false
var _geometry_update_pending: bool = false
var _absorption_bounds: AABB
var _absorption_bounds_ready: bool = false
var _bank: float = 0.0
var _pending_healing: float = 0.0
var _phase_origin: Vector3 = Vector3.ZERO
var _phase_return_pending: bool = false
var _phase_through_objects: bool = false
var _phase_collision_active: bool = false
var _normal_collision_layer: int = 0
var _normal_collision_mask: int = 0
var _phase_path: Array[Vector3] = []
var projectile_reflection_chance: float = 0.0
var effective_movement_speed: float:
	get:
		var raw: float = base_movement_speed * _movement_scale() * movement_multiplier
		return maxf(raw, 0.0) if is_finite(raw) else 0.0
var effective_acceleration: float:
	get:
		var raw: float = acceleration * _movement_scale() * movement_multiplier
		return maxf(raw, 0.0) if is_finite(raw) else 0.0
var effective_drain_reach: float:
	get:
		var raw: float = base_drain_reach * _radius_size() * reach_multiplier
		return maxf(raw, 0.0) if is_finite(raw) else base_drain_reach
var effective_drain_rate: float:
	get:
		var base_rate: float = Scaling.drain_rate_for_volume(volume) if _volume_drain_active else drain_rate_per_scale * size
		var raw: float = base_rate * rate_multiplier
		return maxf(raw, 0.0) if is_finite(raw) else 0.0
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var drain_area: Area3D = $DrainArea
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var reaper: Node3D = $Visuals/Reaper
@onready var smoke: Node3D = $Visuals/ReaperSmoke
@onready var drain_vfx: Node3D = $DrainVfx
@onready var drain_audio: AudioStreamPlayer = $DrainAudio
@onready var collection_point: Marker3D = $CollectionPoint
@onready var camera_rig: Node3D = $CameraRig

func _ready() -> void:
	shockwave_controller = ShockwaveController.new()
	shockwave_controller.name = "ShockwaveController"
	shockwave_controller.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(shockwave_controller)
	body_shape.shape = body_shape.shape.duplicate()
	_normal_collision_layer = collision_layer
	_normal_collision_mask = collision_mask
	add_to_group(&"player")
	health = max_health
	base_volume = Scaling.volume($Visuals/Reaper.model_dimensions * global_basis.get_scale().abs())
	assert(base_volume > 0.0, "Player requires positive model volume")
	initial_size = clampf(initial_size, 0.1, 1000.0) if is_finite(initial_size) else 1.0
	size = _calculate_size()
	drain_area.collector = self
	drain_area.life_absorbed.connect(gain_life)
	drain_area.life_absorbed.connect(drain_audio.record_transfer)
	drain_vfx.configure(collection_point)
	# Presentation callbacks must run after the drain reward transaction completes.
	drain_area.transfer_effect_requested.connect(drain_vfx.record_transfer, CONNECT_DEFERRED)
	_refresh_growth()
	if phase_controller != null:
		phase_controller.bind(reaper)
		phase_controller.set_landing_resolver(_resolve_phase_landing)
	set_gameplay_enabled(false)

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_exit_phase_collision()
		_phase_return_pending = false
		_pending_healing = 0.0
		velocity = Vector3.ZERO
		_tick_phase(delta)
		return
	_consume_pending_healing(delta)
	if _phase_return_pending:
		_phase_return_pending = false
		if _try_phase_return():
			_tick_phase(delta)
			return
	if phase_controller != null and phase_controller.is_travelling():
		_enter_phase_collision()
		var phase_step: float = clampf(phase_controller.get_travel_remaining() / maxf(delta, 0.0001), 0.0, 1.0)
		var travel_velocity: Vector3 = phase_controller.get_travel_velocity() * phase_step
		velocity.x = travel_velocity.x
		velocity.z = travel_velocity.z
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		if _phase_through_objects:
			_phase_path.append(global_position)
		_tick_phase(delta)
		if not phase_controller.is_travelling():
			_exit_phase_collision()
			velocity.x = 0.0
			velocity.z = 0.0
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction: Vector3 = camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	var turn_rate: float = 0.0
	if not direction.is_zero_approx():
		var facing: float = atan2(-direction.x, -direction.z)
		var previous_facing: float = visuals.rotation.y
		visuals.rotation.y = lerp_angle(previous_facing, facing, 1.0 - exp(-turning_speed * delta))
		turn_rate = angle_difference(previous_facing, visuals.rotation.y) / maxf(delta, 0.0001)
	var target_bank: float = clampf(turn_rate * BANK_PER_TURN_RATE, -MAX_BANK, MAX_BANK)
	_bank = lerpf(_bank, target_bank, 1.0 - exp(-BANK_RESPONSE * delta))
	visuals.rotation.z = _bank
	velocity.x = move_toward(velocity.x, direction.x * effective_movement_speed, effective_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_movement_speed, effective_acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()
	_tick_phase(delta)

func _tick_phase(delta: float) -> void:
	if gameplay_enabled and phase_controller != null:
		phase_controller.tick(delta)

func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled and health > 0.0
	_phase_return_pending = false
	velocity = Vector3.ZERO
	_bank = 0.0
	_pending_healing = 0.0
	visuals.rotation.z = 0.0
	if not gameplay_enabled and phase_controller != null:
		if health <= 0.0:
			phase_controller.clear_void()
		if health <= 0.0 or phase_controller.is_travelling():
			phase_controller.cancel()
		_exit_phase_collision()
	camera_rig.set_gameplay_enabled(gameplay_enabled)
	drain_area.enabled = gameplay_enabled
	drain_vfx.set_enabled(gameplay_enabled)
	drain_audio.set_enabled(gameplay_enabled)

func enable_phase_return() -> void:
	if phase_controller != null:
		phase_controller.enable_phase_return()

func enable_phase_through_objects() -> void:
	_phase_through_objects = true

func enable_voidwalker(duration: float) -> void:
	if phase_controller != null:
		phase_controller.enable_voidwalker(duration)

func set_projectile_reflection_chance(chance: float) -> void:
	projectile_reflection_chance = clampf(chance, 0.0, 1.0) if is_finite(chance) else 0.0

func try_reflect_projectile() -> bool:
	if not gameplay_enabled or health <= 0.0 or projectile_reflection_chance <= 0.0:
		return false
	return randf() < projectile_reflection_chance

func activate_volume_drain() -> void:
	if _volume_drain_active:
		return
	_volume_drain_active = true
	_refresh_growth()

func gain_life(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0:
		return
	var current_life: float = life if is_finite(life) else 0.0
	life = minf(MAX_LIFE, current_life + amount)
	size = _calculate_size()
	_refresh_growth()
	growth_changed.emit(life, size)

func request_healing(amount: float) -> void:
	if healing_disabled or not gameplay_enabled or health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	var frame_cap: float = MAX_HEALING_PER_SECOND * maxf(get_physics_process_delta_time(), 0.0)
	_pending_healing = minf(_pending_healing + amount, frame_cap)

func heal_immediately(amount: float) -> void:
	if healing_disabled or not gameplay_enabled or health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	var healed: float = minf(amount, max_health - health)
	if healed <= 0.0:
		return
	health += healed
	health_changed.emit(health, max_health)

func set_healing_disabled(disabled: bool) -> void:
	healing_disabled = disabled
	if healing_disabled:
		_pending_healing = 0.0

func can_drain_target(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if not pacifist:
		return true
	return not bool(target.get(&"pacifist_protected"))

func can_reward_reflection(target: Node) -> bool:
	return can_drain_target(target)

func _consume_pending_healing(delta: float) -> void:
	var demand: float = _pending_healing
	_pending_healing = 0.0
	if demand <= 0.0 or healing_disabled or not gameplay_enabled or health <= 0.0:
		return
	var healed: float = minf(minf(demand, MAX_HEALING_PER_SECOND * maxf(delta, 0.0)), max_health - health)
	if healed <= 0.0:
		return
	health = minf(max_health, health + healed)
	health_changed.emit(health, max_health)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pending_healing = 0.0
		_phase_return_pending = false
		if _phase_collision_active:
			if phase_controller != null and phase_controller.is_travelling():
				phase_controller.cancel()
			_exit_phase_collision()

func _calculate_size() -> float:
	var safe_life: float = life if is_finite(life) else 0.0
	var maximum: float = maxf(initial_size, maximum_size) if is_finite(maximum_size) else initial_size
	var base_size: float = pow(pow(initial_size, 3.0) + Scaling.growth_for_life(maxf(0.0, safe_life)) / base_volume, 1.0 / 3.0)
	var multiplier: float = size_growth_multiplier if is_finite(size_growth_multiplier) and size_growth_multiplier > 0.0 else 1.0
	return clampf(multiplier * base_size, initial_size, maximum)

func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if phase_controller != null and InputMap.has_action(&"phase") and event.is_action_pressed(&"phase"):
		_try_phase()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"debug_increase_life_large", false, true):
		adjust_life(50000.0)
	elif event.is_action_pressed(&"debug_decrease_life_large", false, true):
		adjust_life(-50000.0)
	elif event.is_action_pressed(&"debug_increase_life", false, true):
		adjust_life(500.0)
	elif event.is_action_pressed(&"debug_decrease_life", false, true):
		adjust_life(-500.0)

func _try_phase() -> void:
	if phase_controller == null or not gameplay_enabled or health <= 0.0:
		return
	if phase_controller.get_state() == PhaseController.State.COOLDOWN:
		_phase_return_pending = phase_controller.is_return_available()
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction: Vector3 = camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	if direction.is_zero_approx():
		direction = -visuals.global_basis.z
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	var origin: Vector3 = global_position
	if not phase_controller.try_activate(direction):
		return
	_phase_origin = origin
	_phase_path.clear()
	if _phase_through_objects:
		_phase_path.append(origin)
	_bank = 0.0
	visuals.rotation.z = 0.0
	visuals.rotation.y = atan2(-direction.x, -direction.z)

func _try_phase_return() -> bool:
	if not gameplay_enabled or health <= 0.0 or phase_controller == null or not phase_controller.is_return_available():
		return false
	if body_shape.disabled or body_shape.shape == null or not _phase_origin.is_finite():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape.shape
	query.transform = body_shape.global_transform
	query.transform.origin += _phase_origin - global_position
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.margin = 0.0
	var contacts: PackedVector3Array = get_world_3d().direct_space_state.collide_shape(query)
	for index: int in range(0, contacts.size(), 2):
		# Tangent floor contacts can produce sub-millimetre numerical penetration.
		if contacts[index].distance_squared_to(contacts[index + 1]) > RETURN_CONTACT_TOLERANCE * RETURN_CONTACT_TOLERANCE:
			return false
	phase_controller.consume_return()
	global_position = _phase_origin
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	return true

func _enter_phase_collision() -> void:
	if not _phase_through_objects or _phase_collision_active:
		return
	_phase_collision_active = true
	collision_layer = 0
	collision_mask = PHASE_SOLID_LAYER

func _exit_phase_collision() -> void:
	_phase_path.clear()
	if not _phase_collision_active:
		return
	_phase_collision_active = false
	collision_layer = _normal_collision_layer
	collision_mask = _normal_collision_mask
	if _geometry_update_pending:
		_apply_growth_geometry.call_deferred()

func _resolve_phase_landing() -> void:
	if not _phase_through_objects:
		return
	if _phase_path.is_empty():
		_phase_path.append(_phase_origin)
	if _phase_path[_phase_path.size() - 1].distance_squared_to(global_position) > 0.000001:
		_phase_path.append(global_position)
	var landing: Vector3 = _find_phase_landing()
	if not landing.is_finite():
		landing = global_position
	if landing.distance_squared_to(global_position) <= 0.000001:
		return
	global_position = landing
	velocity = Vector3.ZERO
	reset_physics_interpolation()

func _find_phase_landing() -> Vector3:
	var total: float = 0.0
	for index: int in range(_phase_path.size() - 1):
		total += _phase_path[index].distance_to(_phase_path[index + 1])
	if total <= 0.000001:
		return _safe_phase_origin()
	var samples: int = clampi(ceili(total / PHASE_LANDING_STEP), 1, PHASE_LANDING_SAMPLES)
	var step: float = total / samples
	var clear_distance: float = -1.0
	var blocked_distance: float = -1.0
	# Occupancy is not monotonic along the path, so every sample must be considered backwards.
	for index: int in range(samples, -1, -1):
		var distance: float = index * step
		if _phase_landing_is_clear(_phase_path_point(distance)):
			clear_distance = distance
			break
		blocked_distance = distance
	if clear_distance < 0.0:
		return _safe_phase_origin()
	if blocked_distance > clear_distance:
		clear_distance = _refine_phase_landing(clear_distance, blocked_distance)
	return _phase_path_point(clear_distance)

func _refine_phase_landing(clear_distance: float, blocked_distance: float) -> float:
	var low: float = clear_distance
	var high: float = blocked_distance
	for _pass: int in PHASE_LANDING_REFINEMENT_PASSES:
		var found: float = -1.0
		var next_blocked: float = high
		for index: int in range(PHASE_LANDING_REFINEMENT_STEPS, 0, -1):
			var fraction: float = float(index) / float(PHASE_LANDING_REFINEMENT_STEPS + 1)
			var distance: float = lerpf(low, high, fraction)
			if _phase_landing_is_clear(_phase_path_point(distance)):
				found = distance
				break
			next_blocked = distance
		if found < 0.0:
			high = next_blocked
			continue
		low = found
		high = next_blocked
	return low

func _safe_phase_origin() -> Vector3:
	if _phase_landing_is_clear(_phase_path[0]):
		return _phase_path[0]
	# Physical growth is frozen during the phase, so a blocked origin means moving geometry; keep the resolved physics pose.
	return global_position

func _phase_path_point(distance: float) -> Vector3:
	var remaining: float = distance
	for index: int in range(_phase_path.size() - 1):
		var segment: Vector3 = _phase_path[index + 1] - _phase_path[index]
		var length: float = segment.length()
		if length <= 0.000001:
			continue
		if remaining <= length:
			return _phase_path[index] + segment * (remaining / length)
		remaining -= length
	return _phase_path[_phase_path.size() - 1]

func _phase_landing_is_clear(candidate: Vector3) -> bool:
	if body_shape.disabled or body_shape.shape == null or not candidate.is_finite():
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape.shape
	query.transform = body_shape.global_transform
	query.transform.origin += candidate - global_position
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.margin = 0.0
	var contacts: PackedVector3Array = get_world_3d().direct_space_state.collide_shape(query, PHASE_LANDING_CONTACTS)
	for index: int in range(0, contacts.size(), 2):
		# Tangent floor contacts can produce sub-millimetre numerical penetration.
		if contacts[index].distance_squared_to(contacts[index + 1]) > RETURN_CONTACT_TOLERANCE * RETURN_CONTACT_TOLERANCE:
			return false
	return true

func adjust_life(amount: float) -> void:
	if not is_finite(amount) or health <= 0.0:
		return
	var current_life: float = life if is_finite(life) else 0.0
	life = clampf(current_life + amount, 0.0, MAX_LIFE)
	size = _calculate_size()
	_refresh_growth()
	growth_changed.emit(life, size)

func take_damage(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0 or not gameplay_enabled:
		return
	if phase_controller != null and phase_controller.is_invulnerable():
		return
	var damage: float = maxf(amount * damage_taken_multiplier, MIN_REDUCTION_MULTIPLIER)
	health = maxf(0.0, health - damage)
	var lethal: bool = health <= 0.0
	if lethal:
		set_gameplay_enabled(false)
	health_changed.emit(health, max_health)
	if lethal:
		died.emit()

func grant_shockwave(effect: ShockwaveEffect) -> void:
	shockwave_controller.grant(effect)

func apply_upgrade(effects: Dictionary[String, float]) -> void:
	if _apply_effects(effects):
		_refresh_growth()

func apply_upgrade_variant(effects: Dictionary[String, float], size_multiplier: float, healing_lock: bool, pacifist_effect: bool, proximity_bonus: float, lock_visible: bool, growth_retention: float, phase_multiplier: float) -> bool:
	if not _apply_effects(effects):
		return false
	var previous_size: float = size
	var previous_visible: float = visible_size
	if is_finite(size_multiplier) and size_multiplier > 0.0:
		size_growth_multiplier = clampf(size_growth_multiplier * clampf(size_multiplier, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	if healing_lock:
		set_healing_disabled(true)
	if pacifist_effect:
		pacifist = true
	if is_finite(proximity_bonus) and proximity_bonus > 0.0:
		proximity_drain_bonus_percent = clampf(proximity_drain_bonus_percent + proximity_bonus, 0.0, MAX_UPGRADE_MULTIPLIER)
	if lock_visible:
		lock_visible_size = true
	if is_finite(growth_retention):
		growth_bonus_retention = minf(growth_bonus_retention, clampf(growth_retention, 0.0, 1.0))
	if is_finite(phase_multiplier) and phase_multiplier > 0.0:
		phase_size_multiplier = minf(phase_size_multiplier, clampf(phase_multiplier, 0.01, MAX_UPGRADE_MULTIPLIER))
	size = _calculate_size()
	_refresh_growth()
	return not is_equal_approx(size, previous_size) or not is_equal_approx(visible_size, previous_visible)

func emit_growth_changed() -> void:
	growth_changed.emit(life, size)

func _apply_effects(effects: Dictionary[String, float]) -> bool:
	for effect: float in effects.values():
		if not is_finite(effect):
			return false
	var movement: float = effects.get("movement_multiplier", 1.0)
	var reach: float = effects.get("reach_multiplier", 1.0)
	var rate: float = effects.get("rate_multiplier", 1.0)
	var cooldown: float = effects.get("cooldown_multiplier", 1.0)
	var damage_taken: float = effects.get("damage_taken_multiplier", 1.0)
	var phase_distance: float = effects.get("phase_distance_multiplier", 1.0)
	movement_multiplier = clampf(movement_multiplier * clampf(movement, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	reach_multiplier = clampf(reach_multiplier * clampf(reach, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	rate_multiplier = clampf(rate_multiplier * clampf(rate, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	cooldown_multiplier = clampf(cooldown_multiplier * clampf(cooldown, MIN_REDUCTION_MULTIPLIER, MAX_REDUCTION_MULTIPLIER), MIN_REDUCTION_MULTIPLIER, MAX_REDUCTION_MULTIPLIER)
	damage_taken_multiplier = clampf(damage_taken_multiplier * clampf(damage_taken, MIN_REDUCTION_MULTIPLIER, MAX_REDUCTION_MULTIPLIER), MIN_REDUCTION_MULTIPLIER, MAX_REDUCTION_MULTIPLIER)
	phase_distance_multiplier = clampf(phase_distance_multiplier * clampf(phase_distance, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	return true

func _refresh_growth() -> void:
	var display_size: float = visible_size
	visuals.scale = Vector3.ONE * display_size
	smoke.configure(display_size)
	if phase_controller != null:
		phase_controller.set_upgrade_multipliers(cooldown_multiplier, phase_distance_multiplier)
		phase_controller.set_sizes(phase_size_multiplier * size, display_size)
	collection_point.position.y = 1.25 * display_size
	drain_area.source_volume = volume
	drain_area.drain_rate = effective_drain_rate
	drain_area.set_reach(effective_drain_reach)
	camera_rig.target_size = display_size
	if not _geometry_update_pending:
		_geometry_update_pending = true
		_apply_growth_geometry.call_deferred()

func _apply_growth_geometry() -> void:
	# Landing safety relies on the pre-phase capsule, so growth waits until phase collision ends.
	if _phase_collision_active:
		return
	_geometry_update_pending = false
	var physical_size: float = _physical_body_size()
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	capsule.radius = COMBAT_RADIUS_PER_SIZE * physical_size
	capsule.height = COMBAT_HEIGHT_PER_SIZE * physical_size
	body_shape.position.y = capsule.height * 0.5

func _physical_body_size() -> float:
	var display_size: float = visible_size
	if not is_finite(display_size):
		return minf(initial_size, PHYSICAL_SIZE_LIMIT)
	return clampf(display_size, minf(initial_size, PHYSICAL_SIZE_LIMIT), PHYSICAL_SIZE_LIMIT)

func get_collection_position() -> Vector3:
	return collection_point.global_position

func get_reference_model_height() -> float:
	return reaper.model_dimensions.y * global_basis.get_scale().abs().y

func _movement_scale() -> float:
	if not is_finite(movement_reference_height) or movement_reference_height <= 0.0:
		return 0.0
	if not is_finite(initial_size) or initial_size <= 0.0 or not is_finite(size) or size < 0.0:
		return 0.0
	var reference_height: float = get_reference_model_height()
	if not is_finite(reference_height) or reference_height <= 0.0:
		return 0.0
	var growth_factor: float = sqrt(size / initial_size)
	var scale_factor: float = reference_height * initial_size / movement_reference_height * growth_factor
	return scale_factor if is_finite(scale_factor) else 0.0

func _radius_size() -> float:
	var safe_initial: float = initial_size if is_finite(initial_size) and initial_size > 0.0 else 1.0
	var safe_size: float = size if is_finite(size) else safe_initial
	var retention: float = growth_bonus_retention if is_finite(growth_bonus_retention) else 1.0
	return safe_initial + clampf(retention, 0.0, 1.0) * (safe_size - safe_initial)

func get_absorption_transform() -> Transform3D:
	return visuals.global_transform

func get_absorption_bounds() -> AABB:
	if not _absorption_bounds_ready:
		_absorption_bounds_ready = true
		_absorption_bounds = WorldModel.bounds(visuals, true)
	return _absorption_bounds

func get_combat_radius() -> float:
	return COMBAT_RADIUS_PER_SIZE * visible_size

func get_combat_height() -> float:
	return COMBAT_HEIGHT_PER_SIZE * visible_size

func get_combat_target(from_position: Vector3) -> Vector3:
	var radius: float = get_combat_radius()
	var height: float = get_combat_height()
	var bottom_center: Vector3 = global_position + Vector3.UP * radius
	var top_center: Vector3 = global_position + Vector3.UP * maxf(radius, height - radius)
	if not from_position.is_finite():
		return bottom_center
	var axis_point: Vector3 = Geometry3D.get_closest_point_to_segment(from_position, bottom_center, top_center)
	var offset: Vector3 = from_position - axis_point
	if offset.length_squared() <= radius * radius:
		return from_position
	return axis_point + offset.normalized() * radius

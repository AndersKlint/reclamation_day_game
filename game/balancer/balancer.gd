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
const MAX_UPGRADE_MULTIPLIER: float = 1_000_000.0
const MAX_ACCUMULATED_MULTIPLIER: float = 1_000_000.0
const MAX_LIFE: float = 1_000_000_000_000_000_000_000_000_000_000.0
const BANK_PER_TURN_RATE: float = 0.03
const MAX_BANK: float = 0.035
const BANK_RESPONSE: float = 6.0
const MAX_HEALING_PER_SECOND: float = 2.0

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
var size: float = 1.0
var life: float = 0.0
var base_volume: float = 0.0
var volume: float:
	get:
		return base_volume * size * size * size
var health: float = 100.0
var movement_multiplier: float = 1.0
var reach_multiplier: float = 1.0
var rate_multiplier: float = 1.0
var _volume_drain_active: bool = false
var _geometry_update_pending: bool = false
var _absorption_bounds: AABB
var _absorption_bounds_ready: bool = false
var _bank: float = 0.0
var _pending_healing: float = 0.0
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
		var raw: float = base_drain_reach * size * reach_multiplier
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
	body_shape.shape = body_shape.shape.duplicate()
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
		phase_controller.bind(reaper, size)
	set_gameplay_enabled(false)

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_pending_healing = 0.0
		velocity = Vector3.ZERO
		_tick_phase(delta)
		return
	_consume_pending_healing(delta)
	if phase_controller != null and phase_controller.is_travelling():
		var phase_step: float = clampf(phase_controller.get_travel_remaining() / maxf(delta, 0.0001), 0.0, 1.0)
		var travel_velocity: Vector3 = phase_controller.get_travel_velocity() * phase_step
		velocity.x = travel_velocity.x
		velocity.z = travel_velocity.z
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		_tick_phase(delta)
		if not phase_controller.is_travelling():
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
	velocity = Vector3.ZERO
	_bank = 0.0
	_pending_healing = 0.0
	visuals.rotation.z = 0.0
	if not gameplay_enabled and phase_controller != null:
		phase_controller.cancel()
	camera_rig.set_gameplay_enabled(gameplay_enabled)
	drain_area.enabled = gameplay_enabled
	drain_vfx.set_enabled(gameplay_enabled)
	drain_audio.set_enabled(gameplay_enabled)

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
	if not gameplay_enabled or health <= 0.0 or not is_finite(amount) or amount <= 0.0:
		return
	var frame_cap: float = MAX_HEALING_PER_SECOND * maxf(get_physics_process_delta_time(), 0.0)
	_pending_healing = minf(_pending_healing + amount, frame_cap)

func _consume_pending_healing(delta: float) -> void:
	var demand: float = _pending_healing
	_pending_healing = 0.0
	if demand <= 0.0 or not gameplay_enabled or health <= 0.0:
		return
	var healed: float = minf(minf(demand, MAX_HEALING_PER_SECOND * maxf(delta, 0.0)), max_health - health)
	if healed <= 0.0:
		return
	health = minf(max_health, health + healed)
	health_changed.emit(health, max_health)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_pending_healing = 0.0

func _calculate_size() -> float:
	var safe_life: float = life if is_finite(life) else 0.0
	var maximum: float = maxf(initial_size, maximum_size) if is_finite(maximum_size) else initial_size
	return clampf(pow(pow(initial_size, 3.0) + Scaling.growth_for_life(maxf(0.0, safe_life)) / base_volume, 1.0 / 3.0), initial_size, maximum)

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
	if phase_controller == null or not gameplay_enabled:
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction: Vector3 = camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	if direction.is_zero_approx():
		direction = -visuals.global_basis.z
	direction.y = 0.0
	if direction.is_zero_approx():
		return
	if not phase_controller.try_activate(direction):
		return
	_bank = 0.0
	visuals.rotation.z = 0.0
	visuals.rotation.y = atan2(-direction.x, -direction.z)

func adjust_life(amount: float) -> void:
	if not is_finite(amount) or health <= 0.0:
		return
	var current_life: float = life if is_finite(life) else 0.0
	life = clampf(current_life + amount, 0.0, MAX_LIFE)
	size = _calculate_size()
	_refresh_growth()
	growth_changed.emit(life, size)

func take_damage(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0 or not gameplay_enabled:
		return
	if phase_controller != null and phase_controller.is_invulnerable():
		return
	health = maxf(0.0, health - amount)
	var lethal: bool = health <= 0.0
	if lethal:
		set_gameplay_enabled(false)
	health_changed.emit(health, max_health)
	if lethal:
		died.emit()

func apply_upgrade(effects: Dictionary[String, float]) -> void:
	var movement: float = effects.get("movement_multiplier", 1.0)
	var reach: float = effects.get("reach_multiplier", 1.0)
	var rate: float = effects.get("rate_multiplier", 1.0)
	if not is_finite(movement) or not is_finite(reach) or not is_finite(rate):
		return
	movement_multiplier = clampf(movement_multiplier * clampf(movement, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	reach_multiplier = clampf(reach_multiplier * clampf(reach, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	rate_multiplier = clampf(rate_multiplier * clampf(rate, 0.01, MAX_UPGRADE_MULTIPLIER), 0.01, MAX_ACCUMULATED_MULTIPLIER)
	_refresh_growth()

func _refresh_growth() -> void:
	visuals.scale = Vector3.ONE * size
	smoke.configure(size)
	if phase_controller != null:
		phase_controller.set_body_size(size)
	collection_point.position.y = 1.25 * size
	drain_area.source_volume = volume
	drain_area.drain_rate = effective_drain_rate
	drain_area.set_reach(effective_drain_reach)
	camera_rig.target_size = size
	if not _geometry_update_pending:
		_geometry_update_pending = true
		_apply_growth_geometry.call_deferred()

func _apply_growth_geometry() -> void:
	_geometry_update_pending = false
	var physical_size: float = clampf(size, minf(initial_size, PHYSICAL_SIZE_LIMIT), PHYSICAL_SIZE_LIMIT) if is_finite(size) else minf(initial_size, PHYSICAL_SIZE_LIMIT)
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	capsule.radius = COMBAT_RADIUS_PER_SIZE * physical_size
	capsule.height = COMBAT_HEIGHT_PER_SIZE * physical_size
	body_shape.position.y = capsule.height * 0.5

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
	var scale_factor: float = reference_height * initial_size / movement_reference_height * sqrt(size / initial_size)
	return scale_factor if is_finite(scale_factor) else 0.0

func get_absorption_transform() -> Transform3D:
	return visuals.global_transform

func get_absorption_bounds() -> AABB:
	if not _absorption_bounds_ready:
		_absorption_bounds_ready = true
		_absorption_bounds = WorldModel.bounds(visuals, true)
	return _absorption_bounds

func get_combat_radius() -> float:
	return COMBAT_RADIUS_PER_SIZE * size

func get_combat_target(from_position: Vector3) -> Vector3:
	var radius: float = get_combat_radius()
	var height: float = COMBAT_HEIGHT_PER_SIZE * size
	var bottom_center: Vector3 = global_position + Vector3.UP * radius
	var top_center: Vector3 = global_position + Vector3.UP * maxf(radius, height - radius)
	if not from_position.is_finite():
		return bottom_center
	var axis_point: Vector3 = Geometry3D.get_closest_point_to_segment(from_position, bottom_center, top_center)
	var offset: Vector3 = from_position - axis_point
	if offset.length_squared() <= radius * radius:
		return from_position
	return axis_point + offset.normalized() * radius

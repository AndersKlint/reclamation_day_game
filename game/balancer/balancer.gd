extends CharacterBody3D

signal growth_changed(life: float, size: float)
signal health_changed(current: float, maximum: float)
signal died()

const COMBAT_RADIUS_PER_SIZE: float = 0.45
const COMBAT_HEIGHT_PER_SIZE: float = 2.2
const PHYSICAL_SIZE_LIMIT: float = 3.0
const DRAIN_REACH_PER_SIZE: float = 0.85
const DRAIN_RATE_PER_SIZE: float = 0.35
const MAX_EFFECTIVE_MOVEMENT_SPEED: float = 18.0
const MAX_EFFECTIVE_ACCELERATION: float = 72.0
const MAX_EFFECTIVE_DRAIN_REACH: float = 2000.0
const MAX_EFFECTIVE_DRAIN_RATE: float = 10000.0
const MAX_UPGRADE_MULTIPLIER: float = 1_000_000.0
const MAX_ACCUMULATED_MULTIPLIER: float = 1_000_000.0
const MAX_LIFE: float = 1_000_000_000_000_000_000_000_000_000_000.0

@export var base_movement_speed: float = 6.0
@export var acceleration: float = 24.0
@export var turning_speed: float = 14.0
@export var base_drain_reach: float = 2.8
@export var base_drain_rate: float = 1.6
@export var max_health: float = 100.0
@export var life_per_size: float = 120.0
@export var maximum_size: float = 1000.0
var gameplay_enabled: bool = false
var size: float = 1.0
var life: float = 0.0
var health: float = 100.0
var movement_multiplier: float = 1.0
var reach_multiplier: float = 1.0
var rate_multiplier: float = 1.0
var _geometry_update_pending: bool = false
var effective_movement_speed: float:
	get:
		var raw: float = base_movement_speed * movement_multiplier
		return clampf(raw, 0.0, MAX_EFFECTIVE_MOVEMENT_SPEED) if is_finite(raw) else base_movement_speed
var effective_acceleration: float:
	get:
		var raw: float = acceleration * maxf(1.0, sqrt(movement_multiplier))
		return clampf(raw, 0.0, MAX_EFFECTIVE_ACCELERATION) if is_finite(raw) else acceleration
var effective_drain_reach: float:
	get:
		var raw: float = (base_drain_reach + (size - 1.0) * DRAIN_REACH_PER_SIZE) * reach_multiplier
		return clampf(raw, 0.0, MAX_EFFECTIVE_DRAIN_REACH) if is_finite(raw) else base_drain_reach
var effective_drain_rate: float:
	get:
		var raw: float = base_drain_rate * (1.0 + (size - 1.0) * DRAIN_RATE_PER_SIZE) * rate_multiplier
		return clampf(raw, 0.0, MAX_EFFECTIVE_DRAIN_RATE) if is_finite(raw) else base_drain_rate
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var drain_area: Area3D = $DrainArea
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var drain_vfx: Node3D = $DrainVfx
@onready var drain_audio: AudioStreamPlayer = $DrainAudio
@onready var footsteps: Node = $Footsteps
@onready var collection_point: Marker3D = $CollectionPoint
@onready var camera_rig: Node3D = $CameraRig

func _ready() -> void:
	body_shape.shape = body_shape.shape.duplicate()
	health = max_health
	drain_area.life_absorbed.connect(gain_life)
	drain_area.life_absorbed.connect(drain_audio.record_transfer)
	drain_vfx.configure(collection_point)
	# Presentation callbacks must run after the drain reward transaction completes.
	drain_area.transfer_effect_requested.connect(drain_vfx.record_transfer, CONNECT_DEFERRED)
	_refresh_growth()
	set_gameplay_enabled(false)

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		footsteps.reset_cadence()
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction: Vector3 = camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	if not direction.is_zero_approx():
		var facing: float = atan2(-direction.x, -direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, facing, 1.0 - exp(-turning_speed * delta))
	velocity.x = move_toward(velocity.x, direction.x * effective_movement_speed, effective_acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_movement_speed, effective_acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	var previous_position: Vector3 = global_position
	move_and_slide()
	footsteps.record_movement(previous_position)

func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled and health > 0.0
	velocity = Vector3.ZERO
	camera_rig.set_gameplay_enabled(gameplay_enabled)
	drain_area.enabled = gameplay_enabled
	drain_vfx.set_enabled(gameplay_enabled)
	drain_audio.set_enabled(gameplay_enabled)
	footsteps.set_enabled(gameplay_enabled)

func gain_life(amount: float) -> void:
	if not is_finite(amount) or amount <= 0.0 or health <= 0.0:
		return
	var current_life: float = life if is_finite(life) else 0.0
	life = minf(MAX_LIFE, current_life + amount)
	size = _calculate_size()
	_refresh_growth()
	growth_changed.emit(life, size)

func _calculate_size() -> float:
	var safe_life: float = life if is_finite(life) else 0.0
	var maximum: float = maximum_size if is_finite(maximum_size) and maximum_size >= 1.0 else 1.0
	var per_size: float = life_per_size if is_finite(life_per_size) and life_per_size > 0.0 else 1.0
	return clampf(1.0 + safe_life / per_size, 1.0, maximum)

func _unhandled_input(event: InputEvent) -> void:
	if not gameplay_enabled:
		return
	if event.is_action_pressed(&"debug_increase_life_large", false, true):
		adjust_life(50000.0)
	elif event.is_action_pressed(&"debug_decrease_life_large", false, true):
		adjust_life(-50000.0)
	elif event.is_action_pressed(&"debug_increase_life", false, true):
		adjust_life(500.0)
	elif event.is_action_pressed(&"debug_decrease_life", false, true):
		adjust_life(-500.0)

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
	collection_point.position.y = 1.25 * size
	drain_area.source_size = size
	drain_area.drain_rate = effective_drain_rate
	drain_area.set_reach(effective_drain_reach)
	camera_rig.target_size = size
	if not _geometry_update_pending:
		_geometry_update_pending = true
		_apply_growth_geometry.call_deferred()

func _apply_growth_geometry() -> void:
	_geometry_update_pending = false
	var physical_size: float = clampf(size, 1.0, PHYSICAL_SIZE_LIMIT) if is_finite(size) else 1.0
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	capsule.radius = COMBAT_RADIUS_PER_SIZE * physical_size
	capsule.height = COMBAT_HEIGHT_PER_SIZE * physical_size
	body_shape.position.y = capsule.height * 0.5

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

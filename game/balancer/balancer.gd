extends CharacterBody3D

signal growth_changed(life: float, size: float)
signal health_changed(current: float, maximum: float)
signal died()

@export var base_movement_speed: float = 6.0
@export var acceleration: float = 24.0
@export var turning_speed: float = 14.0
@export var base_drain_reach: float = 2.8
@export var base_drain_rate: float = 1.6
@export var max_health: float = 100.0
@export var life_per_size: float = 120.0
@export var maximum_size: float = 4.5
var gameplay_enabled: bool = false
var size: float = 1.0
var life: float = 0.0
var health: float = 100.0
var movement_multiplier: float = 1.0
var reach_multiplier: float = 1.0
var rate_multiplier: float = 1.0
var _geometry_update_pending: bool = false
var effective_movement_speed: float:
	get: return base_movement_speed * movement_multiplier
var effective_drain_reach: float:
	get: return (base_drain_reach + (size - 1.0) * 0.85) * reach_multiplier
var effective_drain_rate: float:
	get: return base_drain_rate * (1.0 + (size - 1.0) * 0.35) * rate_multiplier
@onready var camera: Camera3D = $CameraRig/SpringArm3D/Camera3D
@onready var drain_area: Area3D = $DrainArea
@onready var body_shape: CollisionShape3D = $CollisionShape3D
@onready var visuals: Node3D = $Visuals
@onready var drain_vfx: Node3D = $DrainVfx
@onready var collection_point: Marker3D = $CollectionPoint
@onready var camera_rig: Node3D = $CameraRig

func _ready() -> void:
	body_shape.shape = body_shape.shape.duplicate()
	health = max_health
	drain_area.life_absorbed.connect(gain_life)
	drain_vfx.configure(collection_point)
	# Presentation callbacks must run after the drain reward transaction completes.
	drain_area.transfer_effect_requested.connect(drain_vfx.record_transfer, CONNECT_DEFERRED)
	_refresh_growth()
	set_gameplay_enabled(false)

func _physics_process(delta: float) -> void:
	if not gameplay_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		velocity = Vector3.ZERO
		return
	var input: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_backward")
	var direction: Vector3 = camera_rig.global_basis * Vector3(input.x, 0.0, input.y)
	if not direction.is_zero_approx():
		var facing: float = atan2(-direction.x, -direction.z)
		visuals.rotation.y = lerp_angle(visuals.rotation.y, facing, 1.0 - exp(-turning_speed * delta))
	velocity.x = move_toward(velocity.x, direction.x * effective_movement_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.z * effective_movement_speed, acceleration * delta)
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_and_slide()

func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled and health > 0.0
	velocity = Vector3.ZERO
	camera_rig.set_gameplay_enabled(gameplay_enabled)
	drain_area.enabled = gameplay_enabled
	drain_vfx.set_enabled(gameplay_enabled)

func gain_life(amount: float) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	life += amount
	size = minf(maximum_size, 1.0 + life / life_per_size)
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
	movement_multiplier *= maxf(0.01, effects.get("movement_multiplier", 1.0))
	reach_multiplier *= maxf(0.01, effects.get("reach_multiplier", 1.0))
	rate_multiplier *= maxf(0.01, effects.get("rate_multiplier", 1.0))
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
	var capsule: CapsuleShape3D = body_shape.shape as CapsuleShape3D
	capsule.radius = 0.45 * size
	capsule.height = 2.2 * size
	body_shape.position.y = capsule.height * 0.5

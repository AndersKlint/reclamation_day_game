extends Node3D

const NEAR_MIN: float = 0.05
const NEAR_MAX: float = 8.0
const NEAR_DISTANCE_RATIO: float = 0.002
const FAR_DISTANCE_RATIO: float = 1.5
const FAR_SIZE_RATIO: float = 3.0
const FAR_MARGIN: float = 500.0
const FRAMING_SNAP_RATIO: float = 0.5

@export var follow_speed: float = 20.0
@export var growth_follow_speed: float = 8.0
@export var base_distance: float = 5.5
@export var distance_per_size: float = 4.0
@export var mouse_sensitivity: float = 0.0025
@export var minimum_pitch: float = -60.0
@export var maximum_pitch: float = 15.0
@export var initial_pitch: float = -15.0
@export var base_far: float = 600.0
@export var collision_disable_distance: float = 150.0
var target: CharacterBody3D
var target_size: float = 1.0:
	set(value):
		if not is_finite(value) or value <= 0.0:
			return
		if absf(value - target_size) > target_size * FRAMING_SNAP_RATIO:
			_snap_framing = true
		target_size = value
var gameplay_enabled: bool = false
var _arm_collision_mask: int
var _collision_disabled: bool = false
var _snap_framing: bool = false
@onready var arm: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D

func _ready() -> void:
	target = get_parent() as CharacterBody3D
	top_level = true
	global_rotation = Vector3.ZERO
	global_position = _pivot_position()
	arm.rotation.x = deg_to_rad(initial_pitch)
	_arm_collision_mask = arm.collision_mask
	var distance: float = _desired_distance()
	arm.spring_length = distance
	_update_arm_collision(distance)
	_update_lens(distance)
	arm.add_excluded_object(target.get_rid())

func set_gameplay_enabled(enabled: bool) -> void:
	gameplay_enabled = enabled
	set_process(enabled)
	set_process_input(enabled)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if not gameplay_enabled or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotation.y = wrapf(rotation.y - event.screen_relative.x * mouse_sensitivity, -PI, PI)
		arm.rotation.x = clampf(arm.rotation.x - event.screen_relative.y * mouse_sensitivity,
			deg_to_rad(minimum_pitch), deg_to_rad(maximum_pitch))
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not gameplay_enabled or get_tree().paused:
		return
	var distance: float = _desired_distance()
	if _snap_framing:
		global_position = _pivot_position()
		arm.spring_length = distance
		_snap_framing = false
	else:
		var weight: float = 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(_pivot_position(), weight)
		var growth_weight: float = 1.0 - exp(-growth_follow_speed * delta)
		arm.spring_length = lerpf(arm.spring_length, distance, growth_weight)
	_update_arm_collision(distance)
	_update_lens(distance)

func _pivot_position() -> Vector3:
	return target.global_position + Vector3.UP * target_size * 1.1

func _desired_distance() -> float:
	return base_distance + (target_size - 1.0) * distance_per_size

func _update_arm_collision(distance: float) -> void:
	# Giant arms hit every skyline and pin the camera; collision only matters at small scale.
	var disabled: bool = distance > collision_disable_distance
	if disabled == _collision_disabled:
		return
	_collision_disabled = disabled
	arm.collision_mask = 0 if disabled else _arm_collision_mask

func _update_lens(distance: float) -> void:
	var framing_distance: float = maxf(distance, camera.global_position.distance_to(_pivot_position()))
	var near: float = clampf(framing_distance * NEAR_DISTANCE_RATIO, NEAR_MIN, NEAR_MAX)
	if not is_equal_approx(camera.near, near):
		camera.near = near
	var far: float = maxf(base_far, framing_distance * FAR_DISTANCE_RATIO + target_size * FAR_SIZE_RATIO + FAR_MARGIN)
	if not is_equal_approx(camera.far, far):
		camera.far = far

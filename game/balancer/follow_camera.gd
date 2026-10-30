extends Node3D

@export var follow_speed: float = 20.0
@export var growth_follow_speed: float = 8.0
@export var base_distance: float = 5.5
@export var distance_per_size: float = 4.0
@export var mouse_sensitivity: float = 0.0025
@export var minimum_pitch: float = -60.0
@export var maximum_pitch: float = 15.0
@export var initial_pitch: float = -15.0
var target: CharacterBody3D
var target_size: float = 1.0
var gameplay_enabled: bool = false
@onready var arm: SpringArm3D = $SpringArm3D

func _ready() -> void:
	target = get_parent() as CharacterBody3D
	top_level = true
	global_rotation = Vector3.ZERO
	global_position = target.global_position + Vector3.UP * 1.1
	arm.rotation.x = deg_to_rad(initial_pitch)
	arm.spring_length = base_distance
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
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target.global_position + Vector3.UP * target_size * 1.1, weight)
	var growth_weight: float = 1.0 - exp(-growth_follow_speed * delta)
	arm.spring_length = lerpf(arm.spring_length, base_distance + (target_size - 1.0) * distance_per_size, growth_weight)

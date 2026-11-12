extends Node

const TARGET_BUS: StringName = &"Master"

@export_group("Environment Fog")
@export var fog_light_color: Color = Color(0.004, 0.006, 0.012, 1.0)
@export_range(0.0, 1.0, 0.001) var fog_light_energy: float = 0.08
@export_range(0.0, 1.0, 0.0001) var fog_density: float = 0.055
@export_range(0.0, 10.0, 0.01) var fog_depth_begin_scale: float = 1.15
@export_range(0.0, 10.0, 0.01) var fog_depth_begin_body_margin: float = 1.5
@export_range(1.0, 10000.0, 1.0) var fog_depth_span: float = 220.0
@export_range(0.0, 1.0, 0.0001) var volumetric_fog_density: float = 0.035
@export var volumetric_fog_albedo: Color = Color(0.012, 0.014, 0.024, 1.0)
@export_group("Ground Fog")
@export_range(0.0, 0.5, 0.001) var ground_fog_density: float = 0.09
@export var ground_fog_albedo: Color = Color(0.003, 0.004, 0.008, 1.0)
@export_range(0.0, 100.0, 0.1) var ground_fog_base_height: float = 0.0
@export_range(0.1, 100.0, 0.1) var ground_fog_height_falloff: float = 5.0
@export_group("Audio")
@export_range(20.0, 20500.0, 1.0) var lowpass_cutoff_hz: float = 800.0
@export_range(0.0, 1.0, 0.01) var lowpass_resonance: float = 0.5

var _world_environment: WorldEnvironment
var _baseline_environment: Environment
var _environment: Environment
var _ground_fog: FogVolume
var _baseline_fog_material: Material
var _fog_material: ShaderMaterial
var _balancer: Node3D
var _camera: Camera3D
var _lowpass_bus: int = -1
var _lowpass_index: int = -1
var _active: bool = false


func configure(world_environment: WorldEnvironment, ground_fog: FogVolume, balancer: Node3D, camera: Camera3D, phase: Node) -> void:
	_world_environment = world_environment
	_ground_fog = ground_fog
	_balancer = balancer
	_camera = camera
	if _world_environment != null:
		_baseline_environment = _world_environment.environment
	if _ground_fog != null:
		_baseline_fog_material = _ground_fog.material
	_find_lowpass()
	set_process(false)
	if phase != null:
		phase.connect(&"void_changed", _on_void_changed)


func set_active(active: bool) -> void:
	if _active == active:
		return
	_active = active
	if _active:
		_apply()
		set_process(true)
	else:
		_restore()
		set_process(false)


func _process(_delta: float) -> void:
	_update_depth_fog()


func _apply() -> void:
	if is_instance_valid(_world_environment) and _baseline_environment != null:
		_environment = _baseline_environment.duplicate() as Environment
		if _environment != null:
			_environment.fog_enabled = true
			_environment.fog_mode = Environment.FOG_MODE_DEPTH
			_environment.fog_light_color = fog_light_color
			_environment.fog_light_energy = fog_light_energy
			_environment.fog_density = fog_density
			_environment.volumetric_fog_enabled = true
			_environment.volumetric_fog_density = volumetric_fog_density
			_environment.volumetric_fog_albedo = volumetric_fog_albedo
			_world_environment.environment = _environment
			_update_depth_fog()
	if is_instance_valid(_ground_fog) and _baseline_fog_material is ShaderMaterial:
		_fog_material = (_baseline_fog_material as ShaderMaterial).duplicate() as ShaderMaterial
		if _fog_material != null:
			_fog_material.set_shader_parameter(&"base_density", ground_fog_density)
			_fog_material.set_shader_parameter(&"base_height", ground_fog_base_height)
			_fog_material.set_shader_parameter(&"height_falloff", ground_fog_height_falloff)
			_fog_material.set_shader_parameter(&"fog_albedo", ground_fog_albedo)
			_ground_fog.material = _fog_material
	_set_lowpass_enabled(true)


func _restore() -> void:
	if is_instance_valid(_world_environment):
		_world_environment.environment = _baseline_environment
	_environment = null
	if is_instance_valid(_ground_fog):
		_ground_fog.material = _baseline_fog_material
	_fog_material = null
	_set_lowpass_enabled(false)


func _update_depth_fog() -> void:
	if _environment == null or not is_instance_valid(_camera):
		return
	var anchor: Vector3 = Vector3.ZERO
	var body_size: float = 1.0
	if is_instance_valid(_balancer):
		anchor = _balancer.global_position
		var size_value: Variant = _balancer.get(&"visible_size")
		if size_value is float or size_value is int:
			body_size = maxf(float(size_value), 1.0)
	var pivot: Vector3 = anchor + Vector3.UP * body_size * 1.1
	var distance: float = _camera.global_position.distance_to(pivot)
	var begin: float = maxf(distance * fog_depth_begin_scale, 1.0) + body_size * fog_depth_begin_body_margin
	_environment.fog_depth_begin = begin
	_environment.fog_depth_end = maxf(begin + fog_depth_span, _camera.far * 1.05)


func _find_lowpass() -> void:
	_lowpass_bus = AudioServer.get_bus_index(TARGET_BUS)
	if _lowpass_bus < 0:
		return
	for index: int in AudioServer.get_bus_effect_count(_lowpass_bus):
		if AudioServer.get_bus_effect(_lowpass_bus, index) is AudioEffectLowPassFilter:
			_lowpass_index = index
			return


func _set_lowpass_enabled(enabled: bool) -> void:
	if _lowpass_bus < 0 or _lowpass_index < 0:
		return
	if _lowpass_index >= AudioServer.get_bus_effect_count(_lowpass_bus):
		return
	if enabled:
		var effect: AudioEffectLowPassFilter = AudioServer.get_bus_effect(_lowpass_bus, _lowpass_index) as AudioEffectLowPassFilter
		if effect != null:
			effect.cutoff_hz = lowpass_cutoff_hz
			effect.resonance = lowpass_resonance
	AudioServer.set_bus_effect_enabled(_lowpass_bus, _lowpass_index, enabled)


func _on_void_changed(active: bool) -> void:
	set_active(active)


func _exit_tree() -> void:
	_restore()

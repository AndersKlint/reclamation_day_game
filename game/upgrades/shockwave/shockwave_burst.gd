extends Node3D

const VISUAL_DURATION: float = 0.8
const MAX_VISUAL_RADIUS: float = 128.0

var _started: bool = false

@onready var _ground_wave: MeshInstance3D = $GroundWave
@onready var _material: ShaderMaterial = _ground_wave.material_override as ShaderMaterial
@onready var _explosion: AudioStreamPlayer = $Explosion


func play(radius: float) -> void:
	if _started:
		return
	_started = true
	if not is_finite(radius) or radius <= 0.0:
		queue_free()
		return
	var visual_radius: float = clampf(radius, 0.1, MAX_VISUAL_RADIUS)
	_ground_wave.scale = Vector3(visual_radius, 1.0, visual_radius)
	_material.set_shader_parameter(&"radius", visual_radius)
	_material.set_shader_parameter(&"progress", 0.0)
	_ground_wave.show()
	_explosion.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_explosion.play()
	var lifetime: float = maxf(VISUAL_DURATION, _explosion.stream.get_length()) + 0.1
	var animation: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	animation.tween_property(_material, "shader_parameter/progress", 1.0, VISUAL_DURATION)
	animation.tween_callback(_ground_wave.hide)
	animation.tween_interval(lifetime - VISUAL_DURATION)
	animation.tween_callback(queue_free)

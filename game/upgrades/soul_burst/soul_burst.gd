extends Node3D

const SMOKE_SHADER: Shader = preload("res://game/upgrades/soul_burst/smoke_ring.gdshader")
const PUFF_COUNT: int = 72
const VISUAL_DURATION: float = 1.5
const MAX_VISUAL_RADIUS: float = 48.0

var _started: bool = false
var _radius: float = 1.0
var _puffs: Array[MeshInstance3D] = []
var _material: ShaderMaterial

@onready var _screech: AudioStreamPlayer = $Screech


func play(radius: float) -> void:
	if _started:
		return
	_started = true
	if not is_finite(radius) or radius <= 0.0:
		queue_free()
		return
	_radius = clampf(radius, 0.1, MAX_VISUAL_RADIUS)
	_create_puffs()
	_animate(0.0)
	_screech.bus = &"SFX" if AudioServer.get_bus_index(&"SFX") >= 0 else &"Master"
	_screech.play()
	var lifetime: float = maxf(VISUAL_DURATION, _screech.stream.get_length()) + 0.15
	var animation: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	animation.tween_method(_animate, 0.0, 1.0, VISUAL_DURATION)
	animation.tween_callback(hide)
	animation.tween_interval(lifetime - VISUAL_DURATION)
	animation.tween_callback(queue_free)


func _create_puffs() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SMOKE_SHADER
	var puff_size: Vector2 = Vector2(clampf(_radius * 0.24, 1.0, 6.5), clampf(_radius * 0.2, 0.9, 5.5))
	var quad: QuadMesh = QuadMesh.new()
	quad.size = puff_size
	for index: int in range(PUFF_COUNT):
		var puff: MeshInstance3D = MeshInstance3D.new()
		puff.name = "SmokePuff%d" % index
		puff.mesh = quad
		puff.material_override = _material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.extra_cull_margin = puff_size.x
		add_child(puff)
		_puffs.append(puff)


func _animate(progress: float) -> void:
	_material.set_shader_parameter(&"progress", progress)
	var spread: float = 1.0 - pow(1.0 - progress, 3.0)
	for index: int in range(PUFF_COUNT):
		var fraction: float = float(index) / float(PUFF_COUNT)
		var variation: float = sin(float(index) * 2.399963 + 0.7)
		var angle: float = fraction * TAU + variation * 0.03
		var reach: float = _radius * (0.82 + 0.18 * variation)
		var distance: float = lerpf(_radius * 0.12, reach, spread)
		var rise: float = 0.6 + progress * (0.6 + 0.5 * sin(float(index) * 1.71))
		var puff_scale: float = lerpf(0.4, 1.0 + 0.35 * variation, spread)
		var puff: MeshInstance3D = _puffs[index]
		puff.position = Vector3(cos(angle) * distance, rise, sin(angle) * distance)
		puff.scale = Vector3(puff_scale, puff_scale, puff_scale)

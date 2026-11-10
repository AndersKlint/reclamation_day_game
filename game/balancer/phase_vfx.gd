extends Node3D

const DRAW_SHADER: Shader = preload("res://game/balancer/phase_fog.gdshader")
const PROCESS_SHADER: Shader = preload("res://game/balancer/reaper_fog_particles.gdshader")
const AMOUNT: int = 140
const TRAIL_AMOUNT: int = 70
const LIFETIME: float = 0.42
const SETTINGS: Dictionary[StringName, float] = {
	&"size_factor": 1.0,
	&"spawn_radius": 0.85,
	&"spawn_inner_radius": 0.0,
	&"spawn_height": 0.95,
	&"spawn_height_jitter": 1.0,
	&"rise_speed": 0.20,
	&"outward_speed": 0.75,
	&"sway": 0.14,
	&"start_scale": 0.62,
	&"end_scale": 1.15,
	&"opacity": 0.92,
	&"fade_in": 0.02,
}

var _emitter: GPUParticles3D
var _cloud: GPUParticles3D
var _cloud_material: ShaderMaterial
var _trail_material: ShaderMaterial
var _body_size: float = 1.0

func _ready() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _draw_material()
	_cloud_material = _draw_material()
	_cloud_material.set_shader_parameter(&"phase_visibility", 0.0)
	var cloud_quad: QuadMesh = QuadMesh.new()
	cloud_quad.size = Vector2.ONE
	cloud_quad.material = _cloud_material
	_cloud = GPUParticles3D.new()
	_cloud.name = "AttachedCloud"
	_cloud.amount = AMOUNT
	_cloud.lifetime = LIFETIME
	_cloud.local_coords = true
	_cloud.fixed_fps = 0
	# Keep the attached cloud simulated while masked to avoid activation-time GPU fill latency.
	_cloud.preprocess = LIFETIME
	_cloud.draw_pass_1 = cloud_quad
	_cloud.process_material = _process_material()
	_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.visibility_aabb = AABB(Vector3(-4.0, -2.0, -4.0), Vector3(8.0, 6.0, 8.0))
	add_child(_cloud)
	_emitter = GPUParticles3D.new()
	_emitter.name = "Trail"
	_emitter.amount = TRAIL_AMOUNT
	_emitter.lifetime = LIFETIME
	_emitter.local_coords = false
	_emitter.fixed_fps = 30
	_emitter.interpolate = true
	_emitter.draw_pass_1 = quad
	_trail_material = _process_material()
	_emitter.process_material = _trail_material
	_emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_emitter.visibility_aabb = AABB(Vector3(-8.0, -4.0, -8.0), Vector3(16.0, 8.0, 16.0))
	_emitter.emitting = false
	add_child(_emitter)
	configure(_body_size)

func configure(body_size: float) -> void:
	_body_size = maxf(body_size, 0.001) if is_finite(body_size) else 1.0
	if _cloud == null:
		return
	# Local particles inherit node scale; world-space particles need shader scaling instead.
	_cloud.scale = Vector3.ONE * _body_size
	_trail_material.set_shader_parameter(&"size_factor", _body_size)
	_emitter.visibility_aabb = AABB(Vector3(-8.0, -4.0, -8.0) * _body_size, Vector3(16.0, 8.0, 16.0) * _body_size)

func set_active(active: bool) -> void:
	if _emitter == null:
		return
	_cloud_material.set_shader_parameter(&"phase_visibility", 1.0 if active else 0.0)
	if active:
		_emitter.visible = true
		_emitter.restart()
		_emitter.emitting = true
	else:
		_emitter.emitting = false

func clear() -> void:
	set_active(false)
	if _emitter != null:
		_emitter.visible = false

func _draw_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = DRAW_SHADER
	material.set_shader_parameter(&"smoke_texture", _noise_texture())
	return material

func _process_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PROCESS_SHADER
	for key: StringName in SETTINGS:
		material.set_shader_parameter(key, SETTINGS[key])
	return material

func _noise_texture() -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture

extends Node3D

const DRAW_SHADER: Shader = preload("res://game/balancer/reaper_fog.gdshader")
const PROCESS_SHADER: Shader = preload("res://game/balancer/reaper_fog_particles.gdshader")
const VEIL_AMOUNT: int = 55
const VEIL_LIFETIME: float = 4.8
const POOL_AMOUNT: int = 85
const POOL_LIFETIME: float = 9.0
const DENSITY_CAPACITY: float = 3.0
const MAX_SIZE_FACTOR: float = 8.0
const TRAIL_HALF_EXTENT: float = 180.0
const VEIL_SETTINGS: Dictionary[StringName, float] = {
	&"spawn_radius": 1.00,
	&"spawn_inner_radius": 0.22,
	&"spawn_height": 0.45,
	&"spawn_height_jitter": 0.18,
	&"rise_speed": 0.30,
	&"outward_speed": 0.90,
	&"sway": 0.06,
	&"start_scale": 0.30,
	&"end_scale": 0.55,
	&"opacity": 0.75,
}
const POOL_SETTINGS: Dictionary[StringName, float] = {
	&"spawn_radius": 1.30,
	&"spawn_inner_radius": 0.30,
	&"spawn_height": 0.14,
	&"spawn_height_jitter": 0.05,
	&"rise_speed": 0.18,
	&"outward_speed": 1.30,
	&"sway": 0.12,
	&"start_scale": 0.45,
	&"end_scale": 0.90,
	&"opacity": 0.42,
}

@export var movement_body: CharacterBody3D

var _veil: GPUParticles3D
var _pool: GPUParticles3D
var _veil_material: ShaderMaterial
var _pool_material: ShaderMaterial
var _size_factor: float = 1.0

func _ready() -> void:
	# World-space emission ignores body banking and growth scale, yet stays under Visuals so the renewal fade reaches it.
	top_level = true
	if movement_body != null:
		global_position = movement_body.global_position
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	quad.material = _make_draw_material()
	_veil_material = _make_process_material(VEIL_SETTINGS)
	_pool_material = _make_process_material(POOL_SETTINGS)
	_veil = _make_emitter("SmokeVeil", quad, VEIL_AMOUNT, VEIL_LIFETIME, _veil_material)
	_pool = _make_emitter("SmokePool", quad, POOL_AMOUNT, POOL_LIFETIME, _pool_material)
	_apply_size()

func _physics_process(_delta: float) -> void:
	if movement_body != null:
		global_position = movement_body.global_position

func configure(body_size: float) -> void:
	var factor: float = clampf(body_size, 1.0, MAX_SIZE_FACTOR) if is_finite(body_size) else 1.0
	if is_equal_approx(factor, _size_factor):
		return
	_size_factor = factor
	_apply_size()

func _apply_size() -> void:
	for material: ShaderMaterial in [_veil_material, _pool_material]:
		material.set_shader_parameter(&"size_factor", _size_factor)
	var density: float = clampf(_size_factor, 1.0, DENSITY_CAPACITY) / DENSITY_CAPACITY
	var extent: float = TRAIL_HALF_EXTENT + 6.0 * _size_factor
	var height: float = 12.0 * _size_factor
	for emitter: GPUParticles3D in [_veil, _pool]:
		emitter.amount_ratio = density
		emitter.visibility_aabb = AABB(Vector3(-extent, -4.0 * _size_factor, -extent), Vector3(extent * 2.0, height, extent * 2.0))

func _make_draw_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = DRAW_SHADER
	material.set_shader_parameter(&"smoke_texture", _noise_texture())
	return material

func _make_process_material(settings: Dictionary[StringName, float]) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = PROCESS_SHADER
	material.set_shader_parameter(&"size_factor", _size_factor)
	for key: StringName in settings:
		material.set_shader_parameter(key, settings[key])
	return material

func _noise_texture() -> NoiseTexture2D:
	# One shared, pre-generated noise sample replaces per-fragment procedural noise.
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

func _make_emitter(node_name: String, draw_mesh: Mesh, amount: int, lifetime: float, process_material: ShaderMaterial) -> GPUParticles3D:
	var emitter: GPUParticles3D = GPUParticles3D.new()
	emitter.name = node_name
	emitter.amount = roundi(amount * DENSITY_CAPACITY)
	emitter.lifetime = lifetime
	emitter.local_coords = false
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.preprocess = lifetime
	emitter.draw_pass_1 = draw_mesh
	emitter.process_material = process_material
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(emitter)
	return emitter

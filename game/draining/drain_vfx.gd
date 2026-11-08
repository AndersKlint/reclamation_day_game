extends Node3D

const STREAM_SHADER: Shader = preload("res://game/draining/life_stream.gdshader")
const MOTE_SHADER: Shader = preload("res://game/draining/life_mote.gdshader")
const WARP_SHADER: Shader = preload("res://game/draining/drain_warp.gdshader")
const MIN_PARTICLE_LIFETIME: float = 2.8

@export_range(1, 12, 1) var pool_size: int = 10
@export_range(32, 128, 1) var particles_per_source: int = 64
@export_range(0.12, 0.2, 0.01) var freshness_timeout: float = 0.16
@export_group("Transfer response")
@export_range(0.1, 20.0, 0.1) var rate_reference: float = 1.6
@export_range(0.05, 0.5, 0.01) var minimum_density: float = 0.18
@export_range(0.0, 1.0, 0.01) var rate_weight: float = 0.6
@export_range(0.0, 1.0, 0.01) var proximity_weight: float = 0.4
@export_range(0.3, 2.5, 0.01) var slow_travel_seconds: float = 1.7
@export_range(0.15, 1.2, 0.01) var fast_travel_seconds: float = 0.6
@export_group("Source shimmer")
@export var enable_warp: bool = true
@export_range(0.0, 2.0, 0.05) var warp_strength_pixels: float = 0.65

class StreamLink:
	var source_id: int = 0
	var age: float = 0.0
	var source_position: Vector3 = Vector3.ZERO
	var radius: float = 0.0
	var intensity: float = 0.0
	var particles: GPUParticles3D
	var material: ShaderMaterial
	var mote_material: ShaderMaterial
	var halo: MeshInstance3D
	var halo_material: ShaderMaterial
	var bounds: AABB

var _collector: Node3D
var _enabled: bool = false
var _particle_lifetime: float = MIN_PARTICLE_LIFETIME
var _links: Array[StreamLink] = []

func _ready() -> void:
	_particle_lifetime = maxf(MIN_PARTICLE_LIFETIME, clampf(slow_travel_seconds, 0.3, 2.5) * 1.5 + 0.2)
	var halo_mesh: QuadMesh = QuadMesh.new()
	halo_mesh.size = Vector2.ONE
	for index: int in range(clampi(pool_size, 1, 12)):
		var link: StreamLink = StreamLink.new()
		link.material = ShaderMaterial.new()
		link.material.shader = STREAM_SHADER
		link.particles = GPUParticles3D.new()
		link.particles.name = "LifeStream%d" % index
		link.particles.emitting = false
		link.particles.amount = clampi(particles_per_source, 32, 128)
		link.particles.lifetime = _particle_lifetime
		link.particles.local_coords = false
		link.particles.fixed_fps = 60
		link.particles.interpolate = true
		link.particles.process_material = link.material
		link.mote_material = ShaderMaterial.new()
		link.mote_material.shader = MOTE_SHADER
		link.mote_material.render_priority = 1
		var mote_mesh: QuadMesh = QuadMesh.new()
		mote_mesh.size = Vector2.ONE
		mote_mesh.material = link.mote_material
		link.particles.draw_pass_1 = mote_mesh
		link.particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(link.particles)
		link.particles.top_level = true
		link.particles.global_transform = Transform3D.IDENTITY
		link.halo_material = ShaderMaterial.new()
		link.halo_material.shader = WARP_SHADER
		link.halo_material.render_priority = -10
		link.halo = MeshInstance3D.new()
		link.halo.mesh = halo_mesh
		link.halo.material_override = link.halo_material
		link.halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(link.halo)
		link.halo.top_level = true
		link.halo.visible = false
		link.particles.visible = false
		_links.append(link)

func configure(collector: Node3D) -> void:
	set_enabled(false)
	_collector = collector

func set_enabled(enabled: bool) -> void:
	_enabled = enabled and is_instance_valid(_collector)
	if _enabled:
		return
	for link: StreamLink in _links:
		link.particles.emitting = false
		link.particles.visible = false
		link.particles.restart()
		link.particles.emitting = false
		link.halo.visible = false
		link.source_id = 0
		link.age = 0.0

func record_transfer(source_id: int, source_position: Vector3, source_radius: float,
		actual_rate: float, proximity: float) -> void:
	if not _enabled or not is_instance_valid(_collector) or actual_rate <= 0.0:
		return
	var link: StreamLink = _find_link(source_id)
	if link == null:
		return
	if link.source_id == 0:
		link.bounds = AABB(source_position, Vector3.ZERO).grow(2.0)
	link.source_id = source_id
	link.age = 0.0
	link.source_position = source_position
	link.radius = clampf(source_radius, 0.05, 64.0)
	var rate_response: float = actual_rate / (actual_rate + maxf(rate_reference, 0.1))
	link.intensity = clampf(rate_weight * rate_response
		+ proximity_weight * clampf(proximity, 0.0, 1.0), 0.0, 1.0)
	link.material.set_shader_parameter("source_position", source_position)
	link.material.set_shader_parameter("source_radius", link.radius)
	var simulated_travel: float = clampf(slow_travel_seconds, 0.3, 2.5)
	var desired_wall_travel: float = lerpf(simulated_travel,
		clampf(fast_travel_seconds, 0.15, simulated_travel), link.intensity)
	link.material.set_shader_parameter("travel_seconds", desired_wall_travel)
	link.particles.amount_ratio = lerpf(minimum_density, 1.0, link.intensity)
	_update_link(link)
	link.particles.visible = true
	link.particles.emitting = true

func _process(delta: float) -> void:
	if not _enabled:
		return
	if not is_instance_valid(_collector):
		set_enabled(false)
		return
	for link: StreamLink in _links:
		if link.source_id == 0:
			continue
		link.age += delta
		if link.age > freshness_timeout:
			link.particles.emitting = false
			link.halo.visible = false
		if link.age > freshness_timeout + _particle_lifetime:
			link.particles.visible = false
			link.source_id = 0
			continue
		_update_link(link)

func _find_link(source_id: int) -> StreamLink:
	var available: StreamLink
	for link: StreamLink in _links:
		if link.source_id == source_id:
			return link
		if link.source_id == 0 and available == null:
			available = link
	return available

func _update_link(link: StreamLink) -> void:
	var destination: Vector3 = _collector.global_position
	link.material.set_shader_parameter("collector_position", destination)
	# Retain prior endpoints until recycling so live world-space births remain inside the bounds.
	link.bounds = link.bounds.merge(AABB(link.source_position, Vector3.ZERO).grow(link.radius + 2.0))
	link.bounds = link.bounds.merge(AABB(destination, Vector3.ZERO).grow(2.0))
	link.particles.visibility_aabb = link.bounds
	link.mote_material.set_shader_parameter("size_scale", clampf(0.4 + link.radius * 2.5, 0.5, 160.0))
	link.halo.global_position = link.source_position
	link.halo.scale = Vector3.ONE * clampf(link.radius * 2.5, 0.6, 5.0)
	link.halo_material.set_shader_parameter("strength_pixels", warp_strength_pixels * link.intensity)
	link.halo.visible = enable_warp and link.age <= freshness_timeout

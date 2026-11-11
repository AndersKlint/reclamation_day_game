extends Node3D

const VISUAL_DURATION: float = 2.5
const SMOKE_PUFFS: int = 10

var _configured: bool = false

@onready var _visuals: Node3D = $Visuals
@onready var _voice: AudioStreamPlayer3D = $ExplosionSound

func configure(blast_radius: float) -> void:
	if _configured:
		return
	_configured = true
	_visuals.scale = Vector3.ONE * maxf(blast_radius, 0.1)
	_spawn_flash()
	_spawn_smoke()
	_spawn_shockwave()
	_voice.pitch_scale = randf_range(0.96, 1.04)
	_voice.play()
	var lifetime: float = maxf(VISUAL_DURATION, _voice.stream.get_length() / _voice.pitch_scale + 0.15)
	var cleanup: Tween = create_tween()
	cleanup.tween_interval(VISUAL_DURATION)
	cleanup.tween_callback(_visuals.hide)
	cleanup.tween_interval(maxf(lifetime - VISUAL_DURATION, 0.01))
	cleanup.tween_callback(queue_free)

func _spawn_flash() -> void:
	var material: StandardMaterial3D = _make_material(Color(1.0, 0.85, 0.45, 0.95))
	var flash: MeshInstance3D = _add_mesh(_make_sphere(), material)
	flash.position.y = 0.12
	flash.scale = Vector3.ONE * 0.15
	var burst: Tween = create_tween().set_parallel(true)
	burst.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	burst.tween_property(flash, "scale", Vector3.ONE * 0.65, 0.18)
	burst.tween_property(material, "albedo_color:a", 0.0, 0.18)
	burst.chain().tween_callback(flash.queue_free)

func _spawn_smoke() -> void:
	var material: StandardMaterial3D = _make_material(Color(1.0, 0.3, 0.025, 0.9))
	var sphere: SphereMesh = _make_sphere()
	for index: int in SMOKE_PUFFS:
		var angle: float = TAU * float(index) / float(SMOKE_PUFFS)
		var outward: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var puff: MeshInstance3D = _add_mesh(sphere, material)
		puff.position = outward * 0.08 + Vector3.UP * 0.12
		puff.scale = Vector3.ONE * randf_range(0.11, 0.18)
		var destination: Vector3 = outward * randf_range(0.35, 0.65)
		destination.y = randf_range(0.3, 0.65)
		var expansion: Tween = create_tween().set_parallel(true)
		expansion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		expansion.tween_property(puff, "position", destination, 1.7)
		expansion.tween_property(puff, "scale", Vector3.ONE * randf_range(0.3, 0.44), 1.8)
	var cooling: Tween = create_tween()
	cooling.tween_property(material, "albedo_color", Color(0.3, 0.27, 0.24, 0.7), 0.4)
	cooling.tween_property(material, "albedo_color:a", 0.0, 2.0)

func _spawn_shockwave() -> void:
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.93
	ring.outer_radius = 1.0
	ring.rings = 32
	ring.ring_segments = 6
	var material: StandardMaterial3D = _make_material(Color(0.8, 0.57, 0.3, 0.65))
	var shockwave: MeshInstance3D = _add_mesh(ring, material)
	shockwave.position.y = 0.025
	shockwave.scale = Vector3(0.08, 0.2, 0.08)
	var expansion: Tween = create_tween().set_parallel(true)
	expansion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	expansion.tween_property(shockwave, "scale", Vector3(1.0, 0.2, 1.0), 0.55)
	expansion.tween_property(material, "albedo_color:a", 0.0, 0.55)
	expansion.chain().tween_callback(shockwave.queue_free)

func _make_sphere() -> SphereMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	return sphere

func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	return material

func _add_mesh(mesh: Mesh, material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)
	return instance

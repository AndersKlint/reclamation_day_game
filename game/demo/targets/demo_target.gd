extends "res://game/demo/targets/demo_scenery.gd"

const Drainable = preload("res://game/draining/drainable.gd")
const DepletionEffect = preload("res://game/draining/depletion_effect.gd")
const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const WITHER_SHADER: Shader = preload("res://game/world/wither.gdshader")

var drainable: Drainable
var depletion_style: DepletionEffect.Style = DepletionEffect.Style.RUBBLE
@export var building_collapse: bool = false
var ground_position: Callable
var _depletion_effect: DepletionEffect
var _collapsed: bool = false
var _materials: Array[ShaderMaterial] = []
var _renewing: bool = false
var _renewal: Tween

func configure_drain() -> void:
	drainable = Drainable.new()
	drainable.name = "Drainable"
	drainable.collision_layer = 8
	drainable.collision_mask = 0
	drainable.monitoring = false
	add_child(drainable)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = BoxShape3D.new()
	drainable.add_child(collision)

func _ready() -> void:
	super()
	if visual == null:
		return
	drainable.configure_volume(fitted_size * global_basis.get_scale().abs())
	var collision: CollisionShape3D = drainable.get_node("CollisionShape3D") as CollisionShape3D
	var box: BoxShape3D = collision.shape as BoxShape3D
	box.size = fitted_size + Vector3(0.3, 0.1, 0.3)
	collision.position.y = fitted_size.y * 0.5
	drainable.emission_offset = Vector3(0.0, fitted_size.y * 0.55, 0.0)
	drainable.emission_radius = maxf(0.25, minf(fitted_size.x, fitted_size.z) * 0.45)
	_collect_materials()
	drainable.drained.connect(_on_drained)
	_depletion_effect = DEPLETION_EFFECT.instantiate() as DepletionEffect
	_depletion_effect.style = depletion_style
	add_child(_depletion_effect)
	_depletion_effect.configure(visual, fitted_size, ground_position)
	drainable.collapsed.connect(_on_collapsed)
	if building_collapse:
		add_to_group(&"shockwave_buildings")

func get_shockwave_bounds() -> AABB:
	return visual.global_transform * WorldModel.bounds(visual)

func topple_from_shockwave(collector: Node3D) -> void:
	if not building_collapse or _collapsed or is_queued_for_deletion() or not is_instance_valid(drainable):
		return
	if drainable.force_collapse(collector):
		_clear_collision()

func _collect_materials() -> void:
	var shared: Dictionary[Material, ShaderMaterial] = {}
	for mesh: MeshInstance3D in WorldModel.meshes(visual):
		for surface: int in mesh.mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
			if source == null or source.emission_enabled:
				continue
			if not shared.has(source):
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = WITHER_SHADER
				material.set_shader_parameter("base_color", source.albedo_color)
				material.set_shader_parameter("albedo_texture", source.albedo_texture)
				material.set_shader_parameter("uv_scale", source.uv1_scale)
				material.set_shader_parameter("uv_offset", source.uv1_offset)
				if source.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					material.set_shader_parameter("alpha_scissor", source.alpha_scissor_threshold)
				shared[source] = material
				_materials.append(material)
			mesh.set_surface_override_material(surface, shared[source])

func _on_drained(_amount: float) -> void:
	if _renewing:
		return
	var wither: float = 1.0 - drainable.drain_fraction()
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("wither_amount", wither)

func _on_collapsed() -> void:
	_collapsed = true
	_start_depletion.call_deferred()

func _start_depletion() -> void:
	set_process(false)
	for light: Node in visual.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false
	_depletion_effect.configure_reward(drainable.take_collapse_life(), drainable.collector)
	_depletion_effect.flattened.connect(_clear_collision, CONNECT_ONE_SHOT)
	_depletion_effect.building_collapse = building_collapse
	_depletion_effect.start()


func _clear_collision() -> void:
	for node: Node in find_children("*", "CollisionShape3D", true, false):
		var shape: CollisionShape3D = node as CollisionShape3D
		if shape.get_parent() is StaticBody3D:
			var body: StaticBody3D = shape.get_parent() as StaticBody3D
			body.collision_layer = 0
			body.collision_mask = 0
			shape.set_deferred(&"disabled", true)

func renew(duration: float) -> void:
	if _collapsed or drainable.is_collapsed:
		return
	_renewing = true
	set_process(false)
	if _renewal != null:
		_renewal.kill()
	if duration <= 0.0:
		_set_renewal(1.0)
		return
	_renewal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renewal.tween_method(_set_renewal, 0.0, 1.0, duration)

func _set_renewal(fraction: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("freshening", fraction)

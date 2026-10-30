extends Node3D

const Drainable = preload("res://game/draining/drainable.gd")
const WorldModel = preload("res://game/world/world_model.gd")
const WITHER_SHADER: Shader = preload("res://game/world/wither.gdshader")
const MEADOW_MODEL: PackedScene = preload("res://available-assets/retro3d-assets/Nature/tree_pack_1.1/models/bush02.fbx")
const ORCHARD_MODEL: PackedScene = preload("res://available-assets/retro3d-assets/Nature/tree_pack_1.1/models/tree01.fbx")
const BARN_MODEL: PackedScene = preload("res://available-assets/retro3d-assets/Industrial/Shacks Shanties Sheds and Gantries 0001/Large Shed A.blend")
const MEADOW_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Nature/tree_pack_1.1/textures/bush02.png")
const ORCHARD_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Nature/tree_pack_1.1/textures/tree01.png")
const BARN_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Industrial/Shacks Shanties Sheds and Gantries 0001/Shed Corrugated Texture.png")
const BARN_FRAME_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Industrial/Shacks Shanties Sheds and Gantries 0001/Shed Frame Texture.png")
@export var dimensions: Vector3 = Vector3(1.2, 1.3, 1.2)
@export var living_color: Color = Color("78884e")
@export var target_label: String = "Meadow"
var _materials: Array[ShaderMaterial] = []
var _renewal: Tween
var _renewing: bool = false
var _new_growth: Node3D
@onready var drainable: Drainable = $Drainable
@onready var visual: Node3D = $Visual
@onready var label: Label3D = $Label3D

func _ready() -> void:
	drainable.emission_offset = Vector3(0.0, dimensions.y * 0.5, 0.0)
	drainable.emission_radius = maxf(0.4, minf(dimensions.x, dimensions.z) * 0.5)
	var model_scene: PackedScene = MEADOW_MODEL
	if target_label == "Orchard":
		model_scene = ORCHARD_MODEL
	elif target_label == "Barn":
		model_scene = BARN_MODEL
	_add_model(model_scene, visual, dimensions)
	_collect_materials(visual)
	_set_life_fraction(drainable.remaining_capacity / drainable.capacity)
	if target_label == "Barn":
		_new_growth = Node3D.new()
		_new_growth.name = "RenewalGrowth"
		add_child(_new_growth)
		for offset: Vector3 in [Vector3(-5.6, 0, -3), Vector3(5.6, 0, 3), Vector3(0, 0, 4.8)]:
			var bush: Node3D = Node3D.new()
			_new_growth.add_child(bush)
			bush.position = offset
			_add_model(MEADOW_MODEL, bush, Vector3(2.0, 1.1, 2.0))
		_new_growth.scale = Vector3.ONE * 0.01
		_new_growth.hide()
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = maxf(0.8, minf(dimensions.x, dimensions.z) * 0.55)
	$Drainable/CollisionShape3D.shape = shape
	label.position.y = dimensions.y + 1.0
	drainable.drained.connect(_on_drained)
	_update_label()

func _on_drained(_amount: float) -> void:
	if _renewing:
		return
	var fraction: float = drainable.remaining_capacity / drainable.capacity
	_set_life_fraction(fraction)
	_update_label()

func renew(duration: float) -> void:
	_renewing = true
	if _renewal != null:
		_renewal.kill()
	label.text = target_label + (" · new growth" if target_label != "Barn" else " · reclaimed")
	label.modulate = Color("bad5a1")
	if duration <= 0.0:
		_set_renewal(1.0)
		return
	_renewal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renewal.tween_method(_set_renewal, 0.0, 1.0, duration)

func _set_renewal(fraction: float) -> void:
	if target_label == "Barn":
		_new_growth.show()
		_new_growth.scale = Vector3.ONE * lerpf(0.01, 1.0, fraction)
		return
	visual.scale = Vector3.ONE.lerp(Vector3(1.08, 1.12, 1.08), fraction)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("freshening", fraction)

func _set_life_fraction(fraction: float) -> void:
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("wither_amount", 1.0 - clampf(fraction, 0.0, 1.0))

func _collect_materials(parent: Node3D) -> void:
	for mesh: MeshInstance3D in WorldModel.meshes(parent):
		for surface: int in mesh.mesh.get_surface_count():
			var source: Material = mesh.get_active_material(surface)
			if source is BaseMaterial3D:
				var base: BaseMaterial3D = source as BaseMaterial3D
				var material: ShaderMaterial = ShaderMaterial.new()
				material.shader = WITHER_SHADER
				material.set_shader_parameter("base_color", base.albedo_color)
				material.set_shader_parameter("albedo_texture", base.albedo_texture)
				material.set_shader_parameter("uv_scale", base.uv1_scale)
				material.set_shader_parameter("uv_offset", base.uv1_offset)
				if base.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
					material.set_shader_parameter("alpha_scissor", base.alpha_scissor_threshold)
				mesh.set_surface_override_material(surface, material)
				_materials.append(material)

func _add_model(scene: PackedScene, parent: Node3D, size: Vector3) -> void:
	var model: Node3D = WorldModel.add_fitted(scene, parent, size, PI * 0.5 if scene == BARN_MODEL else 0.0)
	if scene == BARN_MODEL:
		WorldModel.bind_texture(model, BARN_TEXTURE, false, "Shed A")
		WorldModel.bind_texture(model, BARN_FRAME_TEXTURE, false, "Shed A Frame")
	else:
		WorldModel.bind_texture(model, ORCHARD_TEXTURE if scene == ORCHARD_MODEL else MEADOW_TEXTURE, true)

func _update_label() -> void:
	if drainable.is_depleted:
		label.text = target_label + " · spent"
		label.modulate = Color(0.55, 0.55, 0.55)
	else:
		label.text = "%s · size %.1f\n%.0f / %.0f" % [target_label, drainable.required_size, drainable.remaining_capacity, drainable.capacity]

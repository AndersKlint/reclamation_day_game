extends Node3D

const LivingTarget = preload("res://game/world/living_target.tscn")
const Drainable = preload("res://game/draining/drainable.gd")
const WorldModel = preload("res://game/world/world_model.gd")
const COTTAGE_MODEL: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/retro_house_pack/models/glb/house1.glb")
const COTTAGE_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Buildings/retro_house_pack/textures/256x256/house1_tex1.png")
const GROUND_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Buildings/Abandoned House/Textures/groundgrass.png")
signal progress_changed(drained: float, initial: float)
var initial_capacity: float = 0.0
var drained_capacity: float = 0.0
var _renewal: Tween

func renew(duration: float) -> void:
	for target: Node in $Drainables.get_children():
		target.renew(duration)
	if _renewal != null:
		_renewal.kill()
	var ground: MeshInstance3D = $Ground
	var material: StandardMaterial3D = ground.material_override as StandardMaterial3D
	if duration <= 0.0:
		material.albedo_color = Color("7b9565")
		return
	_renewal = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_renewal.tween_property(material, "albedo_color", Color("7b9565"), duration)

func _ready() -> void:
	_add_box("Ground", Vector3(0, -0.5, 0), Vector3(100, 1, 100), Color("687361"), true)
	var ground_material: StandardMaterial3D = $Ground.material_override as StandardMaterial3D
	ground_material.albedo_texture = GROUND_TEXTURE
	ground_material.uv1_scale = Vector3(35.0, 35.0, 35.0)
	ground_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_add_box("Crossroad", Vector3(0, 0.015, 0), Vector3(9, 0.03, 90), Color("9a9078"))
	_add_box("FarmLane", Vector3(0, 0.035, -10), Vector3(85, 0.03, 6), Color("9a9078"))
	_add_collision("BarnCollision", Vector3(22, 3, -23), Vector3(10, 6, 8))
	_add_box("Silo", Vector3(-27, 5, -25), Vector3(4, 10, 4), Color("9a9990"), true)
	var cottage: Node3D = Node3D.new()
	cottage.name = "Cottage"
	add_child(cottage)
	cottage.position = Vector3(-24, 0, 15)
	var model: Node3D = WorldModel.add_fitted(COTTAGE_MODEL, cottage, Vector3(7, 4.5, 6), PI * 0.5)
	WorldModel.bind_texture(model, COTTAGE_TEXTURE)
	_add_collision("CottageCollision", Vector3(-24, 2, 15), Vector3(7, 4, 6))
	for x: float in [-8.0, 8.0]:
		for z: float in [30.0, 35.0, 40.0]:
			_add_box("LanePost", Vector3(x, 0.65, z), Vector3(0.22, 1.3, 0.22), Color("706754"))
		_add_box("LaneRail", Vector3(x, 0.9, 35), Vector3(0.12, 0.14, 10), Color("706754"))
	for x: float in [-51.0, 51.0]:
		_add_box("Boundary", Vector3(x, 3, 0), Vector3(2, 6, 104), Color("525f56"), true)
	for z: float in [-51.0, 51.0]:
		_add_box("Boundary", Vector3(0, 3, z), Vector3(100, 6, 2), Color("525f56"), true)
	_place_targets()
	progress_changed.emit(drained_capacity, initial_capacity)

func _place_targets() -> void:
	var meadow_positions: Array[Vector2] = [Vector2(-4, 22), Vector2(4, 18), Vector2(-7, 14), Vector2(7, 10), Vector2(-10, 6), Vector2(10, 2), Vector2(-6, -2), Vector2(6, -6), Vector2(-13, 23), Vector2(13, 25), Vector2(-17, 9), Vector2(17, 13)]
	for point: Vector2 in meadow_positions:
		_place_target("Meadow", point, 20.0, 1.0, Vector3(2.4, 0.8, 2.4), Color("83915b"))
	var orchard_positions: Array[Vector2] = [Vector2(-18, -18), Vector2(-25, -12), Vector2(-32, -19), Vector2(-16, -29), Vector2(15, -17), Vector2(30, -14), Vector2(31, -29), Vector2(15, -32)]
	for point: Vector2 in orchard_positions:
		_place_target("Orchard", point, 45.0, 1.8, Vector3(2.5, 4.5, 2.5), Color("5e7754"))
	_place_target("Barn", Vector2(22, -23), 240.0, 3.0, Vector3(10.2, 6.3, 8.2), Color("826455"))

func _place_target(title: String, point: Vector2, capacity: float, required_size: float, dimensions: Vector3, color: Color) -> void:
	var target: Node3D = LivingTarget.instantiate()
	target.name = title + str($Drainables.get_child_count() + 1)
	target.position = Vector3(point.x, 0.0, point.y)
	target.dimensions = dimensions
	target.target_label = title
	target.living_color = color
	target.ground_position = ground_position
	if title == "Barn":
		target.blocking_collision = $BarnCollision/CollisionShape3D
	var component: Area3D = target.get_node("Drainable")
	component.capacity = capacity
	component.required_size = Drainable.gate_to_size(required_size)
	component.drained.connect(_on_target_drained)
	initial_capacity += capacity
	$Drainables.add_child(target)
	var effect: Node = target.get_node_or_null("DepletionEffect")
	if effect != null and effect.has_signal(&"life_absorbed"):
		effect.connect(&"life_absorbed", _on_target_drained)

func ground_position(world_point: Vector3) -> Vector3:
	var local_point: Vector3 = to_local(world_point)
	local_point.y = 0.0
	if absf(local_point.x) <= 42.5 and absf(local_point.z + 10.0) <= 3.0:
		local_point.y = 0.05
	elif absf(local_point.x) <= 4.5 and absf(local_point.z) <= 45.0:
		local_point.y = 0.03
	return to_global(local_point)

func _on_target_drained(amount: float) -> void:
	drained_capacity = minf(initial_capacity, drained_capacity + amount)
	if is_equal_approx(drained_capacity, initial_capacity):
		drained_capacity = initial_capacity
	progress_changed.emit(drained_capacity, initial_capacity)

func _add_box(node_name: String, center: Vector3, dimensions: Vector3, color: Color, solid: bool = false) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = center
	add_child(visual)
	if solid:
		_add_collision(node_name + "Collision", center, dimensions)

func _add_collision(node_name: String, center: Vector3, dimensions: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

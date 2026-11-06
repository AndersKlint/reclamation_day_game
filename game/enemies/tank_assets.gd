extends RefCounted

const WorldModel = preload("res://game/world/world_model.gd")

const TANK_A: PackedScene = preload("res://available-assets/retro3d-assets/Vehicles/Dieselpunk Tanks/Tank A.blend")
const TANK_B: PackedScene = preload("res://available-assets/retro3d-assets/Vehicles/Dieselpunk Tanks/Tank B.blend")
const TANK_A_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Vehicles/Dieselpunk Tanks/Tank-A-Texture.png")
const TANK_B_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Vehicles/Dieselpunk Tanks/Tank-B-Texture.png")
const MODEL_FORWARD_YAW: float = -PI * 0.5

static func build(parent: Node3D, heavy: bool) -> Node3D:
	var scene: PackedScene = TANK_A if heavy else TANK_B
	var texture: Texture2D = TANK_A_TEXTURE if heavy else TANK_B_TEXTURE
	var fit: Node3D = Node3D.new()
	parent.add_child(fit)
	var model: Node3D = scene.instantiate() as Node3D
	fit.add_child(model)
	model.rotation.y = MODEL_FORWARD_YAW
	var bounds: AABB
	var first: bool = true
	for mesh: MeshInstance3D in WorldModel.meshes(model):
		var local_bounds: AABB = (fit.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	var target_size: Vector3 = size_for(heavy)
	var uniform_scale: float = minf(target_size.x / bounds.size.x, target_size.z / bounds.size.z)
	fit.scale = Vector3.ONE * uniform_scale
	fit.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * uniform_scale
	WorldModel.bind_texture(model, texture)
	for node: Node in model.find_children("*", "Camera3D", true, false):
		node.queue_free()
	for node: Node in model.find_children("*", "Light3D", true, false):
		node.queue_free()
	return model

static func size_for(heavy: bool) -> Vector3:
	return Vector3(3.0, 2.05, 6.0) if heavy else Vector3(3.0, 2.3, 6.0)

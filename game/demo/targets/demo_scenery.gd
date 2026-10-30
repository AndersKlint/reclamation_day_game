extends Node3D

const WorldModel = preload("res://game/world/world_model.gd")

var kind: StringName
var dimensions: Vector3 = Vector3.ONE
var model_scene: PackedScene
var texture: Texture2D
var frame_texture: Texture2D
var cutout: bool = false
var blocking: bool = false
var preserve_model_lights: bool = false
var model_yaw: float = 0.0
var fitted_size: Vector3 = Vector3.ONE
var visual: Node3D

func _ready() -> void:
	if model_scene == null:
		return
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var model: Node3D = model_scene.instantiate() as Node3D
	for node: Node in model.find_children("*", "", true, false):
		if node is Camera3D or (node is Light3D and not preserve_model_lights):
			node.get_parent().remove_child(node)
			node.queue_free()
	visual.add_child(model)
	model.rotation.y = model_yaw
	var bounds: AABB
	var first: bool = true
	for mesh: MeshInstance3D in WorldModel.meshes(model):
		var local_bounds: AABB = (visual.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	if first or bounds.size.x <= 0.0 or bounds.size.y <= 0.0 or bounds.size.z <= 0.0:
		push_error("Demo asset has empty bounds: %s" % kind)
		return
	var ratio: Vector3 = dimensions.max(Vector3.ONE * 0.01) / bounds.size
	var fit_scale: float = minf(ratio.x, minf(ratio.y, ratio.z))
	fitted_size = bounds.size * fit_scale
	visual.scale = Vector3.ONE * fit_scale
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * fit_scale
	if kind == &"shed":
		WorldModel.bind_texture(model, texture, false, "Shed A")
		WorldModel.bind_texture(model, frame_texture, false, "Shed A Frame")
	elif texture != null:
		WorldModel.bind_texture(model, texture, cutout)
	if blocking:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 6
		var collision: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = fitted_size
		if String(kind).contains("tree"):
			box.size = Vector3(maxf(0.4, fitted_size.x * 0.12), fitted_size.y * 0.65, maxf(0.4, fitted_size.z * 0.12))
		collision.shape = box
		collision.position.y = box.size.y * 0.5
		body.add_child(collision)
		add_child(body)

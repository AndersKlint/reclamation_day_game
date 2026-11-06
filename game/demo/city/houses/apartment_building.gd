extends Node3D

const SOURCE: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Bui/Bui/Edificios.dae")

static var _templates: Dictionary[StringName, Dictionary] = {}

@export var model_node: StringName = &"Cube_013"

func _ready() -> void:
	var template: Dictionary = _template(model_node)
	if template.is_empty():
		return
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = String(model_node)
	mesh.mesh = template["mesh"] as Mesh
	mesh.transform = template["transform"] as Transform3D
	add_child(mesh)

static func _template(model_name: StringName) -> Dictionary:
	if _templates.has(model_name):
		return _templates[model_name]
	var source: Node3D = SOURCE.instantiate() as Node3D
	var mesh: MeshInstance3D = source.get_node_or_null(String(model_name)) as MeshInstance3D
	if mesh == null:
		push_error("Missing apartment mesh: %s" % model_name)
		source.free()
		return {}
	var bounds: AABB = mesh.transform * mesh.get_aabb()
	var transform: Transform3D = mesh.transform
	transform.origin -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var template: Dictionary = {"mesh": mesh.mesh, "transform": transform}
	source.free()
	_templates[model_name] = template
	return template

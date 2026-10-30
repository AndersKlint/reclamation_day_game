extends RefCounted

static func meshes(parent: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if parent is MeshInstance3D:
		result.append(parent as MeshInstance3D)
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result

static func add_fitted(scene: PackedScene, parent: Node3D, size: Vector3, yaw: float = 0.0) -> Node3D:
	var fit: Node3D = Node3D.new()
	parent.add_child(fit)
	var model: Node3D = scene.instantiate() as Node3D
	fit.add_child(model)
	model.rotation.y = yaw
	var bounds: AABB
	var first: bool = true
	for mesh: MeshInstance3D in meshes(model):
		var local_bounds: AABB = (fit.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	fit.scale = size / bounds.size
	fit.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * fit.scale
	return model

static func bind_texture(parent: Node3D, texture: Texture2D, cutout: bool = false, mesh_name: String = "") -> void:
	for mesh: MeshInstance3D in meshes(parent):
		if not mesh_name.is_empty() and mesh.name != mesh_name:
			continue
		for surface: int in mesh.mesh.get_surface_count():
			var source: BaseMaterial3D = mesh.get_active_material(surface) as BaseMaterial3D
			var material: BaseMaterial3D = source.duplicate() as BaseMaterial3D if source != null else StandardMaterial3D.new()
			material.albedo_texture = texture
			material.albedo_color = Color.WHITE
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			material.roughness = 1.0
			if cutout:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.4
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, material)

extends RefCounted

static func meshes(parent: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if parent is MeshInstance3D:
		result.append(parent as MeshInstance3D)
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		result.append(node as MeshInstance3D)
	return result

static func bounds(parent: Node3D, posed: bool = false) -> AABB:
	var result: AABB
	var initialized: bool = false
	for mesh: MeshInstance3D in meshes(parent):
		if mesh.mesh == null:
			continue
		var box: AABB = mesh_bounds(mesh, parent, posed)
		result = result.merge(box) if initialized else box
		initialized = true
	return result

static func mesh_bounds(mesh: MeshInstance3D, relative_to: Node3D, posed: bool = false) -> AABB:
	var skeleton: Skeleton3D = mesh.get_node_or_null(mesh.skeleton) as Skeleton3D if mesh.skin != null else null
	if not posed or skeleton == null:
		return (relative_to.global_transform.affine_inverse() * mesh.global_transform) * mesh.mesh.get_aabb()
	var transforms: Array[Transform3D] = []
	for index: int in mesh.skin.get_bind_count():
		var bone: int = skeleton.find_bone(mesh.skin.get_bind_name(index))
		if bone < 0:
			bone = mesh.skin.get_bind_bone(index)
		transforms.append(relative_to.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
	var result: AABB
	var initialized: bool = false
	for surface: int in mesh.mesh.get_surface_count():
		var arrays: Array = mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var influences: int = bones.size() / vertices.size()
		for vertex: int in vertices.size():
			var point: Vector3 = Vector3.ZERO
			for influence: int in influences:
				var offset: int = vertex * influences + influence
				point += (transforms[bones[offset]] * vertices[vertex]) * weights[offset]
			result = result.expand(point) if initialized else AABB(point, Vector3.ZERO)
			initialized = true
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

extends RefCounted

const SOURCE: String = "res://available-assets/random-packs/PSX_Forest_Level_byStarkCrafts/PSX_Forest_AssetCollection_byStarkCrafts.fbx"
static var _scenes: Dictionary[StringName, PackedScene] = {}

static func scene(object_name: StringName) -> PackedScene:
	if _scenes.is_empty():
		var collection: PackedScene = load(SOURCE) as PackedScene
		var root: Node3D = collection.instantiate() as Node3D
		for node: Node in root.find_children("*", "MeshInstance3D", true, false):
			var source: MeshInstance3D = node as MeshInstance3D
			var model: MeshInstance3D = MeshInstance3D.new()
			model.mesh = source.mesh.duplicate() as Mesh
			model.basis = source.transform.basis
			for surface: int in model.mesh.get_surface_count():
				var material: BaseMaterial3D = source.get_active_material(surface).duplicate() as BaseMaterial3D
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				if String(material.resource_name).contains("Crown") or String(material.resource_name).contains("Corwn") or String(material.resource_name).contains("Grass") or material.resource_name == "Dandelion":
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					material.alpha_scissor_threshold = 0.45
				model.mesh.surface_set_material(surface, material)
			var wrapper: Node3D = Node3D.new()
			wrapper.add_child(model)
			model.owner = wrapper
			var packed: PackedScene = PackedScene.new()
			packed.pack(wrapper)
			_scenes[StringName(String(source.name).strip_edges())] = packed
			wrapper.free()
		root.free()
	return _scenes.get(object_name) as PackedScene

static func populate(region: Node3D, parent: Node3D) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 431107
	var names: Array[StringName] = [&"PSX_Grass", &"PSX_Dandelion", &"PSX_Lavender", &"PSX_Reed", &"PSX_PineConre"]
	for object_name: StringName in names:
		var root: Node3D = scene(object_name).instantiate() as Node3D
		var model: MeshInstance3D = root.get_child(0) as MeshInstance3D
		var bounds: AABB = model.transform * model.get_aabb()
		var scale_factor: float = (0.25 if object_name == &"PSX_PineConre" else 0.8) / bounds.size.y
		var fit: Transform3D = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor) * model.transform
		for z: int in range(-170, 171, 34):
			for x: int in range(-120, 121, 30):
				for i: int in (6 if object_name == &"PSX_PineConre" else 28):
					var p: Vector2 = Vector2(x + rng.randf_range(0, 30), z + rng.randf_range(0, 34))
					if region._clear_route(p):
						continue
					var placement: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * rng.randf_range(0.6, 1.3)), Vector3(p.x, region.ground_height(p.x, p.y), p.y))
					region._add_cover(model.mesh, placement * fit)
		root.free()

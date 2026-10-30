extends RefCounted

const WorldModel = preload("res://game/world/world_model.gd")
const MAILBOX = preload("res://available-assets/retro3d-assets/Buildings/Mailbox/LP_Mailbox.fbx")
const MAILBOX_TEXTURE = preload("res://available-assets/retro3d-assets/Buildings/Mailbox/LP_MailboxBase.png")
const CRATE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/crate.fbx")
const CRATE_TEXTURE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/textures/crate.png")
const BARREL = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/barrel3/Barrel1.glb")
const BARREL_TEXTURE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/barrel3/Barrel1_Atlas.png")

static func populate(region: Node3D, parent: Node3D) -> void:
	var dressing: Node3D = Node3D.new()
	dressing.name = "YardDressing"
	parent.add_child(dressing)
	for i: int in region.BUILDINGS.size():
		var center: Vector3 = region.BUILDINGS[i]
		var inward: float = 1.0 if center.x < 0 else -1.0
		_prop(region, dressing, MAILBOX, MAILBOX_TEXTURE, Vector2(center.x + inward * 12, center.z + 6), Vector3(0.7, 1.35, 0.7), PI * 0.5 * inward)
		_prop(region, dressing, CRATE, CRATE_TEXTURE, Vector2(center.x - inward * 11.5, center.z + 4), Vector3(1.1, 1.0, 1.1), i * 0.37)
		if i % 2 == 0:
			_prop(region, dressing, BARREL, BARREL_TEXTURE, Vector2(center.x - inward * 11.5, center.z + 6), Vector3(0.85, 1.2, 0.85), i * 0.8)
	for z: float in [-18.0, -58.0, -100.0, -156.0]:
		for x: float in [-11.0, 11.0]:
			_lamp(region, dressing, Vector2(x, z + 7.0))
	_lamp(region, dressing, Vector2(19, 25))

static func _prop(region: Node3D, parent: Node3D, scene: PackedScene, texture: Texture2D, p: Vector2, dimensions: Vector3, yaw: float) -> void:
	var anchor: Node3D = Node3D.new()
	anchor.name = "YardProp"
	anchor.position = Vector3(p.x, region.ground_height(p.x, p.y), p.y)
	anchor.rotation.y = yaw
	parent.add_child(anchor)
	var fit: Node3D = Node3D.new()
	anchor.add_child(fit)
	var model: Node3D = scene.instantiate() as Node3D
	# Imported scene lighting must not override the authored dusk lighting.
	for node: Node in model.find_children("*", "", true, false):
		if node is Light3D or node is Camera3D:
			node.get_parent().remove_child(node)
			node.queue_free()
	fit.add_child(model)
	var bounds: AABB
	var first: bool = true
	for mesh: MeshInstance3D in WorldModel.meshes(model):
		var local_bounds: AABB = (fit.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if first or bounds.size.x <= 0 or bounds.size.y <= 0 or bounds.size.z <= 0:
		push_error("Empty yard prop bounds: %s" % scene.resource_path)
		return
	var ratio: Vector3 = dimensions / bounds.size
	var uniform_scale: float = minf(ratio.x, minf(ratio.y, ratio.z))
	fit.scale = Vector3.ONE * uniform_scale
	fit.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * uniform_scale
	WorldModel.bind_texture(model, texture)
	anchor.set_meta(&"fitted_size", bounds.size * uniform_scale)
	anchor.set_meta(&"source", scene.resource_path)

static func _lamp(region: Node3D, parent: Node3D, p: Vector2) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.name = "LaneLamp"
	lamp.position = Vector3(p.x, region.ground_height(p.x, p.y), p.y)
	parent.add_child(lamp)
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_color = Color(0.09, 0.11, 0.10)
	metal.roughness = 0.8
	_part(lamp, Vector3(0, 2.15, 0), Vector3(0.14, 4.3, 0.14), metal)
	_part(lamp, Vector3(0, 4.5, 0), Vector3(0.65, 0.12, 0.65), metal)
	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.albedo_color = Color(0.95, 0.68, 0.34)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.32, 0.05)
	glow.emission_energy_multiplier = 6.0
	_part(lamp, Vector3(0, 4.25, 0), Vector3(0.6, 0.55, 0.6), glow)
	var light: OmniLight3D = OmniLight3D.new()
	light.position.y = 4.15
	light.light_color = Color(1.0, 0.67, 0.36)
	light.light_energy = 1.1
	light.omni_range = 12
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 3.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 250
	light.distance_fade_length = 40
	lamp.add_child(light)

static func _part(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

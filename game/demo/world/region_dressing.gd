extends RefCounted

const WorldModel = preload("res://game/world/world_model.gd")
const Catalog = preload("res://game/demo/targets/demo_asset_catalog.gd")
const Drainable = preload("res://game/draining/drainable.gd")
const VILLAGE_PROP_LIFE_MULTIPLIER: float = 80.0
const VILLAGE_PROP_RESISTANCE: float = 0.8
const MAILBOX = preload("res://available-assets/retro3d-assets/Buildings/Mailbox/LP_Mailbox.fbx")
const MAILBOX_TEXTURE = preload("res://available-assets/retro3d-assets/Buildings/Mailbox/LP_MailboxBase.png")
const CRATE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/crate.fbx")
const CRATE_TEXTURE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/textures/crate.png")
const BARREL = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/barrel3/Barrel1.glb")
const BARREL_TEXTURE = preload("res://available-assets/retro3d-assets/Boxes_Barrels_Crates/barrel3/Barrel1_Atlas.png")
const BENCH = preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/Props/station_bench.glb")
const BENCH_TEXTURE = preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/Props/station_bench_station_bench.png")
const STREET: String = "res://available-assets/random-packs/Street Furniture/"
const CLUTTER: Array[Array] = [
	["TrashCan", "TrashCan", Vector3(0.7, 1.1, 0.7)],
	["GarbageBag", "GarbageBag", Vector3(0.7, 0.6, 0.7)],
	["Сardboard", "cardboard", Vector3(1.0, 0.3, 0.8)],
	["Box", "Box", Vector3(0.8, 0.7, 0.8)],
	["Barrel", "barrel", Vector3(0.8, 1.2, 0.8)],
	["Bottles", "Bottles", Vector3(0.5, 0.4, 0.5)],
]

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
		for j: int in 3:
			var entry: Array = CLUTTER[(i + j) % CLUTTER.size()]
			var asset: String = entry[0]
			var stem: String = entry[1]
			var scene: PackedScene = load(STREET + asset + "/" + asset + ".fbx") as PackedScene
			var texture: Texture2D = load(STREET + asset + "/" + stem + ".png") as Texture2D
			_prop(region, dressing, scene, texture, Vector2(center.x - inward * (10.5 + j * 0.9), center.z - 4), entry[2], i * 0.43 + j, 0.0, asset in ["Сardboard", "Box"])
		if i % 4 == 0:
			_prop(region, dressing, BENCH, BENCH_TEXTURE, Vector2(center.x + inward * 11, center.z - 5), Vector3(2.4, 1.3, 1.0), PI * 0.5 * inward, 0.0, true)
		if i % 3 == 0:
			var building: Node3D = region._buildings[i]
			var size: Vector3 = building.fitted_size
			var p: Vector2 = Vector2(center.x + inward * (size.x * 0.5 + 0.22), center.z)
			_prop(region, dressing, load(STREET + "Conditioner/Conditioner.fbx") as PackedScene, load(STREET + "Conditioner/Conditioner.png") as Texture2D, p, Vector3(1.1, 0.7, 0.5), PI * 0.5 * inward, 3.0)
	for z: float in [-18.0, -58.0, -100.0, -156.0]:
		for x: float in [-11.0, 11.0]:
			_lamp(region, dressing, Vector2(x, z + 7.0))
	_lamp(region, dressing, Vector2(19, 25))
	for i: int in 8:
		var tool: String = "Hammer" if i % 2 == 0 else "Crowbar"
		var center: Vector3 = region.BUILDINGS[i]
		var inward: float = 1.0 if center.x < 0 else -1.0
		var p: Vector2 = Vector2(center.x - inward * 12, center.z - 7)
		var clear: bool = true
		for marker: Node3D in region._spawn_points:
			if p.distance_squared_to(Vector2(marker.position.x, marker.position.z)) < 16.0:
				clear = false
				break
		if clear:
			_prop(region, dressing, load(STREET + tool + "/" + tool + ".fbx") as PackedScene, load(STREET + tool + "/" + tool + ".png") as Texture2D, p, Vector3(0.8, 0.8, 0.8), i * 0.7)

static func _prop(region: Node3D, parent: Node3D, scene: PackedScene, texture: Texture2D, p: Vector2, dimensions: Vector3, yaw: float, elevation: float = 0.0, wooden: bool = false) -> void:
	if region._on_road(p, 1.5):
		return
	wooden = wooden or scene == CRATE or scene == BARREL
	var anchor: Node3D = Catalog.instantiate_model(&"yard_prop", scene, texture, dimensions, wooden)
	anchor.position = Vector3(p.x, region.ground_height(p.x, p.y) + elevation, p.y)
	anchor.rotation.y = yaw
	anchor.ground_position = region.ground_position
	_configure_village_prop(region, anchor)
	region._register_target(anchor)

static func _lamp(region: Node3D, parent: Node3D, p: Vector2) -> void:
	var lamp: Node3D = Node3D.new()
	lamp.name = "LaneLamp"
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
	for child: Node in lamp.get_children():
		child.owner = lamp
	var scene: PackedScene = PackedScene.new()
	scene.pack(lamp)
	lamp.free()
	var target: Node3D = Catalog.instantiate_model(&"lamp", scene, null, Vector3(0.65, 4.6, 0.65), false)
	target.preserve_model_lights = true
	target.position = Vector3(p.x, region.ground_height(p.x, p.y), p.y)
	target.ground_position = region.ground_position
	_configure_village_prop(region, target)
	region._register_target(target)

static func _configure_village_prop(region: Node3D, target: Node3D) -> void:
	if region.get_zone_at(region.to_global(target.position)) != &"village":
		return
	var drainable: Drainable = target.get_node("Drainable") as Drainable
	drainable.life_modifier *= VILLAGE_PROP_LIFE_MULTIPLIER
	drainable.drain_speed_multiplier *= VILLAGE_PROP_LIFE_MULTIPLIER / VILLAGE_PROP_RESISTANCE

static func _part(parent: Node3D, position: Vector3, dimensions: Vector3, material: Material) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)

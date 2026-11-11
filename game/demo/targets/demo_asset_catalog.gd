extends RefCounted

const Scenery = preload("res://game/demo/targets/demo_scenery.gd")
const Target = preload("res://game/demo/targets/demo_target.gd")
const DepletionEffect = preload("res://game/draining/depletion_effect.gd")
const Scaling = preload("res://game/draining/drain_scaling.gd")
const CityAssets = preload("res://game/demo/city/city_assets.gd")
const ROOT: String = "res://available-assets/retro3d-assets/"
const Forest = preload("res://game/demo/world/forest_assets.gd")

static func instantiate_target(kind: StringName, dimensions: Vector3) -> Node3D:
	var wrapper: Target = Target.new()
	_configure(wrapper, kind, dimensions)
	wrapper.building_collapse = CityAssets.has_building(kind) or kind in [&"house1", &"house2", &"house3", &"house4", &"house5", &"shed"]
	match kind:
		&"bush", &"bush_alt", &"tree", &"tree_alt", &"pine", &"forest_tree1", &"forest_tree2", &"forest_tree3", &"forest_tree4", &"forest_trunk":
			wrapper.depletion_style = DepletionEffect.Style.WOODEN
		_:
			wrapper.depletion_style = DepletionEffect.Style.RUBBLE
	if String(kind).contains("tree"):
		wrapper.blocking = true
	wrapper.configure_drain()
	match kind:
		&"tree", &"tree_alt", &"pine", &"forest_tree1", &"forest_tree2", &"forest_tree3", &"forest_tree4":
			wrapper.drainable.drain_speed_multiplier = 3.0
		&"house1", &"house2", &"house3", &"house4", &"house5":
			wrapper.drainable.drain_speed_multiplier = Scaling.VILLAGE_HOUSE_DRAIN_MULTIPLIER
		&"city_highrise_1", &"city_highrise_2", &"city_highrise_3", &"city_tower_1", &"city_tower_2", &"city_tower_3", &"city_tower_4", &"city_plaza_tower", &"city_landmark":
			wrapper.drainable.drain_speed_multiplier = 2.0
		_:
			pass
	return wrapper

static func instantiate_scenery(kind: StringName, dimensions: Vector3) -> Node3D:
	var wrapper: Scenery = Scenery.new()
	_configure(wrapper, kind, dimensions)
	return wrapper

static func instantiate_model(kind: StringName, scene: PackedScene, texture: Texture2D, dimensions: Vector3, wooden: bool) -> Node3D:
	var wrapper: Target = Target.new()
	wrapper.name = String(kind).to_pascal_case()
	wrapper.kind = kind
	wrapper.model_scene = scene
	wrapper.texture = texture
	wrapper.dimensions = dimensions
	wrapper.depletion_style = DepletionEffect.Style.WOODEN if wooden else DepletionEffect.Style.RUBBLE
	wrapper.configure_drain()
	return wrapper

static func _configure(wrapper: Scenery, kind: StringName, dimensions: Vector3) -> void:
	wrapper.name = String(kind).to_pascal_case()
	wrapper.dimensions = dimensions
	wrapper.kind = kind
	if CityAssets.has_building(kind):
		wrapper.model_scene = CityAssets.building_scene(kind)
		wrapper.texture = CityAssets.building_texture(kind)
		wrapper.blocking = true
		return
	match kind:
		&"forest_tree1", &"forest_tree2", &"forest_tree3", &"forest_tree4", &"forest_trunk", &"forest_rock":
			var object_name: StringName = {&"forest_tree1": &"PSX_Tree1", &"forest_tree2": &"PSX_Tree2", &"forest_tree3": &"PSX_Tree3", &"forest_tree4": &"PSX_Tree4", &"forest_trunk": &"PSX_Treetrunk", &"forest_rock": &"PSX_Rock"}[kind]
			wrapper.model_scene = Forest.scene(object_name)
			wrapper.blocking = kind in [&"forest_trunk", &"forest_rock"]
		&"bush", &"bush_alt", &"tree", &"tree_alt":
			var asset: String = {&"bush": "bush02", &"bush_alt": "bush04", &"tree": "tree01", &"tree_alt": "tree04"}[kind]
			wrapper.model_scene = load(ROOT + "Nature/tree_pack_1.1/models/" + asset + ".fbx") as PackedScene
			wrapper.texture = load(ROOT + "Nature/tree_pack_1.1/textures/" + asset + ".png") as Texture2D
			wrapper.cutout = true
		&"pine":
			wrapper.model_scene = load(ROOT + "Nature/exports/trees/pine_tree.glb") as PackedScene
		&"rock":
			wrapper.model_scene = load(ROOT + "Nature/exports/rocks/rock.glb") as PackedScene
		&"house1", &"house2", &"house3", &"house4", &"house5":
			wrapper.model_scene = load(ROOT + "Buildings/retro_house_pack/models/glb/" + String(kind) + ".glb") as PackedScene
			wrapper.texture = load(ROOT + "Buildings/retro_house_pack/textures/256x256/" + String(kind) + "_tex1.png") as Texture2D
			wrapper.blocking = true
		&"shed":
			wrapper.model_scene = load(ROOT + "Industrial/Shacks Shanties Sheds and Gantries 0001/Large Shed A.blend") as PackedScene
			wrapper.texture = load(ROOT + "Industrial/Shacks Shanties Sheds and Gantries 0001/Shed Corrugated Texture.png") as Texture2D
			wrapper.frame_texture = load(ROOT + "Industrial/Shacks Shanties Sheds and Gantries 0001/Shed Frame Texture.png") as Texture2D
			wrapper.model_yaw = PI * 0.5
			wrapper.blocking = true
		_:
			push_error("Unknown demo asset kind: %s" % kind)

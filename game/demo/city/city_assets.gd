extends RefCounted

const ROOT: String = "res://available-assets/retro3d-assets/"
const BUILDING_ROOT: String = ROOT + "Buildings/skyscraper_pack/"
const APARTMENT_ROOT: String = ROOT + "Buildings/Bui/Bui/"

const BUILDING_DATA: Dictionary = {
	&"city_storefront_1": {"model": "building_01.2", "texture": "building_01", "base": Vector3(25, 37, 25)},
	&"city_storefront_2": {"model": "building_01.4", "texture": "building_01", "base": Vector3(49, 37, 49)},
	&"city_workshop": {"model": "building_02.2", "texture": "building_02", "base": Vector3(33, 49, 33)},
	&"city_loft": {"model": "building_03.2", "texture": "building_03", "base": Vector3(29, 49, 29)},
	&"city_shop": {"model": "building_04.2", "texture": "building_04", "base": Vector3(33, 63, 33)},
	&"city_clinic": {"model": "building_05.2", "texture": "building_05", "base": Vector3(33, 61, 33)},
	&"city_office": {"model": "building_06.2", "texture": "building_06", "base": Vector3(33, 61, 33)},
	&"city_apartment": {"model": "building_07.2", "texture": "building_07", "base": Vector3(33, 61, 33)},
	&"city_warehouse": {"model": "building_08.2", "texture": "building_08", "base": Vector3(65, 37, 65)},
	&"city_highrise_1": {"model": "building_01.1", "texture": "building_01", "base": Vector3(25, 73, 25)},
	&"city_highrise_2": {"model": "building_02.1", "texture": "building_02", "base": Vector3(33, 97, 33)},
	&"city_highrise_3": {"model": "building_03.1", "texture": "building_03", "base": Vector3(29, 97, 29)},
	&"city_tower_1": {"model": "building_04.1", "texture": "building_04", "base": Vector3(33, 125, 33)},
	&"city_tower_2": {"model": "building_05.1", "texture": "building_05", "base": Vector3(33, 121, 33)},
	&"city_tower_3": {"model": "building_06.1", "texture": "building_06", "base": Vector3(33, 121, 33)},
	&"city_tower_4": {"model": "building_07.1", "texture": "building_07", "base": Vector3(33, 121, 33)},
	&"city_plaza_tower": {"model": "building_08.1", "texture": "building_08", "base": Vector3(65, 73, 65)},
	&"city_landmark": {"model": "building_01.3", "texture": "building_01", "base": Vector3(49, 73, 49)},
	&"city_police": {"model": "building_01.2", "texture": "building_01", "base": Vector3(25, 37, 25)},
	&"city_house_1": {"scene": "house_1.tscn", "texture": "building (15).jpg", "base": Vector3(8.539413, 11.21364, 6.213289)},
	&"city_house_2": {"scene": "house_2.tscn", "texture": "building (12).jpg", "base": Vector3(6.486076, 6.848096, 4.675872)},
	&"city_house_3": {"scene": "house_3.tscn", "texture": "building (7).jpg", "base": Vector3(4.819472, 6.094886, 3.994448)},
}

const ROAD_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/roadAsphalt_straight_asphalt.png")
const SIDEWALK_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Buildings/Old building 1/sidewalk_lowres.png")

const BENCH: PackedScene = preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/Props/station_bench.glb")
const BENCH_TEXTURE: Texture2D = preload("res://available-assets/random-packs/Cordatix_PSXBystanders_FreeSampler_v1.0/GLB/Props/station_bench_station_bench.png")
const FOUNTAIN_ROUND: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/stone/fountain01_round.fbx")
const FOUNTAIN_SQUARE: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/stone/fountain01_square.fbx")
const GAZEBO: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/gazebo.fbx")
const FLOWERBED: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/misc_models/flowers/flowerbed1_2x2.fbx")
const HEDGE_LONG: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/modular_hedge/basic/basic_4x1.fbx")
const HEDGE_SQUARE: PackedScene = preload("res://available-assets/retro3d-assets/Nature/Hedge Maze/hedge_maze_pack/modular_hedge/basic/basic_2x2.fbx")
const TRUCK_GREEN: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/truck_green.glb")
const TRUCK_GREY: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/truck_grey.glb")
const BARRIER_A: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/detailBarrier_typeA.glb")
const BARRIER_B: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/detailBarrier_typeB.glb")
const BARRIER_STRONG: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/detailBarrierStrong_typeA.glb")
const DUMPSTER: PackedScene = preload("res://available-assets/retro3d-assets/Buildings/Building kit/Models/GLTF format/detailDumpster_closed.glb")

static var _scenes: Dictionary[StringName, PackedScene] = {}
static var _textures: Dictionary[StringName, Texture2D] = {}

static func has_building(kind: StringName) -> bool:
	return BUILDING_DATA.has(kind)

static func building_scene(kind: StringName) -> PackedScene:
	if not _scenes.has(kind):
		var data: Dictionary = BUILDING_DATA[kind]
		if data.has("scene"):
			_scenes[kind] = load("res://game/demo/city/houses/" + String(data["scene"])) as PackedScene
		else:
			_scenes[kind] = load(BUILDING_ROOT + "models/" + String(data["model"]) + ".fbx") as PackedScene
	return _scenes[kind]

static func building_texture(kind: StringName) -> Texture2D:
	if not _textures.has(kind):
		var data: Dictionary = BUILDING_DATA[kind]
		var texture_path := APARTMENT_ROOT + String(data["texture"]) if data.has("scene") else BUILDING_ROOT + "textures/" + String(data["texture"]) + ".png"
		_textures[kind] = load(texture_path) as Texture2D
	return _textures[kind]

static func building_base(kind: StringName) -> Vector3:
	var data: Dictionary = BUILDING_DATA[kind]
	return Vector3(data["base"])

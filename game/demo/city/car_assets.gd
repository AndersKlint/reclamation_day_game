extends RefCounted

const ROOT: String = "res://available-assets/retro3d-assets/Vehicles/PSX_Style_Cars_by_GGBot_(September2022)/"

const CAR_VARIANTS: Array[Dictionary] = [
	{"model": "Car 01/Car.obj", "texture": "Car 01/car.png"},
	{"model": "Car 02/Car2.obj", "texture": "Car 02/car2.png"},
	{"model": "Car 03/Car3.obj", "texture": "Car 03/car3.png"},
	{"model": "Car 04/Car4.obj", "texture": "Car 04/car4.png"},
	{"model": "Car 05/Car5.obj", "texture": "Car 05/car5.png"},
	{"model": "Car 06/Car6.obj", "texture": "Car 06/car6.png"},
	{"model": "Car 07/Car7.obj", "texture": "Car 07/car7.png"},
	{"model": "Car 05/Car5_Police.obj", "texture": "Car 05/car5_police.png"},
	{"model": "Car 05/Car5_Taxi.obj", "texture": "Car 05/car5_taxi.png"},
]

const CIVILIAN_COUNT: int = 7
const POLICE: int = 7
const TAXI: int = 8

static var _scenes: Dictionary[int, PackedScene] = {}
static var _textures: Dictionary[int, Texture2D] = {}

static func count() -> int:
	return CAR_VARIANTS.size()

static func normalize(variant: int) -> int:
	return posmod(variant, CAR_VARIANTS.size())

static func scene(variant: int) -> PackedScene:
	var index: int = normalize(variant)
	if not _scenes.has(index):
		var mesh: Mesh = load(ROOT + String(CAR_VARIANTS[index]["model"])) as Mesh
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.name = "Car"
		instance.mesh = mesh
		var packed: PackedScene = PackedScene.new()
		var error: Error = packed.pack(instance)
		instance.free()
		if error != OK:
			push_error("Could not pack car variant %d" % index)
			return null
		_scenes[index] = packed
	return _scenes[index]

static func texture(variant: int) -> Texture2D:
	var index: int = normalize(variant)
	if not _textures.has(index):
		_textures[index] = load(ROOT + String(CAR_VARIANTS[index]["texture"])) as Texture2D
	return _textures[index]

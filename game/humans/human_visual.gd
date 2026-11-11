extends Node3D

const CHARACTER = preload("res://game/characters/rigged_character.gd")
const CIVILIANS: Array[String] = ["Male/Character_02", "Male/Character_05", "Female/Character_Female_02"]
const POLICE: String = "Male/Character_18_Police"
const GUN_MUZZLE: Vector3 = Vector3(-0.411244, 0.115697, 0.0)
const GUN: Mesh = preload("res://available-assets/retro3d-assets/Characters/PoliceOfficerSet/Gun_and_Car_OBJ/Gun.obj")
const GUN_TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Characters/PoliceOfficerSet/Textures/Details_and_Gun.png")

var _character: CHARACTER
var _ranged: bool = false
var _hand: BoneAttachment3D
var _muzzle: Marker3D
var female_voice: bool = false

func configure(ranged: bool) -> void:
	_ranged = ranged
	var path: String = POLICE if ranged else CIVILIANS.pick_random()
	female_voice = path.begins_with("Female/")
	_character = CHARACTER.new()
	add_child(_character)
	_character.configure(path, path.get_file(), 1.8)
	if ranged:
		var skeleton: Skeleton3D = _character.skeleton
		_hand = BoneAttachment3D.new()
		skeleton.add_child(_hand)
		_hand.bone_name = "mixamorig_RightHand"
		_hand.on_skeleton_update()
		var gun: MeshInstance3D = MeshInstance3D.new()
		gun.mesh = GUN
		_hand.add_child(gun)
		var hand_scale: float = skeleton.global_basis.get_scale().x
		gun.scale = Vector3.ONE * (0.3 / maxf(GUN.get_aabb().get_longest_axis_size() * hand_scale, 0.00001))
		gun.rotation.z = -PI / 2.0
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = GUN_TEXTURE
		gun.material_override = material
		_muzzle = Marker3D.new()
		_muzzle.name = "Muzzle"
		gun.add_child(_muzzle)
		_muzzle.position = GUN_MUZZLE

func get_muzzle_position() -> Vector3:
	if _muzzle == null:
		return global_position
	_hand.on_skeleton_update()
	return _muzzle.global_position

func update_pose(horizontal: Vector3, attacking: bool, delta: float) -> void:
	_character.update_pose(horizontal, attacking, _ranged, delta)

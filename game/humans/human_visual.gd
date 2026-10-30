extends Node3D

const ROOT: String = "res://available-assets/retro3d-assets/Characters/"
const FARMER: PackedScene = preload(ROOT + "adultman__/FBX_mixamo/AdultMan___.fbx")
const POLICE: PackedScene = preload(ROOT + "PoliceOfficerSet/Police_Officer_FBX/Mesh/MeshRigged.fbx")
const WALK: PackedScene = preload(ROOT + "PoliceOfficerSet/Police_Officer_FBX/Animation/GermanPoliceOfficer_anim_walk.fbx")
const AIM: PackedScene = preload(ROOT + "PoliceOfficerSet/Police_Officer_FBX/Animation/GermanPoliceOfficer_anim_Aim.fbx")
const IDLE: PackedScene = preload(ROOT + "PoliceOfficerSet/Police_Officer_FBX/Animation/GermanPoliceOfficer_anim_Idle.fbx")
const GUN: Mesh = preload(ROOT + "PoliceOfficerSet/Gun_and_Car_OBJ/Gun.obj")

var _animation: AnimationPlayer
var _farmer_skeleton: Skeleton3D
var _phase: float = 0.0

func configure(police: bool) -> void:
	var model: Node3D = (POLICE if police else FARMER).instantiate() as Node3D
	add_child(model)
	model.process_mode = Node.PROCESS_MODE_PAUSABLE
	model.rotation.y = PI
	var bounds: AABB
	var initialized: bool = false
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = _posed_bounds(mesh, model)
		# Imported bind-space bounds omit the skeleton's unit and axis conversion.
		mesh.custom_aabb = (mesh.global_transform.affine_inverse() * model.global_transform) * box.grow(box.size.y * 0.2)
		bounds = bounds.merge(box) if initialized else box
		initialized = true
		for index: int in mesh.mesh.get_surface_count():
			var material: StandardMaterial3D = StandardMaterial3D.new()
			var texture_path: String = "adultman__/textures/ADULT_Texture_LOWRES.jpg"
			if police:
				texture_path = "PoliceOfficerSet/Textures/GermanPoliceOfficer_%s.jpg" % ("Body256" if index == 0 else "Face128")
			material.albedo_texture = load(ROOT + texture_path) as Texture2D
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			mesh.set_surface_override_material(index, material)
	var fit: float = 1.8 / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * fit
	model.position.y = -bounds.position.y * fit
	if police:
		_animation = model.get_node("AnimationPlayer") as AnimationPlayer
		var library: AnimationLibrary = AnimationLibrary.new()
		for entry: Array in [[WALK, "Armature|ArmatureAction", "walk"], [AIM, "Armature|Aim", "aim"], [IDLE, "Armature|Idle", "idle"]]:
			var source: Node = (entry[0] as PackedScene).instantiate()
			var player: AnimationPlayer = source.get_node("AnimationPlayer") as AnimationPlayer
			var clip: Animation = player.get_animation(entry[1]).duplicate() as Animation
			clip.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(entry[2], clip)
			source.free()
		_animation.add_animation_library(&"human", library)
		var skeleton: Skeleton3D = model.get_node("Armature/Skeleton3D") as Skeleton3D
		var hand: BoneAttachment3D = BoneAttachment3D.new()
		skeleton.add_child(hand)
		hand.bone_name = "Hand.R"
		var gun: MeshInstance3D = MeshInstance3D.new()
		gun.mesh = GUN
		hand.add_child(gun)
		var hand_scale: float = (skeleton.global_basis * skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R")).basis).get_scale().x
		var gun_fit: float = 0.3 / maxf(GUN.get_aabb().get_longest_axis_size() * hand_scale, 0.00001)
		gun.scale = Vector3.ONE * gun_fit
		gun.rotation.y = -PI / 2.0
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_texture = preload(ROOT + "PoliceOfficerSet/Textures/Details_and_Gun.png")
		gun.material_override = material
	else:
		_farmer_skeleton = model.get_node("Armature/Skeleton3D") as Skeleton3D

func _posed_bounds(mesh: MeshInstance3D, model: Node3D) -> AABB:
	var skeleton: Skeleton3D = mesh.get_node(mesh.skeleton) as Skeleton3D
	var transforms: Array[Transform3D] = []
	for index: int in mesh.skin.get_bind_count():
		var bone: int = skeleton.find_bone(mesh.skin.get_bind_name(index))
		if bone < 0:
			bone = mesh.skin.get_bind_bone(index)
		transforms.append(model.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
	var bounds: AABB
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
			bounds = bounds.expand(point) if initialized else AABB(point, Vector3.ZERO)
			initialized = true
	return bounds

func update_pose(horizontal: Vector3, attacking: bool, delta: float) -> void:
	var moving: bool = horizontal.length_squared() > 0.04
	if _animation != null:
		_animation.play(&"human/aim" if attacking else (&"human/walk" if moving else &"human/idle"), 0.15)
	else:
		_phase += delta * (8.0 if moving else 0.0)
		for index: int in _farmer_skeleton.get_bone_count():
			var bone: String = _farmer_skeleton.get_bone_name(index).to_lower()
			if "upperarm" in bone or "upper_arm" in bone:
				var side: float = -1.0 if "left" in bone or ".l" in bone else 1.0
				var rest: Quaternion = _farmer_skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
				_farmer_skeleton.set_bone_pose_rotation(index, rest * Quaternion.from_euler(Vector3(-0.9 if attacking else sin(_phase) * 0.2, 0.0, side * 1.1)))
			elif "upperleg" in bone:
				var side: float = -1.0 if ".l" in bone else 1.0
				var rest: Quaternion = _farmer_skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
				_farmer_skeleton.set_bone_pose_rotation(index, rest * Quaternion(Vector3.RIGHT, sin(_phase) * 0.3 * side if moving else 0.0))

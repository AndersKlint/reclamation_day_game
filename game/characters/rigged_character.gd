extends Node3D

const ROOT: String = "res://available-assets/random-packs/characters/Characters_psx_1.2/Characters_psx_02/"

var skeleton: Skeleton3D
var _forward: Vector3
var _down: Vector3
var _phase: float = 0.0
var _stride: float = 0.0

func configure(model_path: String, texture_name: String, height: float, _monster: bool = false) -> void:
	var model: Node3D = (load(ROOT + "Models/Rig/" + model_path + ".fbx") as PackedScene).instantiate() as Node3D
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	var model_to_skeleton: Basis = (model.global_transform.affine_inverse() * skeleton.global_transform).basis.orthonormalized().inverse()
	_forward = model_to_skeleton * Vector3.BACK
	_down = model_to_skeleton * Vector3.DOWN
	for node: Node in model.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).active = false
	skeleton.reset_bone_poses()
	var bounds: AABB
	var initialized: bool = false
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = load(ROOT + "Textures/" + texture_name + ".png") as Texture2D
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = _posed_bounds(mesh, model)
		# Bind-space bounds omit imported skeleton transforms.
		mesh.custom_aabb = (mesh.global_transform.affine_inverse() * model.global_transform) * box.grow(height * 0.25)
		mesh.material_override = material
		bounds = bounds.merge(box) if initialized else box
		initialized = true
	var fit: float = height / maxf(bounds.size.y, 0.01)
	model.scale = Vector3.ONE * fit
	model.rotation.y = PI
	var center: Vector3 = bounds.get_center()
	model.position = -(model.basis * Vector3(center.x, bounds.position.y, center.z))
	update_pose(Vector3.ZERO, false, false, 0.0)

func update_pose(horizontal: Vector3, attacking: bool, ranged: bool, delta: float) -> void:
	_phase += delta * 8.0
	_stride = move_toward(_stride, 1.0 if horizontal.length_squared() > 0.04 else 0.0, delta * 6.0)
	for side: String in ["Left", "Right"]:
		var sign_value: float = 1.0 if side == "Left" else -1.0
		var swing: float = sin(_phase) * 0.35 * _stride * sign_value
		var arm_forward: float = -swing + sin(_phase * 0.25) * 0.025
		if attacking:
			arm_forward = 1.8 if ranged else 1.0 + sin(_phase * 1.5) * 0.65
		_point_bone(side + "Arm", _down * (0.25 if attacking else 1.0) + _forward * arm_forward)
		_point_bone(side + "ForeArm", _down * (0.1 if attacking else 0.9) + _forward * (1.0 if attacking else 0.15))
		_point_bone(side + "UpLeg", _down + _forward * swing)
		var knee_bend: float = maxf(0.0, swing) * 1.8 + 0.04 * _stride
		_point_bone(side + "Leg", _down + _forward * (swing - knee_bend))
		var foot: int = skeleton.find_bone("mixamorig_" + side + "Foot")
		if foot >= 0:
			_set_bone_global_rotation(foot, skeleton.get_bone_global_rest(foot).basis.orthonormalized().get_rotation_quaternion())

func _point_bone(suffix: String, direction: Vector3) -> void:
	var bone: int = skeleton.find_bone("mixamorig_" + suffix)
	if bone < 0:
		return
	var rest: Basis = skeleton.get_bone_global_rest(bone).basis.orthonormalized()
	var target: Quaternion = Quaternion(rest.y, direction.normalized()) * rest.get_rotation_quaternion()
	_set_bone_global_rotation(bone, target)

func _set_bone_global_rotation(bone: int, target: Quaternion) -> void:
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_rotation: Quaternion = skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	skeleton.set_bone_pose_rotation(bone, parent_rotation.inverse() * target)

func _posed_bounds(mesh: MeshInstance3D, model: Node3D) -> AABB:
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

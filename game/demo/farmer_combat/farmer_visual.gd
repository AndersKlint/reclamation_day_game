extends Node3D

const WorldModel = preload("res://game/world/world_model.gd")

# Farmer model: Max Damage (maxdamage_farmer_v1.0); credit required, source assets must not be redistributed.
const MODEL: PackedScene = preload("res://available-assets/random-packs/maxdamage_farmer_v1.0/maxdamage_farmer.blend")
const TEXTURE: Texture2D = preload("res://available-assets/random-packs/maxdamage_farmer_v1.0/t_farmer1.png")
const TARGET_HEIGHT: float = 1.9

const WOOD_COLOR: Color = Color(0.34, 0.22, 0.12)
const IRON_COLOR: Color = Color(0.34, 0.36, 0.38)

var skeleton: Skeleton3D
var body_dimensions: Vector3 = Vector3(0.75, 1.9, 0.45)

var _holder: Node3D
var _mesh: MeshInstance3D
var _hoe: Node3D
var _walk_phase: float = 0.0
var _stopped: bool = false
var _posed_global: Dictionary = {}
var _holding_side: StringName = &"R"


func configure() -> bool:
	var source: Node = MODEL.instantiate()
	for node: Node in source.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).active = false
	var source_skeleton: Skeleton3D = null
	for node: Node in source.find_children("*", "Skeleton3D", true, false):
		var candidate: Skeleton3D = node as Skeleton3D
		if candidate.find_bone(&"Bicep.R") >= 0:
			source_skeleton = candidate
			break
	if source_skeleton == null:
		for node: Node in source.find_children("*", "Skeleton3D", true, false):
			source_skeleton = node as Skeleton3D
			break
	var source_mesh: MeshInstance3D = null
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var candidate: MeshInstance3D = node as MeshInstance3D
		if candidate.name == &"Farmer":
			source_mesh = candidate
			break
		if source_mesh == null and candidate.skin != null:
			source_mesh = candidate
	if source_skeleton == null or source_mesh == null:
		push_error("Farmer model is missing its skeleton or skinned body mesh")
		source.queue_free()
		return false

	_holder = Node3D.new()
	_holder.name = "Model"
	add_child(_holder)
	add_child(source)
	source_skeleton.reparent(_holder, true)
	source_mesh.reparent(_holder, true)
	source_mesh.skeleton = source_mesh.get_path_to(source_skeleton)
	source.queue_free()
	skeleton = source_skeleton
	_mesh = source_mesh
	_holding_side = &"R" if skeleton.find_bone(&"Hand.R") >= 0 else &"L"

	_mesh.material_override = _body_material()
	skeleton.reset_bone_poses()
	update_pose(0.0, 0.0, 0.0, 0.0)
	var bounds: AABB = WorldModel.mesh_bounds(_mesh, _holder, true)
	var fit: float = TARGET_HEIGHT / maxf(bounds.size.y, 0.01)
	_holder.scale = Vector3.ONE * fit
	_holder.rotation.y = PI
	var center: Vector3 = bounds.get_center()
	_holder.position = -(_holder.basis * Vector3(center.x, bounds.position.y, center.z))
	body_dimensions = bounds.size * fit

	var local_bounds: AABB = (_mesh.global_transform.affine_inverse() * _holder.global_transform) * bounds
	_mesh.custom_aabb = local_bounds.grow(local_bounds.size.length() * 0.75)

	_attach_hoe()
	return true


func stop() -> void:
	_stopped = true


func update_pose(move_amount: float, raise_amount: float, chop_amount: float, delta: float) -> void:
	if _stopped or _skeleton_missing():
		return
	var moving: float = clampf(move_amount, 0.0, 1.0)
	var chopping: float = clampf(chop_amount, 0.0, 1.0)
	var raising: float = clampf(raise_amount, 0.0, 1.0 - chopping)
	_walk_phase = fmod(_walk_phase + delta * lerpf(2.0, 9.0, moving), TAU)
	skeleton.reset_bone_poses()
	_posed_global.clear()
	_pose_torso(raising, chopping)
	_pose_arm(&"L", raising if _holding_side == &"L" else 0.0, chopping if _holding_side == &"L" else 0.0, sin(_walk_phase) * 0.22 * moving)
	_pose_arm(&"R", raising if _holding_side == &"R" else 0.0, chopping if _holding_side == &"R" else 0.0, -sin(_walk_phase) * 0.22 * moving)
	_pose_legs(moving)


func update_horizontal_pose(charge: float, sweep: float, recovery: float, arc: float, delta: float) -> void:
	update_pose(0.0, 0.0, 0.0, delta)
	if _stopped or _skeleton_missing() or not is_instance_valid(_hoe):
		return
	var weight: float = clampf(charge, 0.0, 1.0) * (1.0 - clampf(recovery, 0.0, 1.0))
	var angle: float = lerpf(-arc * 0.5, arc * 0.5, clampf(sweep, 0.0, 1.0))
	var shaft_direction: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, angle)
	var holding_target: Vector3 = Vector3.UP * 1.25 + shaft_direction * 0.28
	_pose_reaching_arm(_holding_side, holding_target, weight)
	_point_visual_bone(StringName("Hand." + String(_holding_side)), shaft_direction, weight)
	var hand: int = skeleton.find_bone(StringName("Hand." + String(_holding_side)))
	if hand < 0:
		return
	var hand_to_visual: Transform3D = global_transform.affine_inverse() * skeleton.global_transform * _frame_global(hand)
	var support_target: Vector3 = hand_to_visual * (_hoe.transform * Vector3(0.0, 0.11, 0.0))
	var support_side: StringName = &"L" if _holding_side == &"R" else &"R"
	_pose_reaching_arm(support_side, support_target, weight)
	_point_visual_bone(StringName("Hand." + String(support_side)), shaft_direction, weight)


func _pose_reaching_arm(side: StringName, target: Vector3, weight: float) -> void:
	var upper_name: StringName = StringName("Bicep." + String(side))
	var lower_name: StringName = StringName("Forearm." + String(side))
	var upper: int = skeleton.find_bone(upper_name)
	var lower: int = skeleton.find_bone(lower_name)
	var hand: int = skeleton.find_bone(StringName("Hand." + String(side)))
	if upper < 0 or lower < 0 or hand < 0 or weight <= 0.0:
		return
	var skeleton_to_visual: Transform3D = global_transform.affine_inverse() * skeleton.global_transform
	var shoulder: Vector3 = skeleton_to_visual * _frame_global(upper).origin
	var elbow: Vector3 = skeleton_to_visual * _frame_global(lower).origin
	var wrist: Vector3 = skeleton_to_visual * _frame_global(hand).origin
	var upper_length: float = shoulder.distance_to(elbow)
	var lower_length: float = elbow.distance_to(wrist)
	if minf(upper_length, lower_length) <= 0.0001:
		return
	var reach: Vector3 = target - shoulder
	var direction: Vector3 = reach.normalized()
	if direction.is_zero_approx():
		return
	var distance: float = clampf(reach.length(), absf(upper_length - lower_length) + 0.0001, upper_length + lower_length - 0.0001)
	var along: float = (upper_length * upper_length - lower_length * lower_length + distance * distance) / (2.0 * distance)
	var bend_height: float = sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var outward: float = -1.0 if side == &"R" else 1.0
	var pole: Vector3 = Vector3(outward, -0.45, 0.35)
	var bend: Vector3 = (pole - direction * pole.dot(direction)).normalized()
	if bend.is_zero_approx():
		bend = direction.cross(Vector3.UP).normalized()
	var elbow_target: Vector3 = shoulder + direction * along + bend * bend_height
	_posed_global.erase(lower)
	_posed_global.erase(hand)
	_point_visual_bone(upper_name, elbow_target - shoulder, weight)
	elbow = skeleton_to_visual * _frame_global(lower).origin
	_point_visual_bone(lower_name, shoulder + direction * distance - elbow, weight)


func _point_visual_bone(bone_name: StringName, direction: Vector3, weight: float) -> void:
	_point_bone(bone_name, _holder.basis.inverse() * direction, weight)


func _skeleton_missing() -> bool:
	return not is_instance_valid(skeleton) or not is_instance_valid(_mesh)


func _body_material() -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = TEXTURE
	material.albedo_color = Color.WHITE
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return material


func _pose_torso(raise: float, chop: float) -> void:
	var lean: float = chop * 0.24 - raise * 0.14
	_point_bone(&"Spine.002", Vector3(0.0, 1.0, lean * 0.4))
	_point_bone(&"Spine.003", Vector3(0.0, 1.0, lean))
	_point_bone(&"Head", Vector3(0.0, 1.0, -lean * 0.35))


func _pose_arm(side: StringName, raise: float, chop: float, sway: float) -> void:
	var mirror: float = 1.0 if side == &"L" else -1.0
	var idle: float = 1.0 - raise - chop
	var bicep: Vector3 = Vector3(0.18 * mirror, -1.0, sway) * idle
	bicep += Vector3(0.12 * mirror, 0.78, -0.72) * raise
	bicep += Vector3(0.12 * mirror, -0.68, 0.82) * chop
	var forearm: Vector3 = Vector3(0.10 * mirror, -0.82, 0.55 + sway * 0.5) * idle
	forearm += Vector3(0.10 * mirror, 0.88, -0.42) * raise
	forearm += Vector3(0.10 * mirror, -0.48, 0.86) * chop
	var hand: Vector3 = Vector3(0.05 * mirror, -0.12, 0.99) * idle
	hand += Vector3(0.05 * mirror, 0.52, -0.85) * raise
	hand += Vector3(0.05 * mirror, -0.74, 0.67) * chop
	_point_bone(StringName("Bicep." + String(side)), bicep)
	_point_bone(StringName("Forearm." + String(side)), forearm)
	_point_bone(StringName("Hand." + String(side)), hand)


func _pose_legs(move_amount: float) -> void:
	if move_amount <= 0.01:
		return
	var stride: float = sin(_walk_phase) * 0.5 * move_amount
	_point_bone(&"Thigh.L", Vector3(0.02, -1.0, stride))
	_point_bone(&"Calf.L", Vector3(0.0, -1.0, -maxf(0.0, stride) * 0.8))
	_point_bone(&"Foot.L", Vector3(0.0, -0.18, 0.98))
	_point_bone(&"Thigh.R", Vector3(-0.02, -1.0, -stride))
	_point_bone(&"Calf.R", Vector3(0.0, -1.0, -maxf(0.0, -stride) * 0.8))
	_point_bone(&"Foot.R", Vector3(0.0, -0.18, 0.98))


func _point_bone(bone_name: StringName, direction: Vector3, weight: float = 1.0) -> void:
	var bone: int = skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var target_direction: Vector3 = (skeleton.transform.basis.inverse() * direction).normalized()
	if target_direction.is_zero_approx():
		return
	var parent: int = skeleton.get_bone_parent(bone)
	var parent_global: Transform3D = _frame_global(parent) if parent >= 0 else Transform3D.IDENTITY
	var rest_local: Transform3D = skeleton.get_bone_rest(bone)
	var rest_global: Basis = skeleton.get_bone_global_rest(bone).basis.orthonormalized()
	var target_basis: Basis = Basis(Quaternion(rest_global.y, target_direction)) * rest_global
	var local_rotation: Quaternion = (parent_global.basis.orthonormalized().inverse() * target_basis).get_rotation_quaternion()
	local_rotation = skeleton.get_bone_pose_rotation(bone).slerp(local_rotation, clampf(weight, 0.0, 1.0))
	skeleton.set_bone_pose_rotation(bone, local_rotation)
	var local_pose: Transform3D = Transform3D(Basis(local_rotation).scaled_local(rest_local.basis.get_scale()), rest_local.origin)
	_posed_global[bone] = parent_global * local_pose


func _frame_global(bone: int) -> Transform3D:
	if bone < 0:
		return Transform3D.IDENTITY
	if _posed_global.has(bone):
		return _posed_global[bone]
	var parent: int = skeleton.get_bone_parent(bone)
	var rest: Transform3D = skeleton.get_bone_rest(bone)
	if parent < 0:
		return rest
	return _frame_global(parent) * rest


func _attach_hoe() -> void:
	var hand_bone: StringName = StringName("Hand." + String(_holding_side))
	if skeleton.find_bone(hand_bone) < 0:
		hand_bone = &""
	_hoe = _build_hoe()
	if hand_bone == &"":
		add_child(_hoe)
		_hoe.position = Vector3(0.3, 1.0, 0.2)
		return
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "HoeHand"
	skeleton.add_child(attachment)
	attachment.bone_name = hand_bone
	attachment.add_child(_hoe)
	var hand: int = skeleton.find_bone(hand_bone)
	var hand_basis: Basis = global_basis.inverse() * skeleton.global_basis * _frame_global(hand).basis
	var inherited_scale: Vector3 = hand_basis.get_scale().abs().max(Vector3.ONE * 0.0001)
	_hoe.scale = Vector3.ONE / inherited_scale
	_hoe.position = Vector3(0.0, -0.35, 0.0) / inherited_scale


func _build_hoe() -> Node3D:
	var hoe: Node3D = Node3D.new()
	hoe.name = "Hoe"
	var wood: StandardMaterial3D = StandardMaterial3D.new()
	wood.albedo_color = WOOD_COLOR
	wood.roughness = 1.0
	var iron: StandardMaterial3D = StandardMaterial3D.new()
	iron.albedo_color = IRON_COLOR
	iron.roughness = 0.55
	iron.metallic = 0.45

	var shaft_mesh: CylinderMesh = CylinderMesh.new()
	shaft_mesh.height = 1.85
	shaft_mesh.top_radius = 0.032
	shaft_mesh.bottom_radius = 0.032
	shaft_mesh.radial_segments = 6
	shaft_mesh.rings = 1
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.material_override = wood
	shaft.position.y = 0.925
	hoe.add_child(shaft)

	var neck_mesh: BoxMesh = BoxMesh.new()
	neck_mesh.size = Vector3(0.07, 0.07, 0.24)
	var neck: MeshInstance3D = MeshInstance3D.new()
	neck.mesh = neck_mesh
	neck.material_override = iron
	neck.position = Vector3(0.0, 1.84, 0.11)
	hoe.add_child(neck)

	var blade_mesh: BoxMesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.36, 0.07, 0.11)
	var blade: MeshInstance3D = MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.material_override = iron
	blade.position = Vector3(0.0, 1.80, 0.23)
	hoe.add_child(blade)
	return hoe

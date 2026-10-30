extends Node3D

const CREATURES: PackedScene = preload("res://available-assets/retro3d-assets/Characters/Wendigos/Criaturas.fbx")
const TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Characters/Wendigos/W1.png")
const HEIGHT: float = 2.2

@export var movement_body: CharacterBody3D
var _skeleton: Skeleton3D
var _phase: float = 0.0
var _stride: float = 0.0

func _ready() -> void:
	var collection: Node3D = CREATURES.instantiate() as Node3D
	var creature: Node3D = collection.get_node("W") as Node3D
	collection.remove_child(creature)
	collection.free()
	var pivot: Node3D = Node3D.new()
	add_child(pivot)
	pivot.add_child(creature)
	_skeleton = creature.get_node("Skeleton3D") as Skeleton3D
	_skeleton.reset_bone_poses()
	var mesh: MeshInstance3D = _skeleton.get_node("W_001") as MeshInstance3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = TEXTURE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mesh.material_override = material
	var bounds: AABB = _posed_bounds(mesh, pivot)
	# Bind-space bounds omit the FBX skeleton's axis conversion.
	mesh.custom_aabb = (mesh.global_transform.affine_inverse() * pivot.global_transform) * bounds.grow(HEIGHT * 0.25)
	pivot.scale = Vector3.ONE * (HEIGHT / bounds.size.y)
	pivot.rotation.y = PI / 2.0
	var center: Vector3 = bounds.get_center()
	pivot.position = -(pivot.basis * Vector3(center.x, bounds.position.y, center.z))

func _process(delta: float) -> void:
	var horizontal: Vector3 = movement_body.velocity if movement_body != null else Vector3.ZERO
	horizontal.y = 0.0
	_phase += delta * 8.0
	_stride = move_toward(_stride, 1.0 if horizontal.length_squared() > 0.04 else 0.0, delta * 6.0)
	var swing: float = sin(_phase) * 0.3 * _stride
	_rotate_bone("Bone.009", swing)
	_rotate_bone("Bone.010", -swing)
	_rotate_bone("Bone.011", -maxf(0.0, swing))
	_rotate_bone("Bone.012", -maxf(0.0, -swing))
	_rotate_bone("Bone.004", -swing * 0.7 + sin(_phase * 0.25) * 0.025)
	_rotate_bone("Bone.007", swing * 0.7 - sin(_phase * 0.25) * 0.025)

func _rotate_bone(bone_name: String, angle: float) -> void:
	var bone: int = _skeleton.find_bone(bone_name)
	var parent: int = _skeleton.get_bone_parent(bone)
	var parent_basis: Basis = _skeleton.get_bone_global_rest(parent).basis.orthonormalized()
	var rest: Quaternion = _skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
	_skeleton.set_bone_pose_rotation(bone, Quaternion(parent_basis.inverse() * Vector3.UP, angle) * rest)

func _posed_bounds(mesh: MeshInstance3D, pivot: Node3D) -> AABB:
	var transforms: Array[Transform3D] = []
	for index: int in mesh.skin.get_bind_count():
		var bone: int = _skeleton.find_bone(mesh.skin.get_bind_name(index))
		if bone < 0:
			bone = mesh.skin.get_bind_bone(index)
		transforms.append(pivot.global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(index))
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

extends Node3D

const CREATURES: PackedScene = preload("res://available-assets/retro3d-assets/Characters/Wendigos/Criaturas.fbx")
const TEXTURE: Texture2D = preload("res://available-assets/retro3d-assets/Characters/Wendigos/W1.png")
const BODY_SHADER: Shader = preload("res://game/balancer/reaper_body.gdshader")
const SHROUD_SHADER: Shader = preload("res://game/balancer/reaper_shroud.gdshader")
const HEIGHT: float = 2.2
const LEG_BONES: Array[StringName] = [&"Bone.009", &"Bone.010"]
const ARM_BONES: Array[StringName] = [&"Bone.004", &"Bone.007"]
const HOVER_RATE: float = 1.15
const HOVER_AMPLITUDE: float = 0.07
const HOVER_OFFSET: float = 0.10
const ARM_DRIFT: float = 0.05
const LEAN_PER_SPEED: float = 0.0045
const MAX_LEAN: float = 0.035

@export var movement_body: CharacterBody3D

var _skeleton: Skeleton3D
var _arm_bones: Array[int] = []
var _phase: float = 0.0
var _lean: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	_build_body()
	_build_shroud(1.30, -0.02, 0.30, 0.58, 0.0)
	_build_shroud(1.58, 1.06, 0.20, 0.44, 2.4)
	_base_y = position.y + HOVER_OFFSET
	position.y = _base_y

func _physics_process(delta: float) -> void:
	_phase += delta * HOVER_RATE
	position.y = _base_y + sin(_phase) * HOVER_AMPLITUDE
	rotation.z = sin(_phase * 0.6) * 0.02
	var horizontal_speed: float = 0.0
	if movement_body != null:
		horizontal_speed = Vector2(movement_body.velocity.x, movement_body.velocity.z).length()
	var target_lean: float = clampf(horizontal_speed * LEAN_PER_SPEED, 0.0, MAX_LEAN)
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-3.0 * delta))
	rotation.x = -_lean + sin(_phase * 0.8 + 0.7) * 0.01
	var drift: float = sin(_phase * 0.75) * ARM_DRIFT
	for index: int in _arm_bones.size():
		var mirror: float = 1.0 if index == 0 else -1.0
		_rotate_bone(_arm_bones[index], drift * mirror)

func _build_body() -> void:
	var collection: Node3D = CREATURES.instantiate() as Node3D
	var creature: Node3D = collection.get_node("W") as Node3D
	collection.remove_child(creature)
	collection.free()
	var pivot: Node3D = Node3D.new()
	pivot.name = "Pivot"
	add_child(pivot)
	pivot.add_child(creature)
	_skeleton = creature.get_node("Skeleton3D") as Skeleton3D
	_skeleton.reset_bone_poses()
	var mesh: MeshInstance3D = _skeleton.get_node("W_001") as MeshInstance3D
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BODY_SHADER
	material.set_shader_parameter(&"albedo_texture", TEXTURE)
	mesh.material_override = material
	var bounds: AABB = _posed_bounds(mesh, pivot)
	# Bind-space bounds omit the FBX skeleton's axis conversion.
	mesh.custom_aabb = (mesh.global_transform.affine_inverse() * pivot.global_transform) * bounds.grow(HEIGHT * 0.25)
	pivot.scale = Vector3.ONE * (HEIGHT / bounds.size.y)
	pivot.rotation.y = PI / 2.0
	var center: Vector3 = bounds.get_center()
	pivot.position = -(pivot.basis * Vector3(center.x, bounds.position.y, center.z))
	for bone_name: StringName in ARM_BONES:
		_arm_bones.append(_skeleton.find_bone(bone_name))
	for bone_name: StringName in LEG_BONES:
		var bone: int = _skeleton.find_bone(bone_name)
		if bone >= 0:
			_skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.001)

func _build_shroud(top_y: float, bottom_y: float, top_radius: float, bottom_radius: float, phase: float) -> void:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHROUD_SHADER
	var shroud: MeshInstance3D = MeshInstance3D.new()
	shroud.mesh = _shroud_mesh(top_y, bottom_y, top_radius, bottom_radius, phase)
	shroud.material_override = material
	shroud.position = Vector3(0.0, 0.0, 0.05)
	add_child(shroud)

func _shroud_mesh(top_y: float, bottom_y: float, top_radius: float, bottom_radius: float, phase: float) -> ArrayMesh:
	var segments: int = 36
	var rings: int = 10
	var positions: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for ring: int in rings:
		var t: float = float(ring) / float(rings - 1)
		var y: float = lerpf(top_y, bottom_y, t)
		for segment: int in segments + 1:
			var u: float = float(segment) / float(segments)
			var angle: float = u * TAU
			var radius: float = lerpf(top_radius, bottom_radius, pow(t, 0.7))
			radius *= 1.0 + 0.05 * sin(angle * 7.0 + phase + t * 3.1) + 0.025 * sin(angle * 13.0 - phase + t * 5.7)
			radius *= 1.0 + 0.08 * t * sin(angle * 5.0 + phase * 2.0)
			var hem_drop: float = 0.0
			if ring == rings - 1:
				hem_drop = 0.06 * sin(angle * 9.0 + phase) + 0.03 * sin(angle * 17.0 + phase * 1.7)
			positions.append(Vector3(cos(angle) * radius, y + hem_drop, sin(angle) * radius))
			uvs.append(Vector2(u, t))
	var row: int = segments + 1
	for ring: int in rings - 1:
		for segment: int in segments:
			var a: int = ring * row + segment
			var b: int = a + 1
			var c: int = a + row
			var d: int = c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in positions.size():
		surface.set_uv(uvs[index])
		surface.add_vertex(positions[index])
	for index: int in indices:
		surface.add_index(index)
	surface.generate_normals()
	return surface.commit()

func _rotate_bone(bone: int, angle: float) -> void:
	if bone < 0:
		return
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

extends Node3D

const EXPLOSION: PackedScene = preload("res://game/enemies/tank_explosion.tscn")
const RADIUS: float = 0.2
const OBSTACLE_MASK: int = 1 | 16
const MAX_FLIGHT_TIME: float = 8.0
const FLOOR_NORMAL_Y: float = 0.7

var _player: CharacterBody3D
var _velocity: Vector3
var _damage: float
var _blast_radius: float
var _fuse: float
var _flight_time: float = 0.0
var _grounded: bool = false
var _exploded: bool = false
var _excluded: Array[RID] = []
var _shape: SphereShape3D = SphereShape3D.new()
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

@onready var _armed_cue: MeshInstance3D = $ArmedCue
@onready var _launch_sound: AudioStreamPlayer3D = $LaunchSound

func configure(player: CharacterBody3D, origin: Vector3, velocity: Vector3, damage: float, blast_radius: float, fuse: float, shooter: Node3D) -> void:
	_player = player
	_velocity = velocity
	_damage = damage
	_blast_radius = blast_radius
	_fuse = maxf(fuse, 0.0)
	_excluded = [shooter.get_rid()]
	_shape.radius = RADIUS
	global_position = origin
	reset_physics_interpolation()
	var target: Vector3 = _player.call("get_combat_target", origin)
	var proximity: float = clampf(1.0 - origin.distance_to(target) / 240.0, 0.0, 1.0)
	_launch_sound.volume_db = -4.0 + linear_to_db(0.6 * maxf(proximity * proximity, 0.0001))
	_launch_sound.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		queue_free()

func _physics_process(delta: float) -> void:
	if _exploded or is_queued_for_deletion():
		return
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		queue_free()
		return
	if not bool(_player.get("gameplay_enabled")) or float(_player.get("health")) <= 0.0:
		queue_free()
		return
	if _grounded:
		_fuse -= delta
		if _fuse <= 0.0:
			_explode()
		return
	_flight_time += delta
	if _flight_time >= MAX_FLIGHT_TIME:
		queue_free()
		return
	var motion: Vector3 = _velocity * delta + Vector3.DOWN * (0.5 * _gravity * delta * delta)
	_velocity.y -= _gravity * delta
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = _shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = OBSTACLE_MASK
	query.exclude = _excluded
	query.collide_with_areas = true
	query.margin = 0.001
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var contact: Dictionary = space.get_rest_info(query)
	if contact.is_empty():
		query.motion = motion
		var fractions: PackedFloat32Array = space.cast_motion(query)
		if fractions[0] >= 1.0:
			global_position += motion
			return
		var start: Vector3 = global_position
		global_position = start + motion * fractions[0]
		query.transform = Transform3D(Basis.IDENTITY, start + motion * fractions[1])
		query.motion = Vector3.ZERO
		contact = space.get_rest_info(query)
		if contact.is_empty():
			return
	var normal: Vector3 = contact["normal"]
	global_position += normal * 0.002
	if normal.y >= FLOOR_NORMAL_Y and _velocity.y <= 0.0:
		_grounded = true
		_velocity = Vector3.ZERO
		_armed_cue.visible = true
	else:
		_velocity = _velocity.slide(normal)

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var target: Vector3 = _player.call("get_combat_target", global_position)
	if global_position.distance_to(target) <= _blast_radius:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(global_position, target, OBSTACLE_MASK, _excluded)
		query.collide_with_areas = true
		query.hit_from_inside = true
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			_player.call("take_damage", _damage)
	var effect: Node3D = EXPLOSION.instantiate() as Node3D
	get_parent().add_child(effect)
	effect.global_position = global_position
	effect.configure(_blast_radius)
	queue_free()

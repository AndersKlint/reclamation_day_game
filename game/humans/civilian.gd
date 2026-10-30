extends CharacterBody3D

enum State { IDLE, STROLL, STARTLED, FLEE }

var state: State = State.IDLE
var player: CharacterBody3D
var active: bool = false
var plan_due: bool = false
var _clock: float = 0.0
var _safe_time: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _waypoint: int = 0
var _animation: AnimationPlayer
var _last_position: Vector3
var _stuck_time: float = 0.0
@onready var _visual: Node3D = $Visual
@onready var _drainable: Area3D = $Drainable

func configure(balancer: CharacterBody3D, model: PackedScene) -> void:
	player = balancer
	var actor: Node3D = model.instantiate() as Node3D
	_visual.add_child(actor)
	actor.rotation.y = PI
	_animation = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_animation != null, "Civilian model requires AnimationPlayer")
	var library: AnimationLibrary = _animation.get_animation_library("").duplicate() as AnimationLibrary
	_animation.remove_animation_library("")
	_animation.add_animation_library("", library)
	for clip: StringName in [&"Idle", &"Walk", &"Flee", &"Cower"]:
		var animation: Animation = _animation.get_animation(clip).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR
		_animation.get_animation_library("").add_animation(clip, animation)
	_drainable.drained.connect(_on_drained)
	_drainable.depleted.connect(_on_depleted)
	active = true
	_last_position = global_position
	_enter(State.IDLE)

func stop() -> void:
	active = false
	velocity = Vector3.ZERO
	if _animation != null:
		_animation.pause()

func _enter(next: State) -> void:
	state = next
	_path.clear()
	_waypoint = 0
	_stuck_time = 0.0
	plan_due = false
	match state:
		State.IDLE:
			_clock = randf_range(3.0, 8.0)
			_animation.play(&"Idle", 0.15)
		State.STROLL:
			plan_due = true
			_animation.play(&"Walk", 0.15)
		State.STARTLED:
			_clock = maxf(0.3, _animation.get_animation(&"Startle").length)
			_animation.play(&"Startle", 0.1)
		State.FLEE:
			_clock = 0.0
			_safe_time = 0.0
			plan_due = true
			_animation.play(&"Cower", 0.15)

func accept_path(path: PackedVector3Array) -> void:
	plan_due = false
	_clock = randf_range(1.2, 1.8)
	_path = path
	_waypoint = 0
	_stuck_time = 0.0
	if path.is_empty():
		if state == State.STROLL:
			_enter(State.IDLE)
		else:
			_animation.play(&"Cower", 0.15)
	else:
		_animation.play(&"Flee" if state == State.FLEE else &"Walk", 0.15)

func _physics_process(delta: float) -> void:
	if not active or is_queued_for_deletion() or not is_instance_valid(player):
		return
	if not bool(player.get("gameplay_enabled")):
		return
	_clock -= delta
	var distance: float = _flat_distance(global_position, player.global_position)
	if state in [State.IDLE, State.STROLL] and distance < 13.0:
		_enter(State.STARTLED)
	match state:
		State.IDLE:
			if _clock <= 0.0:
				_enter(State.STROLL)
		State.STARTLED:
			if _clock <= 0.0:
				_enter(State.FLEE)
		State.FLEE:
			_safe_time = _safe_time + delta if distance > 25.0 else 0.0
			if _safe_time >= 3.0:
				_enter(State.IDLE)
			elif _clock <= 0.0 and (_waypoint >= _path.size() or _flat_distance(_path[-1], player.global_position) < distance + 3.0):
				plan_due = true
	var horizontal: Vector3 = Vector3.ZERO
	while _waypoint < _path.size() and _flat_distance(global_position, _path[_waypoint]) < 0.65:
		_waypoint += 1
	if _waypoint < _path.size():
		horizontal = _path[_waypoint] - global_position
		horizontal.y = 0.0
		horizontal = horizontal.normalized() * (4.5 if state == State.FLEE else 1.2)
		_stuck_time = _stuck_time + delta if _flat_distance(global_position, _last_position) < delta * 0.15 else 0.0
		if _stuck_time > 1.0:
			_path.clear()
			horizontal = Vector3.ZERO
			_clock = 1.5
			_animation.play(&"Cower" if state == State.FLEE else &"Idle", 0.15)
	elif state == State.STROLL and not plan_due:
		_enter(State.IDLE)
	elif state == State.FLEE:
		_animation.play(&"Cower", 0.15)
	_last_position = global_position
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	move_and_slide()
	if not horizontal.is_zero_approx():
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-horizontal.x, -horizontal.z), minf(1.0, delta * 8.0))

func _on_drained(_amount: float) -> void:
	_safe_time = 0.0
	if active and state in [State.IDLE, State.STROLL]:
		_enter(State.STARTLED)

func _on_depleted() -> void:
	stop()
	# Queueing preserves the final in-flight drain transfer.
	queue_free()

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

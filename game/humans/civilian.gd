extends CharacterBody3D

const DEPLETION_EFFECT: PackedScene = preload("res://game/draining/depletion_effect.tscn")
const DEPLETION_SCRIPT = preload("res://game/draining/depletion_effect.gd")
const WorldModel = preload("res://game/world/world_model.gd")
const Drainable = preload("res://game/draining/drainable.gd")
const CivilianAudio = preload("res://game/humans/civilian_audio.gd")

const STARTLE_DISTANCE: float = 19.5
const SAFE_DISTANCE: float = 37.5
const DISTANT_INTERVAL: float = 0.2
const FULL_RATE_DISTANCE: float = 70.0

static var _model_libraries: Dictionary = {}
static var _model_bounds: Dictionary = {}

enum State { IDLE, STROLL, STARTLED, FLEE }

var state: State = State.IDLE
var player: CharacterBody3D
var active: bool = false
var plan_due: bool = false
var pedestrian_route: PackedVector3Array = PackedVector3Array()
var route_cursor: int = 0
var route_direction: int = 1
var scream_pool: CivilianAudio
var _clock: float = 0.0
var _safe_time: float = 0.0
var _path: PackedVector3Array = PackedVector3Array()
var _waypoint: int = 0
var _animation: AnimationPlayer
var _last_position: Vector3
var _stuck_time: float = 0.0
var _remains_parent: Node3D
var _ground_position: Callable
var _model_dimensions: Vector3
var _scream_cooldown: float = 0.0
var _kill_rewarded: bool = false
var _simulation_delta: float = 0.0
var _cached_player_radius: float = 0.0
@onready var _visual: Node3D = $Visual
@onready var _drainable: Drainable = $Drainable
@onready var _visibility: VisibleOnScreenNotifier3D = $Visibility

func configure(balancer: CharacterBody3D, model: PackedScene) -> void:
	player = balancer
	_drainable.pacifist_protected = true
	var actor: Node3D = model.instantiate() as Node3D
	_visual.add_child(actor)
	actor.rotation.y = PI
	_animation = actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(_animation != null, "Civilian model requires AnimationPlayer")
	_animation.stop()
	_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if not _model_bounds.has(model):
		_model_bounds[model] = WorldModel.bounds(_visual, true)
	var model_bounds: AABB = _model_bounds[model]
	_model_dimensions = model_bounds.size
	var horizontal_radius: float = Vector2(
		maxf(absf(model_bounds.position.x), absf(model_bounds.end.x)),
		maxf(absf(model_bounds.position.z), absf(model_bounds.end.z))
	).length()
	_visibility.aabb = AABB(
		Vector3(-horizontal_radius, model_bounds.position.y, -horizontal_radius),
		Vector3(horizontal_radius * 2.0, model_bounds.size.y, horizontal_radius * 2.0)
	).grow(_model_dimensions.y * 0.25)
	_drainable.configure_volume(_model_dimensions * global_basis.get_scale().abs())
	if not _model_libraries.has(model):
		var library: AnimationLibrary = _animation.get_animation_library("").duplicate() as AnimationLibrary
		for clip: StringName in [&"Idle", &"Stroll", &"Flee", &"Cower"]:
			var animation: Animation = _animation.get_animation(clip).duplicate() as Animation
			animation.loop_mode = Animation.LOOP_LINEAR
			library.add_animation(clip, animation)
		_model_libraries[model] = library
	_animation.remove_animation_library("")
	_animation.add_animation_library("", _model_libraries[model])
	_drainable.drained.connect(_on_drained)
	_drainable.collapsed.connect(_on_collapsed)
	active = true
	_simulation_delta = randf_range(0.0, DISTANT_INTERVAL)
	_scream_cooldown = randf_range(1.0, 4.0)
	route_direction = -1 if randf() < 0.5 else 1
	_last_position = global_position
	_enter(State.IDLE)

func configure_remains(remains_parent: Node3D, ground_position: Callable) -> void:
	_remains_parent = remains_parent
	_ground_position = ground_position

func stop() -> void:
	active = false
	plan_due = false
	velocity = Vector3.ZERO
	if is_instance_valid(scream_pool):
		scream_pool.stop_speaker(self)
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
			_clock = randf_range(0.8, 2.2)
			_animation.play(&"Idle", 0.15)
		State.STROLL:
			plan_due = true
			_animation.play(&"Stroll", 0.15)
		State.STARTLED:
			_clock = maxf(0.3, _animation.get_animation(&"Startle").length)
			_animation.play(&"Startle", 0.1)
			if _scream_cooldown <= 0.0 and is_instance_valid(scream_pool):
				scream_pool.play_scream(self)
				_scream_cooldown = 5.0
		State.FLEE:
			_clock = 0.0
			_safe_time = 0.0
			plan_due = true
			_animation.play(&"Cower", 0.15)

func accept_path(path: PackedVector3Array) -> void:
	plan_due = false
	_clock = randf_range(2.5, 4.5)
	_path = path
	_waypoint = 0
	_stuck_time = 0.0
	if path.is_empty():
		if state == State.STROLL:
			_enter(State.IDLE)
		else:
			_animation.play(&"Cower", 0.15)
	else:
		_animation.play(&"Flee" if state == State.FLEE else &"Stroll", 0.15)

func _physics_process(delta: float) -> void:
	if not active or is_queued_for_deletion() or not is_instance_valid(player):
		return
	if not bool(player.get("gameplay_enabled")):
		velocity = Vector3.ZERO
		return
	var distance: float = _flat_distance(global_position, player.global_position)
	var distant: bool = distance > FULL_RATE_DISTANCE + _cached_player_radius
	_simulation_delta += delta
	if distant and _simulation_delta < DISTANT_INTERVAL:
		return
	delta = _simulation_delta
	_simulation_delta = 0.0
	_clock -= delta
	_scream_cooldown = maxf(0.0, _scream_cooldown - delta)
	var player_radius: float = _player_radius()
	_cached_player_radius = player_radius
	if state in [State.IDLE, State.STROLL] and distance < STARTLE_DISTANCE + player_radius:
		_enter(State.STARTLED)
	match state:
		State.IDLE:
			if _clock <= 0.0:
				_enter(State.STROLL)
		State.STARTLED:
			if _clock <= 0.0:
				_enter(State.FLEE)
		State.FLEE:
			_safe_time = _safe_time + delta if distance > SAFE_DISTANCE + player_radius else 0.0
			if _safe_time >= 3.0 and _waypoint >= _path.size():
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
		if _animation.current_animation != &"Cower":
			_animation.play(&"Cower", 0.15)
	_last_position = global_position
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = 0.0 if is_on_floor() else velocity.y + get_gravity().y * delta
	if distant:
		var motion: Vector3 = Vector3(horizontal.x * delta, -0.2, horizontal.z * delta)
		var collision: KinematicCollision3D = move_and_collide(motion)
		if collision != null:
			move_and_collide(collision.get_remainder().slide(collision.get_normal()))
		velocity.y = 0.0
	else:
		move_and_slide()
	if not horizontal.is_zero_approx():
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-horizontal.x, -horizontal.z), minf(1.0, delta * 8.0))
	if _visibility.is_on_screen():
		_animation.advance(delta)

func _on_drained(_amount: float) -> void:
	_safe_time = 0.0
	if active and state in [State.IDLE, State.STROLL]:
		_enter(State.STARTLED)

func _on_collapsed() -> void:
	if not _kill_rewarded and is_instance_valid(_drainable.collector) and _drainable.collector.has_method(&"heal_immediately"):
		_kill_rewarded = true
		_drainable.collector.call(&"heal_immediately", 1.0)
	stop()
	collision_layer = 0
	collision_mask = 0
	_create_remains.call_deferred()

func _create_remains() -> void:
	var remains_parent: Node = _remains_parent if is_instance_valid(_remains_parent) and _remains_parent.is_inside_tree() else get_parent()
	if remains_parent != null:
		var effect: Node3D = DEPLETION_EFFECT.instantiate() as Node3D
		effect.process_mode = Node.PROCESS_MODE_PAUSABLE
		remains_parent.add_child(effect)
		effect.global_transform = Transform3D(Basis.IDENTITY, global_position)
		effect.style = DEPLETION_SCRIPT.Style.HUMANOID
		effect.configure_reward(_drainable.take_collapse_life(), _drainable.collector, _drainable.healing_per_life)
		_visual.reparent(effect, true)
		effect.configure(_visual, _model_dimensions, _ground_position)
		effect.start()
	queue_free()

func _player_radius() -> float:
	if is_instance_valid(player) and player.has_method("get_combat_radius"):
		var radius: float = float(player.call("get_combat_radius"))
		return maxf(0.0, radius) if is_finite(radius) else 0.0
	return 0.0

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

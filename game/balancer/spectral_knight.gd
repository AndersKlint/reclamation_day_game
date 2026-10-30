extends Node3D

const IDLE: StringName = &"Armature|k_idle"
const WALK: StringName = &"Armature|k_walk"

@export var movement_body: CharacterBody3D
@onready var animation_player: AnimationPlayer = $Model/AnimationPlayer

func _ready() -> void:
	var library: AnimationLibrary = animation_player.get_animation_library(&"").duplicate()
	for animation_name: StringName in [IDLE, WALK]:
		var animation: Animation = animation_player.get_animation(animation_name).duplicate()
		animation.loop_mode = Animation.LOOP_LINEAR
		library.remove_animation(animation_name)
		library.add_animation(animation_name, animation)
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)
	animation_player.play(IDLE)

func _process(_delta: float) -> void:
	var moving: bool = movement_body != null and Vector2(movement_body.velocity.x, movement_body.velocity.z).length_squared() > 0.04
	animation_player.play(WALK if moving else IDLE, 0.15)

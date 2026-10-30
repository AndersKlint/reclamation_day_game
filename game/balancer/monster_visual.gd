extends Node3D

const CHARACTER = preload("res://game/characters/rigged_character.gd")

@export var movement_body: CharacterBody3D
var _character: CHARACTER

func _ready() -> void:
	_character = CHARACTER.new()
	add_child(_character)
	_character.configure("Killer_M/Character_Monster_07", "Character_Monster_07", 2.2, true)

func _process(delta: float) -> void:
	var horizontal: Vector3 = movement_body.velocity if movement_body != null else Vector3.ZERO
	horizontal.y = 0.0
	_character.update_pose(horizontal, false, false, delta)

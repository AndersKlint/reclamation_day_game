class_name UpgradeDefinition
extends Resource

@export var id: StringName = &""
@export var title: String = ""
@export_multiline var flavor_text: String = ""
@export var repeatable: bool = true
@export var variants: Array[UpgradeVariant] = []

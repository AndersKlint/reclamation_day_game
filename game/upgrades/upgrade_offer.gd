class_name UpgradeOffer
extends RefCounted

var definition: UpgradeDefinition:
	get:
		return _definition
var variant: UpgradeVariant:
	get:
		return _variant

var _definition: UpgradeDefinition
var _variant: UpgradeVariant


func _init(upgrade_definition: UpgradeDefinition, upgrade_variant: UpgradeVariant) -> void:
	_definition = upgrade_definition
	_variant = upgrade_variant

class_name UpgradeCatalog
extends Resource

@export var definitions: Array[UpgradeDefinition] = []
@export_group("Rarity Weights")
@export_range(0.0, 100.0, 0.1, "or_greater") var common_weight: float = 59.0
@export_range(0.0, 100.0, 0.1, "or_greater") var uncommon_weight: float = 30.0
@export_range(0.0, 100.0, 0.1, "or_greater") var epic_weight: float = 9.0
@export_range(0.0, 100.0, 0.1, "or_greater") var legendary_weight: float = 2.0


func get_weight(rarity: int) -> float:
	var weight: float
	match rarity:
		UpgradeVariant.Rarity.COMMON:
			weight = common_weight
		UpgradeVariant.Rarity.UNCOMMON:
			weight = uncommon_weight
		UpgradeVariant.Rarity.EPIC:
			weight = epic_weight
		UpgradeVariant.Rarity.LEGENDARY:
			weight = legendary_weight
		_:
			return 0.0
	return weight if is_finite(weight) and weight >= 0.0 else 0.0

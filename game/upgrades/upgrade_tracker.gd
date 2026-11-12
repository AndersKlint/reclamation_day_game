class_name UpgradeTracker
extends Node

const UpgradeDefinition = preload("res://game/upgrades/upgrade_definition.gd")
const OFFER_COUNT: int = 3
const FIRST_LIFE_THRESHOLD: float = 200.0

@export var catalog: UpgradeCatalog = preload("res://game/upgrades/upgrade_catalog.tres")

var pending_rewards: int = 0
var earned_tiers: int = 0
var _next_threshold: float = 0.0
var _configured: bool = false
var _offers: Array[UpgradeOffer] = []
var _ownership: Dictionary[StringName, int] = {}
var _random: RandomNumberGenerator = RandomNumberGenerator.new()

var next_threshold: float:
	get:
		_ensure_configured()
		return _next_threshold


func configure() -> void:
	assert(not _configured)
	_ensure_configured()


func record_life(life: float) -> void:
	if not is_finite(life):
		return
	_ensure_configured()
	while life >= _next_threshold:
		pending_rewards += 1
		earned_tiers += 1
		_advance_threshold()


func has_pending() -> bool:
	return pending_rewards > 0


func get_or_create_offers() -> Array[UpgradeOffer]:
	if not has_pending():
		return []
	if not _offers.is_empty():
		return _offers.duplicate()
	var eligible: Array[UpgradeDefinition] = _eligible_definitions()
	for _slot: int in OFFER_COUNT:
		var offer: UpgradeOffer = _roll_offer(eligible)
		if offer == null:
			break
		_offers.append(offer)
		eligible.erase(offer.definition)
	return _offers.duplicate()


func select_offer(offer: UpgradeOffer) -> bool:
	if not has_pending() or offer == null or not _offers.has(offer):
		return false
	var definition: UpgradeDefinition = offer.definition
	if not _valid_definition(definition) or not definition.variants.has(offer.variant):
		return false
	if not _is_compatible(definition):
		return false
	if not definition.repeatable and _ownership.has(definition.id):
		return false
	_ownership[definition.id] = _ownership.get(definition.id, 0) + 1
	pending_rewards -= 1
	_offers.clear()
	return true


func get_debug_offers() -> Array[UpgradeOffer]:
	var offers: Array[UpgradeOffer] = []
	for definition: UpgradeDefinition in _catalog_definitions():
		if not _is_compatible(definition):
			continue
		for variant: UpgradeVariant in definition.variants:
			offers.append(UpgradeOffer.new(definition, variant))
	offers.sort_custom(_debug_offer_before)
	return offers


func get_owned_definitions() -> Array[StringName]:
	var owned: Array[StringName] = []
	for id: StringName in _ownership.keys():
		owned.append(id)
	return owned


func grant_debug_offer(offer: UpgradeOffer) -> bool:
	if offer == null:
		return false
	var definition: UpgradeDefinition = offer.definition
	if not _catalog_definitions().has(definition):
		return false
	if not definition.variants.has(offer.variant):
		return false
	if not _is_compatible(definition):
		return false
	if not definition.repeatable and _ownership.has(definition.id):
		return false
	_ownership[definition.id] = _ownership.get(definition.id, 0) + 1
	_offers.clear()
	return true


func _catalog_definitions() -> Array[UpgradeDefinition]:
	var definitions: Array[UpgradeDefinition] = []
	var seen: Dictionary[StringName, bool] = {}
	var seen_titles: Dictionary[String, bool] = {}
	if catalog == null:
		push_warning("Upgrade catalog is missing.")
		return definitions
	for definition: UpgradeDefinition in catalog.definitions:
		if not _valid_definition(definition):
			push_warning("Ignoring invalid upgrade definition in catalog.")
			continue
		if seen.has(definition.id):
			push_warning("Ignoring duplicate upgrade ID: %s" % definition.id)
			continue
		if seen_titles.has(definition.title):
			push_warning("Ignoring duplicate upgrade title: %s" % definition.title)
			continue
		seen[definition.id] = true
		seen_titles[definition.title] = true
		definitions.append(definition)
	return definitions


func _debug_offer_before(a: UpgradeOffer, b: UpgradeOffer) -> bool:
	if a.variant.rarity != b.variant.rarity:
		return a.variant.rarity > b.variant.rarity
	return a.definition.title.naturalnocasecmp_to(b.definition.title) < 0


func _eligible_definitions() -> Array[UpgradeDefinition]:
	var eligible: Array[UpgradeDefinition] = []
	for definition: UpgradeDefinition in _catalog_definitions():
		if not _is_compatible(definition):
			continue
		if definition.repeatable or not _ownership.has(definition.id):
			eligible.append(definition)
	return eligible


func _is_compatible(definition: UpgradeDefinition) -> bool:
	for incompatible_id: StringName in definition.incompatible_ids:
		if _ownership.has(incompatible_id):
			return false
	return true


func _valid_definition(definition: UpgradeDefinition) -> bool:
	if definition == null or definition.id == &"" or definition.title.strip_edges().is_empty():
		return false
	if definition.variants.is_empty():
		return false
	var rarities: Dictionary[int, bool] = {}
	for variant: UpgradeVariant in definition.variants:
		if variant == null or not variant.is_valid():
			return false
		if rarities.has(variant.rarity):
			return false
		rarities[variant.rarity] = true
	return true


func _roll_offer(eligible: Array[UpgradeDefinition]) -> UpgradeOffer:
	var candidates: Array[UpgradeOffer] = []
	var available_weights: Dictionary[int, float] = {}
	for definition: UpgradeDefinition in eligible:
		for variant: UpgradeVariant in definition.variants:
			var weight: float = catalog.get_weight(variant.rarity)
			if not is_finite(weight) or weight <= 0.0:
				continue
			candidates.append(UpgradeOffer.new(definition, variant))
			available_weights[variant.rarity] = weight
	var total_weight: float = 0.0
	for weight: float in available_weights.values():
		total_weight += weight
	if total_weight <= 0.0 or not is_finite(total_weight):
		return null
	var roll: float = _random.randf() * total_weight
	var selected_rarity: int = available_weights.keys()[-1]
	for rarity: int in available_weights:
		roll -= available_weights[rarity]
		if roll < 0.0:
			selected_rarity = rarity
			break
	var matching: Array[UpgradeOffer] = []
	for candidate: UpgradeOffer in candidates:
		if candidate.variant.rarity == selected_rarity:
			matching.append(candidate)
	return matching[_random.randi_range(0, matching.size() - 1)]


func _ensure_configured() -> void:
	if _configured:
		return
	_configured = true
	_next_threshold = FIRST_LIFE_THRESHOLD


func _advance_threshold() -> void:
	_next_threshold *= 2.0

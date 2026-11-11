extends RefCounted

const LIFE_PER_VOLUME: float = 1.0
const REQUIRED_VOLUME_RATIO: float = 0.2
const GROWTH_VOLUME_SHARE: float = 0.10
const COLLAPSE_LIFE_SHARE: float = 0.8
const VILLAGE_HOUSE_DRAIN_MULTIPLIER: float = 5.0
const VOLUME_RATE_REFERENCE_RATIO: float = 0.5
const VOLUME_RATE_REFERENCE_SECONDS: float = 30.0

static func volume(dimensions: Vector3) -> float:
	if not dimensions.is_finite() or dimensions.x <= 0.0 or dimensions.y <= 0.0 or dimensions.z <= 0.0:
		return 0.0
	var result: float = dimensions.x * dimensions.y * dimensions.z
	return result if is_finite(result) else 0.0

static func life_for_volume(object_volume: float) -> float:
	return object_volume * LIFE_PER_VOLUME

static func growth_for_life(life: float) -> float:
	return life * GROWTH_VOLUME_SHARE / LIFE_PER_VOLUME

static func life_for_growth(added_volume: float) -> float:
	return added_volume * LIFE_PER_VOLUME / GROWTH_VOLUME_SHARE

static func drain_rate_for_volume(player_volume: float) -> float:
	if not is_finite(player_volume) or player_volume <= 0.0:
		return 0.0
	var drained_life_per_capacity: float = 1.0 - COLLAPSE_LIFE_SHARE
	var reference: float = VOLUME_RATE_REFERENCE_RATIO * VOLUME_RATE_REFERENCE_SECONDS * VILLAGE_HOUSE_DRAIN_MULTIPLIER
	var rate: float = player_volume * drained_life_per_capacity * LIFE_PER_VOLUME / reference
	return rate if is_finite(rate) else 0.0

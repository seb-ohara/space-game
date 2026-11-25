extends RefCounted
## One equipment-derived profile for flight, tooling and autonomous task selection.

const MODULES := preload("res://scripts/ship_modules.gd")
const LOADOUT := preload("res://scripts/ship_loadout.gd")
const SLOT_WEAPONS := ["laser", "machine_gun", "missile", "railgun", "miner"]

static func build(parts: Array, admin: Dictionary, base: Dictionary) -> Dictionary:
	# Legacy visible turret art no longer participates in player weapon rules.
	# Normalize slot mounts once and share them with the actual firing code.
	var hull := parts.duplicate(true)
	for part: Dictionary in hull:
		part.erase("turret")
	var result := MODULES.stats(hull)
	var speed_unit: float = base.speed_unit
	result.boost = float(base.boost) * float(result.speed)
	for stat in ["health", "shield", "cargo"]:
		if admin.has(stat):
			result[stat] = maxf(0.0, float(admin[stat]))
	if admin.has("speed"):
		result.speed = maxf(0.0, float(admin.speed)) * speed_unit / float(base.speed)
	if admin.has("acceleration"):
		result.acceleration = maxf(0.0, float(admin.acceleration)) * speed_unit / float(base.acceleration)
	if admin.has("turn"):
		result.maneuver = deg_to_rad(maxf(0.0, float(admin.turn))) / float(base.turn)
	if admin.has("boost"):
		result.boost = maxf(0.0, float(admin.boost)) * speed_unit
	result.hyperdrive = maxf(0.0, float(admin.get("hyperdrive", float(base.hyperdrive) * float(result.speed) / speed_unit))) * speed_unit
	var mounts: Array = LOADOUT.slots(admin)
	for slot: Dictionary in mounts:
		match slot.type:
			"shield": result.shield += 100.0
			"shield_recharge": result.shield_recharge += 2.0
			_:
				if slot.type in SLOT_WEAPONS:
					var equipment: Dictionary = MODULES.TYPES[slot.type]
					result.mining += float(equipment.get("mining", 0.0))
					result.weapon += float(equipment.get("weapon", 0.0))
	result.slots = mounts
	result.has_command_deck = MODULES.has_command_deck(parts)
	result.normal_speed = float(result.speed) * float(base.speed)
	result.travel_acceleration = float(result.acceleration) * float(base.acceleration)
	result.turn_rate = float(result.maneuver) * float(base.turn)
	result.mining_rate = result.mining
	result.combat_strength = result.weapon
	result.cargo_capacity = maxi(0, int(result.cargo))
	return result

static func available_space(profile: Dictionary, cargo: Dictionary) -> int:
	return maxi(0, int(profile.cargo_capacity) - int(cargo.get("iron", 0)) - int(cargo.get("tritium", 0)))

static func can_perform(profile: Dictionary, task: String, cargo: Dictionary = {}) -> bool:
	var mobile: bool = profile.has_command_deck and profile.normal_speed > 0.0 and profile.travel_acceleration > 0.0
	match task:
		"idle", "stop", "wait": return true
		"move": return mobile
		"hyperjump": return mobile and profile.hyperdrive > 0.0
		"mine": return profile.mining_rate > 0.0 and available_space(profile, cargo) > 0
		"haul": return mobile and available_space(profile, cargo) > 0
		"combat": return profile.combat_strength > 0.0
	return false

static func suitability(profile: Dictionary, task: String, cargo: Dictionary = {}) -> float:
	if not can_perform(profile, task, cargo):
		return 0.0
	match task:
		"mine": return profile.mining_rate * sqrt(float(available_space(profile, cargo)))
		"haul": return available_space(profile, cargo) * float(profile.normal_speed)
		"hyperjump": return profile.hyperdrive
		"move": return profile.normal_speed
		"combat": return profile.combat_strength * sqrt(maxf(1.0, profile.health + profile.shield))
	return 1.0

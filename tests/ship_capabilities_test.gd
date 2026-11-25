extends SceneTree

const CAPS := preload("res://scripts/ships/ship_capabilities.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const BASE := {"speed": 390.0, "acceleration": 380.0, "turn": 2.0, "boost": 6000.0,
	"hyperdrive": 25000.0, "speed_unit": 112.5}

func _initialize() -> void:
	for preset: String in MODULES.PRESET_LENGTHS_METERS:
		var profile := CAPS.build(MODULES.preset_design(preset), {}, BASE)
		assert(profile.normal_speed > 0.0 and CAPS.can_perform(profile, "move"))
		assert(is_equal_approx(profile.normal_speed, profile.speed * BASE.speed))
		assert(profile.mining_rate == 0.0)
	var parts := MODULES.default_design()
	var base := CAPS.build(parts, {}, BASE)
	var legacy_parts := parts.duplicate(true)
	legacy_parts.append({"type": "turret_base", "x": 2, "y": 1, "turret": "miner"})
	assert(CAPS.build(legacy_parts, {}, BASE).mining_rate == 0.0)
	var cargo_parts := legacy_parts.duplicate(true)
	cargo_parts.append({"type": "retro_cargo", "x": 3, "y": 1})
	assert(CAPS.build(cargo_parts, {}, BASE).cargo_capacity == base.cargo_capacity + 200)
	var equipped := CAPS.build(cargo_parts, {"cargo": 30, "speed": 3, "acceleration": 2, "turn": 90, "boost": 9, "hyperdrive": 0,
		"module_slots": [{"type": "miner"}, {"type": "miner"}, {"type": "railgun"}, {"type": "shield"}]}, BASE)
	assert(is_equal_approx(equipped.normal_speed, 3.0 * BASE.speed_unit))
	assert(is_equal_approx(equipped.travel_acceleration, 2.0 * BASE.speed_unit))
	assert(is_equal_approx(equipped.turn_rate, PI * 0.5) and equipped.boost == 9.0 * BASE.speed_unit)
	assert(not CAPS.can_perform(equipped, "hyperjump") and CAPS.can_perform(equipped, "move"))
	assert(equipped.mining_rate == 2.0 * MODULES.TYPES.miner.mining)
	assert(equipped.combat_strength == MODULES.TYPES.railgun.weapon and equipped.shield == 100.0)
	assert(CAPS.available_space(equipped, {"iron": 20, "tritium": 4}) == 6)
	assert(CAPS.can_perform(equipped, "mine") and not CAPS.can_perform(equipped, "mine", {"iron": 30}))
	assert(CAPS.suitability(equipped, "mine") > CAPS.suitability(equipped, "mine", {"iron": 10}))
	assert(CAPS.suitability(equipped, "combat") > CAPS.suitability(base, "combat"))
	print("Ship capability checks passed")
	quit()

extends SceneTree

const CAPS := preload("res://scripts/ships/ship_capabilities.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const BASE := {"speed": 390.0, "acceleration": 380.0, "turn": MODULES.BASE_TURN_SPEED, "boost": 6000.0,
	"hyperdrive": 25000.0, "speed_unit": 112.5}

func _initialize() -> void:
	for preset: String in MODULES.PRESET_LENGTHS_METERS:
		var profile := CAPS.build(MODULES.preset_design(preset), {}, BASE)
		assert(profile.normal_speed > 0.0 and CAPS.can_perform(profile, "move"))
		assert(is_equal_approx(profile.normal_speed, profile.speed * BASE.speed))
		assert(profile.mining_rate == 0.0)
	_check_light_fighter_propulsion()
	_check_three_engine_fighter()
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

func _check_light_fighter_propulsion() -> void:
	var hull: Array = []
	for i in range(6):
		hull.append({"type": "retro_plain", "x": 0, "y": i})
	var engine_build := hull + [{"type": "engine", "x": 0, "y": 6}]
	var engine_stats := MODULES.stats(engine_build)
	var old_engine_ratio := 150.0 / float(engine_stats.mass)
	var old_engine_speed := 0.40 + 0.85 * (1.0 - exp(-1.05 * old_engine_ratio))
	var old_engine_acceleration := 1.2 * (1.0 - exp(-1.25 * old_engine_ratio))
	var engine_profile := CAPS.build(engine_build, {}, BASE)
	assert(engine_profile.normal_speed > 1.10 * old_engine_speed * BASE.speed)
	assert(engine_profile.travel_acceleration > old_engine_acceleration * BASE.acceleration)

	var thruster_build := hull + [{"type": "thruster", "x": 0, "y": 6}]
	var thruster_stats := MODULES.stats(thruster_build)
	var old_thruster_speed := 0.40 + 26.0 / float(thruster_stats.mass) * 0.55
	var thruster_profile := CAPS.build(thruster_build, {}, BASE)
	assert(thruster_profile.normal_speed > 1.20 * old_thruster_speed * BASE.speed)
	assert(thruster_profile.normal_speed < engine_profile.normal_speed)

func _check_three_engine_fighter() -> void:
	# Match the reference fighter's 296 mass and 24.8 m length with a simple test hull.
	var parts := [
		{"type": "retro_plain", "fine_grid": true, "x": 0, "y": 0, "width": 19, "height": 27},
		{"type": "retro_plain", "fine_grid": true, "x": 19, "y": 0, "width": 1, "height": 19},
		{"type": "engine", "fine_grid": true, "x": 0, "y": 27},
		{"type": "engine", "fine_grid": true, "x": 5, "y": 27},
		{"type": "engine", "fine_grid": true, "x": 10, "y": 27},
	]
	var fighter := CAPS.build(parts, {}, BASE)
	assert(is_equal_approx(fighter.mass, 296.0))
	assert(is_equal_approx(MODULES.dimensions_meters(parts).y, 24.8))
	assert(fighter.normal_speed / BASE.speed_unit >= 15.0)
	assert(rad_to_deg(fighter.turn_rate) >= 110.0)
	var two_engines := CAPS.build(parts.slice(0, 4), {}, BASE)
	assert(fighter.normal_speed > two_engines.normal_speed)
	assert(fighter.turn_rate > two_engines.turn_rate)
	var heavier := CAPS.build(parts + [{"type": "retro_plain", "fine_grid": true, "x": 20, "y": 0, "width": 8, "height": 27}], {}, BASE)
	assert(heavier.normal_speed < fighter.normal_speed and heavier.turn_rate < fighter.turn_rate)
	var old_speed_factor := 0.40 + 1.05 * (1.0 - exp(-1.05 * 675.0 / 296.0))
	assert(is_equal_approx(fighter.boost, BASE.boost * old_speed_factor))
	assert(is_equal_approx(fighter.hyperdrive, BASE.hyperdrive * old_speed_factor))

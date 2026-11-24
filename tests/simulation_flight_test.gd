extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const CLOCK := preload("res://scripts/simulation/simulation_clock.gd")
const FLIGHT := preload("res://main.tscn")
const SEED := 7419

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var baseline := {}
	for rate: int in CLOCK.RATES:
		var result := await _exercise_flight(rate)
		if baseline.is_empty():
			baseline = result
		else:
			for key in baseline:
				var expected: Variant = baseline[key]
				var actual: Variant = result[key]
				# Contact normals can differ slightly across separate physics worlds.
				var equal: bool = actual.distance_to(expected) < 0.02 if expected is Vector2 else actual == expected
				assert(equal, "%s differs at %d×: %s vs %s" % [key, rate, actual, expected])
		assert(Engine.physics_ticks_per_second == CLOCK.TICKS_PER_SECOND and is_equal_approx(Engine.time_scale, 1.0))
	print("Simulation flight checks passed at 1×, 2×, 5× and 10×")
	quit()

func _exercise_flight(rate: int) -> Dictionary:
	var map := GALAXY.create_map(SEED, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [
		{"name": "Miner", "parts": MODULES.default_design(), "position": Vector2.ZERO, "heading": 0.0,
			"hull": 100.0, "shield": 10.0, "shield_delay": 0.5, "admin": {"cargo": 20, "shield": 100,
				"module_slots": [{"type": "miner", "x": 0.5, "y": 0.5}, {"type": "shield_recharge", "x": 0.5, "y": 0.5}]}},
		{"name": "Wing", "parts": MODULES.default_design(), "position": Vector2(580, 0), "heading": 0.0,
			"hull": 100.0, "shield": 100.0, "shield_delay": 0.0},
	]})
	for rock in game.asteroids:
		rock.visual.free()
	game.asteroids.clear()
	game._add_asteroid(Vector2(400, 0), 20.0, 18.0, "test-ore")
	var initial_ore: int = game.asteroids[0].iron
	game.selected_weapon = 2
	game.selected_asteroid = 0
	game.rts_attack_active = true
	game._redraw_flight()
	var initial_orbit: Vector2 = game.solar_system.visible_orbiters[0][0].center
	_select_rate(game, rate)
	assert(Engine.physics_ticks_per_second == CLOCK.TICKS_PER_SECOND * rate)
	# These awaits observe real engine physics callbacks, including collision-server sync.
	await _until(game, 1.5)
	assert(game.iron >= 5 and game.iron <= 6 and game.depleted_ore["test-ore"] == initial_ore - game.iron,
		"Mining should transfer ore to cargo; got %s" % game.iron)
	assert(is_equal_approx(game.player_shield, 12.0), "Recharged shield: %s" % game.player_shield)
	game._redraw_flight()
	var orbit: Vector2 = game.solar_system.visible_orbiters[0][0].center
	assert(initial_orbit != orbit)
	var result := {"ore": game.iron, "recharge": game.player_shield, "orbit": orbit}

	game.rts_attack_active = false
	game.firing = false
	game.asteroids[0].visual.free()
	game.asteroids.clear()
	game.selected_asteroid = -1
	game.mining_asteroid = -1
	game.rts_move_active = true
	game.rts_destination = Vector2(2000, 0)
	await _until(game, 4.5)
	assert(game.ship_position.x > 300.0 and game.ship_position.x < 520.0)
	result.contact = game.ship_position
	result.contact_velocity = game.velocity

	_select_rate(game, 0)
	var frozen_position: Vector2 = game.ship_position
	game._open_settings()
	await process_frame
	game._close_settings()
	game._open_hangar()
	await process_frame
	game._close_hangar()
	for frame in range(3):
		await process_frame
	assert(game.elapsed == 4.5 and game.ship_position == frozen_position and not game.is_physics_processing())
	assert(game.simulation_calendar.text.ends_with("Paused") and game.simulation_clock.rate == rate)
	game.rts_move_active = false
	game.velocity = Vector2.ZERO
	game.heading = PI
	game._set_sustained_boost(true, Vector2.LEFT)
	game._set_simulation_rate(rate)
	await _until(game, 7.5)
	assert(game.sustained_boost_enabled and game.ship_position.x < frozen_position.x - 500.0)
	result.boost = game.ship_position
	result.boost_velocity = game.velocity

	# Exercise the real arrival path without spending an astronomical distance in the test.
	game._execute_hyperjump(0, 1)
	assert(game.hyperjump_time >= 0.0)
	game._rebase_world(game.hyperjump_arrival - Vector2(500, 0))
	game.ship_position = game.hyperjump_arrival - Vector2(500, 0)
	game.ship_motion_remainder = Vector2.ZERO
	game.heading = 0.0
	game.angular_velocity = 0.0
	game.velocity = Vector2.ZERO
	await _until(game, 12.5)
	assert(game.hyperjump_time < 0.0 and game.ship_position.distance_to(game.hyperjump_arrival) < 0.1)
	result.jump_arrival = game.ship_position
	result.jump_banner_until = game.hyperjump_arrival_until
	result.origin = game.world_origin
	game._open_settings()
	for frame in range(3):
		await process_frame
	assert(game.elapsed == 12.5 and Engine.physics_ticks_per_second == CLOCK.TICKS_PER_SECOND)
	game._close_settings()
	assert(game.is_physics_processing() and Engine.physics_ticks_per_second == CLOCK.TICKS_PER_SECOND * rate)
	await _until(game, 13.0)
	game.free()
	await process_frame
	return result

func _select_rate(game: Node, rate: int) -> void:
	var control: OptionButton = game.simulation_rate_control
	control.item_selected.emit(control.get_item_index(rate))

func _until(game: Node, seconds: float) -> void:
	while game.elapsed < seconds:
		await physics_frame
	assert(game.elapsed == seconds)

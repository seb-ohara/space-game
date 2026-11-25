extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const FLIGHT := preload("res://main.tscn")
const SEED := 7419

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var normal_dir := OS.get_user_data_dir()
	var fixture := "drift-order-test-" + SAVES.new_id()
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", fixture)
	var test_dir := OS.get_user_data_dir()
	assert(test_dir != normal_dir and test_dir.get_file() == fixture)
	assert(DirAccess.make_dir_recursive_absolute(test_dir) == OK)
	for rate in [1, 10]:
		await _exercise(rate)
	assert(DirAccess.remove_absolute(SAVES.RECENT_PATH) == OK)
	assert(DirAccess.remove_absolute(SAVES.SAVE_DIR) == OK)
	assert(DirAccess.remove_absolute(test_dir) == OK)
	print("Autonomous order checks passed at 1× and 10×")
	quit()

func _exercise(rate: int) -> void:
	var map := GALAXY.create_map(SEED, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [_ship("Pilot", Vector2.ZERO),
		_ship("Scout", map.systems[1].center - origin)]})
	game.galaxy_name = "Autonomous order fixture"
	game.save_slot = SAVES.new_id()
	var rock: Dictionary = game.asteroids[0]
	var rock_id: String = rock.id
	var initial_ore: int = rock.iron
	var start: Vector2 = rock.position - Vector2(0, 2300)
	var wing: Dictionary = game._register_ship(_ship("Miner", start, true))
	var original: PackedFloat64Array = wing.galaxy_position
	game._set_simulation_rate(rate)
	await _until(game, func(): return game.elapsed >= 0.5, 1.0)
	assert(wing.galaxy_position == original and wing.cargo.iron == 0 and wing.orders.is_empty())

	var destination := STATE.absolute(original, Vector2(0, 500))
	assert(game._submit_fleet_order(2, "move", destination))
	assert(game._submit_fleet_order(2, "wait", null, 0.5, false, true))
	game._open_fleet()
	game.fleet_list.select(2)
	game._fleet_panel_order("mine", 2, false, true)
	assert(game.order_target_request.is_empty())
	assert(wing.orders.size() == 3 and wing.orders[2].target_entity_id == "")
	await _until(game, func(): return wing.galaxy_position != original, 2.0)
	assert(STATE.relative(wing.galaxy_position, original).length() < 20.0)
	game._switch_fleet_control(1)
	assert(game.asteroid_system == 1 and not game.fleet_views.has(wing.id) and not game.live_rocks.has(rock_id))
	assert(game._nearest_mineable_asteroid(wing) == rock_id)
	await _until(game, func(): return wing.orders[0].type == "mine" and wing.orders[0].progress.get("fraction", 0.0) > 0.25, 25.0)
	assert(wing.orders[0].stage == "mining" and wing.cargo.iron == 0 and wing.orders[0].target_entity_id == rock_id)
	game._set_simulation_rate(0)
	assert(game._save_galaxy())
	var slot_id: String = game.save_slot
	var pending: Array = wing.orders.duplicate(true)
	var before_save: PackedFloat64Array = wing.galaxy_position
	game.free()

	game = FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._load_game(slot_id)
	wing = game.fleet[2]
	assert(game.simulation_clock.paused and game.simulation_clock.rate == rate and game.active_fleet_index == 1)
	assert(wing.orders == pending and wing.galaxy_position == before_save and not game.fleet_views.has(wing.id))
	game._set_simulation_rate(rate)
	await _until(game, func(): return wing.orders.is_empty(), 3.0)
	assert(wing.cargo.iron == 2 and game.depleted_ore[rock_id] == initial_ore - 2 and wing.last_order.state == "completed")
	assert(wing.navigation.mode == "idle")

	game._switch_fleet_control(2)
	assert(game._submit_fleet_order(2, "mine", rock_id, 1.0))
	await _until(game, func(): return wing.orders.is_empty(), 3.0)
	assert(game.iron == 3 and wing.cargo.iron == 3 and game.depleted_ore[rock_id] == initial_ore - 3)
	game._switch_fleet_control(1)

	# Two miners contend for the last three units in the system.
	var sites := GALAXY.asteroid_sites(SEED, game.solar_system.systems[0], game.solar_system.system_contents(0))
	for i in sites.size():
		game.depleted_ore[game._asteroid_site_id(0, i, sites[i])] = 0
	game.depleted_ore[rock_id] = 3
	var helper: Dictionary = game._register_ship(_ship("Helper", Vector2.ZERO, true))
	helper.galaxy_position = STATE.absolute(game._resolve_order_rock(rock_id).galaxy_position, Vector2(450, 0))
	assert(game._submit_fleet_order(2, "mine", rock_id, 1.0, true))
	assert(game._submit_fleet_order(3, "mine", rock_id, 1.0, true))
	await _until(game, func(): return wing.orders.is_empty() and helper.orders.is_empty(), 5.0)
	assert(game.depleted_ore[rock_id] == 0 and wing.cargo.iron + helper.cargo.iron == 6)
	assert(wing.last_order.state == "blocked" and helper.last_order.state == "blocked")
	assert("No ore left" in wing.last_order.reason and "No ore left" in helper.last_order.reason)

	var pilot: Dictionary = game.fleet[0]
	assert(game._submit_fleet_order(0, "mine", rock_id, 1.0))
	await _until(game, func(): return pilot.orders.is_empty(), 1.0)
	assert(pilot.last_order.state == "failed" and pilot.last_order.reason == "No mining laser equipped.")
	assert(game._submit_fleet_order(0, "hyperjump", 1))
	await _until(game, func(): return pilot.navigation.mode == "jump" and pilot.navigation.time > 0.25, 2.0)
	var jump: Dictionary = pilot.orders[0].progress
	var target: PackedFloat64Array = jump.travel_target
	assert(STATE.relative(target, pilot.galaxy_position).length() > 1500.0)
	# Put the fixture near its arrival only after observing real off-screen jump progress.
	pilot.galaxy_position = STATE.absolute(target, Vector2(-500.0, 0.0))
	pilot.heading = 0.0
	pilot.angular_velocity = 0.0
	pilot.velocity = Vector2.ZERO
	await _until(game, func(): return pilot.orders.is_empty(), 6.0)
	assert(pilot.last_order.state == "completed" and STATE.relative(target, pilot.galaxy_position).length() <= 4.0)

	assert(game._submit_fleet_order(0, "wait", null, 0.1, true))
	var after_wait: float = game.elapsed + 0.5
	await _until(game, func(): return game.elapsed >= after_wait, 2.0)
	assert(pilot.orders.size() == 1 and pilot.orders[0].stage == "waiting")
	game._cancel_fleet_orders(0)
	assert(pilot.orders.is_empty() and pilot.last_order.state == "cancelled")
	assert(game._submit_fleet_order(0, "stop"))
	assert(game._submit_fleet_order(0, "idle", null, 0.0, false, true))
	await _until(game, func(): return pilot.orders.is_empty(), 2.0)
	assert(pilot.last_order.type == "idle" and pilot.last_order.state == "completed")
	assert(pilot.velocity == Vector2.ZERO and pilot.navigation.mode == "idle")
	var scout: Dictionary = game.fleet[1]
	var manual_target := STATE.absolute(scout.galaxy_position, Vector2(0, 2000.0))
	assert(game._submit_fleet_order(1, "move", manual_target))
	await _until(game, func(): return scout.orders[0].state == "running", 1.0)
	game._toggle_sustained_boost()
	await _until(game, func(): return scout.orders[0].state == "suspended", 1.0)
	game._toggle_sustained_boost()
	await _until(game, func(): return scout.orders[0].state == "running", 1.0)
	assert(game._submit_fleet_order(1, "stop"))
	assert(scout.last_order.type == "move" and scout.last_order.state == "cancelled" and scout.orders.size() == 1)
	await _until(game, func(): return scout.orders.is_empty(), 3.0)
	assert(game.velocity.length() < 0.5 and scout.last_order.type == "stop")
	game.free()
	assert(SAVES.delete(slot_id))
	await process_frame

func _until(game: Node, predicate: Callable, simulated_timeout: float) -> void:
	var deadline: float = game.elapsed + simulated_timeout
	while not predicate.call() and game.elapsed < deadline:
		await physics_frame
	assert(predicate.call(), "Order did not reach the expected state by %.3f" % deadline)

func _ship(name: String, position: Vector2, miner := false) -> Dictionary:
	return {"name": name, "parts": MODULES.default_design(), "position": position, "heading": PI * 0.5,
		"hull": 100.0, "shield": 0.0, "shield_delay": 0.0,
		"admin": {"cargo": 12, "module_slots": [{"type": "miner"}]} if miner else {}}

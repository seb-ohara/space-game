extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const ORDER := preload("res://scripts/ships/ship_order.gd")
const AVOIDANCE := preload("res://scripts/ships/fleet_avoidance.gd")
const FLIGHT := preload("res://main.tscn")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := GALAXY.create_map(7419, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var translation := AVOIDANCE.formation_translation([Vector2(100, 0), Vector2(250, 0)], Vector2(500, 20), Vector2.ZERO, Vector2(500, 500))
	assert(translation == Vector2(250, 20), "The formation must shift together at the world edge.")
	for scenario in ["parked", "head-on", "crossing", "boost"]:
		var crossing: bool = scenario == "crossing"
		var second_position := Vector2(800, -800) if crossing else Vector2(1600, 0)
		var second_heading := PI / 2.0 if crossing else PI
		var game := _start(map, origin, [_ship(Vector2.ZERO), _ship(second_position, second_heading)])
		await physics_frame
		var wing: Dictionary = game.fleet[1]
		var target := Vector2(3000, 0)
		var wing_target := Vector2(800, 1600) if crossing else Vector2(-800, 0)
		if scenario == "boost":
			game._set_sustained_boost(true)
			game._steer_sustained_boost(game._world_to_screen(target))
		else:
			assert(game._submit_fleet_order(0, "move", STATE.absolute(game.galaxy_origin, target)))
		if scenario in ["head-on", "crossing"]:
			assert(game._submit_fleet_order(1, "move", STATE.absolute(game.galaxy_origin, wing_target)))
		var closest := INF
		for tick in 2100:
			game._step_flight(STEP)
			if tick % 30 == 0:
				await physics_frame
			closest = minf(closest, game.ship_position.distance_to(game._ship_local(wing)))
			if game.fleet[0].orders.is_empty() and wing.orders.is_empty() and not game.sustained_boost_enabled:
				break
		assert(closest > game.fleet[0].radius + wing.radius, "%s: minimum clearance %f" % [scenario, closest])
		assert(game.ship_position.distance_to(target) <= 4.0, "%s: ship did not arrive, position %s" % [scenario, game.ship_position])
		if scenario in ["head-on", "crossing"]:
			assert(game._ship_local(wing).distance_to(wing_target) <= 4.0, "%s: wing did not arrive" % scenario)
		game.free()

	var occupied := Vector2(1300, 0)
	var game := _start(map, origin, [_ship(Vector2.ZERO), _ship(occupied)])
	await physics_frame
	assert(game._submit_fleet_order(0, "move", STATE.absolute(game.galaxy_origin, occupied)))
	for tick in 500:
		game._step_flight(STEP)
	assert(not game.fleet[0].orders.is_empty() and game.velocity.length() < 4.0)
	assert(game.ship_position.distance_to(occupied) > game.fleet[0].radius + game.fleet[1].radius)
	assert(game._submit_fleet_order(1, "move", STATE.absolute(game.galaxy_origin, occupied + Vector2(0, 800))))
	for tick in 900:
		game._step_flight(STEP)
		if tick % 30 == 0:
			await physics_frame
		if game.fleet[0].orders.is_empty():
			break
	assert(game.ship_position.distance_to(occupied) <= 4.0, "Position %s, parked ship %s, velocity %s, detours %s" % [game.ship_position, game._ship_local(game.fleet[1]), game.velocity, game.fleet_detours])
	game.free()

	game = _start(map, origin, [_ship(Vector2(0, -350)), _ship(Vector2(0, 350)), _ship(Vector2(0, 1000))])
	await physics_frame
	game.selected_fleet.assign([0, 1, 2])
	game._toggle_sustained_boost()
	game._steer_sustained_boost(game._world_to_screen(Vector2(5000, 1000.0 / 3.0)))
	for index in [1, 2]:
		assert(game.fleet[index].navigation.mode == "boost")
		var position: Vector2 = game._ship_local(game.fleet[index])
		assert(STATE.relative(game.fleet[index].navigation.target, game.galaxy_origin).distance_to(position + Vector2(5000, 0)) < 1.0)
	for tick in 60:
		game._step_flight(STEP)
	assert(game.ship_position.x > 100.0 and game._ship_local(game.fleet[1]).x > 100.0 and game._ship_local(game.fleet[2]).x > 100.0)
	game._toggle_sustained_boost()
	assert(not game.sustained_boost_enabled and game.fleet[1].navigation.mode == "decelerate" and game.fleet[2].navigation.mode == "decelerate")

	game.free()
	game = _start(map, origin, [_ship(Vector2.ZERO), _ship(Vector2(500, 450)), _ship(Vector2(-500, -450))])
	await physics_frame
	game.selected_fleet.assign([0, 1, 2])
	game._show_hyperjump_context(1, Vector2.ZERO)
	assert(game.hyperjump_context_button.text == "Hyperjump 3 Ships" and not game.hyperjump_context_button.disabled)
	game._initiate_context_hyperjump()
	var arrivals: Array[PackedFloat64Array] = []
	for ship: Dictionary in game.fleet:
		var order: Dictionary = ship.orders[0]
		assert(ORDER.valid(order, ship.id, 2))
		for previous in arrivals:
			assert(STATE.relative(order.progress.travel_target, previous).length() > ship.radius * 2.0)
		arrivals.append(order.progress.travel_target)
	var starts: Array[int] = []
	for tick in 62:
		game._step_flight(STEP)
		for ship: Dictionary in game.fleet:
			if ship.navigation.mode == "jump" and is_equal_approx(float(ship.navigation.time), STEP):
				starts.append(tick)
	assert(starts == [0, 30, 60], "Departures must be staggered by 0.5 simulation seconds: %s" % [starts])
	# Exercise the physical arrival without traversing the entire interstellar leg.
	var course := STATE.relative(arrivals[0], game.galaxy_origin).normalized()
	game._rebase_world(STATE.relative(arrivals[0], game.galaxy_origin))
	for index in game.fleet.size():
		var ship: Dictionary = game.fleet[index]
		ship.galaxy_position = STATE.absolute(arrivals[index], -course * 1800.0)
		ship.velocity = Vector2.ZERO
		ship.heading = course.angle()
		ship.angular_velocity = 0.0
	game.ship_position = game._ship_local(game.fleet[0])
	game.velocity = Vector2.ZERO
	game.heading = course.angle()
	game.angular_velocity = 0.0
	game.ship_motion_remainder = Vector2.ZERO
	for tick in 1200:
		game._step_flight(STEP)
		if tick % 30 == 0:
			await physics_frame
		if game.fleet.all(func(ship: Dictionary) -> bool: return ship.orders.is_empty()):
			break
	for index in game.fleet.size():
		var ship: Dictionary = game.fleet[index]
		assert(ship.last_order.get("state") == "completed")
		assert(STATE.relative(ship.galaxy_position, arrivals[index]).length() <= 4.0)
	game.free()
	assert(await _check_converging_arrivals(map, origin))
	assert(await _check_occupied_arrival(map, origin))
	print("Fleet collision avoidance, group boost and staggered hyperjump checks passed")
	quit()

func _check_converging_arrivals(map: Dictionary, origin: Vector2) -> bool:
	# Both ships can brake in separate slots. Extrapolating the second ship's
	# velocity past its slot makes the first ship react to a phantom collision.
	var game := _start(map, origin, [_ship(Vector2(-325, 0)), _ship(Vector2(0, -500), PI / 2.0)])
	await physics_frame
	var first: Dictionary = game.fleet[0]
	var second: Dictionary = game.fleet[1]
	var spacing := AVOIDANCE.clearance(first.radius, second.radius) + 16.0
	var targets := [STATE.absolute(game.galaxy_origin, Vector2.ZERO), STATE.absolute(game.galaxy_origin, Vector2(0, -spacing))]
	second.galaxy_position = STATE.absolute(targets[1], Vector2(0, -300))
	game.velocity = Vector2(520, 0)
	second.velocity = Vector2(0, 800)
	for index in 2:
		assert(game._submit_fleet_order(index, "hyperjump", 1))
		var ship: Dictionary = game.fleet[index]
		ship.orders[0].progress = {"travel_target": targets[index], "jump_distance": 100000.0}
	var previous_speed := [520.0, 800.0]
	for tick in 360:
		game._step_flight(STEP)
		if tick % 10 == 0:
			await physics_frame
		assert(STATE.relative(first.galaxy_position, second.galaxy_position).length() >= spacing - 0.1)
		for index in 2:
			var ship: Dictionary = game.fleet[index]
			var speed: float = ship.velocity.length()
			assert(not game.fleet_detours.has(ship.id), "Arrival predicted a conflict beyond a neighboring slot")
			assert(speed <= previous_speed[index] + 0.5, "A braking ship accelerated again during its final approach")
			previous_speed[index] = speed
			assert(absf(angle_difference(ship.heading, 0.0 if index == 0 else PI / 2.0)) < 0.05)
	for index in 2:
		var ship: Dictionary = game.fleet[index]
		assert(ship.last_order.get("state") == "completed" and ship.velocity == Vector2.ZERO and ship.angular_velocity == 0.0)
		assert(STATE.relative(ship.galaxy_position, targets[index]).length() < 0.1)
	game.free()
	return true

func _check_occupied_arrival(map: Dictionary, origin: Vector2) -> bool:
	var game := _start(map, origin, [_ship(Vector2(-520, 0)), _ship(Vector2.ZERO)])
	await physics_frame
	var first: Dictionary = game.fleet[0]
	var second: Dictionary = game.fleet[1]
	var target: PackedFloat64Array = second.galaxy_position
	game.velocity = Vector2(700, 0)
	assert(game._submit_fleet_order(0, "hyperjump", 1))
	first.orders[0].progress = {"travel_target": target, "jump_distance": 100000.0}
	for tick in 180:
		game._step_flight(STEP)
		if tick % 30 == 0:
			await physics_frame
		assert(STATE.relative(first.galaxy_position, second.galaxy_position).length() > first.radius + second.radius)
	assert(not first.orders.is_empty() and game.velocity.length() < 20.0)
	assert(game._submit_fleet_order(1, "move", STATE.absolute(target, Vector2(0, 800))))
	for tick in 600:
		game._step_flight(STEP)
		if tick % 30 == 0:
			await physics_frame
		if first.orders.is_empty():
			break
	assert(first.last_order.get("state") == "completed" and first.velocity == Vector2.ZERO)
	assert(STATE.relative(first.galaxy_position, target).length() < 0.1)
	game.free()
	return true

func _start(map: Dictionary, origin: Vector2, ships: Array) -> Node:
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": ships})
	game.set_physics_process(false)
	game.set_process(false)
	for rock in game.asteroids:
		rock.visual.free()
	game.asteroids.clear()
	return game

func _ship(position: Vector2, heading := 0.0) -> Dictionary:
	return {"name": "Test ship", "parts": MODULES.default_design(), "position": position, "heading": heading,
		"hull": 100.0, "shield": 0.0, "shield_delay": 0.0}

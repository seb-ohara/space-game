extends SceneTree

const BOARD := preload("res://scripts/job_board.gd")
const WORLD := preload("res://scripts/mission_world.gd")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const FLIGHT := preload("res://main.tscn")
const SEED := 7419
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _test_generation() -> void:
	var map := GALAXY.create_map(SEED, 16)
	var a := BOARD.new()
	var b := BOARD.new()
	var plentiful := func(_index: int) -> int: return 100
	a.refresh(SEED, map.systems, 0, plentiful)
	b.refresh(SEED, map.systems, 0, plentiful)
	assert(a.snapshot() == b.snapshot())
	assert(a.offers.size() == 12)
	for kind in BOARD.KINDS:
		for tier in 3:
			var job := _job(a, kind, tier)
			assert(not job.is_empty())
			if tier > 0:
				assert(job.amount > _job(a, kind, tier - 1).amount and job.reward > _job(a, kind, tier - 1).reward)
	var accepted := _job(a, "mining", 0)
	assert(a.accept(accepted.id) == "" and a.accept(accepted.id) != "")
	a.refresh(SEED, map.systems, 2, func(_index: int) -> int: return 0)
	assert(a.round_number == 2 and a.active == [accepted] and a.offers.size() == 9 and a.offers[0].id > 12)
	assert(a.record_mining((accepted.target + 1) % map.systems.size(), 200).is_empty() and accepted.progress == 0)
	assert(BOARD.valid(a.snapshot(), map.systems.size(), {}))
	var invalid := a.snapshot()
	invalid.active[0].progress = invalid.active[0].amount
	assert(not BOARD.valid(invalid, map.systems.size(), {}))
	var solo := BOARD.new()
	solo.refresh(SEED, GALAXY.create_map(SEED, 1).systems, 0, plentiful)
	assert(solo.offers.size() == 12 and _job(solo, "freight", 2).target == 0)

func _run() -> void:
	_test_generation()
	var fixture := "drift-jobs-test-" + SAVES.new_id()
	var previous := OS.get_user_data_dir()
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", fixture)
	var isolated := OS.get_user_data_dir()
	assert(isolated != previous and isolated.get_file() == fixture)
	assert(DirAccess.make_dir_recursive_absolute(isolated) == OK)
	var map := GALAXY.create_map(SEED, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin,
		"fleet": [_ship("Carrier", Vector2.ZERO), _ship("Wing", Vector2(-5000.0, 0.0))]})
	game.galaxy_name = "Contract fixture"
	game.save_slot = SAVES.new_id()
	var world: WORLD = game.missions
	var board: BOARD = world.board

	# Opening the actual menu pauses the simulation and exposes the generated offers.
	assert(game.is_physics_processing())
	game._open_jobs()
	assert(game._jobs_open() and not game.is_physics_processing() and game.jobs_menu.list.item_count == 12)
	var now: float = game.elapsed
	await process_frame
	assert(game.elapsed == now)
	_button(game.jobs_menu, "Accept contract").pressed.emit()
	assert(game.jobs_menu.page == 1 and board.active.size() == 1)
	var mining := board.active[0]
	assert(mining.kind == "mining")
	_button(game.jobs_menu, "Close").pressed.emit()
	assert(not game._jobs_open() and game.is_physics_processing())
	game.set_physics_process(false)

	# Extraction is credited using the deposit's system, including off-screen ships.
	_place(game, world.site(mining.target, WORLD.EXCHANGE))
	var rock: Dictionary = game.asteroids[0]
	var rock_id: String = rock.id
	assert(rock.iron >= mining.amount)
	_place(game, world.site((mining.target + 1) % 2, WORLD.EXCHANGE))
	var wing: Dictionary = game.fleet[1]
	assert(game._extract_order_ore(wing, rock_id, mining.amount - 1) == mining.amount - 1)
	assert(mining.progress == mining.amount - 1 and board.credits == 0)
	assert(game._extract_order_ore(wing, rock_id, 1) == 1)
	assert(board.credits == mining.reward and board.history[0] == mining and wing.cargo.iron == mining.amount)
	assert(game._extract_order_ore(wing, rock_id, 1) == 1 and board.credits == mining.reward)

	# Survey course uses the existing jump and Move queue; scans require physical arrival.
	var survey := _job(board, "survey", 2)
	assert(board.accept(survey.id) == "")
	_place(game, world.site((survey.target + 1) % 2, WORLD.EXCHANGE))
	assert(world.set_course(survey) == "")
	assert(game.fleet[0].orders.size() == 2 and game.fleet[0].orders[0].type == "hyperjump" and game.fleet[0].orders[0].parameters.system == survey.target)
	assert(game.fleet[0].orders[1].type == "move" and survey.progress == 0)
	game._cancel_fleet_orders(0)
	for index in survey.amount:
		var signal_point := world._goal_point(survey, world.goal(survey))
		_place(game, signal_point)
		assert(survey.progress == index + 1)
		_tick_world(game)
		assert(survey.progress == index + 1)
	assert(board.credits == mining.reward + survey.reward)

	# Freight fills real hold space, and neutral freighters populate a visited relay.
	var freight := _job(board, "freight", 0)
	assert(board.accept(freight.id) == "" and freight.source != freight.target)
	game.iron = 61 - freight.amount
	_place(game, world.site(freight.source, WORLD.EXCHANGE))
	assert(freight.carrier == "" and game.enemies.size() == 1 and not game.enemies[0].hostile)
	assert(world.can_sell())
	var sale: int = game.iron * WORLD.IRON_PRICE
	world.sell_iron()
	assert(game.iron == 0 and board.credits == mining.reward + survey.reward + sale)
	_tick_world(game)
	var carrier: String = game.fleet[0].id
	assert(freight.carrier == carrier and game._flight_cargo().contracts == freight.amount)
	assert(game._ship_capabilities(0).available_cargo_space == 60 - freight.amount)

	# Ambient and wanted pirates are different encounters; only tagged mission kills advance a bounty.
	var bounty := _job(board, "bounty", 2)
	assert(board.accept(bounty.id) == "")
	_place(game, world.site(bounty.target, WORLD.RAIDER))
	assert(game.enemies.size() == 1 and game.enemies[0].hostile and not game.enemies[0].has("contract_id"))
	_shoot(game, game.enemies[0])
	assert(board.ambient_defeated.has(bounty.target) and bounty.progress == 0)
	_place(game, world.site(bounty.target, WORLD.BOUNTY))
	assert(game.enemies.size() == 3 and game.enemies[0].contract_id == bounty.id)
	_shoot(game, game.enemies[0])
	assert(bounty.progress == 1 and bounty.defeated == 1 and not game.enemies[0].alive)
	var actor_offset: Vector2 = game.enemies[1].position - game.ship_position
	game._rebase_world(Vector2(1600, 2400))
	assert((game.enemies[1].position - game.ship_position).is_equal_approx(actor_offset))
	game._set_simulation_rate(0)
	assert(game._save_galaxy())
	var id: String = game.save_slot
	var saved := SAVES.read(id)
	assert(saved.jobs == board.snapshot() and not saved.fleet[0].cargo.has("contracts"))
	var malformed := saved.duplicate(true)
	malformed.jobs.active[0].carrier = "missing-ship"
	assert(not game._valid_flight_save(malformed))
	game.free()

	game = FLIGHT.instantiate()
	root.add_child(game)
	game._load_game(id)
	assert(game.game_started and not game.is_physics_processing())
	world = game.missions
	board = world.board
	assert(board.snapshot() == saved.jobs and game._flight_cargo().contracts == freight.amount)
	bounty = BOARD.find(board.active, bounty.id)
	_tick_world(game)
	assert(game.enemies.size() == 2 and game.enemies[0].pirate_index == 1)
	_shoot(game, game.enemies[0])
	_shoot(game, game.enemies[1])
	assert(board.credits == saved.jobs.credits + bounty.reward and board.history[0].id == bounty.id)
	_tick_world(game)
	_place(game, world.site(bounty.target, WORLD.RAIDER))
	assert(game.enemies.is_empty())

	# Another ship at the depot cannot complete a loaded delivery.
	game._switch_fleet_control(1)
	_place(game, world.site(freight.target, WORLD.DEPOT))
	assert(board.active.size() == 1 and world.course_block(board.active[0]) == "Select Carrier to deliver this freight.")
	game._switch_fleet_control(0)
	var depot := world.site(freight.target, WORLD.DEPOT)
	_place(game, STATE.absolute(depot, Vector2(1800.0, 0.0)))
	assert(board.active.size() == 1 and world.set_course(board.active[0]) == "")
	var deadline: float = game.elapsed + 18.0
	game._set_simulation_rate(10)
	while not board.active.is_empty() and game.elapsed < deadline:
		await physics_frame
	game._set_simulation_rate(0)
	assert(board.active.is_empty() and game._flight_cargo().contracts == 0)
	assert(board.credits == saved.jobs.credits + bounty.reward + freight.reward)
	_tick_world(game)
	assert(board.history[0].id == freight.id and board.history.size() == 4)

	var abandoned := _job(board, "freight", 1)
	assert(board.accept(abandoned.id) == "")
	game._cancel_fleet_orders(0)
	_place(game, world.site(abandoned.source, WORLD.EXCHANGE))
	assert(game._flight_cargo().contracts == abandoned.amount)
	world.abandon(abandoned.id)
	assert(board.active.is_empty() and game._flight_cargo().contracts == 0 and board.history.size() == 4)
	assert(game._save_galaxy())
	game.free()
	assert(SAVES.delete(id))
	assert(DirAccess.remove_absolute(SAVES.RECENT_PATH) == OK)
	assert(DirAccess.remove_absolute(SAVES.SAVE_DIR) == OK)
	assert(DirAccess.remove_absolute(isolated) == OK)
	await process_frame
	print("Job board and galaxy encounter checks passed")
	quit()

func _job(board: BOARD, kind: String, tier: int) -> Dictionary:
	for job in board.offers:
		if job.kind == kind and job.tier == tier:
			return job
	return {}

func _ship(name: String, pos: Vector2) -> Dictionary:
	return {"name": name, "parts": MODULES.default_design(), "position": pos, "heading": 0.0,
		"hull": 100.0, "shield": 100.0, "shield_delay": 0.0,
		"admin": {"cargo": 60, "module_slots": [{"type": "laser"}, {"type": "miner"}]}}

func _place(game, point: PackedFloat64Array) -> void:
	game.ship_position = STATE.relative(point, game.galaxy_origin)
	game._maybe_rebase_world()
	# Preserve the double-precision contact through an interstellar placement.
	game.ship_position = STATE.relative(point, game.galaxy_origin)
	game.velocity = Vector2.ZERO
	game._commit_active_ship_state()
	game._load_asteroids_near_ship()
	_tick_world(game)

func _tick_world(game) -> void:
	for step in 12:
		game.simulation_clock.advance()
	game.missions.update()

func _shoot(game, pirate: Dictionary) -> void:
	var center: Vector2 = pirate.position
	var length: float = pirate.radius + 140.0
	game.projectiles.append({"position": center - Vector2(length, 0), "velocity": Vector2(length * 2.0 / STEP, 0),
		"friendly": true, "damage": 1000.0})
	game._update_combat(STEP)

func _button(parent: Node, caption: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text == caption:
			return child
		var found := _button(child, caption)
		if found != null:
			return found
	return null

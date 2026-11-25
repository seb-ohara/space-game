extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const FLIGHT := preload("res://main.tscn")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := GALAXY.create_map(7419, 2)
	var start: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var remote: Vector2 = map.systems[1].center - start
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": start, "fleet": [_ship(Vector2.ZERO), _ship(remote)]})
	game.set_physics_process(false)
	game.set_process(false)
	var pilot: Dictionary = game.fleet[0]
	var wing: Dictionary = game.fleet[1]
	var original: PackedFloat64Array = wing.galaxy_position
	assert(pilot.id != wing.id and game.ship_registry.find(wing.id) == wing)
	assert(wing.owner_id == "player" and not wing.design_id.is_empty())
	assert(game.fleet_views.is_empty())
	assert(game.ship_registry.nearby(original, 1000.0).size() == 1)
	wing.cargo.iron = 9
	game.iron = 3
	wing.navigation = {"mode": "move", "target": STATE.absolute(original, Vector2(2000, 0))}
	await physics_frame
	game._update_owned_fleet(STEP)
	assert(wing.galaxy_position[0] > original[0] and wing.galaxy_position[0] - original[0] < 1.0)
	var before_rebase: PackedFloat64Array = wing.galaxy_position
	var far_shift := Vector2(345678.375, -6823.625)
	game._rebase_world(far_shift)
	assert(wing.galaxy_position == before_rebase)
	game._update_owned_fleet(STEP)
	assert(wing.galaxy_position[0] > before_rebase[0])
	assert(not game.fleet_views.has(wing.id))

	game._execute_hyperjump(0, 1)
	var pilot_start := STATE.absolute(game.galaxy_origin, game.ship_position)
	game.heading = game.ship_position.direction_to(game.hyperjump_arrival).angle()
	var previous_velocity: Vector2 = wing.velocity
	game._switch_fleet_control(1)
	assert(game.fleet[game.active_fleet_index].id == wing.id and game.fleet.size() == 2)
	assert(game.iron == 9 and pilot.cargo.iron == 3 and game.velocity == previous_velocity and game.rts_move_active)
	assert(pilot.navigation.mode == "jump" and game.hyperjump_time < 0.0)
	for tick in range(30):
		game._update_owned_fleet(STEP)
	assert(pilot.navigation.time > 0.0 and pilot.galaxy_position != pilot_start)
	var jump_time: float = pilot.navigation.time
	game._switch_fleet_control(0)
	assert(game.hyperjump_time == jump_time and game.iron == 3)
	assert(STATE.snapshot(wing).size() == STATE.FIELDS.size() + STATE.ORDER_DEFAULTS.size() and not wing.has("collision_body"))
	game.free()
	print("Ship registry checks passed")
	quit()

func _ship(position: Vector2) -> Dictionary:
	return {"name": "Test ship", "parts": MODULES.default_design(), "position": position, "heading": 0.0,
		"hull": 100.0, "shield": 0.0, "shield_delay": 0.0}

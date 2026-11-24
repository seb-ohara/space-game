extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const FLIGHT := preload("res://main.tscn")
const SEED := 7419
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Isolate both the save slot and the recent-save pointer from player data.
	var normal_data_dir := OS.get_user_data_dir()
	var test_name := "drift-flight-test-" + SAVES.new_id()
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", test_name)
	var test_dir := OS.get_user_data_dir()
	assert(test_dir != normal_data_dir and test_dir.get_file() == test_name)
	assert(DirAccess.make_dir_recursive_absolute(test_dir) == OK)

	var map := GALAXY.create_map(SEED, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var initial := {"active_ship": 0, "world_origin": origin, "fleet": [
		{"name": "Pilot", "parts": MODULES.default_design(), "position": Vector2.ZERO, "heading": 0.0,
			"hull": 73.0, "shield": 20.0, "shield_delay": 2.0},
		{"name": "Wing", "parts": MODULES.default_design(), "position": Vector2(3000, 1000), "heading": 1.0,
			"hull": 57.0, "shield": 15.0, "shield_delay": 1.0},
	]}
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game._start_flight(map, {}, initial)
	game.set_physics_process(false)
	game.set_process(false)
	game.engine_audio.volume = 0.0
	game.galaxy_name = "Flight regression"
	game.save_slot = SAVES.new_id()
	game.play_time = 120.0
	game.elapsed = 30.0
	game.iron = 4
	game.tritium = 3
	assert(not game.asteroids.is_empty())
	var rock_id: String = game.asteroids[0].id
	var remaining := maxi(0, int(game.asteroids[0].iron) - 1)
	game.depleted_ore[rock_id] = remaining

	# Rebase without changing the relative ship or rock positions.
	var wing_offset: Vector2 = game.fleet[1].position - game.ship_position
	var rock_offset: Vector2 = game.asteroids[0].position - game.ship_position
	var shift := Vector2(1024, -2048)
	game._rebase_world(shift)
	assert(game.world_origin == origin + shift)
	assert(game.fleet[1].position - game.ship_position == wing_offset)
	assert((game.asteroids[0].position - game.ship_position).is_equal_approx(rock_offset))

	# Use a real physics-frame context for CharacterBody2D movement.
	await physics_frame
	var wing: Dictionary = game.fleet[1]
	var wing_start: Vector2 = wing.position
	var wing_course := Vector2.from_angle(wing.heading)
	wing.destination = wing_start + wing_course * 10000.0
	wing.move_active = true
	for tick in range(10):
		game._update_owned_fleet(STEP)
	assert(wing.move_active and (wing.position - wing_start).dot(wing_course) > 0.0)
	game._execute_hyperjump(0, 1)
	assert(game.hyperjump_time >= 0.0 and game.hyperjump_destination == 1)
	var position_before: Vector2 = game.ship_position
	game.heading = game.ship_position.direction_to(game.hyperjump_arrival).angle()
	for tick in range(30):
		game._physics_process(STEP)
	assert(game.ship_position != position_before and game.velocity.length() > 0.0)
	assert(is_equal_approx(game.elapsed, 30.5) and game.play_time == 120.0)
	assert(game.player_shield == 20.0 and is_equal_approx(game.player_shield_delay, 1.5))
	assert(game._save_galaxy())
	var slot_id: String = game.save_slot
	var saved := SAVES.read(slot_id)
	assert(saved.format_version == 1 and saved.generator_version == GALAXY.VERSION)
	assert(saved.active_ship == 0 and saved.fleet.size() == 2)
	assert(saved.jump.destination == 1 and saved.jump.arrival == game.hyperjump_arrival)

	var restored := FLIGHT.instantiate()
	root.add_child(restored)
	restored._load_game(slot_id)
	restored.set_physics_process(false)
	restored.set_process(false)
	restored.engine_audio.volume = 0.0
	assert(restored.game_started and restored.world_origin == game.world_origin)
	assert(restored.ship_position == game.ship_position and restored.velocity == game.velocity)
	assert(restored.fleet[1].position == game.fleet[1].position and restored.fleet[1].hull == 57.0)
	assert(restored.elapsed == game.elapsed and restored.play_time == game.play_time)
	assert(restored.iron == 4 and restored.tritium == 3)
	assert(restored.player_shield == game.player_shield and restored.player_shield_delay == game.player_shield_delay)
	assert(restored.hyperjump_time >= 0.0 and restored.hyperjump_arrival == game.hyperjump_arrival)
	assert(restored.depleted_ore[rock_id] == remaining)
	var restored_rock := false
	for asteroid in restored.asteroids:
		if asteroid.id == rock_id:
			restored_rock = asteroid.iron == remaining
			break
	assert(restored_rock)
	restored._physics_process(STEP)
	assert(restored.ship_position != saved.fleet[0].position and restored.hyperjump_time > 0.0)

	game.free()
	restored.free()
	assert(SAVES.delete(slot_id))
	assert(DirAccess.remove_absolute(SAVES.RECENT_PATH) == OK)
	assert(DirAccess.remove_absolute(SAVES.SAVE_DIR) == OK)
	assert(DirAccess.remove_absolute(test_dir) == OK)
	print("Flight persistence checks passed")
	quit()

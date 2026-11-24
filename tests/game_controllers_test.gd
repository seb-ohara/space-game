extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MINING := preload("res://scripts/mining_controller.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rocks := [{"position": Vector2(10, 0), "radius": 5.0, "iron": 2}, {"position": Vector2(10, 0), "radius": 2.0, "iron": 0}]
	assert(MINING.find_target(rocks, Vector2(10, 0)) == 0)
	assert(MINING.find_target(rocks, Vector2.ZERO) == -1)
	assert(MINING.mining_range(5.0, 10.0) == 655.0)
	var result := MINING.tick(2, 0.0, 2.0, 10, 0.5)
	assert(result.extracted == 1 and result.active and result.progress == 0.0)
	result = MINING.tick(1, result.progress, 2.0, 0, 1.0)
	assert(result.extracted == 0 and not result.active and result.progress == 1.0)
	result = MINING.tick(1, result.progress, 2.0, 9, 0.0)
	assert(result.extracted == 1 and result.depleted and result.progress == 0.0)
	assert(rocks[0].iron == 2) # The caller, not the rules, owns ore data.
	# Compare with the original per-unit loop across cargo/depletion boundaries.
	var random := RandomNumberGenerator.new()
	random.seed = 42
	for i in 1000:
		var ore := random.randi_range(1, 30)
		var capacity := random.randi_range(0, 30)
		var rate := random.randf_range(0.0, 8.0)
		var progress := random.randf_range(0.0, 3.0)
		var delta := random.randf_range(0.0, 2.0)
		var old_progress := progress + delta * rate
		var extracted := 0
		while old_progress >= 1.0 and extracted < ore and extracted < capacity:
			old_progress -= 1.0
			extracted += 1
		var active := rate > 0.0
		if extracted >= capacity:
			active = false
			old_progress = minf(old_progress, 1.0)
		if extracted >= ore:
			active = false
			old_progress = 0.0
		result = MINING.tick(ore, progress, rate, capacity, delta)
		assert(result.extracted == extracted and is_equal_approx(result.progress, old_progress) and result.active == active)

	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._start_flight(GALAXY.create_map(123, 1), {}, {})
	game.set_physics_process(false)
	game.set_process(false)
	game.player_shield = 0.0
	game.player_shield_delay = 0.0
	game._update_combat(0.1)
	assert(game.player_shield >= 0.0)
	# Exercise projectile collision through the real combat controller.
	var saved_asteroids: Array[Dictionary] = game.asteroids.duplicate()
	game.asteroids.clear()
	game.player_shield = 50.0
	game.player_shield_delay = 4.0
	game.invulnerability = 0.0
	game.projectiles.append({"position": game.ship_position + Vector2(-1000, 0), "velocity": Vector2(20000, 0), "friendly": false, "damage": 7.0})
	game._update_combat(0.1)
	assert(is_equal_approx(game.player_shield, 43.0) and game.projectiles.is_empty())
	game.asteroids.assign(saved_asteroids)
	assert(game._format_speed(0.0) == "0.0 m/s")
	game.firing = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._input(release)
	assert(not game.firing)
	game.queue_redraw()
	await process_frame
	await process_frame
	game.free()
	print("Game controller checks passed")
	quit()

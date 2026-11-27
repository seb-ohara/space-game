extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MINING := preload("res://scripts/mining_controller.gd")
const HUD := preload("res://scripts/game_hud.gd")
const SOLAR_SYSTEM := preload("res://scripts/solar_system.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map_rect := HUD.MINIMAP_RECT
	var camera_view := Vector2(1200, 800)
	var ship := Vector2(300, -500)
	var chart := HUD._minimap_chart(map_rect, camera_view, ship)
	assert((chart * ship).is_equal_approx(map_rect.get_center()))
	assert(is_equal_approx(maxf(camera_view.x * chart.x.x / map_rect.size.x, camera_view.y * chart.y.y / map_rect.size.y), 0.25))
	var moved_ship := ship + Vector2(120, 50)
	var zoomed_out := HUD._minimap_chart(map_rect, camera_view * 2.0, moved_ship)
	assert((zoomed_out * moved_ship).is_equal_approx(map_rect.get_center()))
	assert(is_equal_approx(zoomed_out.x.x, chart.x.x * 0.5))
	var track_area := Rect2(0, 0, 10, 10)
	var track_lines := PackedVector2Array()
	SOLAR_SYSTEM._append_clipped_minimap_segment(track_lines, track_area, Vector2(-5, -5), Vector2(15, 15))
	SOLAR_SYSTEM._append_clipped_minimap_segment(track_lines, track_area, Vector2(-3, 1), Vector2(-3, 9))
	assert(track_lines == PackedVector2Array([Vector2.ZERO, Vector2(10, 10)]))
	var rocks := [{"position": Vector2(10, 0), "radius": 5.0, "iron": 2}, {"position": Vector2(10, 0), "radius": 2.0, "iron": 0}]
	assert(MINING.find_target(rocks, Vector2(10, 0)) == 0)
	assert(MINING.find_target(rocks, Vector2.ZERO) == -1)
	assert(MINING.mining_range(5.0, 10.0) == 1305.0)
	assert(MINING.mining_range(5.0, 1500.0) == 1540.0)
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
	game._start_flight(GALAXY.create_map(123, 1), {}, {}, game.MODULES.generate_random_design(RandomNumberGenerator.new()))
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
	game.rts_attack_active = true
	game.firing = true
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._input(release)
	assert(game.firing, "Releasing the selection button does not interrupt a strategy attack order.")
	var ship_position: Vector2 = game.ship_position
	var ship_velocity: Vector2 = game.velocity
	var camera_start: Vector2 = game._camera_center()
	game.last_render_usec = Time.get_ticks_usec() - 100000
	Input.action_press("camera_pan_right")
	game._process(0.0)
	Input.action_release("camera_pan_right")
	assert(game._camera_center().x > camera_start.x and not game.camera_following)
	assert(game.ship_position == ship_position and game.velocity == ship_velocity)
	# Send trackpad gestures through the viewport, just like regular input.
	game._set_camera_zoom(sqrt(game._minimum_camera_zoom() * game._maximum_camera_zoom()))
	game.camera_following = true
	camera_start = game._camera_center()
	var swipe := InputEventPanGesture.new()
	swipe.position = root.get_visible_rect().size * 0.5
	var initial_zoom: float = game.camera_zoom_target
	swipe.delta = Vector2(32, 0)
	root.push_input(swipe, true)
	assert(game.camera_zoom_target == initial_zoom, "A horizontal swipe should not zoom.")
	swipe.delta.y = -32
	root.push_input(swipe, true)
	assert(is_equal_approx(game.camera_zoom_target, initial_zoom * game.CAMERA_ZOOM_STEP))
	assert(game.camera_zoom_focus == swipe.position)
	swipe.delta.y = 32
	root.push_input(swipe, true)
	assert(is_equal_approx(game.camera_zoom_target, initial_zoom))
	assert(game.camera_following and game._camera_center() == camera_start)
	assert(game.ship_position == ship_position and game.velocity == ship_velocity)
	var pinch := InputEventMagnifyGesture.new()
	pinch.position = swipe.position + Vector2(30, -40)
	pinch.factor = 1.15
	root.push_input(pinch, true)
	assert(is_equal_approx(game.camera_zoom_target, initial_zoom * pinch.factor))
	assert(game.camera_zoom_focus == pinch.position)
	pinch.factor = 0.5
	root.push_input(pinch, true)
	assert(is_equal_approx(game.camera_zoom_target, maxf(game._minimum_camera_zoom(), initial_zoom * 1.15 * 0.5)))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = pinch.position
	initial_zoom = game.camera_zoom_target
	root.push_input(wheel, true)
	assert(is_equal_approx(game.camera_zoom_target, initial_zoom * game.CAMERA_ZOOM_STEP))
	game._open_settings()
	camera_start = game._camera_center()
	initial_zoom = game.camera_zoom_target
	root.push_input(swipe, true)
	root.push_input(pinch, true)
	assert(game._camera_center() == camera_start and game.camera_zoom_target == initial_zoom)
	game._close_settings()
	game.set_physics_process(false)
	# A panned camera can cull the world renderers without hiding the ship's local orbits.
	game.camera_zoom = 0.0005
	var far_view := Rect2(Vector2.ONE * 100000000.0, Vector2.ONE * 1000.0)
	var solar = game.solar_system
	solar.update_view(game.elapsed, game._world_transform(), far_view.get_center(), Vector2.ZERO, far_view)
	assert(solar.visible_orbiters.is_empty())
	game.queue_redraw()
	await process_frame
	await process_frame
	assert(solar.minimap_orbiters.has(0))
	var planet = solar.minimap_orbiters[0][0]
	assert(planet.track == null and planet.visual == null and planet.label.begins_with("SOL "))
	var star_center: Vector2 = solar.system_centers[0]
	var relative: Vector2 = (planet.center - star_center - planet.center_offset).rotated(-planet.orbit_angle) / planet.axes
	assert(is_equal_approx(relative.length(), 1.0))
	game.free()
	print("Game controller checks passed")
	quit()

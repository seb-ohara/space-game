extends SceneTree
## Run windowed for actual GPU frame rates:
## godot --path . --script res://tests/ship_block_benchmark.gd -- tiles
## Variants: small (144 cells), stretch (3,600 cells in one plate), tiles (225 panels).

const GAME := preload("res://main.tscn")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const BUILDER := preload("res://scripts/ship_builder.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const WARMUP_USEC := 500_000
const SAMPLE_USEC := 1_500_000

func _initialize() -> void:
	_run.call_deferred()

func _design(mode: String) -> Array:
	var result := []
	var span := 12 if mode == "small" else 60
	if mode == "tiles":
		for y in range(15):
			for x in range(15):
				result.append({"type":"retro_plain", "fine_grid":true, "x":x * 4 - 30, "y":y * 4, "width":4, "height":4, "rotation":0})
	else:
		result.append({"type":"retro_plain", "fine_grid":true, "x":-span / 2, "y":0, "width":span, "height":span, "rotation":0})
	result.append_array([
		{"type":"command_station", "fine_grid":true, "layer":"interior", "x":0, "y":0, "rotation":0},
		{"type":"reactor", "fine_grid":true, "layer":"interior", "x":0, "y":4, "rotation":0},
		{"type":"engine", "fine_grid":true, "x":0, "y":span, "rotation":0},
	])
	return result

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var mode := args[0] if not args.is_empty() else "tiles"
	if mode not in ["small", "stretch", "tiles"]:
		push_error("Use small, stretch or tiles as the benchmark variant.")
		quit(1)
		return
	var parts := _design(mode)
	assert(MODULES.validate(parts).is_empty(), MODULES.validate(parts))
	var game := GAME.instantiate()
	root.add_child(game)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.graphics_quality = 2
	game.engine_audio.volume = 0.0
	var map := GALAXY.create_map(7419, 100)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var start := Time.get_ticks_usec()
	game._start_flight(map, {}, {"active_ship":0, "world_origin":origin, "fleet":[{
		"name":"Benchmark", "parts":parts, "position":Vector2.ZERO, "heading":0.0,
		"hull":100.0, "shield":100.0, "shield_delay":0.0,
	}]})
	print("variant=%s driver=%s setup=%.1fms hit_shapes=%d body_shapes=%d" % [mode, DisplayServer.get_name(),
		(Time.get_ticks_usec() - start) / 1000.0, game.cached_hull_shapes.size(), game.player_fleet_body.get_child_count()])
	game._set_camera_zoom(game._maximum_camera_zoom())
	game._set_simulation_rate(1)
	await _sample("Flight", game)
	await _sample("Flight with sustained shield impact", game, func():
		game.shield_impacts.clear()
		game.shield_impacts.append({"enemy":-1, "angle":0.0, "life":0.2, "rays":[]})
		game._queue_flight_redraw()
	)
	game.shield_impacts.clear()
	var builder := BUILDER.new()
	builder.initial_parts = parts
	builder.performance_profile = func(layout: Array) -> Dictionary: return game._stats_with_admin(layout, {})
	builder.show_cursor = true
	root.add_child(builder)
	game.hide()
	game.set_process(false)
	game.set_physics_process(false)
	var frame := [0]
	await _sample("Editor drag", game, func():
		builder.stretching = true
		builder.stretch_start = Vector2i(15, -4)
		builder.stretch_end = Vector2i(15 + int(frame[0]) % 14, -4)
		frame[0] += 1
		builder.queue_redraw()
	)
	quit()

func _sample(label: String, game: Node, update := Callable()) -> void:
	var warm := Time.get_ticks_usec() + WARMUP_USEC
	while Time.get_ticks_usec() < warm:
		if update.is_valid():
			update.call()
		await process_frame
	var started := Time.get_ticks_usec()
	var elapsed: float = game.elapsed
	var frames := 0
	while Time.get_ticks_usec() - started < SAMPLE_USEC:
		if update.is_valid():
			update.call()
		await process_frame
		frames += 1
	var seconds := (Time.get_ticks_usec() - started) / 1000000.0
	print("%s: %.1f FPS, %.2f× simulation rate" % [label, frames / seconds, (game.elapsed - elapsed) / seconds])

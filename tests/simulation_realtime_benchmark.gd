extends SceneTree
## Run without --fixed-fps to exercise real engine scheduling and (when windowed) GPU rendering.

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const CLOCK := preload("res://scripts/simulation/simulation_clock.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const FLIGHT := preload("res://main.tscn")
const WARMUP_USEC := 750000
const SAMPLE_USEC := 2000000

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := FLIGHT.instantiate()
	root.add_child(game)
	var overload := "--overload" in OS.get_cmdline_user_args()
	Engine.max_fps = 15 if overload else 60
	game.graphics_quality = 2
	game.engine_audio.volume = 0.0
	var map := GALAXY.create_map(7419, 1000)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [{
		"name": "Benchmark ship", "parts": MODULES.default_design(), "position": Vector2.ZERO,
		"heading": 0.0, "hull": 100.0, "shield": 100.0, "shield_delay": 0.0,
	}]})
	print("driver,systems,requested_rate,achieved_rate,frames_per_second")
	var rates := [10] if overload else CLOCK.RATES
	for rate: int in rates:
		game.rts_move_active = true
		game.rts_destination = game.ship_position + Vector2(50000.0, 0.0)
		game._set_simulation_rate(rate)
		var until := Time.get_ticks_usec() + WARMUP_USEC
		while Time.get_ticks_usec() < until:
			await process_frame
		var started := Time.get_ticks_usec()
		var started_sim: float = game.elapsed
		var frames := 0
		while Time.get_ticks_usec() - started < SAMPLE_USEC:
			await process_frame
			frames += 1
		var wall := float(Time.get_ticks_usec() - started) / 1000000.0
		var achieved: float = (game.elapsed - started_sim) / wall
		print("%s,1000,%d,%.3f,%.1f" % [DisplayServer.get_name(), rate, achieved, frames / wall])
		if overload:
			assert(achieved > 0.0 and achieved < 8.0 and game.simulation_calendar.text.ends_with("× actual"))
	game.free()
	print("Real-time simulation benchmark complete")
	quit()

extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const FLIGHT := preload("res://main.tscn")
const SHIP_STATE := preload("res://scripts/ships/ship_state.gd")
const SEED := 7419
const SAMPLES := 3
const WARMUP_TICKS := 30
const TICKS_PER_BATCH := 10
const BATCHES := 18
const MEASURED_TICKS := TICKS_PER_BATCH * BATCHES
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var remote_ships := 100 if "--fleet" in OS.get_cmdline_user_args() else 0
	print("systems,remote_ships,map_ms,formation_ms,flight_init_ms,flight_tick_mean_ms,presentation_mean_ms")
	for count in [100, 250, 500, 1000]:
		var map_times: Array[float] = []
		var formation_times: Array[float] = []
		var init_times: Array[float] = []
		var tick_times: Array[float] = []
		var presentation_times: Array[float] = []
		for sample in range(SAMPLES):
			var start := Time.get_ticks_usec()
			var map := GALAXY.create_map(SEED, count)
			map_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			assert(map.systems.size() == count)
			var contents := {}
			start = Time.get_ticks_usec()
			for index in count:
				contents[index] = GALAXY.form_system(SEED, map.systems[index], map.generator_version)
			formation_times.append(float(Time.get_ticks_usec() - start) / 1000.0)

			var game := FLIGHT.instantiate()
			root.add_child(game)
			game.graphics_quality = 2
			game.engine_audio.volume = 0.0
			var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
			# Supply a controlled starter rather than read the user's custom ship.
			var state := {"active_ship": 0, "world_origin": origin, "fleet": [{
				"name": "Benchmark ship", "parts": MODULES.default_design(), "position": Vector2.ZERO,
				"heading": 0.0, "hull": 100.0, "shield": 100.0, "shield_delay": 0.0,
			}]}
			start = Time.get_ticks_usec()
			game._start_flight(map, contents, state)
			for index in remote_ships:
				var system: Dictionary = map.systems[1 + index % (count - 1)]
				var position: Vector2 = system.center - origin + Vector2(index * 900.0, 0.0)
				var ship: Dictionary = game._register_ship({"name": "Remote ship", "parts": MODULES.default_design(),
					"position": position, "heading": 0.0, "hull": 100.0, "shield": 0.0, "shield_delay": 0.0})
				assert(game._submit_fleet_order(index + 1, "move", SHIP_STATE.absolute(ship.galaxy_position, Vector2(50000, 0))))
			game._redraw_flight()
			init_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			game.set_physics_process(false)
			game.set_process(false)
			game.rts_move_active = true
			game.rts_destination = Vector2(50000.0, 0.0)
			await physics_frame
			for tick in range(WARMUP_TICKS):
				game._physics_process(STEP)
			var tick_usec := 0
			var presentation_usec := 0
			# Sample a redraw after each ten ticks, as at 10× and 60 FPS.
			for batch in range(BATCHES):
				start = Time.get_ticks_usec()
				for tick in range(TICKS_PER_BATCH):
					game._physics_process(STEP)
				tick_usec += Time.get_ticks_usec() - start
				start = Time.get_ticks_usec()
				game._redraw_flight()
				presentation_usec += Time.get_ticks_usec() - start
			tick_times.append(float(tick_usec) / (MEASURED_TICKS * 1000.0))
			presentation_times.append(float(presentation_usec) / (BATCHES * 1000.0))
			assert(game.ship_position != Vector2.ZERO)
			assert(game.fleet_views.is_empty())
			if remote_ships > 0:
				assert(game.fleet[remote_ships].velocity.length() > 0.0)
			game.free()
			await process_frame
		print("%d,%d,%.3f,%.3f,%.3f,%.3f,%.3f" % [count, remote_ships, _median(map_times), _median(formation_times),
			_median(init_times), _median(tick_times), _median(presentation_times)])
	print("Galaxy baseline benchmark complete")
	quit()

func _median(samples: Array[float]) -> float:
	samples.sort()
	return samples[samples.size() >> 1]

extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const FLIGHT := preload("res://main.tscn")
const SEED := 7419
const SAMPLES := 3
const WARMUP_TICKS := 30
const MEASURED_TICKS := 180
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	print("systems,map_ms,formation_ms,flight_init_ms,flight_tick_mean_ms")
	for count in [100, 250, 500, 1000]:
		var map_times: Array[float] = []
		var formation_times: Array[float] = []
		var init_times: Array[float] = []
		var tick_times: Array[float] = []
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
			init_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
			game.set_physics_process(false)
			game.set_process(false)
			game.rts_move_active = true
			game.rts_destination = Vector2(50000.0, 0.0)
			await physics_frame
			for tick in range(WARMUP_TICKS):
				game._physics_process(STEP)
			start = Time.get_ticks_usec()
			for tick in range(MEASURED_TICKS):
				game._physics_process(STEP)
			tick_times.append(float(Time.get_ticks_usec() - start) / (MEASURED_TICKS * 1000.0))
			assert(game.ship_position != Vector2.ZERO)
			game.free()
			await process_frame
		print("%d,%.3f,%.3f,%.3f,%.3f" % [count, _median(map_times), _median(formation_times),
			_median(init_times), _median(tick_times)])
	print("Galaxy baseline benchmark complete")
	quit()

func _median(samples: Array[float]) -> float:
	samples.sort()
	return samples[samples.size() >> 1]

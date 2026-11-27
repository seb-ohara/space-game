extends SceneTree

const SHORT_BELL := preload("res://scripts/short_bell_exhaust.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const FLIGHT := preload("res://main.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var image := SHORT_BELL.make_flame_image()
	var core := image.get_pixel(48, 8)
	var edge := image.get_pixel(76, 8)
	assert(core.a > 0.98 and core.g > 0.97 and core.b > 0.93)
	assert(edge.a > 0.20 and edge.a < core.a and edge.g < 0.70)
	assert(image.get_pixel(48, 255).a == 0.0)
	assert(image.get_pixel(76, 160).a < edge.a)
	assert(SHORT_BELL.intensity(0.0) == 0.0)
	assert(SHORT_BELL.flicker(0.1, 0.0) != SHORT_BELL.flicker(0.2, 0.0))

	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(GALAXY.create_map(7419, 1), {}, {}, MODULES.preset_design(MODULES.SMALL_FIGHTER))
	game.set_physics_process(false)
	game.set_process(false)
	game.graphics_quality = 2
	game.exhaust_rng.seed = 7
	assert(game.cached_engines.size() == 2)
	assert(game.player_visual.engine_lights.size() == 2)
	assert(game.short_bell_texture != null)
	var engines: Array[Dictionary] = [game.cached_engines[0]]
	var engine := engines[0]
	var size: Vector2 = engine.bell_size
	var hull_length := 16.0 * MODULES.WORLD_UNITS_PER_METER
	assert(absf(size.y / hull_length - 91.0 / 169.0) < 0.001)
	assert(absf(size.x / hull_length - 8.8 / 169.0) < 0.001)
	assert(SHORT_BELL.dimensions(size, 0.40, 0.0).y < size.y)
	assert(SHORT_BELL.dimensions(size, 1.0, 1.0).y > size.y)
	var modular: Array[Dictionary] = []
	game._collect_engine_nozzles({"type": "engine", "x": 0, "y": 0, "rotation": 1}, Vector2.ZERO, modular, 2.0)
	assert(not modular.is_empty())
	assert((modular[0].nozzle as Transform2D).basis_xform(Vector2.DOWN).is_equal_approx(Vector2.LEFT))
	assert(is_equal_approx(float(modular[0].bell_size.y), 2.0 * SHORT_BELL.MODULE_LENGTH_FACTOR))

	var pose := Transform2D(0.35, Vector2(40, 50))
	var motion := Vector2(20, -25)
	var view := Rect2(-500, -500, 1000, 1000)
	game._emit_exhaust_particles(engines, pose, motion, 0.0, 0.0, 0.25, view)
	assert(game.exhaust_particles.is_empty(), "The bell should not emit while coasting.")
	game._emit_exhaust_particles(engines, pose, motion, 1.0, 0.0, 0.25, view)
	assert(game.exhaust_particles.size() == 4, "A quarter second should produce only a few embers per bell.")
	var nozzle: Transform2D = pose * engine.nozzle
	for particle in game.exhaust_particles:
		var drift: Vector2 = nozzle.basis_xform_inv(particle.velocity - motion) * float(particle.lifetime)
		assert(drift.y >= size.y * 0.89 and drift.y <= size.y * 1.31)
		assert(absf(drift.x) < size.x * 0.74 and float(particle.width) < size.x * 0.10)
		assert(float(particle.lifetime) < 0.44)
	game._update_engine_trails(engines, pose, motion, 1.0, false)
	assert(not engine.has("trail"), "Normal flight should not leave a long travel streak.")
	game._update_engine_trails(engines, pose, motion, 1.0, true)
	assert(engine.trail_active and engine.trail.size() == 1)

	game.engine_flame = 0.85
	game._redraw_flight()
	await process_frame
	assert(game.player_visual.engine_lights[0].visible)
	game.engine_flame = 0.0
	for tick in range(30):
		game.simulation_clock.advance()
	game._update_exhaust_particles(1.0 / 60.0)
	game._redraw_flight()
	assert(game.exhaust_particles.is_empty(), "Old embers should expire after cutoff.")
	assert(not game.player_visual.engine_lights[0].visible)
	game.free()
	print("Short Bell exhaust checks passed")
	quit()

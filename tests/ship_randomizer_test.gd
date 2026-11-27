extends SceneTree

const GENERATOR := preload("res://scripts/ship_randomizer.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const BUILDER := preload("res://scripts/ship_builder.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")
const RELIEF := preload("res://scripts/ship_relief.gd")
const FLIGHT := preload("res://main.tscn")
const GALAXY := preload("res://scripts/galaxy_generator.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var grid := MODULES.grid_bounds(true)
	assert(grid.size == Vector2i(1000, 1000) and grid.position.x + grid.end.x == 4)
	assert(MODULES.grid_bounds() == Rect2i(-21, -22, 43, 45))
	assert(GENERATOR.class_for_length(200.0) == "Capital Ship")
	assert(GENERATOR.class_for_length(199.5) == "Battleship")
	assert(GENERATOR.class_for_length(54.5) == "Custom")
	var rng := RandomNumberGenerator.new()
	var rng_repeat := RandomNumberGenerator.new()
	rng.seed = 7419
	rng_repeat.seed = 7419
	for class_id in GENERATOR.CLASS_NAMES.size():
		var families := {}
		var dimensions := {}
		for index in 12:
			var roll := GENERATOR.generate(rng, class_id)
			assert(roll == GENERATOR.generate(rng_repeat, class_id))
			var error := MODULES.validate(roll.parts)
			assert(error == "", "%s %s %.1f m: %s" % [roll.class, roll.family, roll.length, error])
			var length := MODULES.design_dimensions_meters(roll.parts).y
			assert(is_equal_approx(length, roll.length) and GENERATOR.class_for_length(length) == roll.class)
			assert(roll.parts.any(func(part: Dictionary) -> bool: return part.type == "retro_wedge"))
			assert(roll.parts.any(func(part: Dictionary) -> bool: return part.type == "window"))
			families[roll.family] = true
			dimensions[length] = true
		assert(families.size() == 2 and dimensions.size() >= 3)
	for index in 150:
		var raider := GENERATOR.generate(rng, index % 3, true)
		var error := MODULES.validate(raider.parts)
		assert(error == "", "%s %s: %s" % [raider.class, raider.family, error])
		assert(raider.parts.any(func(part: Dictionary) -> bool: return part.has("turret") and part.turret != "miner"), "%s %.1f m needs a turret" % [raider.family, raider.length])
	var largest: Array = [_part("retro_plain", Rect2i(-8, grid.position.y, 20, grid.size.y - 4)),
		_part("engine", Rect2i(0, grid.end.y - 4, 4, 4)),
		_part("command_station", Rect2i(0, 0, 4, 4), "interior"),
		_part("reactor", Rect2i(0, 4, 4, 4), "interior")]
	assert(MODULES.design_dimensions_meters(largest).y == 500.0 and MODULES.validate(largest) == "")
	var too_long := largest.duplicate(true)
	too_long[1].y += 1
	assert(MODULES.validate(too_long) != "")
	assert(MODULES.validate(LIBRARY.restore_design(JSON.parse_string(JSON.stringify(largest)))) == "")
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var builder := BUILDER.new()
	builder.initial_parts = largest
	host.add_child(builder)
	await process_frame
	assert(builder._grid_spacing() * grid.size.y < builder._grid_viewport().size.y)
	builder.random_class.select(7)
	builder.rng.seed = 19
	builder._randomize_ship()
	var capital := builder.parts.duplicate(true)
	assert(GENERATOR.class_for_length(MODULES.design_dimensions_meters(capital).y) == "Capital Ship")
	builder._undo_edit()
	assert(builder.parts == largest)
	host.free()
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game._start_flight(GALAXY.create_map(42, 1), {}, {}, largest)
	game._set_simulation_rate(0)
	assert(game.game_started and game.has_flight_controls and game.player_fleet_body.get_child_count() > 0)
	var texture: Texture2D = game.player_visual.material.get_shader_parameter("relief_map")
	assert(texture.get_height() <= RELIEF.MAX_RELIEF_EDGE and texture.get_width() <= RELIEF.MAX_RELIEF_EDGE)
	game.free()
	print("Ship randomizer and 500 m blueprint checks passed")
	quit()

func _part(kind: String, rect: Rect2i, layer := "exterior") -> Dictionary:
	return {"type": kind, "fine_grid": true, "layer": layer, "x": rect.position.x, "y": rect.position.y,
		"width": rect.size.x, "height": rect.size.y, "rotation": 0}

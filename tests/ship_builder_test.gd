extends SceneTree

const HANGAR := preload("res://scripts/hangar.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")

func _initialize() -> void:
	call_deferred("_run")

func _mouse(builder: Control, cell: Vector2i, button: MouseButton, pressed: bool, shift := false, offset := Vector2.ZERO) -> void:
	var event := InputEventMouseButton.new()
	event.position = builder._grid_center() + (Vector2(cell) + offset) * builder._grid_spacing()
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	root.push_input(event, true)

func _motion(builder: Control, cell: Vector2i) -> void:
	var event := InputEventMouseMotion.new()
	event.position = builder._grid_center() + Vector2(cell) * builder._grid_spacing()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)

func _key(keycode: Key, meta := false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.meta_pressed = meta
	event.pressed = true
	root.push_input(event, true)

func _run() -> void:
	var hangar := HANGAR.new()
	hangar.current_parts = MODULES.preset_design(MODULES.SMALL_FIGHTER)
	root.add_child(hangar)
	await process_frame
	var builder := hangar.builder
	assert(builder.is_visible_in_tree() and builder.parts.is_empty() and not hangar.library_panel.visible)
	var prior_design := builder.parts
	hangar._show_library()
	assert(hangar.library_designs.all(func(design: Dictionary) -> bool: return HANGAR.is_editable_design(design.parts)))
	hangar._resume_editing()
	assert(builder.parts == prior_design and builder.is_visible_in_tree())
	assert(builder._grid_viewport().size.x > 100)
	var hull_options := []
	for kind in builder.palette_buttons:
		if MODULES.TYPES[kind].category == "HULL & STRUCTURE":
			hull_options.append(builder.palette_buttons[kind].text)
	assert(hull_options == ["Hull", "Right-angle hull"])
	for retired in ["retro_turret_base", "retro_engine", "retro_bridge", "retro_antenna"]:
		assert(not builder.palette_buttons.has(retired))

	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 1)
	assert(builder.parts[0].type == "retro_plain")
	assert(MODULES.footprint(builder.parts[0]).size == Vector2i.ONE)
	var hull_bounds := MODULES.bounds(builder.parts)
	assert(hull_bounds.size == Vector2.ONE * MODULES.CELL / 4.0)
	var first_hull: Dictionary = builder.parts[0]
	var hull_shapes := MODULES.structural_polygons(first_hull, MODULES.part_position(first_hull) - hull_bounds.get_center())
	assert(hull_shapes.size() == 1 and hull_shapes[0][0] == -hull_bounds.size * 0.5)
	var texture := MODULES.HULL_TEXTURES.retro_plain.get_image() as Image
	var swatch := texture.get_pixel(64, 64)
	assert(is_equal_approx(swatch.r, swatch.g) and is_equal_approx(swatch.g, swatch.b))
	assert(swatch != texture.get_pixel(15, 0), "Neutral hull should still have texture")

	builder.palette_buttons.retro_wedge.pressed.emit()
	_key(KEY_R)
	_key(KEY_F)
	_mouse(builder, Vector2i(1, 0), MOUSE_BUTTON_LEFT, true)
	_motion(builder, Vector2i(3, 1))
	assert(builder.stretching and builder.parts.size() == 1)
	assert(builder._stretch_plan().size == Vector2i(3, 2))
	_mouse(builder, Vector2i(3, 1), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 2, builder.status)
	var wedge: Dictionary = builder.parts[1]
	assert(wedge.type == "retro_wedge" and wedge.rotation == 1 and wedge.flip_x)
	assert(MODULES.footprint(wedge) == Rect2i(1, 0, 3, 2))
	assert(MODULES.hull_polygon(wedge, Vector2.ZERO).size() == 3)
	assert(not MODULES.occupies(wedge, Vector2i(3, 0)))

	_mouse(builder, Vector2i(3, 1), MOUSE_BUTTON_LEFT, true, true)
	_motion(builder, Vector2i(4, 2))
	_mouse(builder, Vector2i(4, 2), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 2 and MODULES.footprint(builder.parts[1]) == Rect2i(1, 0, 4, 3), builder.status)
	_key(KEY_Z, true)
	assert(MODULES.footprint(builder.parts[1]) == Rect2i(1, 0, 3, 2))
	_mouse(builder, Vector2i(3, 1), MOUSE_BUTTON_LEFT, true, true)
	_mouse(builder, Vector2i(4, 2), MOUSE_BUTTON_LEFT, false)
	builder.paint_picker.color = Color("26c0b3")
	builder.paint_button.button_pressed = true
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_motion(builder, Vector2i(1, 1))
	_mouse(builder, Vector2i(1, 1), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts[0].has("paint") and builder.parts[1].has("cell_paints"))
	_key(KEY_Z, true)
	assert(not builder.parts[0].has("paint") and not builder.parts[1].has("cell_paints"), "Undo should revert the whole stroke")
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_motion(builder, Vector2i(1, 1))
	_mouse(builder, Vector2i(1, 1), MOUSE_BUTTON_LEFT, false)
	builder.paint_button.button_pressed = false
	var saved := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(saved.size() == 2 and MODULES.footprint(saved[1]) == Rect2i(1, 0, 4, 3))
	assert(saved[0].paint == "26c0b3" and saved[1].cell_paints["0,1"] == "26c0b3")
	assert(MODULES.validate(saved) != "", "An unfinished hull should not launch")

	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_RIGHT, true)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_RIGHT, false)
	assert(builder.parts.size() == 1)
	_key(KEY_Z, true)
	assert(builder.parts.size() == 2 and builder.parts[0].paint == "26c0b3")
	assert(hangar.current_parts == MODULES.preset_design(MODULES.SMALL_FIGHTER))
	var closes := []
	hangar.closed.connect(func(): closes.append(true))
	_key(KEY_ESCAPE)
	assert(builder.exit_dialog.visible)
	builder._exit_action(&"discard")
	assert(closes.size() == 1)
	await process_frame

	# Build a flyable ship using only the simplified palette.
	hangar._open_builder([])
	await process_frame
	builder = hangar.builder
	_mouse(builder, Vector2i(-4, 0), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(7, 7), MOUSE_BUTTON_LEFT, false)
	# A one-fine-cell step under the hull, deliberately off the original grid.
	_mouse(builder, Vector2i(1, 8), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(4, 8), MOUSE_BUTTON_LEFT, false)
	builder.palette_buttons.engine.pressed.emit()
	_mouse(builder, Vector2i(2, 9), MOUSE_BUTTON_LEFT, true, false, Vector2(0.5, 0.0))
	var engine_plan := builder._stretch_plan()
	assert(engine_plan.error == "" and MODULES.footprint(engine_plan.pieces[0]) == Rect2i(1, 9, 4, 4), engine_plan.error)
	_mouse(builder, Vector2i(2, 9), MOUSE_BUTTON_LEFT, false, false, Vector2(0.5, 0.0))
	for placement: Array in [["turret_base", Vector2i(8, 1)], ["laser", Vector2i(11, 3)]]:
		builder.palette_buttons[placement[0]].pressed.emit()
		_mouse(builder, placement[1], MOUSE_BUTTON_LEFT, true)
		_mouse(builder, placement[1], MOUSE_BUTTON_LEFT, false)
	assert(MODULES.footprint(builder.parts[2]) == Rect2i(1, 9, 4, 4))
	assert(MODULES.footprint(builder.parts[3]) == Rect2i(8, 1, 4, 4))
	assert(builder.parts[3].type == "turret_base" and builder.parts[3].turret == "laser")
	builder._toggle_view()
	for placement: Array in [["command_deck", Vector2i(-4, 0)], ["reactor", Vector2i(1, 4)]]:
		assert(builder.palette_buttons[placement[0]].visible)
		builder.palette_buttons[placement[0]].pressed.emit()
		_mouse(builder, placement[1], MOUSE_BUTTON_LEFT, true)
		_mouse(builder, placement[1], MOUSE_BUTTON_LEFT, false)
	assert(MODULES.validate(builder.parts) == "", MODULES.validate(builder.parts))
	var reopened := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(MODULES.validate(reopened) == "" and reopened[4].type == "command_deck")
	assert(MODULES.footprint(reopened[4]).size == Vector2i(12, 4))
	_mouse(builder, Vector2i(-3, 2), MOUSE_BUTTON_RIGHT, true)
	_mouse(builder, Vector2i(-3, 2), MOUSE_BUTTON_RIGHT, false)
	builder.palette_buttons.command_station.pressed.emit()
	_mouse(builder, Vector2i(-3, 2), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(-3, 2), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts[-1].type == "command_station")
	assert(MODULES.footprint(builder.parts[-1]).size == Vector2i(4, 4))
	assert(MODULES.validate(builder.parts) == "" and MODULES.has_command_deck(builder.parts))
	assert(MODULES.validate(LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))) == "")

	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(24):
		var modular := MODULES.generate_random_design(rng)
		assert(MODULES.validate(modular) == "", MODULES.validate(modular))
		assert(modular.all(func(part: Dictionary) -> bool: return part.type in MODULES.ORDER))
		var fine := MODULES.to_fine_grid(modular)
		assert(MODULES.validate(fine) == "", MODULES.validate(fine))
		assert(MODULES.bounds(fine) == MODULES.bounds(modular))
		assert(MODULES.stats(fine).health == MODULES.stats(modular).health)
		assert(MODULES.stats(fine).power == MODULES.stats(modular).power)
		var engine_index := modular.find_custom(func(part: Dictionary) -> bool: return part.type == "engine")
		var old_engine: Dictionary = modular[engine_index]
		var new_engine: Dictionary = fine[engine_index]
		assert(MODULES.engine_vertices(old_engine, MODULES.part_position(old_engine)) == MODULES.engine_vertices(new_engine, MODULES.part_position(new_engine)))
	var launches := []
	hangar.launch_requested.connect(func(parts: Array): launches.append(parts))
	builder._deploy()
	assert(launches.size() == 1 and launches[0] == builder.parts)

	# The two stepped pads from the reported case can be fitted in symmetry mode.
	builder._toggle_view()
	builder.parts = [
		{"type":"retro_plain", "fine_grid":true, "x":-4, "y":0, "width":12, "height":4, "rotation":0},
		{"type":"retro_plain", "fine_grid":true, "x":-5, "y":4, "width":4, "height":3, "rotation":0},
		{"type":"retro_plain", "fine_grid":true, "x":5, "y":4, "width":4, "height":3, "rotation":0},
	]
	builder.symmetry_button.button_pressed = true
	builder.palette_buttons.engine.pressed.emit()
	var right_facing_edge := builder._grid_center() + Vector2(7.0, 5.5) * builder._grid_spacing()
	assert(builder._engine_anchor_at(right_facing_edge, 1) == Vector2i(4, 4))
	_mouse(builder, Vector2i(-4, 7), MOUSE_BUTTON_LEFT, true, false, Vector2(0.5, 0.0))
	_mouse(builder, Vector2i(-4, 7), MOUSE_BUTTON_LEFT, false, false, Vector2(0.5, 0.0))
	assert(builder.parts.size() == 5, builder.status)
	assert(MODULES.footprint(builder.parts[3]) == Rect2i(-5, 7, 4, 4))
	assert(MODULES.footprint(builder.parts[4]) == Rect2i(5, 7, 4, 4))
	hangar.free()
	print("Ship builder checks passed")
	quit()

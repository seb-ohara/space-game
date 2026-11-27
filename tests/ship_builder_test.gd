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
	var swipe := InputEventPanGesture.new()
	swipe.position = builder._grid_viewport().get_center() + Vector2(80, -40)
	var zoom_before := builder.grid_zoom
	var anchor := (swipe.position - builder._grid_center()) / builder._grid_spacing()
	swipe.delta = Vector2(32, 0)
	root.push_input(swipe, true)
	assert(builder.grid_zoom == zoom_before, "A horizontal two-finger drag should not zoom.")
	swipe.delta = Vector2(0, -32)
	root.push_input(swipe, true)
	assert(is_equal_approx(builder.grid_zoom, zoom_before * builder.GRID_ZOOM_STEP))
	assert(anchor.is_equal_approx((swipe.position - builder._grid_center()) / builder._grid_spacing()), "Trackpad zoom should stay anchored to the pointer.")
	swipe.delta.y = 32
	root.push_input(swipe, true)
	assert(is_equal_approx(builder.grid_zoom, zoom_before))
	swipe.position.x = 20
	root.push_input(swipe, true)
	assert(is_equal_approx(builder.grid_zoom, zoom_before), "Dragging outside the canvas must not zoom it.")
	var hull_options := []
	for kind in builder.palette_buttons:
		if MODULES.TYPES[kind].category == "HULL & STRUCTURE":
			hull_options.append(builder.palette_buttons[kind].text)
	assert(hull_options == ["Hull", "Right-angle hull", "Window", "Right-angle window"])
	assert(builder._design_dimensions() == Vector2.ZERO)
	for retired in ["retro_turret_base", "retro_engine", "retro_bridge", "retro_antenna"]:
		assert(not builder.palette_buttons.has(retired))

	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 1)
	assert(builder.parts[0].type == "retro_plain")
	assert(MODULES.footprint(builder.parts[0]).size == Vector2i.ONE)
	assert(builder._design_dimensions().is_equal_approx(Vector2(0.5, 0.5)))
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
	builder._toggle_view()
	builder.palette_buttons.retro_plain.pressed.emit()
	_mouse(builder, Vector2i(0, -4), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(0, -4), MOUSE_BUTTON_LEFT, false)
	assert(MODULES.footprint(builder.parts[-1]) == Rect2i(0, -4, 1, 1), builder.status)
	var draft := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(draft.size() == builder.parts.size())
	builder._deploy()
	assert(launches.is_empty() and builder.status == "Every component must connect to the ship.")
	_mouse(builder, Vector2i(0, -3), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(0, -1), MOUSE_BUTTON_LEFT, false)
	builder.palette_buttons.rivet.pressed.emit()
	_mouse(builder, Vector2i(0, -3), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(0, -3), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts[-1].type == "rivet")
	builder._deploy()
	assert(launches.size() == 1 and launches[0] == builder.parts, builder.status)

	# The two stepped pads from the reported case can be fitted in symmetry mode.
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

	builder.symmetry_button.button_pressed = false
	builder.parts = []
	builder.part_rotation = 0
	builder.part_flipped = false
	builder.palette_buttons.window.pressed.emit()
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(3, 3), MOUSE_BUTTON_LEFT, false)
	builder.palette_buttons.window_wedge.pressed.emit()
	_mouse(builder, Vector2i(4, 0), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(6, 2), MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 2, builder.status)
	assert(MODULES.footprint(builder.parts[1]) == Rect2i(4, 0, 3, 3))
	assert(MODULES.hull_polygon(builder.parts[1], Vector2.ZERO).size() == 3)
	assert(not MODULES.occupies(builder.parts[1], Vector2i(6, 0)))
	assert(MODULES.has_interior_floor(builder.parts[1], Vector2i(4, 2)))
	assert(not MODULES.has_interior_floor(builder.parts[1], Vector2i(4, 0)))
	assert(builder._design_dimensions().is_equal_approx(Vector2(3.5, 2.0)))
	builder._toggle_view()
	builder.palette_buttons.command_station.pressed.emit()
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, false)
	assert(builder.parts.size() == 3)
	var glass := MODULES.window_render_context(builder.parts)
	assert(glass.interior == [builder.parts[2]])
	# The angled pane shares only three of the square pane's four edge cells.
	# Keep the exposed one-cell tail, not the border underneath the join.
	var seam_x := MODULES.part_position(builder.parts[1]).x - MODULES.FINE_CELL * 0.5
	var exposed := 0.0
	for rim: PackedVector2Array in glass.rims.values():
		for i in range(0, rim.size(), 2):
			if is_equal_approx(rim[i].x, seam_x) and is_equal_approx(rim[i + 1].x, seam_x):
				exposed += rim[i].distance_to(rim[i + 1])
	assert(is_equal_approx(exposed, MODULES.FINE_CELL), "Joined panes must not draw internal borders")
	var second_square: Dictionary = builder.parts[0].duplicate()
	second_square.x = 4
	var joined := MODULES.window_render_context([builder.parts[0], second_square])
	for rim: PackedVector2Array in joined.rims.values():
		for i in range(0, rim.size(), 2):
			assert(not (is_equal_approx(rim[i].x, seam_x) and is_equal_approx(rim[i + 1].x, seam_x)))
	assert(MODULES.validate(builder.parts, false, false) == "")
	var windows_reopened := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(windows_reopened.size() == 3 and windows_reopened[1].type == "window_wedge")
	assert(MODULES.bounds(windows_reopened) == MODULES.bounds(builder.parts))
	builder._toggle_view()
	await _exercise_wedge_infill(builder)
	await _exercise_circle(builder)
	await _exercise_decorations(builder)
	await _exercise_layout_cache(builder)
	await process_frame
	await process_frame
	hangar.free()
	print("Ship builder checks passed")
	quit()

func _exercise_decorations(builder: Control) -> void:
	if builder.interior_view:
		assert(not builder.palette_buttons.rivet.visible and not builder.palette_buttons.vent.visible)
		builder._toggle_view()
	assert(builder.category_labels["DECORATIONS"].visible)
	var hull := {"type":"retro_plain", "fine_grid":true, "x":-4, "y":0, "width":12, "height":6, "rotation":0}
	var island := {"type":"retro_plain", "fine_grid":true, "x":9, "y":1, "rotation":0}
	builder.parts = [hull, island]
	builder.part_rotation = 0
	builder.part_flipped = false
	builder.palette_buttons.rivet.pressed.emit()
	var rivet_cell := Vector2i(1, 1)
	_mouse(builder, rivet_cell, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, rivet_cell, MOUSE_BUTTON_LEFT, false)
	var rivet: Dictionary = builder.parts[-1]
	assert(rivet.type == "rivet" and MODULES.is_decoration(rivet))
	assert(MODULES.footprint(rivet) == Rect2i(1, 1, 1, 1), "One click places a one-cell rivet, including on a disconnected draft")
	_mouse(builder, Vector2i(1, 2), MOUSE_BUTTON_RIGHT, true)
	_mouse(builder, Vector2i(1, 2), MOUSE_BUTTON_RIGHT, false)
	assert(MODULES.occupies(hull, Vector2i(1, 2)), "Decorations should erase without cutting hull")
	builder.parts = [hull, rivet]
	var before: Array = builder.parts.duplicate(true)
	builder.palette_buttons.vent.pressed.emit()
	builder.symmetry_button.button_pressed = true
	_key(KEY_R)
	var start := Vector2i(-3, 2)
	var finish := Vector2i(-1, 3)
	_mouse(builder, start, MOUSE_BUTTON_LEFT, true)
	_motion(builder, finish)
	var plan: Dictionary = builder._stretch_plan()
	assert(plan.error == "" and plan.size == Vector2i(3, 2) and plan.pieces.size() == 2, plan.error)
	await process_frame
	_mouse(builder, finish, MOUSE_BUTTON_LEFT, false)
	assert(builder.parts[2].type == "vent" and builder.parts[2].rotation == 1)
	assert(MODULES.footprint(builder.parts[2]) == Rect2i(-3, 2, 3, 2))
	assert(MODULES.footprint(builder.parts[3]) == Rect2i(4, 2, 3, 2))
	_mouse(builder, finish, MOUSE_BUTTON_LEFT, true, true)
	_mouse(builder, Vector2i(-1, 6), MOUSE_BUTTON_LEFT, false)
	assert(MODULES.footprint(builder.parts[2]).size == Vector2i(3, 2), "Resize must not extend beyond the supporting hull")
	_mouse(builder, finish, MOUSE_BUTTON_LEFT, true, true)
	_mouse(builder, Vector2i(-1, 4), MOUSE_BUTTON_LEFT, false)
	assert(MODULES.footprint(builder.parts[2]) == Rect2i(-3, 2, 3, 3))
	assert(MODULES.footprint(builder.parts[3]) == Rect2i(4, 2, 3, 3))
	assert(MODULES.stats(builder.parts) == MODULES.stats([hull]) and MODULES.bounds(builder.parts) == MODULES.bounds([hull]))
	assert(not MODULES.validate(builder.parts + [rivet], false, false).is_empty(), "Decorations cannot overlap")
	var placed: Array = builder.parts.duplicate(true)
	var restored := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(placed)))
	assert(restored.size() == placed.size() and MODULES.validate(restored, false, false) == "")
	for i in range(1, restored.size()):
		assert(MODULES.is_decoration(restored[i]) and restored[i].type == placed[i].type)
		assert(MODULES.footprint(restored[i]) == MODULES.footprint(placed[i]))
		assert(int(restored[i].rotation) == placed[i].rotation and restored[i].flip_x == placed[i].flip_x)
	_mouse(builder, start, MOUSE_BUTTON_RIGHT, true)
	_mouse(builder, start, MOUSE_BUTTON_RIGHT, false)
	assert(builder.parts == before, "Erase should remove the vent and its mirror without touching hull")
	_key(KEY_Z, true)
	assert(builder.parts == placed, "Undo should restore both decorations")
	builder.symmetry_button.button_pressed = false

func _exercise_layout_cache(builder: Control) -> void:
	if builder.interior_view:
		builder._toggle_view()
	var profile_calls: Array[int] = []
	builder.performance_profile = func(_parts: Array) -> Dictionary:
		profile_calls.append(1)
		return {"travel_acceleration":0.0, "normal_speed":0.0, "turn_rate":0.0, "boost":0.0, "hyperdrive":0.0}
	builder.parts = [{"type":"retro_plain", "fine_grid":true, "x":-20, "y":-15, "width":40, "height":30, "rotation":0}]
	builder.palette_buttons.retro_plain.pressed.emit()
	builder.queue_redraw()
	await process_frame
	await process_frame
	assert(profile_calls.size() == 1)
	for x in range(4):
		_motion(builder, Vector2i(x, -16))
		await process_frame
	assert(profile_calls.size() == 1, "Hovering should not recompute flight stats")
	_mouse(builder, Vector2i(0, -16), MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i(3, -16), MOUSE_BUTTON_LEFT, false)
	await process_frame
	await process_frame
	assert(profile_calls.size() == 2 and builder.layout_cache.dimensions == Vector2(20.0, 15.5))
	_mouse(builder, Vector2i(0, -16), MOUSE_BUTTON_RIGHT, true)
	_mouse(builder, Vector2i(0, -16), MOUSE_BUTTON_RIGHT, false)
	await process_frame
	await process_frame
	assert(profile_calls.size() == 3 and builder.parts[-1].has("cutouts"), "Erasing in place must invalidate the layout")

func _exercise_wedge_infill(builder: Control) -> void:
	# A stretched window leaves half a slot open along its diagonal.
	var pane := {"type":"window_wedge", "fine_grid":true, "x":0, "y":0, "width":2, "height":2, "rotation":0}
	builder.parts = [pane]
	builder.part_rotation = 0
	builder.part_flipped = false
	builder.palette_buttons.retro_wedge.pressed.emit()
	var cell := Vector2i(1, 1)
	var open_half := Vector2(0.25, -0.25)
	_mouse(builder, cell, MOUSE_BUTTON_LEFT, true, false, open_half)
	_mouse(builder, cell, MOUSE_BUTTON_LEFT, false, false, open_half)
	assert(builder.parts.size() == 1 and builder.status == "Components cannot overlap.")
	_key(KEY_R)
	_key(KEY_R)
	_mouse(builder, cell, MOUSE_BUTTON_LEFT, true, false, open_half)
	_mouse(builder, cell, MOUSE_BUTTON_LEFT, false, false, open_half)
	assert(builder.parts.size() == 2, builder.status)
	var infill: Dictionary = builder.parts[1]
	assert(infill.type == "retro_wedge" and MODULES.footprint(infill) == Rect2i(1, 1, 1, 1))
	var neighbor := {"type":"retro_plain", "fine_grid":true, "x":2, "y":1, "rotation":0}
	assert(MODULES.validate([pane, neighbor], false, false) == "Every component must connect to the ship.")
	assert(MODULES.validate([pane, infill, neighbor], false, false) == "")
	assert(MODULES.validate([pane, infill, infill.duplicate()], false, false) == "Components cannot overlap.")
	var restored := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(restored.size() == 2 and MODULES.validate(restored, false, false) == "")
	await process_frame
	_mouse(builder, cell, MOUSE_BUTTON_RIGHT, true, false, open_half)
	_mouse(builder, cell, MOUSE_BUTTON_RIGHT, false, false, open_half)
	assert(builder.parts == [pane] and not pane.has("cutouts"))

func _exercise_circle(builder: Control) -> void:
	builder.parts = []
	builder.palette_buttons.retro_plain.pressed.emit()
	assert(not builder.circle_button.disabled)
	builder.circle_button.set_pressed_no_signal(true)
	builder.circle_button.pressed.emit()
	assert(builder.selected_type == MODULES.CIRCLE_HULL and builder.palette_buttons.retro_plain.button_pressed)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, false)
	assert(MODULES.footprint(builder.parts[0]).size == Vector2i.ONE)
	builder._undo_edit()
	assert(builder.parts.is_empty())
	_mouse(builder, Vector2i.ZERO, MOUSE_BUTTON_LEFT, true)
	_motion(builder, Vector2i(6, 2))
	var preview: Dictionary = builder._stretch_plan()
	assert(preview.error == "" and preview.size == Vector2i(7, 7))
	_mouse(builder, Vector2i(6, 2), MOUSE_BUTTON_LEFT, false)
	var circle: Dictionary = builder.parts[0]
	assert(circle.type == MODULES.CIRCLE_HULL and MODULES.footprint(circle) == Rect2i(0, 0, 7, 7))
	assert(not MODULES.occupies(circle, Vector2i.ZERO))
	assert(MODULES.has_interior_floor(circle, Vector2i(3, 3)))
	assert(MODULES.has_interior_floor(circle, Vector2i(6, 3)))
	var cells := MODULES.occupied_cells(circle)
	assert(cells.size() == 37)
	var hull := MODULES.structural_polygons(circle, Vector2.ZERO)
	for cell in MODULES.occupied_cells({"type":"retro_plain", "x":0, "y":0, "width":7, "height":7, "rotation":0}):
		var point := Vector2(cell) * MODULES.FINE_CELL
		assert(hull.any(func(shape: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(point, shape)) == cells.has(cell))
	for shape in hull:
		for i in range(shape.size()):
			var edge: Vector2 = shape[(i + 1) % shape.size()] - shape[i]
			assert(is_zero_approx(edge.x) or is_zero_approx(edge.y))
	var attached := {"type":"retro_plain", "fine_grid":true, "x":7, "y":3, "rotation":0}
	assert(MODULES.validate([circle, attached], false, false) == "")
	attached.y = 0
	assert(MODULES.validate([circle, attached], false, false) == "Every component must connect to the ship.")
	assert(is_equal_approx(MODULES.stats([circle]).mass, 8.0 * cells.size() / 16.0))
	var smooth := circle.duplicate()
	smooth.type = "hull_circle"
	assert(MODULES.structural_polygons(smooth, Vector2.ZERO)[0].size() == 48)
	assert(not MODULES.has_interior_floor(smooth, Vector2i(6, 3)))
	assert(LIBRARY.restore_design(JSON.parse_string(JSON.stringify([smooth]))).size() == 1)

	_mouse(builder, Vector2i(6, 3), MOUSE_BUTTON_LEFT, true, true)
	_mouse(builder, Vector2i(9, 3), MOUSE_BUTTON_LEFT, false, true)
	circle = builder.parts[0]
	assert(MODULES.footprint(circle).size == Vector2i(10, 10), builder.status)
	var mass: float = MODULES.stats([circle]).mass
	MODULES.remove_block(circle, Vector2i(4, 4))
	assert(not MODULES.occupies(circle, Vector2i(4, 4)) and MODULES.stats([circle]).mass < mass)
	var restored := LIBRARY.restore_design(JSON.parse_string(JSON.stringify(builder.parts)))
	assert(restored.size() == 1 and restored[0].type == MODULES.CIRCLE_HULL)
	assert(MODULES.footprint(restored[0]) == MODULES.footprint(circle) and restored[0].cutouts == circle.cutouts)
	assert(MODULES.validate(restored, false, false) == "")
	await process_frame
	builder._toggle_view()
	assert(builder.circle_button.disabled)
	await process_frame

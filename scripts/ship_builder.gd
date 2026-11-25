extends Control

signal closed
signal deploy(parts: Array)
signal library_requested
const MODULES := preload("res://scripts/ship_modules.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")
const STEP := MODULES.HULL_SUBDIVISIONS
const MIRROR_X := STEP - 1
const DEFAULT_ZOOM := 2.5
const HISTORY_LIMIT := 50
var initial_parts: Array = []
var performance_profile: Callable
var speed_unit := 1.0
var close_caption := "Return to flight"
var parts: Array = []
var saved_parts: Array = []
var exit_dialog: ConfirmationDialog
var saving_before_exit := false
var selected_type := "retro_plain"
var interior_view := false
var part_rotation := 0
var part_flipped := false
var grid_zoom := DEFAULT_ZOOM
var grid_pan := Vector2.ZERO
var panning := false
var pan_last_position := Vector2.ZERO
var cursor_cell := Vector2i.ZERO
var cursor_position := Vector2.ZERO
var show_cursor := false
var painting := false
var erasing := false
var navigation_redraw_time := 0.0
var erase_area_active := false
var erase_area_start := Vector2i.ZERO
var erase_area_end := Vector2i.ZERO
var last_paint_cell := Vector2i.ZERO
var last_erase_cell := Vector2i.ZERO
var stretching := false
var stretch_start := Vector2i.ZERO
var stretch_end := Vector2i.ZERO
var stretch_index := -1
var stretch_rotation := 0
var status := "Select a part, then click a connection point. Right-drag to erase; Shift-right-drag erases an area."
var palette_buttons: Dictionary = {}
var category_labels: Dictionary = {}
var select_mode := false
var paint_mode := false
var symmetry_enabled := false
var selected_parts: Array[Dictionary] = []
var marquee_active := false
var marquee_start := Vector2i.ZERO
var marquee_end := Vector2i.ZERO
var moving_selection := false
var move_anchor := Vector2i.ZERO
var move_delta := Vector2i.ZERO
var select_button: Button
var interior_button: Button
var paint_button: Button
var paint_picker: ColorPickerButton
var symmetry_button: Button
var undo_button: Button
var undo_history: Array[Array] = []
var gesture_before: Variant = null
var rng := RandomNumberGenerator.new()
var design_dialog: AcceptDialog
var design_name: LineEdit
var design_message: Label
var palette_scroll: ScrollContainer
var tools: HFlowContainer
var actions: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	parts = MODULES.to_fine_grid(initial_parts)
	saved_parts = parts.duplicate(true)
	rng.randomize()
	_create_toolbar()
	palette_scroll = ScrollContainer.new()
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(palette_scroll)
	resized.connect(_layout)
	tools.resized.connect(_layout)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(260, 0)
	column.add_theme_constant_override("separation", 4)
	palette_scroll.add_child(column)
	var delete_all := Button.new()
	delete_all.name = "DeleteAll"
	delete_all.text = "Delete All"
	delete_all.custom_minimum_size = Vector2(0, 36)
	delete_all.focus_mode = Control.FOCUS_NONE
	delete_all.pressed.connect(_delete_all_parts)
	column.add_child(delete_all)
	var category := ""
	for id in MODULES.ORDER:
		var item: Dictionary = MODULES.TYPES[id]
		if item.category != category:
			category = item.category
			var label := Label.new()
			label.text = category
			label.add_theme_font_size_override("font_size", 12)
			label.add_theme_color_override("font_color", Color("7dacc4"))
			column.add_child(label)
			category_labels[category] = label
		var button := Button.new()
		button.text = item.name
		button.custom_minimum_size = Vector2(0, 34)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_pressed = id == selected_type
		if id == "retro_wedge":
			button.icon = MODULES.RETRO_WEDGE_ICON
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 26)
		elif MODULES.HULL_TEXTURES.has(id) or MODULES.DECORATION_TEXTURES.has(id):
			button.icon = MODULES.HULL_TEXTURES.get(id, MODULES.DECORATION_TEXTURES.get(id))
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 26)
		button.pressed.connect(_select_part.bind(id))
		palette_buttons[id] = button
		column.add_child(button)
	_update_palette()
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	_action_button(close_caption, request_close)
	_action_button("Ship library", func(): library_requested.emit())
	_action_button("Save to library", _open_save_dialog)
	_action_button("Launch design", _deploy)
	actions.resized.connect(_layout)
	_layout()
	exit_dialog = ConfirmationDialog.new()
	exit_dialog.title = "Unsaved ship design"
	exit_dialog.dialog_text = "Save this design before leaving the builder?"
	exit_dialog.get_ok_button().text = "Save design"
	exit_dialog.get_cancel_button().text = "Keep editing"
	exit_dialog.add_button("Leave without saving", false, "discard")
	exit_dialog.confirmed.connect(_save_before_exit)
	exit_dialog.custom_action.connect(_exit_action)
	add_child(exit_dialog)

func _layout() -> void:
	tools.position = Vector2(310, 16)
	tools.size.x = maxf(1.0, size.x - 334.0)
	actions.position = Vector2(size.x - actions.size.x - 24.0, tools.position.y + tools.size.y + 8.0)
	palette_scroll.position = Vector2(24, _grid_top() + 12.0)
	palette_scroll.size = Vector2(282, maxf(1.0, size.y - palette_scroll.position.y - 24.0))
	queue_redraw()

func _grid_top() -> float:
	return maxf(105.0, actions.position.y + actions.size.y + 10.0)

func _action_button(caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	actions.add_child(button)

func request_close() -> void:
	if design_dialog.visible:
		design_dialog.hide()
	elif exit_dialog.visible:
		exit_dialog.hide()
	elif parts == saved_parts:
		closed.emit()
	else:
		painting = false
		erasing = false
		erase_area_active = false
		exit_dialog.popup_centered()

func _save_before_exit() -> void:
	exit_dialog.hide()
	saving_before_exit = true
	_open_save_dialog()
	design_message.text = "Name your design and select Save design to leave."
	design_name.grab_focus()

func _exit_action(action: StringName) -> void:
	if action == "discard":
		exit_dialog.hide()
		closed.emit()

func _toolbar_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 34
	button.focus_mode = Control.FOCUS_NONE
	tools.add_child(button)
	return button

func _create_toolbar() -> void:
	tools = HFlowContainer.new()
	tools.add_theme_constant_override("h_separation", 8)
	add_child(tools)
	select_button = _toolbar_button("Select")
	select_button.toggle_mode = true
	select_button.toggled.connect(func(enabled: bool):
		select_mode = enabled
		if enabled and paint_mode:
			paint_button.button_pressed = false
		painting = false
		erasing = false
		var target := "armour panels" if _armour_selected() else "parts"
		status = "Drag a box over %s, then drag the selection to move it." % target if enabled else "Choose a component to place."
		queue_redraw()
	)
	symmetry_button = _toolbar_button("Symmetry: Off")
	symmetry_button.toggle_mode = true
	symmetry_button.toggled.connect(func(enabled: bool):
		symmetry_enabled = enabled
		symmetry_button.text = "Symmetry: On" if enabled else "Symmetry: Off"
		status = "Symmetry mirrors placement and removal across the center grid." if enabled else "Symmetry off."
		queue_redraw()
	)
	var random_button := _toolbar_button("Randomize")
	random_button.pressed.connect(_randomize_ship)
	undo_button = _toolbar_button("Undo")
	undo_button.tooltip_text = "Undo last edit (Cmd+Z / Ctrl+Z)"
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_edit)
	var reset_view := _toolbar_button("Reset view")
	reset_view.pressed.connect(_reset_grid_view)
	interior_button = _toolbar_button("View: Exterior")
	interior_button.pressed.connect(_toggle_view)
	paint_button = _toolbar_button("Paint hull")
	paint_button.toggle_mode = true
	paint_button.toggled.connect(func(enabled: bool):
		paint_mode = enabled
		if enabled and select_mode:
			select_button.button_pressed = false
		painting = false
		erasing = false
		status = "Click or drag over hull blocks to paint. Right-drag removes parts; Shift-right-drag removes an area." if enabled else "Choose a component to place."
		queue_redraw()
	)
	paint_picker = ColorPickerButton.new()
	paint_picker.custom_minimum_size = Vector2(90, 34)
	paint_picker.text = "Colour"
	paint_picker.edit_alpha = false
	paint_picker.color = Color("a6a6a6")
	paint_picker.focus_mode = Control.FOCUS_NONE
	tools.add_child(paint_picker)
	_create_save_dialog()

func _update_palette() -> void:
	for kind in palette_buttons:
		palette_buttons[kind].visible = MODULES.can_place_on_layer(kind, interior_view)
		palette_buttons[kind].button_pressed = kind == selected_type
	for category in category_labels:
		var has_visible := false
		for kind in palette_buttons:
			if MODULES.TYPES[kind].category == category and palette_buttons[kind].visible:
				has_visible = true
				break
		category_labels[category].visible = has_visible

func _toggle_view() -> void:
	interior_view = not interior_view
	interior_button.text = "View: Interior" if interior_view else "View: Exterior"
	selected_type = "reactor" if interior_view else "retro_plain"
	select_mode = false
	select_button.button_pressed = false
	select_button.disabled = interior_view
	paint_mode = false
	paint_button.button_pressed = false
	paint_button.disabled = interior_view
	paint_picker.disabled = interior_view
	selected_parts.clear()
	painting = false
	erasing = false
	_update_palette()
	status = "Place equipment on the hull footprint." if interior_view else "Build the ship's outside shape."
	queue_redraw()

func _create_save_dialog() -> void:
	design_dialog = AcceptDialog.new()
	design_dialog.title = "Save ship design"
	design_dialog.get_ok_button().text = "Close"
	design_dialog.visibility_changed.connect(func():
		if not design_dialog.visible:
			saving_before_exit = false
	)
	add_child(design_dialog)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 420
	column.add_theme_constant_override("separation", 8)
	design_dialog.add_child(column)
	design_name = LineEdit.new()
	design_name.placeholder_text = "Design name"
	design_name.max_length = 60
	design_name.text_submitted.connect(func(_name: String): _save_named_design())
	column.add_child(design_name)
	var save_button := Button.new()
	save_button.text = "Save design"
	save_button.pressed.connect(_save_named_design)
	column.add_child(save_button)
	design_message = Label.new()
	design_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(design_message)

func _open_save_dialog() -> void:
	painting = false
	erasing = false
	erase_area_active = false
	design_message.text = "Save a named copy to the Hangar ship library."
	design_dialog.popup_centered()
	design_name.grab_focus()

func _save_named_design() -> void:
	var entries: Variant = LIBRARY.read()
	if entries == null:
		design_message.text = "Couldn't read the library, so it cannot be changed."
		return
	var design_title := design_name.text.strip_edges()
	if design_title.is_empty():
		design_message.text = "Enter a name for this design."
		return
	if entries.has(design_title):
		design_message.text = "That name is already in use. Choose another name."
		return
	var error := MODULES.validate(parts, false, false)
	if not LIBRARY.is_draft_result(error):
		design_message.text = error
		return
	entries[design_title] = parts.duplicate(true)
	if not LIBRARY.write(entries):
		design_message.text = "Couldn't save the design. Please try again."
		return
	saved_parts = parts.duplicate(true)
	status = "Saved design: %s." % design_title
	var leave := saving_before_exit
	design_dialog.hide()
	if leave:
		closed.emit()
	else:
		queue_redraw()

func _randomize_ship() -> void:
	var generated := _generate_random_design()
	if MODULES.validate(generated) != "":
		status = "Could not generate a valid ship. Please try again."
		queue_redraw()
		return
	_push_undo(parts.duplicate(true))
	parts = generated
	selected_parts.clear()
	status = "Random ship created. Undo random restores your previous design."
	queue_redraw()

func _delete_all_parts() -> void:
	if parts.is_empty():
		return
	_push_undo(parts.duplicate(true))
	parts.clear()
	selected_parts.clear()
	painting = false
	erasing = false
	erase_area_active = false
	stretching = false
	stretch_index = -1
	marquee_active = false
	moving_selection = false
	move_delta = Vector2i.ZERO
	status = "All parts removed. Undo restores your design."
	queue_redraw()

func _push_undo(before: Array) -> void:
	undo_history.append(before)
	if undo_history.size() > HISTORY_LIMIT:
		undo_history.pop_front()
	undo_button.disabled = false

func _finish_gesture() -> void:
	if gesture_before != null and gesture_before != parts:
		_push_undo(gesture_before)
	gesture_before = null

func _undo_edit() -> void:
	_finish_gesture()
	stretching = false
	stretch_index = -1
	painting = false
	erasing = false
	erase_area_active = false
	marquee_active = false
	moving_selection = false
	move_delta = Vector2i.ZERO
	if not undo_history.is_empty():
		parts = undo_history.pop_back()
		selected_parts.clear()
		undo_button.disabled = undo_history.is_empty()
		status = "Undid the last edit."
	queue_redraw()

func _generate_random_design() -> Array:
	return MODULES.to_fine_grid(MODULES.generate_random_design(rng))

func _process(delta: float) -> void:
	if interior_view:
		return
	navigation_redraw_time -= delta
	if navigation_redraw_time <= 0.0:
		navigation_redraw_time = 0.08
		if parts.any(func(part: Dictionary) -> bool: return part.get("type", "") == "navigation_lights"):
			queue_redraw()

func _select_part(id: String) -> void:
	if MODULES.is_armour(id) != _armour_selected():
		selected_parts.clear()
	selected_type = id
	if paint_mode:
		paint_button.button_pressed = false
	select_button.button_pressed = false
	select_mode = false
	for key in palette_buttons:
		palette_buttons[key].button_pressed = key == id
	if id == "retro_bridge":
		part_rotation -= part_rotation % 2
		status = "Place the bridge over an exterior block. Right-click to remove it."
	elif id == "command_deck":
		part_rotation -= part_rotation % 2
		status = "Click the left of three free equipment slots. R reverses the deck."
	elif id == "command_station":
		status = "Place the command station in one free equipment slot."
	elif MODULES.POWER_ADJACENCY_BONUS.has(id):
		status = "Place a %s on a free hull slot. Matching modules that share an edge improve spare power." % MODULES.TYPES[id].name.to_lower()
	elif id == "wedge_half":
		status = "Click to place a half-width angled hull in one slot. R rotates · F flips."
	elif MODULES.is_armour(id):
		status = "Drag %s over existing hull. Shift-drag resizes · R rotates · F flips." % MODULES.TYPES[id].name.to_lower()
	elif MODULES.DECORATION_TEXTURES.has(id):
		status = "Click anywhere to place the antenna. R rotates · F flips · right-click removes details." if id == "retro_antenna" else "Click a hull block. R rotates · F flips · right-click removes details."
	elif id in MODULES.MAIN_ENGINE_TYPES:
		status = "Aim at the hull edge to attach the engine. R rotates its mounting edge."
	elif MODULES.can_stretch(id):
		status = "Click or drag to place %s. Shift-drag an existing piece to resize it." % MODULES.TYPES[id].name
	elif id in MODULES.TURRETS:
		var degrees_per_second := int(round(rad_to_deg(MODULES.TYPES[id].turret_turn_speed)))
		status = "Mount %s on a turret base. Turn speed: %d°/s." % [MODULES.TYPES[id].name, degrees_per_second]
	else:
		status = "Selected %s. R rotates · F flips · right-click removes." % MODULES.TYPES[id].name
	queue_redraw()

func _deploy() -> void:
	var error: String = MODULES.validate(parts)
	if error != "":
		status = error
		queue_redraw()
		return
	deploy.emit(parts.duplicate(true))

func _grid_viewport() -> Rect2:
	var top := _grid_top()
	return Rect2(Vector2(310.0, top), Vector2(maxf(1.0, size.x - 620.0), maxf(1.0, size.y - top - 90.0)))

func _grid_center() -> Vector2:
	return _grid_viewport().get_center() + grid_pan - Vector2.ONE * MIRROR_X * 0.5 * _grid_spacing()

func _build_grid() -> Rect2i:
	return MODULES.grid_bounds(true)

func _engine_anchor_at(position: Vector2, rotation: int) -> Vector2i:
	# The pointer marks the middle of the engine's mounting edge, not a corner
	# of its footprint. This lets the nozzle line up with the fine hull edge.
	var local := (position - _grid_center()) / _grid_spacing()
	var cell := _cell_at(position)
	if rotation % 2 == 0:
		cell.x = floori(local.x - MIRROR_X * 0.5 + 0.5)
		if rotation == 2:
			cell.y -= MIRROR_X
	else:
		cell.y = floori(local.y - MIRROR_X * 0.5 + 0.5)
		if rotation == 1:
			cell.x -= MIRROR_X
	return cell

func _size_delta(delta: Vector2i, step: int) -> Vector2i:
	return Vector2i((Vector2(delta) / step).round()) * step

func _new_piece(kind: String, cell: Vector2i, layer := "exterior") -> Dictionary:
	return {"type":kind, "fine_grid":true, "layer":layer, "x":cell.x, "y":cell.y, "rotation":part_rotation, "flip_x":part_flipped}

func _reset_grid_view() -> void:
	grid_zoom = DEFAULT_ZOOM
	grid_pan = Vector2.ZERO
	status = "View reset. Scroll to zoom; middle-drag to pan."
	queue_redraw()

func _zoom_grid_at(position: Vector2, factor: float) -> void:
	var grid_position := (position - _grid_center()) / _grid_spacing()
	grid_zoom = clampf(grid_zoom * factor, 0.75, 12.0)
	grid_pan = position - _grid_viewport().get_center() - (grid_position - Vector2.ONE * MIRROR_X * 0.5) * _grid_spacing()
	cursor_position = position
	cursor_cell = _cell_at(position)
	queue_redraw()

func _grid_spacing() -> float:
	var workspace := _grid_viewport().size
	var available_width := maxf(29.0, workspace.x - 30.0)
	var available_height := maxf(21.0, workspace.y - 10.0)
	var grid_size := _build_grid().size
	return grid_zoom * minf(10.0, minf(available_width / grid_size.x, available_height / grid_size.y))

func _cell_at(position: Vector2) -> Vector2i:
	var local := (position - _grid_center()) / _grid_spacing()
	return Vector2i(roundi(local.x), roundi(local.y))

func _index_at(cell: Vector2i, layer: String = "") -> int:
	var wanted := ("interior" if interior_view else "exterior") if layer == "" else layer
	for i in range(parts.size()):
		var part: Dictionary = parts[i]
		if part.get("layer", "exterior") == wanted and MODULES.occupies(part, cell):
			return i
	return -1

func _armour_selected() -> bool:
	return not interior_view and MODULES.is_armour(selected_type)

func _paint_index_at(cell: Vector2i) -> int:
	var index := _index_at(cell, MODULES.ARMOUR_LAYER) if _armour_selected() else -1
	return index if index >= 0 else _index_at(cell, "exterior")

func _mirrored_part(part: Dictionary) -> Dictionary:
	var area := MODULES.footprint(part)
	var mirror := part.duplicate()
	mirror.x = STEP - area.end.x
	mirror.rotation = posmod(-int(part.rotation), 4)
	mirror.flip_x = not part.get("flip_x", false)
	MODULES.copy_cutouts(part, mirror, true)
	return mirror

func _mirror_index(part: Dictionary) -> int:
	var area := MODULES.footprint(_mirrored_part(part))
	if area == MODULES.footprint(part):
		return -1
	for i in range(parts.size()):
		var other: Dictionary = parts[i]
		if other.type == part.type and other.get("layer", "exterior") == part.get("layer", "exterior") and MODULES.footprint(other) == area:
			return i
	return -1

func _start_stretch(cell: Vector2i, resize: bool, position: Vector2) -> bool:
	stretch_index = -1
	stretch_rotation = part_rotation
	if resize:
		if _armour_selected():
			stretch_index = _index_at(cell, MODULES.ARMOUR_LAYER)
		else:
			stretch_index = _index_at(cell, "decoration") if not interior_view else -1
			if stretch_index < 0:
				stretch_index = _index_at(cell)
		if stretch_index < 0 or not MODULES.can_stretch(parts[stretch_index].type):
			return false
	elif not MODULES.can_stretch(selected_type) or (not _armour_selected() and selected_type not in MODULES.MAIN_ENGINE_TYPES and _index_at(cell, "decoration" if _decoration_tool() else "") >= 0):
		return false
	if not resize and _decoration_tool():
		var placement := _decoration_plan(cell)
		if placement.error != "":
			status = placement.error
			return true
		stretch_rotation = int(placement.details[0].rotation)
	stretching = true
	stretch_start = _engine_anchor_at(position, stretch_rotation) if not resize and selected_type in MODULES.MAIN_ENGINE_TYPES else cell
	stretch_end = stretch_start
	return true

func _resized_footprint(area: Rect2i) -> Rect2i:
	var low := area.position
	var high := area.end - Vector2i.ONE
	var kind: String = parts[stretch_index].type
	var step := MODULES.size_step(kind)
	var delta := _size_delta(stretch_end - stretch_start, step)
	for axis in range(2):
		var distance_to_low := stretch_start[axis] - low[axis]
		var distance_to_high := high[axis] - stretch_start[axis]
		var move_low := distance_to_low < distance_to_high or (distance_to_low == distance_to_high and delta[axis] < 0)
		if move_low:
			low[axis] = mini(low[axis] + delta[axis], high[axis] - step + 1)
		else:
			high[axis] = maxi(high[axis] + delta[axis], low[axis] + step - 1)
	return Rect2i(low, high - low + Vector2i.ONE)

func _touches_existing_hull(piece: Dictionary) -> bool:
	for cell in MODULES.occupied_cells(piece):
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor := cell + direction
			var index := _index_at(neighbor, "exterior")
			if index >= 0 and MODULES.shares_edge(piece, parts[index], cell, direction):
				return true
	return false

func _stretch_plan(hover: bool = false) -> Dictionary:
	var resizing := not hover and stretch_index >= 0
	var hover_cell := _engine_anchor_at(cursor_position, part_rotation) if selected_type in MODULES.MAIN_ENGINE_TYPES else cursor_cell
	var start_cell := hover_cell if hover else stretch_start
	var end_cell := hover_cell if hover else stretch_end
	var rotation := part_rotation if hover else stretch_rotation
	var layer := MODULES.ARMOUR_LAYER if _armour_selected() else ("interior" if interior_view else ("decoration" if _decoration_tool() else "exterior"))
	var piece: Dictionary = parts[stretch_index].duplicate() if resizing else _new_piece(selected_type, start_cell, layer)
	if not resizing:
		piece.rotation = rotation
	var old_area := MODULES.footprint(piece)
	var step := MODULES.size_step(piece.type)
	var a := start_cell
	var b := a + _size_delta(end_cell - start_cell, step)
	var low := a.min(b)
	var high := a.max(b) + Vector2i.ONE * (step - 1)
	if resizing:
		var area := _resized_footprint(old_area)
		low = area.position
		high = area.end - Vector2i.ONE
	if symmetry_enabled and step == 1 and low.x <= MIRROR_X - low.x and high.x >= MIRROR_X - high.x and not MODULES.is_full_wedge(piece.type):
		low.x = mini(low.x, MIRROR_X - high.x)
		high.x = MIRROR_X - low.x
	piece.merge({"x":low.x, "y":low.y, "width":high.x - low.x + 1, "height":high.y - low.y + 1}, true)
	if resizing:
		MODULES.copy_cutouts(parts[stretch_index], piece)
	var pieces: Array[Dictionary] = [piece]
	var replaced: Array[int] = []
	if resizing:
		replaced.append(stretch_index)
	var error := ""
	if symmetry_enabled:
		var mirror := _mirrored_part(piece)
		if resizing:
			var mirror_index := _mirror_index(parts[stretch_index])
			if mirror_index >= 0:
				replaced.append(mirror_index)
				MODULES.copy_cutouts(parts[mirror_index], mirror)
				if parts[mirror_index].has("paint"):
					mirror.paint = parts[mirror_index].paint
		if mirror.x != piece.x:
			pieces.append(mirror)
		elif MODULES.is_full_wedge(piece.type) or piece.type == "cargo_corner" or (piece.type == "cargo_edge" and int(piece.rotation) % 2 == 0):
			error = "This orientation cannot be mirrored on the center line."
	var layout: Array = []
	for i in range(parts.size()):
		if i not in replaced:
			layout.append(parts[i])
	layout.append_array(pieces)
	if error == "":
		if parts.is_empty() and (MODULES.is_armour_overlay(piece) or (not MODULES.supports_interior(piece.type) and piece.type != "retro_wedge")):
			error = "Place a hull block first."
		else:
			error = MODULES.validate(layout, false, false)
			if error == "Every component must connect to the ship.":
				# Keep partially connected drafts editable while they are being repaired.
				if interior_view or MODULES.is_armour_overlay(piece) or (resizing and MODULES.validate(parts, false, false) == error) or (not resizing and pieces.all(_touches_existing_hull)):
					error = ""
	return {"pieces":pieces, "layout":layout, "error":error, "size":MODULES.footprint(piece).size, "replaced":replaced}

func _stretch_cell_at(position: Vector2) -> Vector2i:
	var grid := _build_grid()
	return _cell_at(position).clamp(grid.position, grid.end - Vector2i.ONE)

func _stretch_end_at(position: Vector2) -> Vector2i:
	if stretch_index < 0 and selected_type in MODULES.MAIN_ENGINE_TYPES:
		return _engine_anchor_at(position, stretch_rotation)
	return _stretch_cell_at(position)

func _finish_stretch(position: Vector2) -> void:
	if _grid_viewport().has_point(position):
		var resizing := stretch_index >= 0
		stretch_end = _stretch_end_at(position)
		if not resizing or stretch_end != stretch_start:
			var plan := _stretch_plan()
			if plan.error == "":
				parts = plan.layout
				selected_parts.clear()
				status = "%s %s at %d × %d slots." % [MODULES.TYPES[plan.pieces[0].type].name, "resized" if resizing else "placed", plan.size.x, plan.size.y]
			else:
				status = plan.error
	stretching = false
	stretch_index = -1
	queue_redraw()

func _interior_placement_error(anchors: Array[Vector2i], kind: String) -> String:
	if kind in MODULES.COMMAND_TYPES and MODULES.has_command_deck(parts):
		return "A ship can have only one command deck."
	if parts.size() + anchors.size() > MODULES.MAX_COMPONENTS:
		return "A ship can have up to %d components." % MODULES.MAX_COMPONENTS
	for anchor in anchors:
		var piece := _new_piece(kind, anchor, "interior")
		if not _build_grid().encloses(MODULES.footprint(piece)):
			return "The module would extend outside the grid."
		for location in MODULES.occupied_cells(piece):
			var hull_index := _index_at(location, "exterior")
			if hull_index < 0 or not MODULES.supports_interior(parts[hull_index].type):
				return "The command deck needs three adjacent flat hull slots." if kind == "command_deck" else "Place this module on a fully covered hull slot."
			if _index_at(location, "interior") >= 0:
				return "That interior cell is occupied."
	return ""

func _paint_at(cell: Vector2i, restore: bool = false) -> void:
	if interior_view:
		return
	var locations: Array[Vector2i] = [cell]
	if symmetry_enabled:
		locations.append(Vector2i(MIRROR_X - cell.x, cell.y))
	var changed := 0
	for location in locations:
		var index := _paint_index_at(location)
		if index < 0 or not MODULES.can_paint(parts[index].type):
			continue
		var part: Dictionary = parts[index]
		if MODULES.footprint(part).get_area() == 1:
			if restore:
				part.erase("paint")
			else:
				part.paint = paint_picker.color.to_html(false)
		else:
			var offset := location - MODULES.footprint(part).position
			var key := "%d,%d" % [offset.x, offset.y]
			if restore:
				part.get("cell_paints", {}).erase(key)
			else:
				if not part.has("cell_paints"):
					part.cell_paints = {}
				part.cell_paints[key] = paint_picker.color.to_html(false)
		changed += 1
	if changed > 0:
		status = "Original hull colour restored." if restore else "Hull painted."
	else:
		status = "Paint works on square and right-angle hull blocks."

func _decoration_tool() -> bool:
	return not interior_view and not select_mode and not paint_mode and MODULES.DECORATION_TEXTURES.has(selected_type)

func _decoration_placement_error(detail: Dictionary) -> String:
	if not MODULES.on_grid(MODULES.footprint(detail), true):
		return "The decoration needs to fit inside the build area."
	var slot_detail := detail.duplicate()
	for cell in MODULES.occupied_cells(detail):
		if _index_at(cell, "decoration") >= 0:
			return "That slot already has a decoration."
		slot_detail.x = cell.x
		slot_detail.y = cell.y
		var mount_index := _index_at(MODULES.decoration_mount(slot_detail), "exterior")
		var support: Dictionary = parts[mount_index] if mount_index >= 0 else {}
		var error := MODULES.decoration_mount_error(slot_detail, support, _index_at(cell, "exterior") >= 0)
		if not error.is_empty():
			return error
	return ""

func _decoration_plan(cell: Vector2i) -> Dictionary:
	if selected_type == "retro_bridge" and MODULES.has_command_deck(parts):
		return {"error":"A ship can have only one command deck or bridge."}
	var detail := _new_piece(selected_type, cell, "decoration")
	var area := MODULES.footprint(detail)
	var mirror := _mirrored_part(detail)
	var mirror_area := MODULES.footprint(mirror)
	var mirrored := symmetry_enabled and area != mirror_area and selected_type != "retro_bridge"
	if mirrored and area.intersects(mirror_area):
		return {"error":"Centre the panel on the symmetry line or place it to one side."}
	if parts.size() + (2 if mirrored else 1) > MODULES.MAX_COMPONENTS:
		return {"error":"A ship can have up to %d components." % MODULES.MAX_COMPONENTS}
	var error := ""
	for offset in range(4 if selected_type in MODULES.EDGE_DECORATIONS else 1):
		detail.rotation = posmod(part_rotation + offset, 4)
		var primary_error := _decoration_placement_error(detail)
		if primary_error != "":
			if error.is_empty():
				error = primary_error
			continue
		if not mirrored:
			return {"details":[detail], "error":""}
		mirror = _mirrored_part(detail)
		if _decoration_placement_error(mirror) == "":
			return {"details":[detail, mirror], "error":""}
		error = "The mirrored detail needs a matching hull mount and a free slot."
	return {"error":error}

func _place_at(cell: Vector2i) -> void:
	if not _build_grid().has_point(cell):
		return
	if not MODULES.can_place_on_layer(selected_type, interior_view):
		return
	if _armour_selected():
		return
	if MODULES.DECORATION_TEXTURES.has(selected_type):
		var plan := _decoration_plan(cell)
		if plan.error == "":
			parts.append_array(plan.details)
			status = "%s placed." % MODULES.TYPES[selected_type].name
		else:
			status = plan.error
		return
	var piece := _new_piece(selected_type, cell, "interior" if interior_view else "exterior")
	var reflected := _mirrored_part(piece)
	var mirror_cell := MODULES.footprint(reflected).position
	var self_mirrored := cell == mirror_cell
	if symmetry_enabled and self_mirrored:
		var directional := selected_type == "triangle" or MODULES.ENGINE_NOZZLE_OFFSETS.has(selected_type)
		var asymmetric := selected_type in ["wedge", "retro_wedge", "wedge_half", "wing", "cargo_corner"] or (selected_type == "cargo_edge" and part_rotation % 2 == 0) or (directional and part_rotation % 2 != 0)
		if asymmetric:
			status = "This orientation cannot be mirrored on the center line."
			return
	if interior_view:
		var locations: Array[Vector2i] = [cell]
		if symmetry_enabled and not self_mirrored and selected_type not in MODULES.COMMAND_TYPES:
			locations.append(mirror_cell)
		var placement_error := _interior_placement_error(locations, selected_type)
		if placement_error != "":
			status = placement_error
			return
		if locations.size() == 2 and MODULES.footprint(piece).intersects(MODULES.footprint(reflected)):
			status = "Mirrored modules cannot overlap."
			return
		parts.append(piece)
		if locations.size() == 2:
			parts.append(reflected)
		status = "%s installed inside the hull." % MODULES.TYPES[selected_type].name
		return
	if selected_type in MODULES.TURRETS:
		var locations: Array[Vector2i] = [cell]
		if symmetry_enabled:
			var other_cell := Vector2i(MIRROR_X - cell.x, cell.y)
			if _index_at(other_cell) != _index_at(cell):
				locations.append(other_cell)
		for location in locations:
			var index := _index_at(location)
			if index < 0 or parts[index].type not in MODULES.TURRET_BASE_TYPES or parts[index].has("turret"):
				status = "Place turrets on empty turret bases."
				return
		for location in locations:
			parts[_index_at(location)].turret = selected_type
		status = "%s mounted." % MODULES.TYPES[selected_type].name
		return
	if _index_at(cell) >= 0:
		return
	if _index_at(cell, "decoration") >= 0 and parts[_index_at(cell, "decoration")].type != "retro_antenna":
		status = "Remove the decoration before building in this slot."
		return
	if selected_type == "cockpit" and (parts.any(func(part: Dictionary) -> bool: return part.type == "cockpit") or (symmetry_enabled and not self_mirrored)):
		status = "Only one exterior cockpit is allowed. In symmetry mode, place it on the center line."
		return
	var placements := {cell:piece}
	if symmetry_enabled and not self_mirrored:
		if _index_at(mirror_cell) >= 0:
			status = "The mirrored cell is occupied."
			return
		if _index_at(mirror_cell, "decoration") >= 0 and parts[_index_at(mirror_cell, "decoration")].type != "retro_antenna":
			status = "Remove the decoration from the mirrored slot first."
			return
		placements[mirror_cell] = reflected
	if parts.size() + placements.size() > MODULES.MAX_COMPONENTS:
		status = "A ship can have up to %d components." % MODULES.MAX_COMPONENTS
		return
	var starting_component := parts.is_empty() and placements.size() == 1 and (MODULES.supports_interior(selected_type) or selected_type == "cockpit")
	if parts.is_empty() and not starting_component:
		status = "Place a hull block first."
		return
	var layout := parts + placements.values()
	var error := MODULES.validate(layout, false, false)
	if error != "" and not (LIBRARY.is_draft_result(error) and placements.values().all(_touches_existing_hull)):
		status = error
		return
	parts = layout
	status = "%s attached." % MODULES.TYPES[selected_type].name

func _hull_removal_error(cell: Vector2i) -> String:
	if _index_at(cell, MODULES.ARMOUR_LAYER) >= 0:
		return "Remove the armour over this block first."
	if _index_at(cell, "interior") >= 0:
		return "Remove the interior equipment beneath this block first."
	for part in parts:
		if MODULES.is_decoration(part):
			for slot in MODULES.occupied_cells(part):
				var detail: Dictionary = part.duplicate()
				detail.x = slot.x
				detail.y = slot.y
				if detail.type != "retro_antenna" and MODULES.decoration_mount(detail) == cell:
					return "Remove the detail attached to this block first."
	return ""

func _remove_blocks(index: int, cell: Vector2i) -> void:
	var part: Dictionary = parts[index]
	var kind: String = part.type
	var targets := {cell:index}
	if symmetry_enabled:
		var reflected := Vector2i(MIRROR_X - cell.x, cell.y)
		var mirror := _index_at(reflected, part.get("layer", "exterior"))
		if mirror >= 0 and parts[mirror].type == kind:
			targets[reflected] = mirror
	if MODULES.is_exterior_structure(part):
		for slot in targets:
			var error := _hull_removal_error(slot)
			if error != "":
				status = error
				return
	var affected: Array[int] = []
	for slot in targets:
		var target: int = targets[slot]
		MODULES.remove_block(parts[target], slot)
		if target not in affected:
			affected.append(target)
	affected.sort()
	affected.reverse()
	for target in affected:
		if MODULES.occupied_cells(parts[target]).is_empty():
			selected_parts.erase(parts[target])
			parts.remove_at(target)
	status = "%s block removed." % MODULES.TYPES[kind].name if targets.size() == 1 else "Mirrored %s blocks removed." % MODULES.TYPES[kind].name.to_lower()
	if not interior_view and not parts.is_empty():
		var error := MODULES.validate(parts, false)
		if error != "":
			status += " " + error

func _remove_at(cell: Vector2i) -> void:
	var index := _index_at(cell)
	if not interior_view:
		var armour_index := _index_at(cell, MODULES.ARMOUR_LAYER)
		if _armour_selected():
			if armour_index >= 0:
				_remove_blocks(armour_index, cell)
			return
		var detail_index := _index_at(cell, "decoration")
		if detail_index >= 0:
			var detail: Dictionary = parts[detail_index]
			if detail.type in ["armour_panel", "retro_bridge"]:
				var mirror_index := _mirror_index(detail) if symmetry_enabled and detail.type != "retro_bridge" else -1
				if mirror_index >= 0:
					parts.remove_at(mirror_index)
				parts.erase(detail)
				status = "%s removed." % MODULES.TYPES[detail.type].name
				return
			if MODULES.footprint(detail).get_area() > 1:
				if symmetry_enabled and cell.x != 0:
					var reflected := Vector2i(-cell.x, cell.y)
					var mirror := _index_at(reflected, "decoration")
					if mirror >= 0 and parts[mirror].type == detail.type:
						var mirror_detail: Dictionary = parts[mirror]
						MODULES.remove_block(mirror_detail, reflected)
						if MODULES.occupied_cells(mirror_detail).is_empty():
							parts.erase(mirror_detail)
				MODULES.remove_block(detail, cell)
				if MODULES.occupied_cells(detail).is_empty():
					parts.erase(detail)
				status = "%s block removed." % MODULES.TYPES[detail.type].name
				return
			if symmetry_enabled and cell.x != 0:
				var mirror := _index_at(Vector2i(-cell.x, cell.y), "decoration")
				if mirror >= 0 and parts[mirror].type == detail.type:
					parts.remove_at(mirror)
			parts.erase(detail)
			status = "%s removed." % MODULES.TYPES[detail.type].name
			return
		if armour_index >= 0:
			_remove_blocks(armour_index, cell)
			return
	if index < 0:
		return
	var part: Dictionary = parts[index]
	var kind: String = part.type
	if MODULES.can_stretch(kind) and kind not in MODULES.MAIN_ENGINE_TYPES:
		_remove_blocks(index, cell)
		return
	var indices: Array[int] = [index]
	if symmetry_enabled and kind not in MODULES.COMMAND_TYPES:
		var mirror := _mirror_index(part)
		if mirror >= 0:
			indices.append(mirror)
	if not interior_view:
		for remove_index in indices:
			for slot in MODULES.occupied_cells(parts[remove_index]):
				var error := _hull_removal_error(slot)
				if error != "":
					status = error
					return
	var removing_turret: bool = part.has("turret")
	var removed_name: String = MODULES.TYPES[part.get("turret", kind)].name
	indices.sort()
	indices.reverse()
	for remove_index in indices:
		selected_parts.erase(parts[remove_index])
		if removing_turret:
			parts[remove_index].erase("turret")
		else:
			parts.remove_at(remove_index)
	var error := "" if interior_view else MODULES.validate(parts, false)
	status = "%s removed." % removed_name if error == "" else "%s removed. %s" % [removed_name, error]

func _surface_moves_with_selection(detail: Dictionary) -> bool:
	for cell in MODULES.occupied_cells(detail):
		var support_index := _index_at(cell, "exterior")
		if support_index < 0 or not selected_parts.has(parts[support_index]):
			return false
	return true

func _decoration_moves_with_selection(detail: Dictionary) -> bool:
	if detail.type in ["armour_panel", "retro_bridge"]:
		return _surface_moves_with_selection(detail)
	var mount_index := _index_at(MODULES.decoration_mount(detail), "exterior")
	return mount_index >= 0 and selected_parts.has(parts[mount_index])

func _finish_selection(release_position: Vector2) -> void:
	var cell := _cell_at(release_position)
	if marquee_active:
		marquee_end = cell
		var low := marquee_start.min(cell)
		var selection := Rect2i(low, marquee_start.max(cell) - low + Vector2i.ONE)
		selected_parts.clear()
		for part in parts:
			var selectable := MODULES.is_armour_overlay(part) if _armour_selected() else MODULES.is_exterior_structure(part)
			if not selectable or not selection.intersects(MODULES.footprint(part)):
				continue
			for slot in MODULES.occupied_cells(part):
				if selection.has_point(slot):
					selected_parts.append(part)
					break
		marquee_active = false
		status = "%d parts selected. Drag the selection to move it." % selected_parts.size() if not selected_parts.is_empty() else "No parts selected."
	elif moving_selection:
		move_delta = cell - move_anchor
		var layout: Array = []
		var moving: Array[Dictionary] = []
		for part in parts:
			var moves := selected_parts.has(part)
			if moves and MODULES.is_exterior_structure(part):
				for slot in MODULES.occupied_cells(part):
					if _index_at(slot, "interior") >= 0:
						status = "Remove interior equipment before moving its hull piece."
						moving_selection = false
						move_delta = Vector2i.ZERO
						queue_redraw()
						return
			elif MODULES.is_armour_overlay(part):
				moves = moves or _surface_moves_with_selection(part)
			elif MODULES.is_decoration(part):
				moves = _decoration_moves_with_selection(part)
			if moves:
				moving.append(part)
				var moved: Dictionary = part.duplicate()
				moved.x += move_delta.x
				moved.y += move_delta.y
				layout.append(moved)
			else:
				layout.append(part)
		var error := MODULES.validate(layout, false, false)
		if error in ["", "Every component must connect to the ship."]:
			for part in moving:
				part.x += move_delta.x
				part.y += move_delta.y
			status = "Selection moved." if error == "" else "Selection moved. " + error
		else:
			status = error
		moving_selection = false
		move_delta = Vector2i.ZERO
	queue_redraw()

func _drag_line(start: Vector2i, target: Vector2i, erase: bool) -> void:
	# Include skipped cells and take orthogonal steps so diagonal drags stay connected.
	var grid := _build_grid()
	var end := target.clamp(grid.position, grid.end - Vector2i.ONE)
	var current := start
	var dx := absi(end.x - current.x)
	var dy := absi(end.y - current.y)
	var step_x := signi(end.x - current.x)
	var step_y := signi(end.y - current.y)
	var x_steps := 0
	var y_steps := 0
	while x_steps < dx or y_steps < dy:
		if x_steps < dx and (y_steps >= dy or (1 + 2 * x_steps) * dy <= (1 + 2 * y_steps) * dx):
			current.x += step_x
			x_steps += 1
		else:
			current.y += step_y
			y_steps += 1
		if erase:
			_remove_at(current)
			if not erasing:
				break
		elif paint_mode:
			_paint_at(current)
		else:
			_place_at(current)
	if erase:
		last_erase_cell = end
	else:
		last_paint_cell = end

func _finish_erase_area(release_position: Vector2) -> void:
	erase_area_end = _stretch_cell_at(release_position)
	var low := erase_area_start.min(erase_area_end)
	var high := erase_area_start.max(erase_area_end)
	var visited := {}
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if visited.has(cell):
				continue
			var reflected := Vector2i(MIRROR_X - x, y)
			var before: Array = []
			if symmetry_enabled:
				for layer in (["interior"] if interior_view else ["exterior", MODULES.ARMOUR_LAYER, "decoration"]):
					var index := _index_at(reflected, layer)
					if index >= 0:
						var part: Dictionary = parts[index]
						before.append({"part": part, "layer": layer, "turret": part.get("turret", "")})
			_remove_at(cell)
			for snapshot in before:
				var index := _index_at(reflected, snapshot.layer)
				if index < 0 or not is_same(parts[index], snapshot.part) or parts[index].get("turret", "") != snapshot.turret:
					visited[reflected] = true
					break
	erase_area_active = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if panning and event is InputEventMouseMotion:
		grid_pan += event.position - pan_last_position
		pan_last_position = event.position
		show_cursor = false
		queue_redraw()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = false
		if event.button_index == MOUSE_BUTTON_LEFT:
			painting = false
			if stretching:
				_finish_stretch(event.position)
				_finish_gesture()
				get_viewport().set_input_as_handled()
				return
			if marquee_active or moving_selection:
				_finish_selection(event.position)
			_finish_gesture()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if erase_area_active:
				_finish_erase_area(event.position)
			erasing = false
			_finish_gesture()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and (event.meta_pressed or event.ctrl_pressed) and not event.shift_pressed and not event.alt_pressed:
			if design_dialog.visible or exit_dialog.visible:
				return
			_undo_edit()
		elif event.keycode == KEY_R:
			part_rotation = (part_rotation + (2 if selected_type in ["command_deck", "retro_bridge"] else 1)) % 4
		elif event.keycode == KEY_F:
			part_flipped = not part_flipped
		else:
			return
		get_viewport().set_input_as_handled()
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_finish_gesture()
		painting = false
		erasing = false
		erase_area_active = false
		panning = false
		stretching = false
		stretch_index = -1
		marquee_active = false
		moving_selection = false
		move_delta = Vector2i.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_position = event.position
		cursor_cell = _cell_at(event.position)
		show_cursor = _grid_viewport().has_point(event.position) and _build_grid().has_point(cursor_cell)
		if erase_area_active:
			erase_area_end = _stretch_cell_at(event.position)
		elif marquee_active:
			marquee_end = cursor_cell
		elif moving_selection:
			move_delta = cursor_cell - move_anchor
		elif stretching:
			stretch_end = _stretch_end_at(event.position)
		elif painting:
			if paint_mode or event.shift_pressed:
				_drag_line(last_paint_cell, cursor_cell, false)
			else:
				painting = false
		elif erasing:
			_drag_line(last_erase_cell, cursor_cell, true)
		queue_redraw()
	elif event is InputEventMouseButton:
		if not event.pressed:
			return
		if not _grid_viewport().has_point(event.position):
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_grid_at(event.position, 1.2)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_grid_at(event.position, 1.0 / 1.2)
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			painting = false
			erasing = false
			erase_area_active = false
			panning = true
			pan_last_position = event.position
			return
		var cell := _cell_at(event.position)
		if not _build_grid().has_point(cell):
			return
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_finish_gesture()
			gesture_before = parts.duplicate(true)
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if stretching:
				stretching = false
				stretch_index = -1
				queue_redraw()
				return
			painting = false
			erase_area_active = event.shift_pressed
			erasing = not erase_area_active
			last_erase_cell = cell
			if erase_area_active:
				erase_area_start = cell
				erase_area_end = cell
			else:
				_remove_at(cell)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			erasing = false
			if paint_mode:
				painting = true
				last_paint_cell = cell
				_paint_at(cell)
			elif event.shift_pressed and _start_stretch(cell, true, event.position):
				pass
			elif select_mode:
				var index := _index_at(cell, MODULES.ARMOUR_LAYER if _armour_selected() else "")
				if index >= 0 and selected_parts.has(parts[index]):
					moving_selection = true
					move_anchor = cell
					move_delta = Vector2i.ZERO
				else:
					marquee_active = true
					marquee_start = cell
					marquee_end = cell
			elif not _start_stretch(cell, false, event.position):
				painting = event.shift_pressed and selected_type != "armour_panel"
				last_paint_cell = cell
				_place_at(cell)
		queue_redraw()

func _flight_performance() -> Dictionary:
	if not performance_profile.is_valid():
		return {"acceleration": 0.0, "speed": 0.0, "boost": 0.0, "hyperdrive": 0.0}
	var profile: Dictionary = performance_profile.call(parts)
	return {"acceleration": float(profile.travel_acceleration) / speed_unit,
		"speed": float(profile.normal_speed) / speed_unit, "boost": float(profile.boost) / speed_unit,
		"hyperdrive": float(profile.hyperdrive) / speed_unit}

func _draw() -> void:
	var area := size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, area), Color("08111e"))
	var center := _grid_center()
	var spacing := _grid_spacing()
	var part_scale := spacing / MODULES.FINE_CELL
	var grid := _build_grid()
	var origin := center + Vector2.ONE * MIRROR_X * 0.5 * spacing
	var placement_hover := show_cursor and not select_mode and not paint_mode and not panning and not erasing
	var armour_hover := placement_hover and _armour_selected()
	var engine_hover := placement_hover and selected_type in MODULES.MAIN_ENGINE_TYPES
	var preview_plan := _stretch_plan() if stretching else (_stretch_plan(true) if (armour_hover or engine_hover) else {})
	var valid_preview: bool = not preview_plan.is_empty() and preview_plan.error == ""
	var armour_layout: Array = preview_plan.layout if valid_preview else parts
	if not interior_view and moving_selection and not valid_preview:
		armour_layout = parts.duplicate()
		for index in range(parts.size()):
			var part: Dictionary = parts[index]
			if selected_parts.has(part) or (MODULES.is_armour_overlay(part) and _surface_moves_with_selection(part)):
				var moved := part.duplicate()
				moved.x += move_delta.x
				moved.y += move_delta.y
				armour_layout[index] = moved
	var placed_count: int = armour_layout.size() - (preview_plan.pieces.size() if valid_preview else 0)
	var armour_borders := {} if interior_view else MODULES.armour_borders(armour_layout)
	var totals := MODULES.stats(parts)
	var power_bonus_by_cell: Dictionary = totals.power_bonus_by_cell
	var grid_rect := Rect2(center + (Vector2(grid.position) - Vector2.ONE * 0.5) * spacing, Vector2(grid.size) * spacing)
	var fine_line := Color(0.23, 0.4, 0.5, 0.18)
	var coarse_line := Color(0.32, 0.53, 0.66, 0.35)
	for x in range(grid.size.x + 1):
		var grid_x := grid_rect.position.x + x * spacing
		draw_line(Vector2(grid_x, grid_rect.position.y), Vector2(grid_x, grid_rect.end.y), coarse_line if x % STEP == 0 else fine_line)
	for y in range(grid.size.y + 1):
		var grid_y := grid_rect.position.y + y * spacing
		draw_line(Vector2(grid_rect.position.x, grid_y), Vector2(grid_rect.end.x, grid_y), coarse_line if y % STEP == 0 else fine_line)
	if symmetry_enabled:
		draw_line(Vector2(origin.x, grid_rect.position.y), Vector2(origin.x, grid_rect.end.y), Color(0.42, 0.75, 1.0, 0.3), 2.0)
	var origin_rect := Rect2(origin - Vector2.ONE * spacing * STEP * 0.5, Vector2.ONE * spacing * STEP)
	draw_rect(origin_rect, Color(0.18, 0.70, 0.92, 0.12))
	draw_rect(origin_rect, Color(0.35, 0.85, 1.0, 0.6), false, 2.0)
	var occupied := {}
	var connection_points := {}
	if not interior_view and not stretching:
		for part in parts:
			if not MODULES.is_exterior_structure(part):
				continue
			for cell in MODULES.occupied_cells(part):
				occupied[cell] = part
		for cell: Vector2i in occupied:
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = cell + direction
				if grid.has_point(neighbor) and not occupied.has(neighbor) and MODULES.touches_edge(occupied[cell], cell, direction):
					connection_points[neighbor] = true
	for cell in connection_points:
		draw_circle(center + Vector2(cell) * spacing, minf(3.0, spacing * 0.14), Color(0.3, 0.8, 1.0, 0.55))
	var mounted_turrets: Array[Dictionary] = []
	var layout_index := -1
	for i in range(parts.size()):
		if valid_preview and i in preview_plan.replaced:
			continue
		layout_index += 1
		var part: Dictionary = parts[i]
		if not MODULES.is_exterior_structure(part):
			continue
		var area_in_cells := MODULES.footprint(part)
		var chosen := selected_parts.has(part)
		var draw_cell := area_in_cells.position + move_delta if chosen and moving_selection else area_in_cells.position
		var part_position := center + Vector2(draw_cell) * spacing
		if part.has("turret"):
			mounted_turrets.append({"type": part.turret, "position": part_position + Vector2.ONE * MIRROR_X * 0.5 * spacing})
		var piece_rect := Rect2(part_position - Vector2.ONE * spacing * 0.5, Vector2(area_in_cells.size) * spacing)
		if chosen:
			draw_rect(piece_rect, Color(0.25, 0.68, 1.0, 0.28))
		if interior_view:
			if MODULES.supports_interior(part.type):
				if part.has("cutouts"):
					for slot in MODULES.occupied_cells(part):
						var floor_position := piece_rect.position + Vector2(slot - area_in_cells.position) * spacing
						var floor_tile := Rect2(floor_position, Vector2.ONE * spacing)
						draw_rect(floor_tile, Color("4a5860"))
						draw_rect(floor_tile, Color("61737d"), false, 1.0)
				else:
					draw_rect(piece_rect, Color("4a5860"))
					draw_rect(piece_rect, Color("82949a"), false, 1.0)
					for x in range(1, area_in_cells.size.x):
						var top := piece_rect.position + Vector2(x * spacing, 0)
						draw_line(top, top + Vector2(0, piece_rect.size.y), Color("61737d"))
					for y in range(1, area_in_cells.size.y):
						var left := piece_rect.position + Vector2(0, y * spacing)
						draw_line(left, left + Vector2(piece_rect.size.x, 0), Color("61737d"))
			else:
				MODULES.draw_part(self, part, part_position, part_scale, 0.28)
		else:
			MODULES.draw_part(self, part, part_position, part_scale)
			if armour_borders.has(layout_index):
				MODULES.draw_armour_border(self, armour_borders[layout_index], center, spacing)
		if chosen:
			draw_rect(piece_rect, Color(0.47, 0.84, 1.0, 0.95), false, 2.0)
	if interior_view:
		for i in range(parts.size()):
			var part: Dictionary = parts[i]
			if MODULES.is_interior(part):
				if valid_preview and i in preview_plan.replaced:
					continue
				var fills_cell: bool = part.type in MODULES.COMMAND_TYPES or part.type in MODULES.CARGO_HOLD_TYPES
				var interior_scale := part_scale if fills_cell else part_scale * 0.83
				var cell := Vector2i(int(part.x), int(part.y))
				var part_position := center + Vector2(cell) * spacing
				var mount_offset := Vector2.ONE * MIRROR_X * 0.5 * spacing
				MODULES.draw_part(self, part, part_position + mount_offset * (0.0 if fills_cell else 0.17), interior_scale)
				if MODULES.POWER_ADJACENCY_BONUS.has(part.type) and power_bonus_by_cell.has(cell):
					var half_size := Vector2.ONE * spacing * STEP * 0.44
					draw_rect(Rect2(part_position + mount_offset - half_size, half_size * 2.0), Color("8ce1c4"), false, 1.5)
	else:
		for index in range(armour_layout.size()):
			var panel: Dictionary = armour_layout[index]
			if not MODULES.is_armour_overlay(panel):
				continue
			var footprint := MODULES.footprint(panel)
			var position_on_grid := center + Vector2(footprint.position) * spacing
			var alpha := 0.62 if index >= placed_count else 1.0
			MODULES.draw_part(self, panel, position_on_grid, part_scale, alpha)
			MODULES.draw_armour_border(self, armour_borders.get(index, []), center, spacing, alpha)
			if not valid_preview and selected_parts.has(parts[index]):
				draw_rect(Rect2(position_on_grid - Vector2.ONE * spacing * 0.5, Vector2(footprint.size) * spacing), Color(0.47, 0.84, 1.0, 0.95), false, 2.0)
		for detail in parts:
			if not MODULES.is_decoration(detail):
				continue
			if valid_preview and parts.find(detail) in preview_plan.replaced:
				continue
			var cell := Vector2(detail.x, detail.y)
			if moving_selection and _decoration_moves_with_selection(detail):
				cell += Vector2(move_delta)
			var brightness := MODULES.navigation_light_brightness(Time.get_ticks_msec() / 1000.0) if detail.type == "navigation_lights" else 1.0
			MODULES.draw_part(self, detail, center + cell * spacing, part_scale, 1.0, Color.WHITE, brightness)
	if marquee_active or erase_area_active:
		var start := erase_area_start if erase_area_active else marquee_start
		var end := erase_area_end if erase_area_active else marquee_end
		var low := Vector2(mini(start.x, end.x), mini(start.y, end.y))
		var high := Vector2(maxi(start.x, end.x), maxi(start.y, end.y))
		var rect := Rect2(center + (low - Vector2.ONE * 0.5) * spacing, (high - low + Vector2.ONE) * spacing)
		draw_rect(rect, Color(1.0, 0.35, 0.29, 0.16) if erase_area_active else Color(0.25, 0.7, 1.0, 0.16))
		draw_rect(rect, Color(1.0, 0.45, 0.38, 0.95) if erase_area_active else Color(0.45, 0.85, 1.0, 0.95), false, 2.0)
	# Corner brackets remain visible around components placed on the center cell.
	var corner := spacing * STEP * 0.5
	var arm := maxf(5.0, spacing * STEP * 0.20)
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			var p := origin + Vector2(x_sign * corner, y_sign * corner)
			draw_line(p, p + Vector2(-x_sign * arm, 0), Color("76ecff"), 2.5, true)
			draw_line(p, p + Vector2(0, -y_sign * arm), Color("76ecff"), 2.5, true)
	var clearance: Array = [] if interior_view else MODULES.clearance_issues(parts)
	for issue in clearance:
		var part: Dictionary = issue.part
		var part_center := center + Vector2(part.x, part.y) * spacing
		draw_rect(Rect2(part_center - Vector2.ONE * spacing * 0.48, Vector2.ONE * spacing * 0.96), Color(1.0, 0.35, 0.29, 0.95), false, 2.0)
		var blocked_center := center + Vector2(issue.blocked_at) * spacing
		draw_line(part_center, blocked_center, Color(1.0, 0.35, 0.29, 0.7), 2.0, true)
	if paint_mode and show_cursor:
		var paint_index := _paint_index_at(cursor_cell)
		if paint_index >= 0 and MODULES.can_paint(parts[paint_index].type):
			var paint_position := center + (Vector2(cursor_cell) - Vector2.ONE * 0.5) * spacing
			draw_rect(Rect2(paint_position, Vector2.ONE * spacing), paint_picker.color, false, 3.0)
	if not preview_plan.is_empty():
		var color := Color("76ecff") if valid_preview else Color("ff8d83")
		var preview_index := placed_count
		for piece: Dictionary in preview_plan.pieces:
			var position_on_grid := center + Vector2(piece.x, piece.y) * spacing
			if (stretching or engine_hover) and (not valid_preview or not MODULES.is_armour_overlay(piece)):
				MODULES.draw_part(self, piece, position_on_grid, part_scale, 0.62)
				if valid_preview and armour_borders.has(preview_index):
					MODULES.draw_armour_border(self, armour_borders[preview_index], center, spacing, 0.62)
			for shape in MODULES.material_polygons(piece, position_on_grid, spacing):
				shape.append(shape[0])
				draw_polyline(shape, color, 1.5, true)
			preview_index += 1
	elif show_cursor and _decoration_tool():
		var plan := _decoration_plan(cursor_cell)
		if plan.error == "":
			for detail in plan.details:
				MODULES.draw_part(self, detail, center + Vector2(detail.x, detail.y) * spacing, part_scale, 0.7)
		else:
			var size := MODULES.footprint({"type":selected_type, "rotation":part_rotation}).size
			var top_left := center + (Vector2(cursor_cell) - Vector2.ONE * 0.5) * spacing
			draw_rect(Rect2(top_left, Vector2(size) * spacing), Color("ff8d83"), false, 1.5)
	elif show_cursor and not paint_mode and not select_mode:
		var anchor := cursor_cell
		var anchor_position := center + Vector2(anchor) * spacing
		var piece := _new_piece(selected_type, anchor, "interior" if interior_view else "exterior")
		if interior_view:
			var anchors: Array[Vector2i] = [anchor]
			var available := _interior_placement_error(anchors, selected_type) == ""
			var footprint := Rect2(anchor_position - Vector2.ONE * spacing * 0.5, Vector2(MODULES.footprint(piece).size) * spacing)
			if available:
				MODULES.draw_part(self, piece, anchor_position, part_scale, 0.55)
			draw_rect(footprint, Color("76ecff") if available else Color("ff8d83"), false, 1.5)
		elif selected_type in MODULES.TURRETS:
			var index := _index_at(anchor)
			if index >= 0 and parts[index].type in MODULES.TURRET_BASE_TYPES and not parts[index].has("turret"):
				var mount := Vector2(MODULES.footprint(parts[index]).position) + Vector2.ONE * MIRROR_X * 0.5
				MODULES.draw_mounted_turret(self, selected_type, center + mount * spacing, part_scale, 0.55)
		elif _index_at(anchor) < 0:
			MODULES.draw_part(self, piece, anchor_position, part_scale, 0.4)
			if symmetry_enabled:
				var reflected := _mirrored_part(piece)
				var mirror := MODULES.footprint(reflected).position
				if mirror != anchor and _index_at(mirror) < 0:
					MODULES.draw_part(self, reflected, center + Vector2(mirror) * spacing, part_scale, 0.4)
	for turret in mounted_turrets:
		MODULES.draw_mounted_turret(self, turret.type, turret.position, part_scale, 0.28 if interior_view else 1.0)
	var hovered_part := -1
	if show_cursor and not stretching and not paint_mode:
		hovered_part = _index_at(cursor_cell, MODULES.ARMOUR_LAYER if _armour_selected() else "")
		if hovered_part >= 0 and MODULES.can_stretch(parts[hovered_part].type) and MODULES.footprint(parts[hovered_part]).get_area() > 1:
			var hovered_center := center + Vector2(cursor_cell) * spacing
			draw_rect(Rect2(hovered_center - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing), Color(0.46, 0.85, 1.0, 0.85), false, 1.5)
	# Cover anything outside the workspace so zoomed parts cannot obscure controls.
	var background := Color("08111e")
	draw_rect(Rect2(0, 0, 310, area.y), background)
	draw_rect(Rect2(area.x - 310, 0, 310, area.y), background)
	draw_rect(Rect2(0, 0, area.x, _grid_top()), background)
	draw_rect(Rect2(310, area.y - 90, maxf(0.0, area.x - 620), 90), background)
	draw_string(font, Vector2(24, 44), "SHIP BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("e5f6ff"))
	draw_string(font, Vector2(24, 74), "INTERIOR  /  INSTALL SYSTEMS" if interior_view else "EXTERIOR  /  BUILD SHAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78a3ba"))
	var divider := _grid_top() - 1.0
	draw_line(Vector2(24, divider), Vector2(area.x - 24, divider), Color("345166"), 1.0)
	var right := area.x - 300.0
	draw_string(font, Vector2(right, 155), "SHIP PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9f0fb"))
	var flight := _flight_performance()
	var labels := ["Acceleration", "Top speed", "Boost speed", "Hyperdrive speed", "Components", "Mass", "Hull", "Spare power", "Shield capacity", "Shield recharge", "Weapon power", "Cargo capacity", "Mining rate"]
	var values := [
		"%.2f km/s²" % flight.acceleration, "%.2f km/s" % flight.speed, "%.2f km/s" % flight.boost, "%.2f km/s" % flight.hyperdrive,
		str(parts.size()), str(int(totals.mass)), str(int(totals.health)), "%+d" % int(totals.power),
		str(int(totals.shield)), "%.1f HP/s" % totals.shield_recharge,
		str(int(totals.weapon)), str(int(totals.cargo)), "%s / sec" % str(totals.mining),
	]
	var row_height := 26.0
	for i in range(labels.size()):
		var y := 192.0 + float(i) * row_height
		draw_string(font, Vector2(right, y), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ab4c1"))
		var value_color := Color("ff8d83") if labels[i] == "Spare power" and totals.power < 0.0 else (Color("8ce1c4") if i < 4 else Color("e5f3f9"))
		draw_string(font, Vector2(right + 140, y), values[i], HORIZONTAL_ALIGNMENT_RIGHT, 135, 15, value_color)
	var readiness_y := 235.0 + float(labels.size()) * row_height
	var detail := "CYAN BRACKETS = CENTER"
	if interior_view and hovered_part >= 0:
		var kind: String = parts[hovered_part].type
		if MODULES.POWER_ADJACENCY_BONUS.has(kind):
			var bonus: float = power_bonus_by_cell.get(cursor_cell, 0.0)
			detail = "%+d POWER" % int(float(MODULES.TYPES[kind].power) + bonus)
			detail += "  ·  +%d FROM ADJACENCY" % int(bonus) if bonus > 0.0 else "  ·  MATCH AN EDGE FOR A BONUS"
	draw_string(font, Vector2(right, readiness_y - 30.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("76d8ef"))
	draw_string(font, Vector2(right, readiness_y), "FLIGHT READINESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("81acc2"))
	var error: String = MODULES.validate(parts)
	draw_string(font, Vector2(right, readiness_y + 26.0), "READY TO LAUNCH" if error == "" else "NEEDS ATTENTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ce1c4") if error == "" else Color("ffb58c"))
	if error != "":
		draw_multiline_string(font, Vector2(right, readiness_y + 55.0), error, HORIZONTAL_ALIGNMENT_LEFT, 275, 13, -1, Color("ffc2a0"))
	draw_string(font, Vector2(320, area.y - 58), "CLICK/DRAG place   ·   SHIFT-DRAG resize   ·   RIGHT-DRAG erase   ·   R rotate   ·   F flip   ·   CMD+Z undo", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cbac9"))
	var current_status := status
	if stretching:
		current_status = "%d × %d slots" % [preview_plan.size.x, preview_plan.size.y]
		if not valid_preview:
			current_status += "  ·  " + str(preview_plan.error)
	elif (armour_hover or engine_hover) and not valid_preview:
		current_status = str(preview_plan.error)
	draw_string(font, Vector2(320, area.y - 31), current_status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8bd5ee"))

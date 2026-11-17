extends Control

signal closed
signal deploy(parts: Array)
const MODULES := preload("res://scripts/ship_modules.gd")
var initial_parts: Array = []
var base_turn_speed := MODULES.BASE_TURN_SPEED
var parts: Array = []
var selected_type := "hull"
var interior_view := false
var part_rotation := 0
var part_flipped := false
var grid_zoom := 1.0
var grid_pan := Vector2.ZERO
var panning := false
var pan_last_position := Vector2.ZERO
var cursor_cell := Vector2i.ZERO
var show_cursor := false
var painting := false
var erasing := false
var last_paint_cell := Vector2i.ZERO
var last_erase_cell := Vector2i.ZERO
var status := "Select a part, then click a highlighted connection point."
var palette_buttons: Dictionary = {}
var category_labels: Dictionary = {}
var select_mode := false
var paint_mode := false
var symmetry_enabled := false
var selected_cells: Array[Vector2i] = []
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
var random_backup: Array = []
var has_random_backup := false
var rng := RandomNumberGenerator.new()
var library_path := "user://ship_designs.json"
var design_dialog: AcceptDialog
var design_name: LineEdit
var design_list: ItemList
var design_message: Label
var library_entries: Dictionary = {}
var library_available := true
var library_confirmation: ConfirmationDialog
var library_action := ""
var library_selected_name := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	parts = MODULES.migrate_legacy(initial_parts)
	rng.randomize()
	_create_toolbar()
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 122)
	scroll.size = Vector2(282, maxf(200.0, get_viewport_rect().size.y - 152))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(260, 0)
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)
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
		button.pressed.connect(_select_part.bind(id))
		palette_buttons[id] = button
		column.add_child(button)
	_update_palette()
	var launch := Button.new()
	launch.text = "SAVE & LAUNCH"
	launch.position = Vector2(get_viewport_rect().size.x - 260, 62)
	launch.size = Vector2(220, 44)
	launch.focus_mode = Control.FOCUS_NONE
	launch.pressed.connect(_deploy)
	add_child(launch)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.position = Vector2(get_viewport_rect().size.x - 375, 62)
	cancel.size = Vector2(100, 44)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(func(): closed.emit())
	add_child(cancel)

func _toolbar_button(label: String, x: float, width: float) -> Button:
	var button := Button.new()
	button.text = label
	button.position = Vector2(x, 56)
	button.size = Vector2(width, 34)
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

func _create_toolbar() -> void:
	select_button = _toolbar_button("Select", 320, 105)
	select_button.toggle_mode = true
	select_button.toggled.connect(func(enabled: bool):
		select_mode = enabled
		if enabled and paint_mode:
			paint_button.button_pressed = false
		painting = false
		erasing = false
		status = "Drag a box over parts, then drag the selection to move it." if enabled else "Choose a component to place."
		queue_redraw()
	)
	symmetry_button = _toolbar_button("Symmetry: Off", 435, 155)
	symmetry_button.toggle_mode = true
	symmetry_button.toggled.connect(func(enabled: bool):
		symmetry_enabled = enabled
		symmetry_button.text = "Symmetry: On" if enabled else "Symmetry: Off"
		status = "Symmetry mirrors placement and removal across the center grid." if enabled else "Symmetry off."
		queue_redraw()
	)
	var random_button := _toolbar_button("Randomize", 600, 125)
	random_button.pressed.connect(_randomize_ship)
	undo_button = _toolbar_button("Undo random", 735, 135)
	undo_button.disabled = true
	undo_button.pressed.connect(_undo_random)
	var library_button := _toolbar_button("Ship designs", 880, 135)
	library_button.pressed.connect(_open_design_library)
	var reset_view := _toolbar_button("Reset view", 1025, 120)
	reset_view.pressed.connect(_reset_grid_view)
	interior_button = _toolbar_button("View: Exterior", 1155, 160)
	interior_button.pressed.connect(_toggle_view)
	paint_button = _toolbar_button("Paint hull", 1325, 110)
	paint_button.toggle_mode = true
	paint_button.toggled.connect(func(enabled: bool):
		paint_mode = enabled
		if enabled and select_mode:
			select_button.button_pressed = false
		painting = false
		erasing = false
		status = "Drag over hull blocks to paint. Right-drag restores their original colour." if enabled else "Choose a component to place."
		queue_redraw()
	)
	paint_picker = ColorPickerButton.new()
	paint_picker.position = Vector2(1445, 56)
	paint_picker.size = Vector2(90, 34)
	paint_picker.text = "Colour"
	paint_picker.edit_alpha = false
	paint_picker.color = MODULES.HULL_BASE_COLOR
	paint_picker.focus_mode = Control.FOCUS_NONE
	add_child(paint_picker)
	_create_design_library()

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
	selected_type = "reactor" if interior_view else "hull"
	select_mode = false
	select_button.button_pressed = false
	select_button.disabled = interior_view
	paint_mode = false
	paint_button.button_pressed = false
	paint_button.disabled = interior_view
	paint_picker.disabled = interior_view
	selected_cells.clear()
	painting = false
	erasing = false
	_update_palette()
	status = "Place equipment on the hull footprint." if interior_view else "Build the ship's outside shape."
	queue_redraw()

func _create_design_library() -> void:
	design_dialog = AcceptDialog.new()
	design_dialog.title = "Ship designs"
	design_dialog.size = Vector2i(520, 430)
	design_dialog.get_ok_button().text = "Close"
	add_child(design_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	design_dialog.add_child(column)
	var label := Label.new()
	label.text = "Save the current design with a name, or load a saved design."
	column.add_child(label)
	design_name = LineEdit.new()
	design_name.placeholder_text = "Design name"
	design_name.max_length = 60
	column.add_child(design_name)
	var save_button := Button.new()
	save_button.text = "Save current design"
	save_button.pressed.connect(_save_named_design)
	column.add_child(save_button)
	design_list = ItemList.new()
	design_list.custom_minimum_size = Vector2(460, 180)
	design_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	design_list.item_activated.connect(func(_index: int): _request_library_action("load"))
	column.add_child(design_list)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var load_button := Button.new()
	load_button.text = "Load selected"
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.pressed.connect(_request_library_action.bind("load"))
	actions.add_child(load_button)
	var delete_button := Button.new()
	delete_button.text = "Delete selected"
	delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_button.pressed.connect(_request_library_action.bind("delete"))
	actions.add_child(delete_button)
	design_message = Label.new()
	design_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(design_message)
	library_confirmation = ConfirmationDialog.new()
	library_confirmation.title = "Confirm"
	library_confirmation.confirmed.connect(_confirm_library_action)
	design_dialog.add_child(library_confirmation)

func has_open_design_dialog() -> bool:
	return is_instance_valid(design_dialog) and design_dialog.visible

func close_design_dialog() -> void:
	if library_confirmation.visible:
		library_confirmation.hide()
	else:
		design_dialog.hide()

func _open_design_library() -> void:
	painting = false
	erasing = false
	library_available = true
	library_entries = {}
	if FileAccess.file_exists(library_path):
		var file := FileAccess.open(library_path, FileAccess.READ)
		if file == null:
			library_available = false
		else:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				library_entries = parsed
			else:
				library_available = false
	_refresh_design_list()
	design_message.text = "" if library_available else "Couldn't read the saved design library. No changes were made."
	design_dialog.popup_centered()

func _refresh_design_list() -> void:
	design_list.clear()
	var names := library_entries.keys()
	names.sort()
	for name in names:
		design_list.add_item(str(name))

func _write_design_library(entries: Dictionary) -> bool:
	var temporary := library_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(entries))
	file.flush()
	if file.get_error() != OK:
		file.close()
		return false
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(library_path)) == OK

func _safe_saved_design(design: Variant) -> bool:
	if not design is Array:
		return false
	var error: String = MODULES.validate(MODULES.migrate_legacy(design), false, false)
	# Incomplete or disconnected work may be saved and repaired in the builder.
	return error in ["", "A ship needs exactly one cockpit.", "Every component must connect to the ship."]

func _save_named_design() -> void:
	if not library_available:
		design_message.text = "Couldn't read the library, so it cannot be changed."
		return
	var name := design_name.text.strip_edges()
	if name.is_empty():
		design_message.text = "Enter a name for this design."
		return
	if library_entries.has(name):
		design_message.text = "That name is already in use. Choose another name."
		return
	if not _safe_saved_design(parts):
		design_message.text = "Add at least one valid component before saving."
		return
	var updated := library_entries.duplicate(true)
	updated[name] = parts.duplicate(true)
	if not _write_design_library(updated):
		design_message.text = "Couldn't save the design. Please try again."
		return
	library_entries = updated
	_refresh_design_list()
	design_message.text = "Saved ‘%s’." % name
	status = "Saved design: %s." % name
	queue_redraw()

func _request_library_action(action: String) -> void:
	var selected := design_list.get_selected_items()
	if selected.is_empty():
		design_message.text = "Select a saved design first."
		return
	if not library_available:
		design_message.text = "Couldn't read the library, so it cannot be changed."
		return
	library_selected_name = design_list.get_item_text(selected[0])
	library_action = action
	library_confirmation.dialog_text = "Load ‘%s’? Your current builder changes will be replaced." % library_selected_name if action == "load" else "Delete the saved design ‘%s’?" % library_selected_name
	library_confirmation.popup_centered()

func _confirm_library_action() -> void:
	if not library_entries.has(library_selected_name):
		design_message.text = "That design is no longer available."
		return
	if library_action == "load":
		var saved: Variant = library_entries[library_selected_name]
		if not _safe_saved_design(saved):
			design_message.text = "This design is invalid and couldn't be loaded."
			return
		parts = MODULES.migrate_legacy(saved)
		selected_cells.clear()
		has_random_backup = false
		random_backup.clear()
		undo_button.disabled = true
		status = "Loaded design: %s." % library_selected_name
		design_dialog.hide()
		queue_redraw()
	elif library_action == "delete":
		var updated := library_entries.duplicate(true)
		updated.erase(library_selected_name)
		if not _write_design_library(updated):
			design_message.text = "Couldn't delete the design. Please try again."
			return
		library_entries = updated
		_refresh_design_list()
		design_message.text = "Deleted ‘%s’." % library_selected_name

func _randomize_ship() -> void:
	var generated := _generate_random_design()
	if MODULES.validate(generated) != "":
		status = "Could not generate a valid ship. Please try again."
		queue_redraw()
		return
	random_backup = parts.duplicate(true)
	has_random_backup = true
	undo_button.disabled = false
	parts = generated
	selected_cells.clear()
	status = "Random ship created. Undo random restores your previous design."
	queue_redraw()

func _undo_random() -> void:
	if not has_random_backup:
		return
	parts = random_backup.duplicate(true)
	random_backup.clear()
	has_random_backup = false
	undo_button.disabled = true
	selected_cells.clear()
	status = "Previous design restored."
	queue_redraw()

func _generate_random_design() -> Array:
	return MODULES.generate_random_design(rng)

func _select_part(id: String) -> void:
	selected_type = id
	if paint_mode:
		paint_button.button_pressed = false
	select_button.button_pressed = false
	select_mode = false
	for key in palette_buttons:
		palette_buttons[key].button_pressed = key == id
	if id in MODULES.TURRETS:
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
	var area := get_viewport_rect().size
	return Rect2(Vector2(310.0, 105.0), Vector2(maxf(1.0, area.x - 620.0), maxf(1.0, area.y - 195.0)))

func _grid_center() -> Vector2:
	return _grid_viewport().get_center() + grid_pan

func _reset_grid_view() -> void:
	grid_zoom = 1.0
	grid_pan = Vector2.ZERO
	status = "View reset. Scroll to zoom; middle-drag to pan."
	queue_redraw()

func _zoom_grid_at(position: Vector2, factor: float) -> void:
	var grid_position := (position - _grid_center()) / _grid_spacing()
	grid_zoom = clampf(grid_zoom * factor, 0.75, 4.0)
	grid_pan = position - _grid_viewport().get_center() - grid_position * _grid_spacing()
	cursor_cell = _cell_at(position)
	queue_redraw()

func _grid_spacing() -> float:
	var area := get_viewport_rect().size
	var available_width := maxf(29.0, area.x - 650.0)
	var available_height := maxf(21.0, area.y - 205.0)
	return grid_zoom * minf(40.0, minf(available_width / (MODULES.GRID_HALF_WIDTH * 2 + 1), available_height / (MODULES.GRID_HALF_HEIGHT * 2 + 1)))

func _cell_at(position: Vector2) -> Vector2i:
	var local := (position - _grid_center()) / _grid_spacing()
	return Vector2i(roundi(local.x), roundi(local.y))

func _index_at(cell: Vector2i, layer: String = "") -> int:
	var want_interior := interior_view if layer == "" else layer == "interior"
	for i in range(parts.size()):
		if MODULES.is_interior(parts[i]) == want_interior and int(parts[i].x) == cell.x and int(parts[i].y) == cell.y:
			return i
	return -1

func _paint_at(cell: Vector2i, restore: bool = false) -> void:
	if interior_view:
		return
	var locations: Array[Vector2i] = [cell]
	if symmetry_enabled and cell.x != 0:
		locations.append(Vector2i(-cell.x, cell.y))
	var changed := 0
	for location in locations:
		var index := _index_at(location, "exterior")
		if index < 0 or parts[index].type not in MODULES.PAINTABLE_HULL_TYPES:
			continue
		if restore:
			parts[index].erase("paint")
		else:
			parts[index].paint = paint_picker.color.to_html(false)
		changed += 1
	if changed > 0:
		status = "Original hull colour restored." if restore else "Hull painted."
	else:
		status = "Paint works on square and right-angle hull blocks."

func _place_at(cell: Vector2i) -> void:
	if abs(cell.x) > MODULES.GRID_HALF_WIDTH or abs(cell.y) > MODULES.GRID_HALF_HEIGHT:
		return
	if not MODULES.can_place_on_layer(selected_type, interior_view):
		return
	if symmetry_enabled and cell.x == 0:
		var asymmetric := selected_type in ["wedge", "wing", "cargo_corner"] or (selected_type == "cargo_edge" and part_rotation % 2 == 0) or (selected_type in ["triangle", "engine", "thruster"] and part_rotation % 2 != 0)
		if asymmetric:
			status = "This orientation cannot be mirrored on the center line."
			return
	if interior_view:
		var locations: Array[Vector2i] = [cell]
		if symmetry_enabled and cell.x != 0:
			locations.append(Vector2i(-cell.x, cell.y))
		for location in locations:
			var hull_index := _index_at(location, "exterior")
			if hull_index < 0 or not MODULES.supports_interior(parts[hull_index].type):
				status = "Place interior equipment on a hull cell."
				return
			if _index_at(location, "interior") >= 0:
				status = "That interior cell is occupied."
				return
		if parts.size() + locations.size() > MODULES.MAX_COMPONENTS:
			status = "A ship can have up to %d components." % MODULES.MAX_COMPONENTS
			return
		parts.append({"type":selected_type, "layer":"interior", "x":cell.x, "y":cell.y, "rotation":part_rotation, "flip_x":part_flipped})
		if locations.size() == 2:
			parts.append({"type":selected_type, "layer":"interior", "x":-cell.x, "y":cell.y, "rotation":posmod(-part_rotation, 4), "flip_x":not part_flipped})
		status = "%s installed inside the hull." % MODULES.TYPES[selected_type].name
		return
	if selected_type in MODULES.TURRETS:
		var locations: Array[Vector2i] = [cell]
		if symmetry_enabled and cell.x != 0:
			locations.append(Vector2i(-cell.x, cell.y))
		for location in locations:
			var index := _index_at(location)
			if index < 0 or parts[index].type != "turret_base" or parts[index].has("turret"):
				status = "Place turrets on empty turret bases."
				return
		for location in locations:
			parts[_index_at(location)].turret = selected_type
		status = "%s mounted." % MODULES.TYPES[selected_type].name
		return
	if _index_at(cell) >= 0:
		return
	if selected_type == "cockpit" and (parts.any(func(part: Dictionary) -> bool: return part.type == "cockpit") or (symmetry_enabled and cell.x != 0)):
		status = "Each ship has one cockpit; place it on the center line in symmetry mode."
		return
	var locations: Array[Vector2i] = [cell]
	if symmetry_enabled and cell.x != 0:
		var mirror := Vector2i(-cell.x, cell.y)
		if _index_at(mirror) >= 0:
			status = "The mirrored cell is occupied."
			return
		locations.append(mirror)
	if parts.size() + locations.size() > MODULES.MAX_COMPONENTS:
		status = "A ship can have up to %d components." % MODULES.MAX_COMPONENTS
		return
	for location in locations:
		var adjacent := false
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if _index_at(location + direction) >= 0 or locations.has(location + direction):
				adjacent = true
				break
		if not adjacent and not (parts.is_empty() and selected_type == "cockpit"):
			status = "Place a cockpit first." if parts.is_empty() else "Both sides must attach to an existing edge."
			return
	parts.append({"type": selected_type, "x": cell.x, "y": cell.y, "rotation": part_rotation, "flip_x": part_flipped})
	if locations.size() == 2:
		var mirror: Vector2i = locations[1]
		parts.append({"type": selected_type, "x": mirror.x, "y": mirror.y, "rotation": posmod(-part_rotation, 4), "flip_x": not part_flipped})
	var error: String = MODULES.validate(parts, false)
	status = "%s attached." % MODULES.TYPES[selected_type].name if error == "" else "%s attached. %s" % [MODULES.TYPES[selected_type].name, error]

func _remove_at(cell: Vector2i) -> void:
	if abs(cell.x) > MODULES.GRID_HALF_WIDTH or abs(cell.y) > MODULES.GRID_HALF_HEIGHT:
		return
	var index := _index_at(cell)
	if index < 0:
		return
	if interior_view:
		var removed_name: String = MODULES.TYPES[parts[index].type].name
		parts.remove_at(index)
		if symmetry_enabled and cell.x != 0:
			var mirror_index := _index_at(Vector2i(-cell.x, cell.y), "interior")
			if mirror_index >= 0:
				parts.remove_at(mirror_index)
		status = "%s removed." % removed_name
		return
	if _index_at(cell, "interior") >= 0:
		status = "Remove the interior equipment beneath this hull cell first."
		return
	if symmetry_enabled and cell.x != 0 and _index_at(Vector2i(-cell.x, cell.y), "interior") >= 0:
		status = "Remove the mirrored interior equipment first."
		return
	var removing_turret: bool = parts[index].has("turret")
	var removed_name: String = MODULES.TYPES[parts[index].get("turret", parts[index].type)].name
	if removing_turret:
		parts[index].erase("turret")
	else:
		parts.remove_at(index)
	selected_cells.erase(cell)
	if symmetry_enabled and cell.x != 0:
		var mirror := Vector2i(-cell.x, cell.y)
		var mirror_index := _index_at(mirror)
		if mirror_index >= 0:
			if removing_turret:
				parts[mirror_index].erase("turret")
			else:
				parts.remove_at(mirror_index)
			selected_cells.erase(mirror)
	var error: String = MODULES.validate(parts, false)
	status = "%s removed." % removed_name if error == "" else "%s removed. %s" % [removed_name, error]

func _finish_selection(release_position: Vector2) -> void:
	var cell := _cell_at(release_position)
	if marquee_active:
		marquee_end = cell
		var left := mini(marquee_start.x, marquee_end.x)
		var right := maxi(marquee_start.x, marquee_end.x)
		var top := mini(marquee_start.y, marquee_end.y)
		var bottom := maxi(marquee_start.y, marquee_end.y)
		selected_cells.clear()
		for part in parts:
			if MODULES.is_interior(part):
				continue
			var p := Vector2i(int(part.x), int(part.y))
			if p.x >= left and p.x <= right and p.y >= top and p.y <= bottom:
				selected_cells.append(p)
		marquee_active = false
		status = "%d parts selected. Drag the selection to move it." % selected_cells.size() if not selected_cells.is_empty() else "No parts selected."
	elif moving_selection:
		for selected in selected_cells:
			if _index_at(selected, "interior") >= 0:
				status = "Remove interior equipment before moving its hull cell."
				moving_selection = false
				move_delta = Vector2i.ZERO
				queue_redraw()
				return
		move_delta = cell - move_anchor
		var destinations := {}
		var possible := true
		for part in parts:
			if MODULES.is_interior(part):
				continue
			var original := Vector2i(int(part.x), int(part.y))
			var target := original + move_delta if selected_cells.has(original) else original
			if absi(target.x) > MODULES.GRID_HALF_WIDTH or absi(target.y) > MODULES.GRID_HALF_HEIGHT or destinations.has(target):
				possible = false
				break
			destinations[target] = true
		if possible:
			for part in parts:
				if MODULES.is_interior(part):
					continue
				var original := Vector2i(int(part.x), int(part.y))
				if selected_cells.has(original):
					part.x = original.x + move_delta.x
					part.y = original.y + move_delta.y
			for i in range(selected_cells.size()):
				selected_cells[i] += move_delta
			var error: String = MODULES.validate(parts, false)
			status = "Selection moved." if error == "" else "Selection moved. " + error
		else:
			status = "Cannot move parts outside the grid or on top of other parts."
		moving_selection = false
		move_delta = Vector2i.ZERO
	queue_redraw()

func _drag_line(start: Vector2i, target: Vector2i, erase: bool) -> void:
	# Include skipped cells and take orthogonal steps so diagonal drags stay connected.
	var end := Vector2i(clampi(target.x, -MODULES.GRID_HALF_WIDTH, MODULES.GRID_HALF_WIDTH), clampi(target.y, -MODULES.GRID_HALF_HEIGHT, MODULES.GRID_HALF_HEIGHT))
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
		if paint_mode:
			_paint_at(current, erase)
		elif erase:
			_remove_at(current)
		else:
			_place_at(current)
	if erase:
		last_erase_cell = end
	else:
		last_paint_cell = end

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
			if marquee_active or moving_selection:
				_finish_selection(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			erasing = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			part_rotation = (part_rotation + 1) % 4
		elif event.keycode == KEY_F:
			part_flipped = not part_flipped
		else:
			return
		get_viewport().set_input_as_handled()
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		painting = false
		erasing = false
		panning = false
		marquee_active = false
		moving_selection = false
		move_delta = Vector2i.ZERO

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor_cell = _cell_at(event.position)
		show_cursor = _grid_viewport().has_point(event.position) and abs(cursor_cell.x) <= MODULES.GRID_HALF_WIDTH and abs(cursor_cell.y) <= MODULES.GRID_HALF_HEIGHT
		if marquee_active:
			marquee_end = cursor_cell
		elif moving_selection:
			move_delta = cursor_cell - move_anchor
		elif painting:
			_drag_line(last_paint_cell, cursor_cell, false)
		elif erasing:
			_drag_line(last_erase_cell, cursor_cell, true)
		queue_redraw()
	elif event is InputEventMouseButton:
		if not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			painting = false
			if marquee_active or moving_selection:
				_finish_selection(event.position)
			return
		if not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			erasing = false
			return
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
			panning = true
			pan_last_position = event.position
			return
		var cell := _cell_at(event.position)
		if abs(cell.x) > MODULES.GRID_HALF_WIDTH or abs(cell.y) > MODULES.GRID_HALF_HEIGHT:
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			painting = false
			erasing = true
			last_erase_cell = cell
			if paint_mode:
				_paint_at(cell, true)
			else:
				_remove_at(cell)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			erasing = false
			if paint_mode:
				painting = true
				last_paint_cell = cell
				_paint_at(cell)
			elif select_mode:
				if selected_cells.has(cell):
					moving_selection = true
					move_anchor = cell
					move_delta = Vector2i.ZERO
				else:
					marquee_active = true
					marquee_start = cell
					marquee_end = cell
			else:
				painting = true
				last_paint_cell = cell
				_place_at(cell)
		queue_redraw()

func _draw() -> void:
	var area := get_viewport_rect().size
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, area), Color("08111e"))
	draw_string(font, Vector2(24, 44), "SHIP BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("e5f6ff"))
	draw_string(font, Vector2(24, 74), "INTERIOR  /  INSTALL SYSTEMS" if interior_view else "EXTERIOR  /  BUILD SHAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78a3ba"))
	draw_line(Vector2(24, 94), Vector2(area.x - 24, 94), Color("345166"), 1.0)
	var center := _grid_center()
	var spacing := _grid_spacing()
	var part_scale := spacing / MODULES.CELL
	if symmetry_enabled:
		draw_line(center + Vector2(0, -spacing * (MODULES.GRID_HALF_HEIGHT + 0.5)), center + Vector2(0, spacing * (MODULES.GRID_HALF_HEIGHT + 0.5)), Color(0.42, 0.75, 1.0, 0.3), 2.0)
	var grid_left := center.x - (MODULES.GRID_HALF_WIDTH + 0.5) * spacing
	var grid_right := center.x + (MODULES.GRID_HALF_WIDTH + 0.5) * spacing
	var grid_top := center.y - (MODULES.GRID_HALF_HEIGHT + 0.5) * spacing
	var grid_bottom := center.y + (MODULES.GRID_HALF_HEIGHT + 0.5) * spacing
	var grid_color := Color(0.23, 0.4, 0.5, 0.16)
	for x in range(MODULES.GRID_HALF_WIDTH * 2 + 2):
		var grid_x := grid_left + x * spacing
		draw_line(Vector2(grid_x, grid_top), Vector2(grid_x, grid_bottom), grid_color)
	for y in range(MODULES.GRID_HALF_HEIGHT * 2 + 2):
		var grid_y := grid_top + y * spacing
		draw_line(Vector2(grid_left, grid_y), Vector2(grid_right, grid_y), grid_color)
	# A persistent marker identifies the (0, 0) cell even when it contains a part.
	var origin_rect := Rect2(center - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing)
	draw_rect(origin_rect, Color(0.18, 0.70, 0.92, 0.12))
	draw_rect(origin_rect, Color(0.35, 0.85, 1.0, 0.6), false, 2.0)
	var occupied := {}
	var connection_points := {}
	for part in parts:
		if not MODULES.is_interior(part):
			occupied[Vector2i(int(part.x), int(part.y))] = true
	if not interior_view:
		for part in parts:
			if MODULES.is_interior(part):
				continue
			for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var cell: Vector2i = Vector2i(int(part.x), int(part.y)) + direction
				if abs(cell.x) <= MODULES.GRID_HALF_WIDTH and abs(cell.y) <= MODULES.GRID_HALF_HEIGHT and not occupied.has(cell):
					connection_points[cell] = true
	for cell in connection_points:
		draw_circle(center + Vector2(cell) * spacing, minf(3.0, spacing * 0.14), Color(0.3, 0.8, 1.0, 0.55))
	for part in parts:
		if MODULES.is_interior(part):
			continue
		var cell := Vector2i(int(part.x), int(part.y))
		var chosen := selected_cells.has(cell)
		var draw_cell := cell + move_delta if chosen and moving_selection else cell
		var part_position := center + Vector2(draw_cell) * spacing
		if chosen:
			draw_rect(Rect2(part_position - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing), Color(0.25, 0.68, 1.0, 0.28))
		if interior_view:
			if MODULES.supports_interior(part.type):
				var footprint := Rect2(part_position - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing)
				draw_rect(footprint, Color("4a5860"))
				draw_rect(footprint, Color("82949a"), false, 1.0)
			else:
				MODULES.draw_part(self, part, part_position, part_scale, 0.28)
		else:
			MODULES.draw_part(self, part, part_position, part_scale)
		if chosen:
			draw_rect(Rect2(part_position - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing), Color(0.47, 0.84, 1.0, 0.95), false, 2.0)
	if interior_view:
		for part in parts:
			if MODULES.is_interior(part):
				var interior_scale := part_scale if part.type in MODULES.CARGO_HOLD_TYPES else part_scale * 0.83
				MODULES.draw_part(self, part, center + Vector2(part.x, part.y) * spacing, interior_scale)
	if marquee_active:
		var low := Vector2(mini(marquee_start.x, marquee_end.x), mini(marquee_start.y, marquee_end.y))
		var high := Vector2(maxi(marquee_start.x, marquee_end.x), maxi(marquee_start.y, marquee_end.y))
		var rect := Rect2(center + (low - Vector2.ONE * 0.5) * spacing, (high - low + Vector2.ONE) * spacing)
		draw_rect(rect, Color(0.25, 0.7, 1.0, 0.16))
		draw_rect(rect, Color(0.45, 0.85, 1.0, 0.95), false, 2.0)
	# Corner brackets remain visible around components placed on the center cell.
	var corner := spacing * 0.5
	var arm := maxf(5.0, spacing * 0.20)
	for x_sign in [-1.0, 1.0]:
		for y_sign in [-1.0, 1.0]:
			var p := center + Vector2(x_sign * corner, y_sign * corner)
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
		var paint_index := _index_at(cursor_cell, "exterior")
		if paint_index >= 0 and parts[paint_index].type in MODULES.PAINTABLE_HULL_TYPES:
			var paint_position := center + Vector2(cursor_cell) * spacing
			draw_rect(Rect2(paint_position - Vector2.ONE * spacing * 0.5, Vector2.ONE * spacing), paint_picker.color, false, 3.0)
	if not paint_mode and not select_mode and show_cursor and _index_at(cursor_cell) < 0 and (not interior_view or (_index_at(cursor_cell, "exterior") >= 0 and MODULES.supports_interior(parts[_index_at(cursor_cell, "exterior")].type))):
		MODULES.draw_part(self, {"type":selected_type, "rotation":part_rotation, "flip_x":part_flipped}, center + Vector2(cursor_cell) * spacing, part_scale, 0.4)
		if symmetry_enabled and cursor_cell.x != 0:
			var mirror := Vector2i(-cursor_cell.x, cursor_cell.y)
			if _index_at(mirror) < 0 and (not interior_view or (_index_at(mirror, "exterior") >= 0 and MODULES.supports_interior(parts[_index_at(mirror, "exterior")].type))):
				MODULES.draw_part(self, {"type":selected_type, "rotation":posmod(-part_rotation, 4), "flip_x":not part_flipped}, center + Vector2(mirror) * spacing, part_scale, 0.4)
	# Cover anything outside the workspace so zoomed parts cannot obscure controls.
	var background := Color("08111e")
	draw_rect(Rect2(0, 0, 310, area.y), background)
	draw_rect(Rect2(area.x - 310, 0, 310, area.y), background)
	draw_rect(Rect2(0, 0, area.x, 105), background)
	draw_rect(Rect2(310, area.y - 90, maxf(0.0, area.x - 620), 90), background)
	draw_string(font, Vector2(24, 44), "SHIP BUILDER", HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("e5f6ff"))
	draw_string(font, Vector2(24, 74), "INTERIOR  /  INSTALL SYSTEMS" if interior_view else "EXTERIOR  /  BUILD SHAPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("78a3ba"))
	draw_line(Vector2(24, 94), Vector2(area.x - 24, 94), Color("345166"), 1.0)
	var right := area.x - 300.0
	draw_string(font, Vector2(right, 155), "SHIP PERFORMANCE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d9f0fb"))
	var totals: Dictionary = MODULES.stats(parts)
	var labels := ["Components", "Mass", "Hull", "Power balance", "Thrust", "Turn rate", "Weapon power", "Shield", "Cargo capacity", "Mining rate"]
	var values := [str(parts.size()), str(int(totals.mass)), str(int(totals.health)), ("+" if totals.power >= 0.0 else "") + str(int(totals.power)), str(int(totals.thrust)), "%d°/s" % roundi(rad_to_deg(base_turn_speed * float(totals.maneuver))), str(int(totals.weapon)), str(int(totals.shield)), str(int(totals.cargo)), "%s / sec" % str(totals.mining)]
	for i in range(labels.size()):
		var y := 192.0 + float(i) * 31.0
		draw_string(font, Vector2(right, y), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9ab4c1"))
		var value_color := Color("ff8d83") if i == 3 and totals.power < 0.0 else Color("e5f3f9")
		draw_string(font, Vector2(right + 140, y), values[i], HORIZONTAL_ALIGNMENT_RIGHT, 135, 15, value_color)
	draw_string(font, Vector2(right, 515), "CYAN BRACKETS = CENTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("76d8ef"))
	draw_string(font, Vector2(right, 545), "FLIGHT READINESS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("81acc2"))
	var error: String = MODULES.validate(parts)
	draw_string(font, Vector2(right, 571), "READY TO LAUNCH" if error == "" else "NEEDS ATTENTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8ce1c4") if error == "" else Color("ffb58c"))
	if error != "":
		draw_multiline_string(font, Vector2(right, 600), error, HORIZONTAL_ALIGNMENT_LEFT, 275, 13, -1, Color("ffc2a0"))
	draw_string(font, Vector2(320, area.y - 58), "PAINT: drag to colour, right-drag to restore   ·   PLACE: drag   ·   SELECT: box & drag   ·   R rotate   ·   F flip   ·   SCROLL: zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9cbac9"))
	draw_string(font, Vector2(320, area.y - 31), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("8bd5ee"))

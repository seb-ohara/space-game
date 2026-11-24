extends Control

signal closed
signal launch_requested(parts: Array)
signal admin_save_requested(index: int, values: Dictionary)

const MODULES := preload("res://scripts/ship_modules.gd")
const SHIP_ADMIN := preload("res://scripts/ship_admin.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")
const LOADOUT := preload("res://scripts/ship_loadout.gd")
const ICONS := preload("res://scripts/module_icons.gd")
const HARDPOINT_PREVIEW := preload("res://scripts/hardpoint_preview.gd")
const DECK := Color("101c29")
const INK := Color("e5ebee")
const MUTED := Color("9fb3c0")
const EDGE := Color("3b5060")
const AMBER := Color("efbc7d")

var current_parts: Array = []
var current_ship_values: Dictionary = {}
var admin_ships: Array = []
var active_fleet_index := 0
var dragging_slot := -1
var drag_offset := Vector2.ZERO
var preview_draw: Callable
var library_entries: Variant
var designs: Array[Dictionary] = []
var selected_index := 0
var body: VBoxContainer
var navigation: HBoxContainer
var admin_tab: Button
var admin_view: VBoxContainer
var ship_admin: SHIP_ADMIN
var library_view: HBoxContainer
var library_list: ItemList
var preview: Control
var ship_title: Label
var ship_details: Label
var status: Label
var delete_button: Button
var launch_button: Button
var confirmation: ConfirmationDialog
var confirm_action: Callable

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var hangar_theme := Theme.new()
	hangar_theme.default_font_size = 16
	for item_type in ["Button", "OptionButton", "CheckButton", "ColorPickerButton", "LineEdit", "ItemList"]:
		hangar_theme.set_color("font_color", item_type, INK)
		hangar_theme.set_color("font_hover_color", item_type, Color.WHITE)
		hangar_theme.set_color("font_disabled_color", item_type, Color("7b8e9a"))
	hangar_theme.set_color("font_color", "Label", INK)
	hangar_theme.set_stylebox("normal", "Button", _style(Color("1d3040"), EDGE))
	hangar_theme.set_stylebox("hover", "Button", _style(Color("2a4254"), Color("628897")))
	hangar_theme.set_stylebox("pressed", "Button", _style(Color("354b53"), AMBER))
	hangar_theme.set_stylebox("disabled", "Button", _style(Color("162632"), Color("2b3c47")))
	var focus := _style(Color.TRANSPARENT, AMBER)
	focus.set_border_width_all(2)
	hangar_theme.set_stylebox("focus", "Button", focus)
	theme = hangar_theme
	var background := ColorRect.new()
	background.color = DECK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	margin.add_child(body)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	body.add_child(header)
	var title := _label(header, "Hangar", 34, INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(header, "Return to flight", request_close)
	body.add_child(HSeparator.new())
	_create_navigation()
	_create_library_view()
	_create_admin_view()
	_show_library()
	status = _label(body, "", 15, MUTED)
	status.custom_minimum_size.y = 23
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	confirmation = ConfirmationDialog.new()
	confirmation.title = "Hangar"
	confirmation.confirmed.connect(func():
		if confirm_action.is_valid():
			confirm_action.call()
	)
	add_child(confirmation)

	library_entries = LIBRARY.read()
	_refresh_library()
	if library_entries == null:
		_set_status("The saved ship library could not be read. Built-in ships are available.")

func _style(background: Color, outline: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = outline
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style

func _label(parent: Control, caption: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label

func _button(parent: Control, caption: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 38
	button.pressed.connect(action)
	if primary:
		button.add_theme_stylebox_override("normal", _style(AMBER, AMBER))
		button.add_theme_stylebox_override("hover", _style(Color("ffcf91"), AMBER))
		button.add_theme_stylebox_override("pressed", _style(Color("db9d5b"), AMBER))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("18222a"))
	parent.add_child(button)
	return button

func _create_navigation() -> void:
	navigation = HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	body.add_child(navigation)
	admin_tab = _tab("Ship admin")

func _tab(caption: String) -> Button:
	var tab := Button.new()
	tab.text = caption
	tab.toggle_mode = true
	tab.custom_minimum_size = Vector2(170, 36)
	tab.focus_mode = Control.FOCUS_NONE
	tab.pressed.connect(func():
		admin_view.visible = tab.button_pressed
		dragging_slot = -1
		_refresh_preview_context()
	)
	navigation.add_child(tab)
	return tab

func _show_library() -> void:
	library_view.show()
	admin_view.hide()
	admin_tab.set_pressed_no_signal(false)

func _create_admin_view() -> void:
	admin_view = VBoxContainer.new()
	admin_view.custom_minimum_size.x = 390
	admin_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	admin_view.add_theme_constant_override("separation", 12)
	library_view.add_child(admin_view)
	admin_view.hide()
	_label(admin_view, "Ship admin", 22, INK)
	var hint := _label(admin_view, "Adjust the size and flight stats of any ship in your fleet. Changes are saved with this galaxy.", 15, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_admin = SHIP_ADMIN.new()
	ship_admin.ships = admin_ships
	ship_admin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ship_admin.save_requested.connect(func(index: int, values: Dictionary): admin_save_requested.emit(index, values))
	ship_admin.slots_changed.connect(_refresh_preview_context)
	admin_view.add_child(ship_admin)
	ship_admin.selector.item_selected.connect(func(_index: int):
		dragging_slot = -1
		_refresh_preview_context()
	)

func _create_library_view() -> void:
	library_view = HBoxContainer.new()
	library_view.add_theme_constant_override("separation", 20)
	library_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(library_view)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 250
	sidebar.add_theme_constant_override("separation", 10)
	library_view.add_child(sidebar)
	_label(sidebar, "Ship library", 22, INK)
	library_list = ItemList.new()
	library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_list.fixed_icon_size = Vector2i(29, 36)
	library_list.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	library_list.add_theme_constant_override("v_separation", 10)
	library_list.add_theme_constant_override("icon_margin", 9)
	library_list.add_theme_stylebox_override("panel", _style(Color("132230"), EDGE))
	library_list.item_selected.connect(_select_design)
	sidebar.add_child(library_list)

	var bay := VBoxContainer.new()
	bay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bay.add_theme_constant_override("separation", 10)
	library_view.add_child(bay)
	ship_title = _label(bay, "", 28, INK)
	ship_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ship_details = _label(bay, "", 16, MUTED)
	ship_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var hardpoint_preview := HARDPOINT_PREVIEW.new()
	hardpoint_preview.drag_from_hardpoint = _module_drag_data
	hardpoint_preview.can_drop_module = _can_drop_module
	hardpoint_preview.drop_module = _drop_module
	preview = hardpoint_preview
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = 120
	preview.clip_contents = true
	preview.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	preview.tooltip_text = "Drag squares to move hardpoints. Drop modules onto them; right-click to remove a module."
	preview.draw.connect(_draw_preview)
	preview.gui_input.connect(_preview_input)
	bay.add_child(preview)
	var actions := HBoxContainer.new()
	bay.add_child(actions)
	delete_button = _button(actions, "Delete saved ship", _request_delete)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	launch_button = _button(actions, "Launch ship", _launch, true)

func _refresh_library(select_name: String = "") -> void:
	designs.clear()
	library_list.clear()
	_add_design("Current ship", current_parts, "Current")
	for caption in MODULES.PRESET_NAMES:
		_add_design(caption.trim_prefix("Built-in · "), MODULES.preset_design(MODULES.PRESET_NAMES[caption]), "Built-in")
	var next_selection := 0
	if library_entries is Dictionary:
		var names: Array = library_entries.keys()
		names.sort()
		for saved_name in names:
			var parts := LIBRARY.restore_design(library_entries[saved_name])
			if parts.is_empty():
				continue
			if saved_name == select_name:
				next_selection = designs.size()
			_add_design(saved_name, parts, "Saved")
	library_list.select(next_selection)
	library_list.ensure_current_is_visible()
	_select_design(next_selection)

func _add_design(caption: String, parts: Array, category: String) -> void:
	designs.append({"name": caption, "parts": parts, "category": category, "flight_error": MODULES.validate(parts)})
	var icon: Texture2D
	if _has_pixel_art(parts):
		icon = MODULES.preset_texture(parts[0])
	library_list.add_item(caption, icon)
	library_list.set_item_tooltip(designs.size() - 1, "%s · %s" % [category, caption])

func _has_pixel_art(parts: Array) -> bool:
	return parts.size() == 1 and MODULES.PRESET_TEXTURES.has(parts[0].type)

func _select_design(index: int) -> void:
	dragging_slot = -1
	selected_index = index
	var design := designs[index]
	var parts: Array = design.parts
	var category: String = design.category
	var dimensions := MODULES.dimensions_meters(parts)
	var stats := MODULES.stats(parts)
	if category == "Current" and not current_ship_values.is_empty():
		dimensions = Vector2(current_ship_values.width, current_ship_values.length_meters)
		stats.health = current_ship_values.health
	ship_title.text = design.name
	ship_details.text = "%s  •  %d hull\nLength: %.1f m  •  Width: %.1f m" % [category, int(stats.health), dimensions.y, dimensions.x]
	var pixel_art := _has_pixel_art(parts)
	if not pixel_art:
		ship_details.text += "\nLegacy modular ship"
		if design.flight_error != "":
			ship_details.text += " · " + design.flight_error
	delete_button.visible = category == "Saved"
	launch_button.disabled = design.flight_error != ""
	launch_button.tooltip_text = design.flight_error
	_refresh_preview_context()

func _refresh_preview_context() -> void:
	if designs.is_empty() or not is_instance_valid(ship_admin):
		return
	if selected_index == 0 and admin_view.visible and ship_admin.selected_index < admin_ships.size():
		var ship: Dictionary = admin_ships[ship_admin.selected_index]
		ship_title.text = ship.name
		var values: Dictionary = ship.values
		ship_details.text = "Fleet ship  •  %d hull\nLength: %.1f m  •  Width: %.1f m" % [int(values.get("health", 0)), float(values.length_meters), float(values.width)]
	elif selected_index == 0:
		ship_title.text = designs[0].name
		if not current_ship_values.is_empty():
			ship_details.text = "Current  •  %d hull\nLength: %.1f m  •  Width: %.1f m" % [int(current_ship_values.health), float(current_ship_values.length_meters), float(current_ship_values.width)]
	preview.queue_redraw()

func _preview_parts() -> Array:
	if selected_index == 0 and admin_view.visible and ship_admin.selected_index < admin_ships.size():
		return admin_ships[ship_admin.selected_index].get("parts", current_parts)
	return designs[selected_index].parts

func _preview_ship_rect() -> Rect2:
	var bounds := MODULES.bounds(_preview_parts())
	var insets := (preview.size - Vector2(108, 92)).max(Vector2.ONE)
	var fit := minf(insets.x / bounds.size.x, insets.y / bounds.size.y)
	var size := bounds.size * fit
	return Rect2((preview.size - size) * 0.5, size)

func _draw_preview() -> void:
	var area := Rect2(Vector2.ZERO, preview.size)
	var centre := area.get_center()
	preview.draw_rect(area, Color("0c1722"))
	var grid_spacing := 34
	for axis in range(2):
		var other := 1 - axis
		for line in range(-floori(centre[axis] / grid_spacing), ceili(centre[axis] / grid_spacing)):
			var start := Vector2.ZERO
			start[axis] = centre[axis] + line * grid_spacing
			var finish := start
			finish[other] = area.size[other]
			preview.draw_line(start, finish, Color("263b49") if line == 0 else Color("172834"))
	var parts: Array = _preview_parts()
	var bounds := MODULES.bounds(parts)
	var insets := (area.size - Vector2(108, 92)).max(Vector2.ONE)
	var fit := minf(insets.x / bounds.size.x, insets.y / bounds.size.y)
	preview.draw_rect(Rect2(centre - bounds.size * fit * 0.5, bounds.size * fit).grow(13.0), Color("344b59"), false, 1.0)
	preview.draw_polyline(PackedVector2Array([centre + Vector2(-7, -bounds.size.y * fit * 0.5 - 21), centre + Vector2(0, -bounds.size.y * fit * 0.5 - 28), centre + Vector2(7, -bounds.size.y * fit * 0.5 - 21)]), AMBER, 2.0, true)
	preview.draw_set_transform(centre, 0.0, Vector2.ONE * fit)
	if preview_draw.is_valid():
		preview_draw.call(preview, {"parts": parts})
	preview.draw_set_transform(Vector2.ZERO)
	if selected_index == 0 and admin_view.visible:
		var slots := ship_admin._slot_values()
		var ship_rect := _preview_ship_rect()
		for index in slots.size():
			var point := ship_rect.position + Vector2(slots[index].x, slots[index].y) * ship_rect.size
			var square := Rect2(point - Vector2.ONE * 16.0, Vector2.ONE * 32.0)
			var outline := AMBER if index == dragging_slot else Color("62d8e7")
			preview.draw_rect(square, Color("10212d"))
			preview.draw_rect(square, outline, false, 2.0)
			ICONS.draw(preview, square.grow(-5.0), slots[index].type, outline)
			preview.draw_string(ThemeDB.fallback_font, point + Vector2(10, -12), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	preview.draw_rect(area, EDGE, false, 1.0)

func _hardpoint_at(position: Vector2) -> int:
	if selected_index != 0 or not admin_view.visible:
		return -1
	var slots := ship_admin._slot_values()
	var ship_rect := _preview_ship_rect()
	var nearest := INF
	var selected := -1
	for index in slots.size():
		var point := ship_rect.position + Vector2(slots[index].x, slots[index].y) * ship_rect.size
		var difference := (position - point).abs()
		var distance := difference.length_squared()
		if difference.x <= 16.0 and difference.y <= 16.0 and distance <= nearest:
			nearest = distance
			selected = index
	return selected

func _module_drag_data(position: Vector2) -> Variant:
	var index := _hardpoint_at(position)
	if index < 0:
		return null
	var kind: String = ship_admin._slot_values()[index].type
	if kind == "":
		return null
	return {"module_type": kind, "source_index": index, "source_ship": ship_admin.selected_index}

func _can_drop_module(position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.get("module_type") is String:
		return false
	var kind: String = data.module_type
	if kind == "" or not LOADOUT.TYPES.has(kind) or _hardpoint_at(position) < 0:
		return false
	var source := int(data.get("source_index", -1))
	if source >= 0:
		var slots := ship_admin._slot_values()
		return data.get("source_ship", -1) == ship_admin.selected_index and source < slots.size() and slots[source].type == kind
	return source == -1

func _drop_module(position: Vector2, data: Variant) -> void:
	if not _can_drop_module(position, data):
		return
	var target := _hardpoint_at(position)
	var source := int(data.get("source_index", -1))
	if source >= 0 and source != target:
		ship_admin.set_slot_type(source, "")
	ship_admin.set_slot_type(target, data.module_type)
	_set_status("Module fitted. Save ship changes to apply the loadout.")

func _preview_input(event: InputEvent) -> void:
	if selected_index != 0 or not admin_view.visible:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var index := _hardpoint_at(event.position)
		if index >= 0:
			ship_admin.set_slot_type(index, "")
			_set_status("Module removed. Save ship changes to apply the loadout.")
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not event.shift_pressed:
			dragging_slot = _hardpoint_at(event.position)
			if dragging_slot >= 0:
				var slot: Dictionary = ship_admin._slot_values()[dragging_slot]
				var ship_rect := _preview_ship_rect()
				drag_offset = event.position - (ship_rect.position + Vector2(slot.x, slot.y) * ship_rect.size)
				preview.queue_redraw()
				accept_event()
		elif not event.pressed and dragging_slot >= 0:
			dragging_slot = -1
			_set_status("Hardpoint moved. Save ship changes to apply the loadout.")
			preview.queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and dragging_slot >= 0:
		var ship_rect := _preview_ship_rect()
		var position: Vector2 = (event.position - drag_offset - ship_rect.position) / ship_rect.size
		ship_admin.place_slot(dragging_slot, position)
		accept_event()

func _request_delete() -> void:
	var ship_name: String = designs[selected_index].name
	_confirm("Delete the saved ship “%s”?" % ship_name, "Delete ship", func():
		var updated: Dictionary = library_entries.duplicate()
		updated.erase(ship_name)
		if LIBRARY.write(updated):
			library_entries = updated
			_refresh_library()
			_set_status("Deleted %s." % ship_name)
		else:
			_set_status("The saved ship could not be deleted.")
	)

func _confirm(prompt: String, action_name: String, action: Callable) -> void:
	confirm_action = action
	confirmation.dialog_text = prompt
	confirmation.ok_button_text = action_name
	confirmation.popup_centered()
	confirmation.get_cancel_button().grab_focus()

func _launch() -> void:
	var design := designs[selected_index]
	if design.flight_error == "":
		launch_requested.emit(design.parts)

func _set_status(message: String) -> void:
	status.text = message

func set_admin_status(message: String) -> void:
	if is_instance_valid(ship_admin):
		ship_admin.set_status(message)

func refresh_admin_values(index: int, values: Dictionary, is_active: bool) -> void:
	admin_ships[index].values = values
	if ship_admin.selected_index == index:
		ship_admin.refresh_selection()
	if is_active:
		current_ship_values = values
		if selected_index == 0:
			_select_design(selected_index)

func request_close() -> void:
	closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		request_close()
		get_viewport().set_input_as_handled()

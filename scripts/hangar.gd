extends Control

signal closed
signal launch_requested(parts: Array)

const MODULES := preload("res://scripts/ship_modules.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")
const PIXEL_EDITOR := preload("res://scripts/pixel_ship_editor.gd")
const DECK := Color("101c29")
const INK := Color("e5ebee")
const MUTED := Color("9fb3c0")
const EDGE := Color("3b5060")
const AMBER := Color("efbc7d")

var current_parts: Array = []
var preview_draw: Callable
var library_entries: Variant
var designs: Array[Dictionary] = []
var selected_index := 0
var editing_saved_name := ""
var editor: PIXEL_EDITOR
var body: VBoxContainer
var library_view: HBoxContainer
var editor_view: VBoxContainer
var library_list: ItemList
var preview: Control
var ship_title: Label
var ship_details: Label
var status: Label
var edit_button: Button
var delete_button: Button
var launch_button: Button
var name_field: LineEdit
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
	_create_library_view()
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
	var new_button := _button(sidebar, "New pixel ship", func(): _open_editor({}))
	new_button.tooltip_text = "Start with a blank canvas."

	var bay := VBoxContainer.new()
	bay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bay.add_theme_constant_override("separation", 10)
	library_view.add_child(bay)
	ship_title = _label(bay, "", 28, INK)
	ship_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ship_details = _label(bay, "", 16, MUTED)
	ship_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview = Control.new()
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size.y = 120
	preview.clip_contents = true
	preview.draw.connect(_draw_preview)
	bay.add_child(preview)
	var actions := HBoxContainer.new()
	bay.add_child(actions)
	edit_button = _button(actions, "Edit pixel copy", func(): _open_editor(designs[selected_index]))
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
	selected_index = index
	var design := designs[index]
	var parts: Array = design.parts
	var category: String = design.category
	var dimensions := MODULES.dimensions_meters(parts)
	var stats := MODULES.stats(parts)
	ship_title.text = design.name
	ship_details.text = "%s  •  %d hull\nLength: %.1f m  •  Width: %.1f m" % [category, int(stats.health), dimensions.y, dimensions.x]
	for part in parts:
		if MODULES.CRUISER_TURRET_LAYOUTS.has(part.type):
			ship_details.text += "\n%d twin-barrel machine lasers  •  Weapon slot 3" % MODULES.CRUISER_TURRET_LAYOUTS[part.type].mounts.size()
			break
	var pixel_art := _has_pixel_art(parts)
	if not pixel_art:
		ship_details.text += "\nLegacy modular ship"
		if design.flight_error != "":
			ship_details.text += " · " + design.flight_error
	edit_button.visible = pixel_art
	edit_button.text = "Edit pixel ship" if category == "Saved" and parts[0].type == "pixel_custom" else "Edit pixel copy"
	delete_button.visible = category == "Saved"
	launch_button.disabled = design.flight_error != ""
	launch_button.tooltip_text = design.flight_error
	preview.queue_redraw()

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
	var parts: Array = designs[selected_index].parts
	var bounds := MODULES.bounds(parts)
	var insets := (area.size - Vector2(108, 92)).max(Vector2.ONE)
	var fit := minf(insets.x / bounds.size.x, insets.y / bounds.size.y)
	preview.draw_rect(Rect2(centre - bounds.size * fit * 0.5, bounds.size * fit).grow(13.0), Color("344b59"), false, 1.0)
	preview.draw_polyline(PackedVector2Array([centre + Vector2(-7, -bounds.size.y * fit * 0.5 - 21), centre + Vector2(0, -bounds.size.y * fit * 0.5 - 28), centre + Vector2(7, -bounds.size.y * fit * 0.5 - 21)]), AMBER, 2.0, true)
	preview.draw_set_transform(centre, 0.0, Vector2.ONE * fit)
	if preview_draw.is_valid():
		preview_draw.call(preview, {"parts": parts})
	preview.draw_set_transform(Vector2.ZERO)
	preview.draw_rect(area, EDGE, false, 1.0)

func _open_editor(design: Dictionary) -> void:
	editing_saved_name = ""
	var suggestion := ""
	editor = PIXEL_EDITOR.new()
	if not design.is_empty():
		var part: Dictionary = design.parts[0]
		editor.source = MODULES.preset_texture(part).get_image()
		if part.type != "pixel_custom":
			var world_size := MODULES.preset_draw_rect(part, Vector2.ZERO).size
			var pixel_size := MODULES.CELL / MODULES.SHIP_PIXELS_PER_CELL
			var target := (world_size / pixel_size).round().clamp(Vector2.ONE, Vector2(PIXEL_EDITOR.CANVAS_SIZE))
			editor.source.resize(int(target.x), int(target.y), Image.INTERPOLATE_NEAREST)
		editor.source.convert(Image.FORMAT_RGBA8)
		var origin: Variant = part.get("pixel_origin")
		if origin is Array and origin.size() == 2 and typeof(origin[0]) in [TYPE_INT, TYPE_FLOAT] and typeof(origin[1]) in [TYPE_INT, TYPE_FLOAT]:
			editor.source_origin = Vector2i(int(origin[0]), int(origin[1]))
		if design.category == "Saved" and part.type == "pixel_custom":
			editing_saved_name = design.name
			suggestion = editing_saved_name
		else:
			suggestion = "%s copy" % design.name

	editor_view = VBoxContainer.new()
	editor_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_view.add_theme_constant_override("separation", 12)
	body.add_child(editor_view)
	body.move_child(editor_view, status.get_index())
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 10)
	editor_view.add_child(toolbar)
	_button(toolbar, "Back to library", _request_editor_back)
	name_field = LineEdit.new()
	name_field.max_length = 60
	name_field.text = suggestion
	name_field.placeholder_text = "Ship name"
	name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(name_field)
	_button(toolbar, "Save to library", _save, true)
	var label := _label(editor_view, "Nose points up  •  256 × 256 pixel canvas", 15, MUTED)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_view.add_child(editor)
	library_view.hide()
	_set_status("")

func _save() -> void:
	var ship_name := name_field.text.strip_edges()
	if library_entries == null:
		_set_status("The saved ship library could not be read. Saving is unavailable.")
		return
	if ship_name.is_empty():
		_set_status("Give your ship a name before saving.")
		name_field.grab_focus()
		return
	if ship_name != editing_saved_name:
		for used_name in library_entries.keys() + MODULES.PRESET_NAMES.keys():
			if String(used_name).trim_prefix("Built-in · ").nocasecmp_to(ship_name) == 0:
				_set_status("That name is already in use. Choose another name to save a copy.")
				return
	var parts := editor.to_ship()
	if parts.is_empty():
		_set_status("Draw a hull before saving your ship.")
		return
	var error := MODULES.validate(parts)
	if not error.is_empty():
		_set_status(error)
		return
	var updated: Dictionary = library_entries.duplicate()
	updated[ship_name] = parts
	if not LIBRARY.write(updated):
		_set_status("The ship could not be saved. Your artwork is still open.")
		return
	library_entries = updated
	_close_editor(ship_name)
	_set_status("Saved %s. Select Launch ship to take it out." % ship_name)

func _request_editor_back() -> void:
	if editor.is_dirty():
		_confirm("Discard the unsaved pixel edits?", "Discard edits", _close_editor)
	else:
		_close_editor()

func _close_editor(select_name: String = "") -> void:
	editor_view.hide()
	editor_view.queue_free()
	editor = null
	library_view.show()
	if not select_name.is_empty():
		_refresh_library(select_name)
	_set_status("")

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

func request_close() -> void:
	if is_instance_valid(editor) and editor.is_dirty():
		_confirm("Return to flight and discard the unsaved pixel edits?", "Discard and return", func(): closed.emit())
	else:
		closed.emit()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(editor):
			_request_editor_back()
		else:
			request_close()
		get_viewport().set_input_as_handled()

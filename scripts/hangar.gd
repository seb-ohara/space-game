extends Control
## Hosts the editor directly. The library contains player-created designs only.

signal closed
signal launch_requested(parts: Array)

const BINDINGS := preload("res://scripts/key_bindings.gd")

const MODULES := preload("res://scripts/ship_modules.gd")
const RANDOMIZER := preload("res://scripts/ship_randomizer.gd")
const BUILDER := preload("res://scripts/ship_builder.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")
const MENU_STYLE := preload("res://scripts/fleet_order_panel.gd")

var current_parts: Array = []
var library_read_only := false
var performance_profile: Callable
var speed_unit := 1.0
var close_caption := "Return to flight"
var builder: BUILDER
var library_panel: PanelContainer
var library_list: ItemList
var library_status: Label
var preview: Control
var preview_name: Label
var preview_dimensions: Label
var preview_readiness: Label
var library_designs: Array[Dictionary] = []
var confirmation: ConfirmationDialog
var confirm_action: Callable
var open_button: Button
var delete_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_library()
	_open_builder(current_parts if is_editable_design(current_parts) else [])

static func is_editable_design(parts: Array) -> bool:
	return not parts.is_empty() and parts.all(func(part: Dictionary) -> bool:
		return not MODULES.PRESET_TEXTURES.has(part.type)
	)

func _open_builder(parts: Array, design_name := "") -> void:
	if is_instance_valid(builder):
		builder.hide()
		builder.set_process_input(false)
		builder.queue_free()
	builder = BUILDER.new()
	builder.initial_parts = parts
	builder.saved_design_name = design_name
	builder.library_read_only = library_read_only
	builder.performance_profile = performance_profile
	builder.speed_unit = speed_unit
	builder.close_caption = close_caption
	builder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	builder.closed.connect(func(): closed.emit())
	builder.deploy.connect(func(design: Array): launch_requested.emit(design))
	builder.library_requested.connect(_show_library)
	add_child(builder)
	library_panel.hide()

func _create_library() -> void:
	library_panel = PanelContainer.new()
	library_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	library_panel.theme = MENU_STYLE.make_theme()
	library_panel.add_theme_stylebox_override("panel", MENU_STYLE.surface(Color("08111e"), Color.TRANSPARENT, 0, 32, 24))
	add_child(library_panel)
	var center := CenterContainer.new()
	library_panel.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(850, 490)
	card.add_theme_stylebox_override("panel", MENU_STYLE.surface(Color("101c24"), MENU_STYLE.EDGE, 8, 20, 16))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	MENU_STYLE.label(titles, "SHIP BUILDER", 11, MENU_STYLE.ACCENT)
	MENU_STYLE.label(titles, "Ship library", 25, MENU_STYLE.INK)
	_add_button(header, "Back to editor", _resume_editing)
	column.add_child(HSeparator.new())
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	var saved := VBoxContainer.new()
	saved.custom_minimum_size.x = 260
	saved.add_theme_constant_override("separation", 8)
	columns.add_child(saved)
	MENU_STYLE.label(saved, "Saved designs", 14, MENU_STYLE.MUTED)
	library_list = ItemList.new()
	library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	library_list.item_selected.connect(func(_index: int): _update_library_buttons())
	library_list.item_activated.connect(func(_index: int): _open_selected())
	saved.add_child(library_list)
	var inspector := PanelContainer.new()
	inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspector.add_theme_stylebox_override("panel", MENU_STYLE.surface(Color("14232c"), MENU_STYLE.EDGE, 8, 16, 13))
	columns.add_child(inspector)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 7)
	inspector.add_child(details)
	preview_name = MENU_STYLE.label(details, "", 20, MENU_STYLE.INK)
	preview_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_dimensions = MENU_STYLE.label(details, "", 13, MENU_STYLE.MUTED)
	preview = Control.new()
	preview.custom_minimum_size.y = 180
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	preview.clip_contents = true
	preview.draw.connect(_draw_library_preview)
	details.add_child(preview)
	preview_readiness = MENU_STYLE.label(details, "", 13, MENU_STYLE.MUTED)
	preview_readiness.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	library_status = MENU_STYLE.label(column, "", 13, MENU_STYLE.MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	_add_button(actions, "New blank design", func(): _request_open([]))
	delete_button = _add_button(actions, "Delete design", _delete_selected)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	open_button = _add_button(actions, "Open in editor", _open_selected)
	open_button.theme_type_variation = &"FleetPrimary"
	confirmation = ConfirmationDialog.new()
	confirmation.theme = library_panel.theme
	confirmation.confirmed.connect(func():
		if confirm_action.is_valid():
			confirm_action.call()
	)
	add_child(confirmation)
	library_panel.hide()

func _add_button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _show_library() -> void:
	builder.hide()
	builder.set_process_input(false)
	library_panel.show()
	_refresh_library()

func _refresh_library() -> void:
	library_designs.clear()
	library_list.clear()
	var entries: Variant = LIBRARY.read()
	if entries is Dictionary:
		var names: Array = entries.keys()
		names.sort()
		for design_name in names:
			var parts := LIBRARY.restore_design(entries[design_name])
			if is_editable_design(parts):
				library_designs.append({"name": design_name, "parts": parts})
				library_list.add_item(design_name)
	library_status.text = "Could not read the ship library." if entries == null else ("%d saved designs" % library_designs.size())
	if not library_designs.is_empty():
		library_list.select(0)
	_update_library_buttons()

func _selected_design() -> Dictionary:
	var selected := library_list.get_selected_items()
	return {} if selected.is_empty() else library_designs[selected[0]]

func _update_library_buttons() -> void:
	var design := _selected_design()
	var selected := not design.is_empty()
	open_button.disabled = not selected
	delete_button.disabled = library_read_only or not selected
	preview_name.text = design.name if selected else "No saved designs yet"
	if selected:
		var dimensions := MODULES.design_dimensions_meters(design.parts)
		preview_dimensions.text = "%s  •  %.1f m long × %.1f m wide  •  %d parts" % [RANDOMIZER.class_for_length(dimensions.y), dimensions.y, dimensions.x, design.parts.size()]
		var issue := MODULES.validate(design.parts)
		preview_readiness.text = "Flight-ready" if issue.is_empty() else "Draft  •  " + issue
		preview_readiness.add_theme_color_override("font_color", MENU_STYLE.ACCENT if issue.is_empty() else MENU_STYLE.MUTED)
	else:
		preview_dimensions.text = "Save a build from the editor to see it here."
		preview_readiness.text = ""
	preview.queue_redraw()

func _draw_library_preview() -> void:
	var design := _selected_design()
	if design.is_empty():
		return
	var parts: Array = design.parts
	var bounds := MODULES.bounds(parts)
	var center := bounds.get_center()
	var available := (preview.size - Vector2(28, 28)).max(Vector2.ONE)
	var scale_factor := minf(available.x / maxf(bounds.size.x, 1.0), available.y / maxf(bounds.size.y, 1.0))
	var glass := MODULES.window_render_context(parts)
	for part: Dictionary in parts:
		if not MODULES.is_interior(part) and not MODULES.is_decoration(part):
			MODULES.draw_part(preview, part, preview.size * 0.5 + (MODULES.part_position(part) - center) * scale_factor, scale_factor, 1.0, Color.WHITE, 1.0, false, glass)
	for part: Dictionary in parts:
		if MODULES.is_decoration(part):
			MODULES.draw_part(preview, part, preview.size * 0.5 + (MODULES.part_position(part) - center) * scale_factor, scale_factor)
	for part: Dictionary in parts:
		if part.has("turret"):
			MODULES.draw_mounted_turret(preview, part.turret, preview.size * 0.5 + (MODULES.mount_position(part) - center) * scale_factor, scale_factor)

func _resume_editing() -> void:
	library_panel.hide()
	builder.show()
	builder.set_process_input(true)

func _open_selected() -> void:
	var design := _selected_design()
	if not design.is_empty():
		_request_open(design.parts, design.name)

func _request_open(parts: Array, design_name := "") -> void:
	if builder.parts != builder.saved_parts:
		_confirm("Discard the unsaved changes to this design?", "Discard and open", _open_builder.bind(parts, design_name))
	else:
		_open_builder(parts, design_name)

func _delete_selected() -> void:
	var selected := library_list.get_selected_items()
	if selected.is_empty():
		return
	var design_name: String = library_designs[selected[0]].name
	_confirm("Delete the saved design “%s”?" % design_name, "Delete design", func():
		var entries: Variant = LIBRARY.read()
		if entries is Dictionary and entries.erase(design_name) and LIBRARY.write(entries):
			_refresh_library()
		else:
			library_status.text = "Could not delete this design."
	)

func _confirm(message: String, caption: String, action: Callable) -> void:
	confirm_action = action
	confirmation.dialog_text = message
	confirmation.ok_button_text = caption
	confirmation.popup_centered()
	confirmation.get_cancel_button().grab_focus()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and BINDINGS.pressed(event, "game_back") and BINDINGS.shortcut_allowed(event, get_viewport()):
		if library_panel.visible:
			_resume_editing()
		else:
			builder.request_close()
		get_viewport().set_input_as_handled()

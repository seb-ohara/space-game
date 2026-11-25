extends Control
## Hosts the editor directly. The library contains player-created designs only.

signal closed
signal launch_requested(parts: Array)

const MODULES := preload("res://scripts/ship_modules.gd")
const BUILDER := preload("res://scripts/ship_builder.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")

var current_parts: Array = []
var performance_profile: Callable
var speed_unit := 1.0
var close_caption := "Return to flight"
var builder: BUILDER
var library_panel: PanelContainer
var library_list: ItemList
var library_status: Label
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

func _open_builder(parts: Array) -> void:
	if is_instance_valid(builder):
		builder.hide()
		builder.set_process_input(false)
		builder.queue_free()
	builder = BUILDER.new()
	builder.initial_parts = parts
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
	var style := StyleBoxFlat.new()
	style.bg_color = Color("08111e")
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	library_panel.add_theme_stylebox_override("panel", style)
	add_child(library_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	library_panel.add_child(column)
	var title := Label.new()
	title.text = "Saved ship designs"
	title.add_theme_font_size_override("font_size", 28)
	column.add_child(title)
	library_list = ItemList.new()
	library_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library_list.item_selected.connect(func(_index: int): _update_library_buttons())
	library_list.item_activated.connect(func(_index: int): _open_selected())
	column.add_child(library_list)
	library_status = Label.new()
	column.add_child(library_status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	_add_button(actions, "Back to editor", _resume_editing)
	_add_button(actions, "New blank design", func(): _request_open([]))
	open_button = _add_button(actions, "Open design", _open_selected)
	delete_button = _add_button(actions, "Delete design", _delete_selected)
	confirmation = ConfirmationDialog.new()
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
	library_status.text = "Could not read the ship library." if entries == null else ("No saved modular designs yet." if library_designs.is_empty() else "")
	_update_library_buttons()

func _update_library_buttons() -> void:
	var selected := not library_list.get_selected_items().is_empty()
	open_button.disabled = not selected
	delete_button.disabled = not selected

func _resume_editing() -> void:
	library_panel.hide()
	builder.show()
	builder.set_process_input(true)

func _open_selected() -> void:
	var selected := library_list.get_selected_items()
	if not selected.is_empty():
		_request_open(library_designs[selected[0]].parts)

func _request_open(parts: Array) -> void:
	if builder.parts != builder.saved_parts:
		_confirm("Discard the unsaved changes to this design?", "Discard and open", _open_builder.bind(parts))
	else:
		_open_builder(parts)

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

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if library_panel.visible:
			_resume_editing()
		else:
			builder.request_close()
		get_viewport().set_input_as_handled()

extends VBoxContainer

signal save_requested(index: int, values: Dictionary)
signal save_version_requested(index: int, version_name: String, values: Dictionary)
signal apply_version_requested(index: int, version_name: String, discard_edits: bool)
signal default_version_requested(index: int, version_name: String, enabled: bool)
signal slots_changed
signal add_hardpoint_requested

const MODULES := preload("res://scripts/ship_modules.gd")
const LOADOUT := preload("res://scripts/ship_loadout.gd")
const PALETTE_BUTTON := preload("res://scripts/module_palette_button.gd")
const VERSION_NAME_LIMIT := 48
const VERSION_DESCRIPTION := "Name this setup. It will be applied to this ship and saved for all ships of this type."

var ships: Array = []
var selected_index := 0
var fields := {}
var selector: OptionButton
var version_selector: OptionButton
var apply_version_button: Button
var default_version_button: Button
var version_dialog: ConfirmationDialog
var version_name_input: LineEdit
var status: Label
var modules_label: Label
var width_ratio := 1.0
var displayed_values: Dictionary = {}
var slot_count: SpinBox
var add_hardpoint_button: Button
var slot_rows: VBoxContainer
var slot_controls: Array = []
var changing_slots := false

const FIELDS := [
	["health", "Hull integrity"],
	["shield", "Shield capacity"],
	["acceleration", "Acceleration (scaled km/s²)"],
	["speed", "Top speed (scaled km/s)"],
	["turn", "Turning speed (degrees/s)"],
	["boost", "Boost speed (scaled km/s)"],
	["hyperdrive", "Hyperdrive top speed (scaled km/s)"],
	["cargo", "Cargo capacity"],
	["passengers", "Passenger capacity (record only)"],
	["hangars", "Hangar bays (record only)"],
]

func _ready() -> void:
	selector = OptionButton.new()
	for ship in ships:
		selector.add_item(ship.name)
	selector.item_selected.connect(_select_ship)
	add_child(selector)
	_create_version_picker()
	add_hardpoint_button = Button.new()
	add_hardpoint_button.text = "+ Add empty hardpoint"
	add_hardpoint_button.disabled = ships.is_empty()
	add_hardpoint_button.pressed.connect(func(): add_hardpoint_requested.emit())
	add_child(add_hardpoint_button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var class_label := Label.new()
	class_label.text = "Class (record only)"
	grid.add_child(class_label)
	var ship_class := LineEdit.new()
	ship_class.max_length = 80
	ship_class.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(ship_class)
	fields["class"] = ship_class
	var length_label := Label.new()
	length_label.text = "Length (m)"
	grid.add_child(length_label)
	var length := SpinBox.new()
	length.min_value = MODULES.MIN_SHIP_LENGTH_METERS
	length.max_value = MODULES.MAX_SHIP_LENGTH_METERS
	length.step = 0.001
	length.custom_minimum_size.x = 150
	length.value_changed.connect(_update_width)
	grid.add_child(length)
	fields["length_meters"] = length
	var width_label := Label.new()
	width_label.text = "Width (m)"
	grid.add_child(width_label)
	fields["width"] = Label.new()
	grid.add_child(fields["width"])
	for field in FIELDS:
		var label := Label.new()
		label.text = field[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var value := SpinBox.new()
		value.min_value = 0.01 if field[0] == "hyperdrive" else 0.0
		value.max_value = 100000000.0
		value.step = 1.0 if field[0] in ["cargo", "passengers", "hangars"] else 0.01
		value.custom_minimum_size.x = 150
		grid.add_child(value)
		fields[field[0]] = value
	var slot_label := Label.new()
	slot_label.text = "Module slots"
	grid.add_child(slot_label)
	slot_count = SpinBox.new()
	slot_count.min_value = 0
	slot_count.max_value = LOADOUT.MAX_SLOTS
	slot_count.step = 1
	grid.add_child(slot_count)
	var palette_label := Label.new()
	palette_label.text = "Drag a module"
	grid.add_child(palette_label)
	var palette := GridContainer.new()
	palette.columns = 2
	grid.add_child(palette)
	for kind in LOADOUT.TYPES:
		if kind == "":
			continue
		var item := PALETTE_BUTTON.new()
		item.module_type = kind
		item.text = "     " + LOADOUT.TYPES[kind]
		palette.add_child(item)
	var positions_label := Label.new()
	positions_label.text = "Hardpoint loadout"
	grid.add_child(positions_label)
	slot_rows = VBoxContainer.new()
	slot_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(slot_rows)
	slot_count.value_changed.connect(_slot_count_changed)
	var note := Label.new()
	note.text = "Drag hardpoint squares to position them. Drop modules onto them or leave them empty. Shift-drag a module to move it; right-click to clear it. Save to apply changes."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	modules_label = Label.new()
	modules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(modules_label)
	var save := MenuButton.new()
	save.text = "Save ship changes ▾"
	save.flat = false
	save.disabled = ships.is_empty()
	var save_menu := save.get_popup()
	save_menu.add_item("Save to current ship", 0)
	save_menu.add_item("Save as new version…", 1)
	save_menu.id_pressed.connect(func(id: int):
		if id == 0:
			_save()
		else:
			_open_version_dialog()
	)
	add_child(save)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	_create_version_dialog()
	if not ships.is_empty():
		_select_ship(0)

func _create_version_picker() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	version_selector = OptionButton.new()
	version_selector.fit_to_longest_item = false
	version_selector.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	version_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_selector.add_item("Saved versions…")
	version_selector.disabled = true
	version_selector.item_selected.connect(func(_index: int): _update_version_actions())
	row.add_child(version_selector)
	apply_version_button = Button.new()
	apply_version_button.text = "Apply version"
	apply_version_button.disabled = true
	apply_version_button.tooltip_text = "Apply the selected version to this ship without changing the saved version."
	apply_version_button.pressed.connect(func():
		var version_name := _selected_version()
		if not version_name.is_empty():
			apply_version_requested.emit(selected_index, version_name, not _changes().is_empty())
	)
	row.add_child(apply_version_button)
	default_version_button = Button.new()
	default_version_button.text = "Set default"
	default_version_button.disabled = true
	default_version_button.pressed.connect(func():
		var version_name := _selected_version()
		if not version_name.is_empty():
			default_version_requested.emit(selected_index, version_name, version_name != _default_version())
	)
	row.add_child(default_version_button)

func _selected_version() -> String:
	return version_selector.get_selected_metadata() if version_selector.selected > 0 else ""

func _update_version_actions() -> void:
	var version_name := _selected_version()
	apply_version_button.disabled = version_name.is_empty()
	default_version_button.disabled = version_name.is_empty()
	var is_default := not version_name.is_empty() and version_name == _default_version()
	default_version_button.text = "Clear default" if is_default else "Set default"
	default_version_button.tooltip_text = "Stop using this version automatically on newly spawned or launched ships." if is_default else "Use this version on newly spawned or launched ships of this type. Existing ships stay unchanged."

func _create_version_dialog() -> void:
	version_dialog = ConfirmationDialog.new()
	version_dialog.title = "Save a new ship version"
	version_dialog.dialog_text = VERSION_DESCRIPTION
	version_dialog.ok_button_text = "Save version"
	version_name_input = LineEdit.new()
	version_name_input.placeholder_text = "e.g. High-speed test"
	version_name_input.max_length = VERSION_NAME_LIMIT
	version_name_input.text_changed.connect(_validate_version_name)
	version_dialog.add_child(version_name_input)
	version_name_input.text_submitted.connect(func(_text: String):
		var ok := version_dialog.get_ok_button()
		if not ok.disabled:
			ok.pressed.emit()
	)
	version_dialog.confirmed.connect(func():
		var version_name := version_name_input.text.strip_edges()
		if _valid_version_name(version_name):
			save_version_requested.emit(selected_index, version_name, _changes())
	)
	add_child(version_dialog)

func _open_version_dialog() -> void:
	version_name_input.clear()
	_validate_version_name("")
	version_dialog.popup_centered()
	version_name_input.grab_focus()

func _version_entry() -> Dictionary:
	return ships[selected_index].get("version_entry", {}) if not ships.is_empty() else {}

func _versions() -> Dictionary:
	return _version_entry().get("versions", {})

func _default_version() -> String:
	return _version_entry().get("default", "")

func _valid_version_name(version_name: String) -> bool:
	if version_name.is_empty():
		return false
	for existing_name: String in _versions():
		if existing_name.nocasecmp_to(version_name) == 0:
			return false
	return true

func _validate_version_name(text: String) -> void:
	var version_name := text.strip_edges()
	var valid := _valid_version_name(version_name)
	version_dialog.get_ok_button().disabled = not valid
	version_dialog.dialog_text = "That version name is already in use. Choose a different name." if not version_name.is_empty() and not valid else VERSION_DESCRIPTION

func refresh_version_picker(selected_version: String) -> void:
	version_selector.clear()
	version_selector.add_item("Saved versions…")
	var names := _versions().keys()
	names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	var default_name := _default_version()
	var target := default_name if selected_version.is_empty() else selected_version
	var pick := 0
	for version_name: String in names:
		var item := version_selector.item_count
		if version_name == target:
			pick = item
		version_selector.add_item(version_name + " · Default" if version_name == default_name else version_name)
		version_selector.set_item_metadata(item, version_name)
	version_selector.select(pick)
	version_selector.disabled = names.is_empty()
	_update_version_actions()

func _select_ship(index: int) -> void:
	selected_index = index
	refresh_selection()
	slots_changed.emit()
	status.text = ""

func refresh_selection(selected_version: String = "") -> void:
	var ship: Dictionary = ships[selected_index]
	var values: Dictionary = ship.values
	refresh_version_picker(selected_version)
	modules_label.text = "Hull components: " + ", ".join(ship.get("modules", []))
	var saved_slots := LOADOUT.slots(values)
	_set_slots(saved_slots)
	fields["class"].text = values.get("class", "")
	var length := float(values.length_meters)
	width_ratio = float(values.width) / length
	_set_number(fields["length_meters"], length)
	_update_width(fields["length_meters"].value)
	for field in FIELDS:
		_set_number(fields[field[0]], float(values.get(field[0], 0.0)))
	displayed_values = _field_values()

func _slot_count_changed(value: float) -> void:
	if changing_slots:
		return
	_rebuild_slots(LOADOUT.resize_slots(_slot_values(), int(value)))
	slots_changed.emit()

func _set_slots(slots: Array) -> void:
	changing_slots = true
	_set_number(slot_count, slots.size())
	_rebuild_slots(slots)
	changing_slots = false

func _rebuild_slots(slots: Array) -> void:
	add_hardpoint_button.disabled = ships.is_empty() or slots.size() >= LOADOUT.MAX_SLOTS
	for child in slot_rows.get_children():
		slot_rows.remove_child(child)
		child.queue_free()
	slot_controls.clear()
	for index in slots.size():
		var slot: Dictionary = slots[index]
		var row := HBoxContainer.new()
		slot_rows.add_child(row)
		var label := Label.new()
		label.text = "%d · %s" % [index + 1, LOADOUT.TYPES[slot.type]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove := Button.new()
		remove.text = "Remove hardpoint"
		remove.tooltip_text = "Remove this hardpoint and its fitted module"
		remove.pressed.connect(func(): _remove_slot(index))
		row.add_child(remove)
		slot_controls.append({"label": label, "type": slot.type, "x": float(slot.x), "y": float(slot.y)})

func _remove_slot(index: int) -> void:
	var slots := _slot_values()
	if index < 0 or index >= slots.size():
		return
	slots.remove_at(index)
	_set_slots(slots)
	slots_changed.emit()

func add_empty_hardpoint(position: Vector2) -> void:
	var slots := _slot_values()
	if ships.is_empty() or slots.size() >= LOADOUT.MAX_SLOTS:
		return
	slots.append({"type": "", "x": clampf(position.x, 0.0, 1.0), "y": clampf(position.y, 0.0, 1.0)})
	_set_slots(slots)
	slots_changed.emit()

func set_slot_type(index: int, kind: String) -> void:
	if index < 0 or index >= slot_controls.size() or not LOADOUT.TYPES.has(kind):
		return
	slot_controls[index].type = kind
	slot_controls[index].label.text = "%d · %s" % [index + 1, LOADOUT.TYPES[kind]]
	slots_changed.emit()

func place_slot(index: int, position: Vector2) -> void:
	if index < 0 or index >= slot_controls.size():
		return
	slot_controls[index].x = clampf(position.x, 0.0, 1.0)
	slot_controls[index].y = clampf(position.y, 0.0, 1.0)
	slots_changed.emit()

func _slot_values() -> Array:
	var result: Array = []
	for row in slot_controls:
		result.append({"type": row.type, "x": row.x, "y": row.y})
	return result

func _set_number(field: SpinBox, value: float) -> void:
	field.value = value
	field.get_line_edit().text = str(field.value)

func _update_width(length: float) -> void:
	fields["width"].text = "%.2f" % (length * width_ratio)

func _field_values() -> Dictionary:
	var values := {"class": fields["class"].text.strip_edges(), "module_slots": _slot_values()}
	values.length_meters = fields["length_meters"].value
	for field in FIELDS:
		values[field[0]] = fields[field[0]].value
	return values

func _save() -> void:
	if not ships.is_empty():
		save_requested.emit(selected_index, _changes())

func _changes() -> Dictionary:
	fields["length_meters"].apply()
	slot_count.apply()
	for field in FIELDS:
		fields[field[0]].apply()
	var values := _field_values()
	var changes := {}
	for field in values:
		if values[field] != displayed_values.get(field):
			changes[field] = values[field]
	return changes

func set_status(message: String) -> void:
	status.text = message

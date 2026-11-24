extends VBoxContainer

signal save_requested(index: int, values: Dictionary)
signal slots_changed

const MODULES := preload("res://scripts/ship_modules.gd")
const LOADOUT := preload("res://scripts/ship_loadout.gd")
const PALETTE_BUTTON := preload("res://scripts/module_palette_button.gd")

var ships: Array = []
var selected_index := 0
var fields := {}
var selector: OptionButton
var status: Label
var modules_label: Label
var width_ratio := 1.0
var displayed_values: Dictionary = {}
var slot_count: SpinBox
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
	var count_row := HBoxContainer.new()
	count_row.add_child(slot_count)
	var add_slot := Button.new()
	add_slot.text = "+ Hardpoint"
	add_slot.pressed.connect(func(): slot_count.value = minf(slot_count.value + 1, LOADOUT.MAX_SLOTS))
	count_row.add_child(add_slot)
	grid.add_child(count_row)
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
	note.text = "Select Current ship in the library. Drag squares to position hardpoints and drag modules onto them. Shift-drag a fitted module to move it; right-click a square to remove its module. Save to apply changes."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	modules_label = Label.new()
	modules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(modules_label)
	var save := Button.new()
	save.text = "Save ship changes"
	save.pressed.connect(_save)
	add_child(save)
	status = Label.new()
	add_child(status)
	if not ships.is_empty():
		_select_ship(0)

func _select_ship(index: int) -> void:
	selected_index = index
	refresh_selection()
	slots_changed.emit()
	status.text = ""

func refresh_selection() -> void:
	var ship: Dictionary = ships[selected_index]
	var values: Dictionary = ship.values
	modules_label.text = "Hull components: " + ", ".join(ship.get("modules", []))
	var saved_slots := LOADOUT.slots(values)
	changing_slots = true
	slot_count.value = saved_slots.size()
	_rebuild_slots(saved_slots)
	changing_slots = false
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

func _rebuild_slots(slots: Array) -> void:
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
	changing_slots = true
	slot_count.value = slots.size()
	_rebuild_slots(slots)
	changing_slots = false
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
	if ships.is_empty():
		return
	fields["length_meters"].apply()
	slot_count.apply()
	for field in FIELDS:
		fields[field[0]].apply()
	var values := _field_values()
	var changes := {}
	for field in values:
		if values[field] != displayed_values.get(field):
			changes[field] = values[field]
	save_requested.emit(selected_index, changes)

func set_status(message: String) -> void:
	status.text = message

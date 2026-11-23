extends VBoxContainer

signal save_requested(index: int, values: Dictionary)

var ships: Array = []
var selected_index := 0
var fields := {}
var selector: OptionButton
var status: Label
var modules_label: Label

const FIELDS := [
	["length", "Length (m, record only)"],
	["width", "Width (m, record only)"],
	["health", "Hull integrity"],
	["shield", "Shield capacity"],
	["acceleration", "Acceleration (scaled km/s²)"],
	["speed", "Top speed (scaled km/s)"],
	["turn", "Turning speed (degrees/s)"],
	["boost", "Boost speed (scaled km/s)"],
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
	for field in FIELDS:
		var label := Label.new()
		label.text = field[1]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var value := SpinBox.new()
		value.min_value = 0.0
		value.max_value = 100000000.0
		value.step = 1.0 if field[0] in ["cargo", "passengers", "hangars"] else 0.01
		value.custom_minimum_size.x = 150
		grid.add_child(value)
		fields[field[0]] = value
	var note := Label.new()
	note.text = "Modules and physical dimensions follow the ship design. Edit the design in the Hangar."
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
	var values: Dictionary = ships[index].values
	modules_label.text = "Modules (design): " + ", ".join(ships[index].get("modules", []))
	fields["class"].text = values.get("class", "")
	for field in FIELDS:
		fields[field[0]].value = float(values.get(field[0], 0.0))
	status.text = ""

func _save() -> void:
	var values := {"class": fields["class"].text.strip_edges()}
	for field in FIELDS:
		fields[field[0]].get_line_edit().release_focus()
		values[field[0]] = fields[field[0]].value
	save_requested.emit(selected_index, values)

func set_status(message: String) -> void:
	status.text = message

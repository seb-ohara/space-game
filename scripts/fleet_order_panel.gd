extends VBoxContainer

signal submitted(type: String, parameter: float, repeat: bool, append: bool)
signal cancel_requested

const ORDER := preload("res://scripts/ships/ship_order.gd")
var systems: Array = []
var type_select: OptionButton
var system_select: OptionButton
var quantity: SpinBox
var repeat_check: CheckBox
var replace_button: Button
var queue_button: Button
var hint: Label

func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	type_select = OptionButton.new()
	for type: String in ORDER.TYPES:
		type_select.add_item(type.capitalize())
	row.add_child(type_select)
	system_select = OptionButton.new()
	system_select.custom_minimum_size.x = 190.0
	system_select.clip_text = true
	for system: Dictionary in systems:
		system_select.add_item(system.name)
	row.add_child(system_select)
	quantity = SpinBox.new()
	quantity.min_value = 1.0
	quantity.max_value = 86400.0
	quantity.value = 10.0
	row.add_child(quantity)
	repeat_check = CheckBox.new()
	repeat_check.text = "Repeat"
	row.add_child(repeat_check)

	var actions := HBoxContainer.new()
	add_child(actions)
	replace_button = Button.new()
	replace_button.text = "Replace orders"
	replace_button.pressed.connect(_submit.bind(false))
	actions.add_child(replace_button)
	queue_button = Button.new()
	queue_button.text = "Queue order"
	queue_button.pressed.connect(_submit.bind(true))
	actions.add_child(queue_button)
	var cancel_button := Button.new()
	cancel_button.text = "Cancel all orders"
	cancel_button.pressed.connect(func(): cancel_requested.emit())
	actions.add_child(cancel_button)
	hint = Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	type_select.item_selected.connect(func(_index: int): _update_options())
	repeat_check.toggled.connect(func(_enabled: bool): _update_options())
	type_select.select(1)
	_update_options()

func _update_options() -> void:
	var type: String = ORDER.TYPES[type_select.selected]
	var picking := type in ["move", "mine"]
	replace_button.text = "Pick target & replace" if picking else "Replace orders"
	queue_button.text = "Pick target & queue" if picking else "Queue order"
	system_select.visible = type == "hyperjump"
	repeat_check.visible = type in ["mine", "wait"]
	quantity.visible = (type == "mine" and not repeat_check.button_pressed) or type == "wait"
	quantity.suffix = " sec" if type == "wait" else " iron"
	match type:
		"move": hint.text = "Pick a destination in flight. Shift + right-click also queues RTS moves."
		"mine": hint.text = "Pick a visible asteroid. Repeat mines it until the cargo hold is full or the rock is exhausted."
		"hyperjump": hint.text = "Choose the destination system. The ship will travel there physically."
		"wait": hint.text = "Brake and wait for the selected number of simulated seconds."
		_: hint.text = "Brake and hold position. No other activity starts unless it was queued."

func _submit(append: bool) -> void:
	var type: String = ORDER.TYPES[type_select.selected]
	var parameter := float(system_select.selected) if type == "hyperjump" else quantity.value
	submitted.emit(type, parameter, repeat_check.visible and repeat_check.button_pressed, append)

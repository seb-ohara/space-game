extends VBoxContainer

signal submitted(type: String, parameter: float, repeat: bool, append: bool)
signal cancel_requested

const ORDER := preload("res://scripts/ships/ship_order.gd")
const INK := Color("e6f0f5")
const MUTED := Color("9aafbd")
const ACCENT := Color("9ce9dc")
const EDGE := Color("30444f")
const ORDER_TYPES := ["mine", "move", "hyperjump", "wait", "stop", "idle"]
const ORDER_LABELS := ["Mine asteroids", "Move to point", "Hyperjump", "Wait", "Stop ship", "Idle"]

var systems: Array = []
var type_select: OptionButton
var system_select: OptionButton
var quantity: SpinBox
var repeat_check: CheckBox
var replace_button: Button
var queue_button: Button
var clear_button: Button
var hint: Label
var ship_title: Label
var cargo_label: Label
var cargo_bar: ProgressBar
var current_order: Label
var current_detail: Label
var queue_label: RichTextLabel
var outcome: Label
var action_hint: Label

func _ready() -> void:
	add_theme_constant_override("separation", 14)
	ship_title = label(self, "Orders", 24, INK)
	ship_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cargo := _column(self, 5)
	cargo_label = label(cargo, "", 13, MUTED)
	cargo_bar = ProgressBar.new()
	cargo_bar.show_percentage = false
	cargo_bar.custom_minimum_size.y = 5
	cargo_bar.add_theme_stylebox_override("background", surface(Color("1e313c"), Color.TRANSPARENT, 3, 0, 0))
	cargo_bar.add_theme_stylebox_override("fill", surface(Color("4da797"), Color.TRANSPARENT, 3, 0, 0))
	cargo.add_child(cargo_bar)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", surface(Color("14232c"), EDGE, 8, 14, 10))
	add_child(card)
	var summary := _column(card, 6)
	label(summary, "CURRENT ORDER", 12, ACCENT)
	current_order = label(summary, "No active orders", 17, INK)
	current_detail = label(summary, "", 13, MUTED)
	current_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	queue_label = RichTextLabel.new()
	queue_label.add_theme_font_size_override("normal_font_size", 13)
	queue_label.add_theme_color_override("default_color", MUTED)
	queue_label.custom_minimum_size.y = 46
	queue_label.mouse_filter = Control.MOUSE_FILTER_STOP
	queue_label.hide()
	summary.add_child(queue_label)
	outcome = label(summary, "", 13, MUTED)
	outcome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var form := _column(self, 7)
	label(form, "NEW ORDER", 12, ACCENT)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	form.add_child(row)
	type_select = OptionButton.new()
	type_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text: String in ORDER_LABELS:
		type_select.add_item(text)
	row.add_child(type_select)
	system_select = OptionButton.new()
	system_select.custom_minimum_size.x = 170.0
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
	form.add_child(repeat_check)
	hint = label(form, "", 13, MUTED)
	hint.custom_minimum_size.y = 36
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	add_child(actions)
	replace_button = Button.new()
	replace_button.theme_type_variation = "FleetPrimary"
	replace_button.pressed.connect(_submit.bind(false))
	actions.add_child(replace_button)
	queue_button = Button.new()
	queue_button.pressed.connect(_submit.bind(true))
	actions.add_child(queue_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	clear_button = Button.new()
	clear_button.text = "Clear orders"
	clear_button.tooltip_text = "Cancel the current order and clear the queue."
	clear_button.pressed.connect(func(): cancel_requested.emit())
	actions.add_child(clear_button)
	action_hint = label(self, "Start replaces current orders. Queue runs after them.", 12, MUTED)
	action_hint.hide()
	type_select.item_selected.connect(func(index: int):
		repeat_check.set_pressed_no_signal(ORDER_TYPES[index] == "mine")
		_update_options()
	)
	repeat_check.toggled.connect(func(_enabled: bool): _update_options())
	type_select.select(0)
	repeat_check.set_pressed_no_signal(true)
	_update_options()

func show_ship(ship: Dictionary, cargo: Dictionary, capacity: int) -> void:
	ship_title.text = ship.name
	ship_title.tooltip_text = ship.name
	var freight := int(cargo.get("contracts", 0))
	var held := int(cargo.iron) + int(cargo.tritium) + freight
	cargo_label.text = "CARGO   %d / %d   ·   %d iron  ·  %d tritium" % [held, capacity, cargo.iron, cargo.tritium] if capacity > 0 else "NO CARGO HOLD"
	if freight > 0:
		cargo_label.text += "  ·  %d freight" % freight
	cargo_bar.visible = capacity > 0
	cargo_bar.max_value = maxi(capacity, 1)
	cargo_bar.value = held
	var orders: Array = ship.orders
	var has_current_order := not orders.is_empty()
	if has_current_order:
		var order: Dictionary = orders[0]
		current_order.text = _caption(order)
		current_detail.text = ORDER.activity(order)
		if order.type == "mine":
			current_detail.text += "  ·  %d iron collected" % int(order.progress.get("mined", 0))
	else:
		current_order.text = "No active orders"
		current_detail.text = "Choose an order below to get started."
	var lines := PackedStringArray()
	for i in range(1, orders.size()):
		lines.append("%d.  %s" % [i, _caption(orders[i])])
	var queue_text := "UP NEXT\n" + "\n".join(lines) if not lines.is_empty() else ""
	if queue_label.text != queue_text:
		queue_label.text = queue_text
	queue_label.visible = not lines.is_empty()
	var report: Dictionary = ship.last_order
	outcome.visible = not report.is_empty()
	if outcome.visible:
		outcome.text = "LAST RESULT   %s" % report.reason
	action_hint.visible = has_current_order
	clear_button.disabled = not has_current_order
	queue_button.disabled = not has_current_order
	queue_button.tooltip_text = "Runs after all existing orders." if has_current_order else "Start an order before adding one to the queue."
	replace_button.tooltip_text = "Replaces the current order and clears the queue." if has_current_order else "Starts the selected order."

func _caption(order: Dictionary) -> String:
	if order.type == "hyperjump" and order.parameters.system < systems.size():
		return "Hyperjump to %s" % systems[order.parameters.system].name
	return ORDER.caption(order)

func _update_options() -> void:
	var type: String = ORDER_TYPES[type_select.selected]
	var picking := type == "move"
	replace_button.text = "Pick & start" if picking else "Start now"
	queue_button.text = "Pick & queue" if picking else "Add to queue"
	system_select.visible = type == "hyperjump"
	repeat_check.visible = type in ["mine", "wait"]
	repeat_check.text = "Until cargo hold is full" if type == "mine" else "Repeat wait"
	quantity.visible = (type == "mine" and not repeat_check.button_pressed) or type == "wait"
	quantity.suffix = " sec" if type == "wait" else " iron"
	match type:
		"mine": hint.text = "Finds asteroids in the ship’s system when this order starts, then moves on as each rock runs out."
		"move": hint.text = "Pick a destination in flight."
		"hyperjump": hint.text = "Travel to the selected system."
		"wait": hint.text = "Hold position for the selected time. A repeating wait blocks the queue until cleared."
		_: hint.text = "Brake and hold position."

func _submit(append: bool) -> void:
	var type: String = ORDER_TYPES[type_select.selected]
	var parameter := float(system_select.selected) if type == "hyperjump" else quantity.value
	submitted.emit(type, parameter, repeat_check.visible and repeat_check.button_pressed, append)

static func _column(parent: Control, gap: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", gap)
	parent.add_child(column)
	return column

static func label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result

static func surface(fill: Color, border: Color, radius: int, x: int, y: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(0 if border == Color.TRANSPARENT else 1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = x
	style.content_margin_right = x
	style.content_margin_top = y
	style.content_margin_bottom = y
	return style

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_stylebox("panel", "AcceptDialog", surface(Color("101c24"), EDGE, 8, 18, 14))
	for control in ["Button", "OptionButton", "CheckBox"]:
		result.set_color("font_color", control, INK)
		result.set_color("font_hover_color", control, Color.WHITE)
		result.set_color("font_disabled_color", control, Color("718390"))
		result.set_stylebox("focus", control, surface(Color.TRANSPARENT, ACCENT, 6, 0, 0))
	for control in ["Button", "OptionButton"]:
		result.set_stylebox("normal", control, surface(Color("192b36"), EDGE, 6, 12, 7))
		result.set_stylebox("hover", control, surface(Color("253d4a"), Color("517581"), 6, 12, 7))
		result.set_stylebox("pressed", control, surface(Color("263f4b"), ACCENT, 6, 12, 7))
		result.set_stylebox("disabled", control, surface(Color("14232c"), EDGE, 6, 12, 7))
	result.set_type_variation("FleetPrimary", "Button")
	result.set_stylebox("normal", "FleetPrimary", surface(Color("245752"), Color("458f82"), 6, 12, 7))
	result.set_stylebox("hover", "FleetPrimary", surface(Color("326e66"), ACCENT, 6, 12, 7))
	result.set_stylebox("panel", "ItemList", surface(Color("14232c"), EDGE, 8, 7, 6))
	for state in ["selected", "selected_focus"]:
		result.set_stylebox(state, "ItemList", surface(Color("234640"), Color.TRANSPARENT, 5, 0, 0))
	result.set_color("font_color", "ItemList", INK)
	result.set_color("font_selected_color", "ItemList", ACCENT)
	result.set_constant("v_separation", "ItemList", 9)
	return result

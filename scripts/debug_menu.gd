extends Window
## Flight test controls; configuration rows are built from the tuning schema.

const BINDINGS := preload("res://scripts/key_bindings.gd")

const STYLE := preload("res://scripts/fleet_order_panel.gd")
const TUNING := preload("res://scripts/debug_tuning.gd")
const MODULES := preload("res://scripts/ship_modules.gd")

var game
var tabs: TabContainer
var telemetry: Label
var block_picker: OptionButton
var block_fields: VBoxContainer
var confirm: ConfirmationDialog
var on_confirm: Callable
var spacing: SpinBox
var factor_fields := {}
var enemy_picker: OptionButton
var enemy_designs: Array[Dictionary] = []
var wave_toggle: CheckButton

func _ready() -> void:
	title = "Debug · Test Flight"
	transient = true
	exclusive = true
	theme = STYLE.make_theme()
	close_requested.connect(hide)
	window_input.connect(func(event: InputEvent):
		if (BINDINGS.pressed(event, "game_back") or BINDINGS.pressed(event, "flight_debug")) and BINDINGS.shortcut_allowed(event, self) and not confirm.visible:
			hide()
			set_input_as_handled()
	)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", STYLE.surface(Color("101c24"), STYLE.EDGE, 0, 18, 16))
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	panel.add_child(body)
	STYLE.label(body, "TEST FLIGHT  /  DEBUG CONTROLS", 12, STYLE.ACCENT)
	_text(body, "You’re in a test copy. Back to test flight resumes the simulation; Return to campaign restores your original flight.")
	telemetry = _text(body, "")
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	_build_flight(_tab("Flight"))
	_build_blocks(_tab("Blocks"))
	_build_world(_tab("World"))
	_build_combat(_tab("Combat"))
	_build_actions(_tab("Actions"))
	var footer := HBoxContainer.new()
	body.add_child(footer)
	_button(footer, "Return to campaign", func():
		_ask("Discard this test flight and resume your original flight?", "Return to campaign", game._exit_debug_flight))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_button(footer, "Back to test flight", hide)
	confirm = ConfirmationDialog.new()
	confirm.theme = theme
	confirm.confirmed.connect(func(): on_confirm.call())
	add_child(confirm)

func open_panel() -> void:
	_refresh_enemy_designs()
	_refresh_telemetry()
	var available := Vector2i(get_parent().get_viewport().get_visible_rect().size)
	popup_centered(Vector2i(mini(660, available.x - 40), mini(610, available.y - 45)))

func _refresh_telemetry() -> void:
	var stats: Dictionary = game._custom_stats()
	telemetry.text = "%s  •  NOW %s  /  AVG (5 SIM S) %s  /  PEAK %s\n" % [game.fleet[game.active_fleet_index].name,
		game._format_speed(game.velocity.length()), game._format_speed(game.debug_tuning.average_speed()), game._format_speed(game.debug_tuning.peak_speed)]
	telemetry.text += "Cruise limit %s  •  Turn %.1f / %.1f°/s  •  Throttle %.0f%%  •  %d parts" % [
		game._format_speed(stats.normal_speed), rad_to_deg(game.angular_velocity), rad_to_deg(stats.turn_rate), game.thrust * 100.0, game.custom_parts.size()]

func _tab(caption: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = caption
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var margin := MarginContainer.new()
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	return column

func _text(parent: Control, text: String) -> Label:
	var label := STYLE.label(parent, text, 14, STYLE.MUTED)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(parent: Control, caption: String, action: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	parent.add_child(button)

func _number(parent: Control, caption: String, value: float, minimum: float, maximum: float, step: float, suffix: String) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := STYLE.label(row, caption, 14, STYLE.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var field := SpinBox.new()
	field.custom_minimum_size.x = 130
	field.min_value = minimum
	field.max_value = maximum
	field.step = step
	field.value = value
	field.suffix = suffix
	row.add_child(field)
	return field

func _factor_rows(parent: Control, specs: Array) -> void:
	for spec in specs:
		var key: String = spec[0]
		var field := _number(parent, spec[1], game.debug_tuning.factor(key), spec[2], spec[3], 0.05, "×")
		factor_fields[key] = field
		field.value_changed.connect(func(value: float):
			if is_equal_approx(value, 1.0):
				game.debug_tuning.factors.erase(key)
			else:
				game.debug_tuning.factors[key] = value
			_apply_tuning()
		)

func _apply_tuning() -> void:
	game._debug_refresh_tuning()
	_refresh_telemetry()

func _build_flight(parent: Control) -> void:
	_text(parent, "Multipliers apply to your fleet after equipment and saved ship overrides. 1× uses normal tuning.")
	_factor_rows(parent, TUNING.FLIGHT)
	parent.add_child(HSeparator.new())
	var speed := _number(parent, "Set forward speed", 0.0, 0.0, 60000.0, 1.0, "km/s")
	speed.tooltip_text = "In the same scaled units as the flight HUD."
	var spin := _number(parent, "Set angular velocity", 0.0, -1800.0, 1800.0, 1.0, "°/s")
	_button(parent, "Inject velocity and cancel current orders", func():
		game._debug_set_velocity(speed.value, spin.value)
		_refresh_telemetry()
	)
	_button(parent, "Reset speed samples", func():
		game.debug_tuning.reset_samples()
		_refresh_telemetry()
	)

func _build_blocks(parent: Control) -> void:
	_text(parent, "Tune a block type across your fleet. Open the Hangar to add or remove blocks and launch the edited ship. Saved per-ship stat overrides still take precedence over equipment totals.")
	block_picker = OptionButton.new()
	parent.add_child(block_picker)
	var kinds: Array = MODULES.TYPES.keys()
	kinds.sort_custom(func(a: String, b: String) -> bool:
		return str(MODULES.TYPES[a].name).naturalnocasecmp_to(str(MODULES.TYPES[b].name)) < 0)
	for kind: String in kinds:
		var info: Dictionary = MODULES.TYPES[kind]
		if TUNING.BLOCK_STATS.any(func(key: String): return float(info.get(key, 0.0)) != 0.0):
			block_picker.add_item(str(info.name))
			block_picker.set_item_metadata(block_picker.item_count - 1, kind)
	block_picker.item_selected.connect(_show_block)
	block_fields = VBoxContainer.new()
	parent.add_child(block_fields)
	_show_block(0)

func _show_block(index: int) -> void:
	for child in block_fields.get_children():
		block_fields.remove_child(child)
		child.queue_free()
	var kind: String = block_picker.get_item_metadata(index)
	var info: Dictionary = MODULES.TYPES[kind]
	for key: String in TUNING.BLOCK_STATS:
		var base := float(info.get(key, 0.0))
		if base == 0.0:
			continue
		var value: float = game.debug_tuning.blocks.get(kind, {}).get(key, 1.0)
		var field := _number(block_fields, "%s (base %s)" % [key.capitalize(), base], value, 0.05, 20.0, 0.05, "×")
		field.value_changed.connect(func(factor: float):
			var values: Dictionary = game.debug_tuning.blocks.get(kind, {})
			if is_equal_approx(factor, 1.0):
				values.erase(key)
			else:
				values[key] = factor
			if values.is_empty():
				game.debug_tuning.blocks.erase(kind)
			else:
				game.debug_tuning.blocks[kind] = values
			_apply_tuning()
		)

func _build_world(parent: Control) -> void:
	_factor_rows(parent, TUNING.WORLD)
	parent.add_child(HSeparator.new())
	_text(parent, "Star-to-star spacing changes actual travel distances, not the size of planets or their orbits. Restart the test to apply spacing.")
	spacing = _number(parent, "Star system spacing", game.debug_spacing, TUNING.MIN_SPACING, TUNING.MAX_SPACING, 0.05, "×")
	_button(parent, "Restart test flight with spacing", func():
		_ask("Restart near Sol with this spacing? Tuning is kept, but test flight progress is discarded.",
			"Restart test flight", func(): game._launch_debug_flight(spacing.value))
	)

func _toggle(parent: Control, caption: String, enabled: bool, action: Callable = Callable()) -> CheckButton:
	var button := CheckButton.new()
	button.text = caption
	button.button_pressed = enabled
	if action.is_valid():
		button.toggled.connect(action)
	parent.add_child(button)
	return button

func _build_combat(parent: Control) -> void:
	_text(parent, "Pick a fleet ship, saved library design, or built-in preset. Spawned ships start hostile and face you. Close the panel to begin combat.")
	enemy_picker = OptionButton.new()
	enemy_picker.fit_to_longest_item = false
	enemy_picker.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(enemy_picker)
	var quantity := _number(parent, "Number of ships", 1, 1, 8, 1, "")
	var distance := _number(parent, "Spawn distance", 600, 100, 12000, 50, "world units")
	var arm_unarmed := _toggle(parent, "Add a laser if the design is unarmed", true)
	var status := _text(parent, "")
	_button(parent, "Spawn hostile ships", func():
		if enemy_picker.selected < 0:
			return
		if game.hyperjump_time >= 0.0:
			status.text = "Wait until the hyperjump finishes before spawning."
			return
		var design: Dictionary = enemy_designs[enemy_picker.selected]
		var requested := int(quantity.value)
		var spawned: int = game._debug_spawn_enemy_design(design, requested, distance.value, arm_unarmed.button_pressed)
		if spawned == requested:
			status.text = "Spawned %d × %s." % [spawned, design.name]
		else:
			status.text = "Spawned %d of %d × %s. Try another distance or clear enemies to free slots." % [spawned, requested, design.name]
	)
	_button(parent, "Clear enemies and projectiles", func():
		game._debug_clear_enemies()
		status.text = "Combat area cleared."
	)
	parent.add_child(HSeparator.new())
	wave_toggle = _toggle(parent, "Repeat random enemy waves", game.debug_tuning.waves, func(value: bool):
		game.debug_tuning.waves = value
		game.enemy_wave_timer = -1.0
	)
	_button(parent, "Replace enemies with a random wave", func():
		game._spawn_enemy_wave()
		game._queue_flight_redraw()
		status.text = "Random wave spawned."
	)

func _refresh_enemy_designs() -> void:
	var selected_id: String = enemy_designs[enemy_picker.selected].id if enemy_picker.selected >= 0 else ""
	enemy_designs = game._debug_enemy_designs()
	enemy_picker.clear()
	var selected := 0
	for index in enemy_designs.size():
		var design: Dictionary = enemy_designs[index]
		enemy_picker.add_item(design.label)
		if design.id == selected_id:
			selected = index
	enemy_picker.select(selected)

func _build_actions(parent: Control) -> void:
	var god_mode := _toggle(parent, "Ignore incoming weapon damage", game.debug_tuning.invulnerable, func(value: bool): game.debug_tuning.invulnerable = value)
	_button(parent, "Refill hull and shields", game._debug_refill)
	_button(parent, "Empty this ship's cargo", func():
		game.iron = 0
		game.tritium = 0
		game._commit_active_ship_state()
		game._queue_flight_redraw()
	)
	_button(parent, "Reset live tuning to defaults", func():
		game.debug_tuning.factors.clear()
		game.debug_tuning.blocks.clear()
		god_mode.button_pressed = false
		wave_toggle.button_pressed = false
		for field: SpinBox in factor_fields.values():
			field.set_value_no_signal(1.0)
		_show_block(block_picker.selected)
		_apply_tuning()
	)

func _ask(message: String, caption: String, action: Callable) -> void:
	on_confirm = action
	confirm.dialog_text = message
	confirm.ok_button_text = caption
	confirm.popup_centered()
	confirm.get_cancel_button().grab_focus()

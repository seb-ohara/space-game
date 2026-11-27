extends CanvasLayer

const BOARD := preload("res://scripts/job_board.gd")
const STYLE := preload("res://scripts/fleet_order_panel.gd")
const INK := Color("d7e9ef")
const MUTED := Color("9bb2c0")
const GOLD := Color("ffd88e")
const TIER_COLORS := [Color("89daca"), Color("f2c77d"), Color("f09c98")]

signal closed

var world
var tabs: HBoxContainer
var list: ItemList
var detail: VBoxContainer
var balance: Label
var status: Label
var exchange: Button
var page := 0
var selected_id := 0
var rows: Array[Dictionary] = []
var confirming := false

func _ready() -> void:
	layer = 22
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.theme = STYLE.make_theme()
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", STYLE.surface(Color("101c24"), Color("385461"), 12, 24, 20))
	var available := get_viewport().get_visible_rect().size
	shell.custom_minimum_size = Vector2(clampf(available.x - 62.0, 590.0, 960.0), clampf(available.y - 64.0, 415.0, 600.0))
	center.add_child(shell)
	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 13)
	shell.add_child(main)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	main.add_child(top)
	var heading := _label(top, "Galactic job board", INK, 25)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance = _label(top, "", GOLD, 17)
	_button(top, "Close", func(): closed.emit())
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	main.add_child(tabs)
	for index in 3:
		var tab := _button(tabs, ["Available", "Active", "Completed"][index], _switch.bind(index))
		tab.toggle_mode = true
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_button(tabs, "Refresh offers", func():
		world.refresh()
		page = 0
		selected_id = 0
		redraw("New offers downloaded. Active contracts are unchanged."))
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(content)
	list = ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 0.8
	list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	list.item_selected.connect(func(index: int):
		selected_id = rows[index].id
		confirming = false
		_render_detail())
	content.add_child(list)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.2
	card.add_theme_stylebox_override("panel", STYLE.surface(Color("14232c"), Color("294450"), 8, 18, 15))
	content.add_child(card)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 11)
	card.add_child(detail)
	status = _label(main, "", MUTED, 13, true)
	status.custom_minimum_size.y = 21.0
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	main.add_child(footer)
	var subtitle := _label(footer, "Local exchange", MUTED, 13)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exchange = _button(footer, "", _use_exchange)
	exchange.tooltip_text = "Plot a course to the local Exchange Relay, or sell the active ship's iron when in range. Plotting replaces its orders."
	redraw()

func _switch(index: int) -> void:
	page = index
	selected_id = 0
	redraw()

func redraw(message := "") -> void:
	confirming = false
	var board = world.board
	status.text = message
	balance.text = "%d credits" % board.credits
	exchange.text = "Sell %d iron · +%d credits" % [world.game.iron, world.game.iron * world.IRON_PRICE] if world.can_sell() else "Plot course to exchange"
	rows = [board.offers, board.active, board.history][page]
	for index in 3:
		var tab: Button = tabs.get_child(index)
		tab.text = ["Available · %d" % board.offers.size(), "Active · %d/%d" % [board.active.size(), BOARD.ACTIVE_LIMIT], "Completed · %d" % board.history.size()][index]
		tab.set_pressed_no_signal(index == page)
	list.clear()
	var selected := 0
	for index in rows.size():
		var job := rows[index]
		var caption := "%s · %s · %s" % [BOARD.TIERS[job.tier], BOARD.TYPES[job.kind], world.system_name(job.target)]
		list.add_item(caption)
		list.set_item_custom_fg_color(index, TIER_COLORS[job.tier])
		list.set_item_tooltip(index, "%s  ·  %s  ·  %d credits" % [BOARD.title(job), BOARD.TIERS[job.tier], job.reward])
		if job.id == selected_id:
			selected = index
	selected_id = 0 if rows.is_empty() else rows[selected].id
	if not rows.is_empty():
		list.select(selected)
		list.ensure_current_is_visible()
	_render_detail()

func _use_exchange() -> void:
	if world.can_sell():
		redraw(world.sell_iron())
	else:
		var result: String = world.set_exchange_course()
		if result == "":
			closed.emit()
		else:
			status.text = result

func _render_detail() -> void:
	for node in detail.get_children():
		detail.remove_child(node)
		node.queue_free()
	var job := BOARD.find(rows, selected_id)
	if job.is_empty():
		_label(detail, ["No offers remaining", "No active contracts", "No completed contracts"][page], INK, 20)
		_label(detail, ["Refresh to find a new batch of jobs.", "Accept a job from Available to start.", "Completed contracts and their payouts appear here."][page], MUTED, 15, true)
		return
	_label(detail, "%s  /  %s" % [BOARD.TYPES[job.kind].to_upper(), BOARD.TIERS[job.tier].to_upper()], TIER_COLORS[job.tier], 13)
	_label(detail, BOARD.title(job), INK, 23, true)
	_label(detail, "%s  ·  %d credits" % [world.system_name(job.target), job.reward], GOLD, 16, true)
	var source: String = world.system_name(job.source)
	var target: String = world.system_name(job.target)
	var briefing := ""
	match job.kind:
		"mining": briefing = "Extract %d fresh iron in %s. Any fleet ship can contribute, and the ore stays in your holds." % [job.amount, target]
		"survey": briefing = "Scan %d signals in %s. Bring your active ship within range of each marked signal in order." % [job.amount, target]
		"bounty": briefing = "Destroy %d wanted pirate ships at the %s hideout. Equip a weapon before setting out." % [job.amount, target]
		"freight": briefing = "Collect %d units of freight at the %s Exchange Relay. Deliver them to the %s Freight Depot aboard the same ship." % [job.amount, source, target]
	_label(detail, briefing, INK, 15, true)
	if page == 1:
		var progress := "%d / %d complete" % [job.progress, job.amount]
		if job.kind == "freight":
			progress = "Awaiting pickup" if job.carrier == "" else "Loaded aboard %s" % world.carrier_name(job)
		_label(detail, progress, TIER_COLORS[job.tier], 15, true)
		var destination: Dictionary = world.goal(job)
		_label(detail, "Next: %s · %s" % [world.system_name(destination.system), destination.label], MUTED, 14, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 7)
	detail.add_child(buttons)
	if page == 0:
		_button(buttons, "Accept contract", func():
			var result: String = world.board.accept(job.id)
			if result == "":
				page = 1
				world.tracked_id = job.id
			redraw("Contract accepted." if result == "" else result), true)
	elif page == 1:
		var blocked: String = world.course_block(job)
		if blocked != "":
			_label(detail, blocked, MUTED, 13, true)
		var course := _button(buttons, "Set course", func():
			var result: String = world.set_course(job)
			if result == "":
				closed.emit()
			else:
				status.text = result, true)
		course.disabled = blocked != ""
		course.tooltip_text = "Replace the active ship's orders with a route to the next objective."
		_button(buttons, "Track", func():
			world.tracked_id = job.id
			closed.emit())
		_button(buttons, "Confirm abandon" if confirming else "Abandon…", func():
			if confirming:
				world.abandon(job.id)
				redraw("Contract abandoned. No payout earned.")
			else:
				confirming = true
				status.text = "Abandon this contract and forfeit its progress and cargo? Ship orders are unchanged."
				_render_detail())
	else:
		_label(buttons, "Paid in full", TIER_COLORS[0], 14)

func _label(parent: Control, text: String, color: Color, font_size: int, wrap := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Control, caption: String, pressed: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = caption
	if primary:
		button.theme_type_variation = "FleetPrimary"
	button.pressed.connect(pressed)
	parent.add_child(button)
	return button

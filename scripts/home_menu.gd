extends Control

signal settings_requested
signal new_game_requested(name: String, galaxy: Dictionary, contents: Dictionary)
signal load_game_requested(slot_id: String)

const BINDINGS := preload("res://scripts/key_bindings.gd")

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const PREVIEW := preload("res://scripts/galaxy_preview.gd")
const INK := Color("050b18")
const SURFACE := Color("102030")
const BORDER := Color("36536a")
const TEXT := Color("e4f1f5")
const MUTED := Color("a5bdcb")
const AMBER := Color("f3c78e")

var column: VBoxContainer
var preview: PREVIEW
var menu_page := ""
var generation_run := 0
var home_focus: Button
var status: Label
var save_list: ItemList
var galaxy_name: LineEdit
var seed_input: LineEdit
var systems_input: SpinBox
var arms_input: OptionButton
var settings_button: Button
var draft_name := "New Galaxy"
var draft_count := GALAXY.DEFAULT_SYSTEMS
var draft_arms := GALAXY.DEFAULT_ARMS
var draft_seed := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	var background := ColorRect.new()
	background.color = INK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var layout := BoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 40.0
	layout.offset_right = -40.0
	layout.offset_top = 24.0
	layout.offset_bottom = -24.0
	layout.add_theme_constant_override("separation", 46)
	add_child(layout)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.78
	layout.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 420.0
	column.add_theme_constant_override("separation", 13)
	center.add_child(column)

	preview = PREVIEW.new()
	preview.custom_minimum_size = Vector2(360, 440)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(preview)
	resized.connect(_fit_layout)
	_fit_layout()
	show_home()

func _fit_layout() -> void:
	var narrow := size.x < 970.0
	preview.visible = not narrow or menu_page == "generating"
	var layout: BoxContainer = preview.get_parent()
	layout.vertical = narrow
	layout.add_theme_constant_override("separation", 14 if narrow else 46)
	var scroll := layout.get_child(0) as ScrollContainer
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_SHRINK_CENTER
	var margin := clampf(size.x * 0.045, 16.0, 84.0)
	layout.offset_left = margin
	layout.offset_right = -margin
	column.custom_minimum_size.x = clampf(size.x * (0.36 if preview.visible else 0.75), 300.0, 520.0)
	preview.custom_minimum_size.x = 300.0
	preview.custom_minimum_size.y = clampf(size.y * (0.45 if narrow else 0.68), 250.0, 700.0)

func _set_page(next_page: String) -> void:
	menu_page = next_page
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	status = null
	_fit_layout()

func show_home() -> void:
	generation_run += 1
	_set_page("home")
	preview.show_progress({}, 0, {})
	_label("Drift", 74, TEXT)
	_gap(18)
	var recent := SAVES.recent_slot()
	if not recent.is_empty():
		home_focus = _button("Continue", func(): load_game_requested.emit(recent), true)
		_button("New game", _show_setup)
	else:
		home_focus = _button("New game", _show_setup, true)
	_button("Load game", _show_saves)
	settings_button = _button("Settings", func(): settings_requested.emit())
	home_focus.grab_focus()

func focus_settings() -> void:
	if is_instance_valid(settings_button):
		settings_button.grab_focus()

func set_error(message: String) -> void:
	if not is_instance_valid(status):
		status = _label("", 16, AMBER)
	status.text = message

func _show_setup() -> void:
	generation_run += 1
	_set_page("setup")
	preview.show_progress({}, 0, {})
	_label("Create a galaxy", 42, TEXT)
	_gap(6)
	_label("Galaxy name", 16, MUTED)
	galaxy_name = LineEdit.new()
	galaxy_name.text = draft_name
	galaxy_name.max_length = 48
	galaxy_name.custom_minimum_size.y = 42.0
	column.add_child(galaxy_name)

	_label("Star systems", 16, MUTED)
	systems_input = SpinBox.new()
	systems_input.name = "SystemCount"
	systems_input.min_value = GALAXY.MIN_SYSTEMS
	systems_input.max_value = GALAXY.MAX_SYSTEMS
	systems_input.value = draft_count
	systems_input.custom_minimum_size.y = 42.0
	column.add_child(systems_input)
	_label("Choose up to 1,000 systems, including Sol.", 14, MUTED)

	_label("Spiral arms", 16, MUTED)
	arms_input = OptionButton.new()
	arms_input.name = "SpiralArms"
	arms_input.custom_minimum_size.y = 42.0
	for arms in range(GALAXY.MIN_ARMS, GALAXY.MAX_ARMS + 1):
		arms_input.add_item("%d arms" % arms, arms)
	arms_input.select(arms_input.get_item_index(draft_arms))
	column.add_child(arms_input)

	_label("Galaxy seed", 16, MUTED)
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "Random if blank"
	seed_input.text = draft_seed
	seed_input.max_length = 19
	seed_input.custom_minimum_size.y = 42.0
	column.add_child(seed_input)
	_label("Reuse the seed, system count, and arm count to recreate this map.", 14, MUTED)
	_gap(7)
	_button("Generate galaxy", _start_generation, true)
	_button("Back", show_home)
	galaxy_name.grab_focus()

func _start_generation() -> void:
	var raw_seed := seed_input.text.strip_edges()
	if not raw_seed.is_empty() and (not raw_seed.is_valid_int() or raw_seed.trim_prefix("-").trim_prefix("+").length() > 18):
		set_error("Enter a whole number with up to 18 digits, or leave the seed blank.")
		return
	var title := galaxy_name.text.strip_edges()
	if title.is_empty():
		title = "New Galaxy"
	systems_input.apply()
	var count := int(systems_input.value)
	draft_count = count
	draft_arms = arms_input.get_selected_id()
	draft_name = title
	draft_seed = raw_seed
	var seed_value := int(randi()) if raw_seed.is_empty() else raw_seed.to_int()
	_set_page("generating")
	var progress_title := _label("Placing stars", 36, TEXT)
	_label(title, 20, AMBER)
	var progress := ProgressBar.new()
	progress.max_value = 2.0 * count
	progress.custom_minimum_size.y = 22.0
	progress.show_percentage = false
	column.add_child(progress)
	var progress_detail := _label("0 / %d stars" % count, 16, MUTED)
	_gap(10)
	var cancel := _button("Cancel", _show_setup)
	cancel.grab_focus()

	generation_run += 1
	var run := generation_run
	var data := GALAXY.create_map(seed_value, count, GALAXY.VERSION, draft_arms)
	var contents := {}
	preview.show_progress(data, 0, contents)
	var placement_batch := maxi(1, ceili(count / 25.0))
	var placement_steps := ceili(float(count) / placement_batch)
	var placement_duration := minf(1.5, 0.60 + count * 0.001)
	for i in range(0, count, placement_batch):
		await get_tree().create_timer(placement_duration / placement_steps, true, false, true).timeout
		if run != generation_run:
			return
		var placed := mini(i + placement_batch, count)
		progress.value = placed
		progress_detail.text = "%d / %d stars" % [placed, count]
		preview.show_progress(data, placed, contents)

	progress_title.text = "Forming systems"
	var system_label := "system" if count == 1 else "systems"
	progress_detail.text = "0 / %d %s populated" % [count, system_label]
	# Limit the simulation work per frame so the largest galaxy still animates and can be cancelled.
	var formation_batch := clampi(ceili(count / 20.0), 1, 16)
	var formation_steps := ceili(float(count) / formation_batch)
	var formation_duration := minf(4.2, 1.55 + count * 0.003)
	for i in range(0, count, formation_batch):
		await get_tree().create_timer(formation_duration / formation_steps, true, false, true).timeout
		if run != generation_run:
			return
		var populated := mini(i + formation_batch, count)
		for index in range(i, populated):
			contents[index] = GALAXY.form_system(seed_value, data.systems[index], data.generator_version)
		progress.value = count + populated
		progress_detail.text = "%d / %d %s populated" % [populated, count, system_label]
		preview.show_progress(data, count, contents, populated - 1)
	progress_title.text = "Galaxy ready"
	await get_tree().create_timer(0.58, true, false, true).timeout
	if run == generation_run:
		new_game_requested.emit(title, data, contents)

func _show_saves() -> void:
	_set_page("saves")
	preview.show_progress({}, 0, {})
	_label("Load a game", 42, TEXT)
	var slots := SAVES.slots()
	if slots.is_empty():
		_label("No saved galaxies yet.", 17, MUTED)
		_button("New game", _show_setup, true).grab_focus()
	else:
		save_list = ItemList.new()
		save_list.custom_minimum_size.y = 232.0
		save_list.add_theme_constant_override("v_separation", 16)
		column.add_child(save_list)
		var save_detail := _label("", 15, MUTED)
		var load_button := _button("Load selected game", _load_selected, true)
		_button("Delete selected world", _confirm_delete_selected)
		for slot in slots:
			var stamp := Time.get_date_string_from_unix_time(slot.saved_at)
			var count_text := ("%d systems" % slot.count if slot.count != 1 else "1 system") if slot.readable else "Unavailable"
			var index := save_list.add_item("%s   ·   %s   ·   %s" % [slot.name, count_text, stamp])
			save_list.set_item_metadata(index, slot.id)
		var update_detail := func(index: int):
			var slot := slots[index]
			load_button.disabled = not slot.readable
			save_detail.text = "Play time  %s  ·  Galaxy seed  %d" % [_format_play_time(slot.play_time), slot.seed] if slot.readable else "This save could not be read."
		save_list.item_selected.connect(update_detail)
		save_list.item_activated.connect(func(_index: int): _load_selected())
		save_list.select(0)
		update_detail.call(0)
		save_list.grab_focus()
	_button("Back", show_home)

func _load_selected() -> void:
	var selected := save_list.get_selected_items()
	if not selected.is_empty():
		var slot_id: String = save_list.get_item_metadata(selected[0])
		if not SAVES.read(slot_id).is_empty():
			load_game_requested.emit(slot_id)

func _confirm_delete_selected() -> void:
	var selected := save_list.get_selected_items()
	if selected.is_empty():
		return
	var slot_id: String = save_list.get_item_metadata(selected[0])
	var slot_name := save_list.get_item_text(selected[0]).split("   ·   ")[0]
	var dialog := ConfirmationDialog.new()
	dialog.title = "Delete world?"
	dialog.dialog_text = "Permanently delete ‘%s’ and its saved progress? This cannot be undone." % slot_name
	dialog.ok_button_text = "Delete world"
	add_child(dialog)
	dialog.confirmed.connect(func():
		if SAVES.delete(slot_id):
			_show_saves()
		else:
			set_error("Could not delete this world. Please try again.")
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.close_requested.connect(dialog.queue_free)
	dialog.popup_centered()

func _format_play_time(seconds: float) -> String:
	var total_minutes := int(seconds) / 60
	return "%dh %02dm" % [total_minutes / 60, total_minutes % 60]

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not BINDINGS.pressed(event, "game_back") or not BINDINGS.shortcut_allowed(event, get_viewport()):
		return
	if menu_page == "generating":
		_show_setup()
	elif menu_page != "home":
		show_home()
	else:
		return
	get_viewport().set_input_as_handled()

func _label(copy: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	column.add_child(label)
	return label

func _gap(height: float) -> void:
	var space := Control.new()
	space.custom_minimum_size.y = height
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(space)

func _button(copy: String, action: Callable, primary := false) -> Button:
	var button := Button.new()
	button.text = copy
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 48.0
	if primary:
		button.add_theme_stylebox_override("normal", _surface(AMBER, AMBER))
		button.add_theme_stylebox_override("hover", _surface(Color("ffe0ad"), AMBER))
		button.add_theme_stylebox_override("pressed", _surface(Color("cca575"), AMBER))
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, INK)
	button.pressed.connect(action)
	column.add_child(button)
	return button

func _make_theme() -> Theme:
	var menu_theme := Theme.new()
	menu_theme.default_font_size = 18
	for control in ["Button", "LineEdit", "ItemList"]:
		menu_theme.set_color("font_color", control, TEXT)
		menu_theme.set_stylebox("normal", control, _surface(SURFACE, BORDER))
		menu_theme.set_stylebox("focus", control, _focus_ring())
	menu_theme.set_stylebox("hover", "Button", _surface(Color("192f43"), Color("6a9bb3")))
	menu_theme.set_stylebox("pressed", "Button", _surface(Color("203e55"), AMBER))
	menu_theme.set_stylebox("disabled", "Button", _surface(INK, BORDER))
	menu_theme.set_stylebox("panel", "ItemList", _surface(SURFACE, BORDER))
	menu_theme.set_stylebox("selected", "ItemList", _surface(Color("213f54"), BORDER))
	menu_theme.set_stylebox("selected_focus", "ItemList", _surface(Color("213f54"), BORDER))
	menu_theme.set_stylebox("background", "ProgressBar", _surface(SURFACE, BORDER))
	menu_theme.set_stylebox("fill", "ProgressBar", _surface(AMBER, AMBER))
	return menu_theme

func _surface(fill: Color, stroke: Color) -> StyleBoxFlat:
	var surface := StyleBoxFlat.new()
	surface.bg_color = fill
	surface.border_color = stroke
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(4)
	surface.content_margin_left = 15.0
	surface.content_margin_right = 15.0
	surface.content_margin_top = 5.0
	surface.content_margin_bottom = 5.0
	return surface

func _focus_ring() -> StyleBoxFlat:
	var ring := StyleBoxFlat.new()
	ring.draw_center = false
	ring.border_color = Color("b7dbed")
	ring.set_border_width_all(2)
	ring.set_corner_radius_all(4)
	return ring

extends Control

const KEY_BINDINGS := preload("res://scripts/key_bindings.gd")

class BindingCapture extends Node:
	var capture: Callable

	func _input(event: InputEvent) -> void:
		capture.call(event)

signal closed
signal save_requested(return_home: bool)
signal key_binding_changed
signal zoom_changed(value: float)
signal hangar_requested
signal graphics_quality_changed(value: int)
signal frame_cap_changed(value: int)
signal vsync_changed(enabled: bool)
signal engine_volume_changed(value: float)

var in_flight := true
var test_flight := false
var save_status: Label
var initial_zoom := 0.25
var minimum_zoom := 0.05
var maximum_zoom := 1.0
var initial_graphics_quality := 2
var initial_frame_cap := 0
var initial_vsync := false
var initial_engine_volume := 0.7
var rebinding_action := ""
var binding_buttons := {}
var binding_window: Window
var binding_message: Label
var cancel_capture: Button
var pending_modifier := 0
var return_hint: Label

func _refresh_binding_labels() -> void:
	for action in binding_buttons:
		binding_buttons[action].text = KEY_BINDINGS.label(action)
	return_hint.text = ("Game paused  ·  " if in_flight else "") + "%s to return" % KEY_BINDINGS.label("game_back")

func _stop_capture() -> void:
	rebinding_action = ""
	pending_modifier = 0
	cancel_capture.disabled = true
	binding_message.text = "Select an action to change its binding."
	_refresh_binding_labels()

func _capture_binding(event: InputEvent) -> void:
	if rebinding_action.is_empty() or not (event is InputEventKey or event is InputEventMouseButton):
		return
	# Keep the visible Cancel button usable without reserving Escape or any other key.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and cancel_capture.get_global_rect().has_point(event.position):
		return
	binding_window.set_input_as_handled()
	if event.is_echo():
		return
	var modifier_key: int = event.keycode if event is InputEventKey else 0
	if modifier_key in KEY_BINDINGS.MODIFIERS:
		if event.is_pressed():
			pending_modifier = modifier_key
			return
		if pending_modifier != modifier_key:
			return
	elif not event.is_pressed():
		return
	pending_modifier = 0
	if not KEY_BINDINGS.accepts(rebinding_action, event):
		binding_message.text = "Use a key or a mouse button you can hold for this action."
		return
	var conflict := KEY_BINDINGS.conflict(rebinding_action, event)
	if not conflict.is_empty():
		binding_message.text = "Already used by %s. Try another input." % KEY_BINDINGS.ACTIONS[conflict][0]
		return
	KEY_BINDINGS.set_binding(rebinding_action, event)
	_stop_capture()
	key_binding_changed.emit()

func _open_key_bindings() -> void:
	if is_instance_valid(binding_window):
		binding_window.popup_centered()
		return
	binding_window = Window.new()
	binding_window.title = "Mouse & keyboard bindings"
	binding_window.size = Vector2i(560, 640)
	binding_window.transient = true
	binding_window.exclusive = true
	var input_capture := BindingCapture.new()
	input_capture.capture = _capture_binding
	binding_window.add_child(input_capture)
	binding_window.close_requested.connect(func():
		_stop_capture()
		binding_window.hide()
	)
	add_child(binding_window)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	binding_window.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	binding_message = Label.new()
	binding_message.custom_minimum_size.y = 44
	binding_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(binding_message)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 6)
	scroll.add_child(column)
	var previous_scope := ""
	for action in KEY_BINDINGS.ACTIONS:
		if action == "flight_debug" and not OS.is_debug_build():
			continue
		var scope: String = KEY_BINDINGS.ACTIONS[action][1]
		if scope != previous_scope:
			var heading := Label.new()
			heading.text = scope.to_upper()
			heading.modulate = Color("90afc0")
			column.add_child(heading)
			previous_scope = scope
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = KEY_BINDINGS.ACTIONS[action][0]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 32)
		button.pressed.connect(func():
			_refresh_binding_labels()
			rebinding_action = action
			pending_modifier = 0
			cancel_capture.disabled = false
			binding_message.text = "Press a key or mouse button, with or without modifiers. You can also scroll the wheel."
			button.text = "Waiting for input…"
		)
		binding_buttons[action] = button
		row.add_child(button)
	var footer := HBoxContainer.new()
	layout.add_child(footer)
	var reset := Button.new()
	reset.text = "Restore defaults"
	reset.pressed.connect(func():
		KEY_BINDINGS.setup(ConfigFile.new())
		_stop_capture()
		key_binding_changed.emit()
	)
	footer.add_child(reset)
	cancel_capture = Button.new()
	cancel_capture.text = "Cancel rebinding"
	cancel_capture.pressed.connect(_stop_capture)
	footer.add_child(cancel_capture)
	var close := Button.new()
	close.text = "Done"
	close.pressed.connect(func(): binding_window.close_requested.emit())
	footer.add_child(close)
	_stop_capture()
	binding_window.popup_centered()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.025, 0.05, 0.82)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("0b1929")
	surface.border_color = Color("34566e")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(9)
	surface.content_margin_left = 32
	surface.content_margin_right = 32
	surface.content_margin_top = 28
	surface.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", surface)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "FLIGHT MENU" if in_flight else "SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e4f5ff"))
	column.add_child(title)
	return_hint = Label.new()
	return_hint.add_theme_color_override("font_color", Color("90afc0"))
	column.add_child(return_hint)
	_refresh_binding_labels()
	var separator := HSeparator.new()
	column.add_child(separator)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	column.add_child(navigation)
	var sections := {}
	var section_content := VBoxContainer.new()
	section_content.custom_minimum_size = Vector2(0, 210)
	column.add_child(section_content)
	for section_name in (["Controls", "Sound", "Graphics", "Ship Builder"] if in_flight else ["Controls", "Sound", "Graphics"]):
		var section := VBoxContainer.new()
		section.name = section_name
		section.add_theme_constant_override("separation", 12)
		section_content.add_child(section)
		sections[section_name] = section
		var tab := Button.new()
		tab.text = section_name
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.custom_minimum_size.y = 36
		navigation.add_child(tab)
		tab.pressed.connect(func():
			for name in sections:
				sections[name].visible = name == section_name
			for child in navigation.get_children():
				child.set_pressed_no_signal(child == tab)
		)
		section.visible = section_name == "Controls"
		tab.set_pressed_no_signal(section_name == "Controls")
	var controls_section: VBoxContainer = sections["Controls"]
	var sound_section: VBoxContainer = sections["Sound"]
	var graphics_section: VBoxContainer = sections["Graphics"]
	var hangar_button := Button.new()
	hangar_button.text = "Open Ship Builder"
	hangar_button.custom_minimum_size = Vector2(0, 40)
	hangar_button.focus_mode = Control.FOCUS_NONE
	hangar_button.pressed.connect(func(): hangar_requested.emit())
	if in_flight:
		sections["Ship Builder"].add_child(hangar_button)
	else:
		hangar_button.free()
	var bindings_button := Button.new()
	bindings_button.text = "Mouse & keyboard bindings"
	bindings_button.pressed.connect(_open_key_bindings)
	controls_section.add_child(bindings_button)
	var controls_hint := Label.new()
	controls_hint.text = "Customize flight and Ship Builder controls. Standard menu clicks and navigation are unchanged.\nTrackpad: drag up or down with two fingers to zoom in flight and in the Ship Builder. Pinch also zooms in flight."
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls_hint.add_theme_font_size_override("font_size", 12)
	controls_hint.add_theme_color_override("font_color", Color("90afc0"))
	controls_section.add_child(controls_hint)
	var zoom_title := Label.new()
	zoom_title.text = "CAMERA ZOOM"
	zoom_title.add_theme_font_size_override("font_size", 13)
	zoom_title.add_theme_color_override("font_color", Color("a7c7d8"))
	graphics_section.add_child(zoom_title)
	zoom_title.visible = in_flight
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 16)
	graphics_section.add_child(zoom_row)
	zoom_row.visible = in_flight
	var slider := HSlider.new()
	slider.min_value = minf(minimum_zoom, initial_zoom)
	slider.max_value = maximum_zoom
	slider.step = 0.0
	slider.exp_edit = true
	slider.value = initial_zoom
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(slider)
	var zoom_value := Label.new()
	zoom_value.custom_minimum_size = Vector2(72, 0)
	zoom_value.text = "%.5f%%" % (initial_zoom * 100.0)
	zoom_row.add_child(zoom_value)
	slider.value_changed.connect(func(value: float):
		zoom_value.text = "%.5f%%" % (value * 100.0)
		zoom_changed.emit(value)
	)
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 12)
	sound_section.add_child(audio_row)
	var audio_label := Label.new()
	audio_label.text = "ENGINE VOLUME"
	audio_row.add_child(audio_label)
	var audio_slider := HSlider.new()
	audio_slider.name = "EngineVolume"
	audio_slider.max_value = 1.0
	audio_slider.step = 0.01
	audio_slider.value = initial_engine_volume
	audio_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_row.add_child(audio_slider)
	var audio_value := Label.new()
	audio_value.custom_minimum_size = Vector2(54, 0)
	audio_value.text = "%d%%" % int(round(initial_engine_volume * 100.0))
	audio_row.add_child(audio_value)
	audio_slider.value_changed.connect(func(value: float):
		audio_value.text = "%d%%" % int(round(value * 100.0))
		engine_volume_changed.emit(value)
	)
	var graphics_row := HBoxContainer.new()
	graphics_section.add_child(graphics_row)
	var graphics_label := Label.new()
	graphics_label.text = "GRAPHICS QUALITY"
	graphics_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	graphics_row.add_child(graphics_label)
	var quality := OptionButton.new()
	quality.name = "GraphicsQuality"
	quality.custom_minimum_size = Vector2(180, 0)
	for text in ["Low", "Medium", "High"]:
		quality.add_item(text)
	quality.select(clampi(initial_graphics_quality, 0, 2))
	quality.item_selected.connect(func(index: int): graphics_quality_changed.emit(index))
	graphics_row.add_child(quality)
	var graphics_hint := Label.new()
	graphics_hint.text = "Lower quality reduces background detail and hit effects."
	graphics_hint.add_theme_font_size_override("font_size", 12)
	graphics_hint.add_theme_color_override("font_color", Color("90afc0"))
	graphics_section.add_child(graphics_hint)
	var fps_title := Label.new()
	fps_title.text = "FRAME RATE LIMIT"
	fps_title.add_theme_font_size_override("font_size", 13)
	fps_title.add_theme_color_override("font_color", Color("a7c7d8"))
	graphics_section.add_child(fps_title)
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 12)
	graphics_section.add_child(fps_row)
	var fps := HSlider.new()
	fps.name = "FrameRateLimit"
	fps.min_value = 30
	fps.max_value = 240
	fps.step = 1
	fps.value = initial_frame_cap if initial_frame_cap > 0 else 60
	fps.editable = initial_frame_cap > 0
	fps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fps_row.add_child(fps)
	var fps_value := Label.new()
	fps_value.name = "FrameRateValue"
	fps_value.custom_minimum_size = Vector2(65, 0)
	fps_value.text = "%d FPS" % int(fps.value)
	fps_row.add_child(fps_value)
	var unlimited := CheckBox.new()
	unlimited.name = "UnlimitedFrameRate"
	unlimited.text = "Unlimited"
	unlimited.button_pressed = initial_frame_cap == 0
	fps_row.add_child(unlimited)
	fps.value_changed.connect(func(value: float):
		fps_value.text = "%d FPS" % int(value)
		if not unlimited.button_pressed:
			frame_cap_changed.emit(int(value))
	)
	unlimited.toggled.connect(func(enabled: bool):
		fps.editable = not enabled
		frame_cap_changed.emit(0 if enabled else int(fps.value))
	)
	var vsync := CheckButton.new()
	vsync.name = "VSync"
	vsync.text = " VSync (may limit frame rate to display refresh)"
	vsync.button_pressed = initial_vsync
	vsync.toggled.connect(func(enabled: bool): vsync_changed.emit(enabled))
	graphics_section.add_child(vsync)
	var fullscreen := CheckButton.new()
	fullscreen.text = " Fullscreen"
	var mode := DisplayServer.window_get_mode()
	fullscreen.button_pressed = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	graphics_section.add_child(fullscreen)
	if in_flight:
		var save_row := HBoxContainer.new()
		save_row.add_theme_constant_override("separation", 10)
		column.add_child(save_row)
		var save_button := Button.new()
		save_button.text = "Save game"
		save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		save_button.custom_minimum_size.y = 40.0
		save_button.pressed.connect(func(): save_requested.emit(false))
		save_row.add_child(save_button)
		save_button.visible = not test_flight
		var home_button := Button.new()
		home_button.text = "Return to campaign" if test_flight else "Save and return to home"
		home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		home_button.pressed.connect(func(): save_requested.emit(true))
		save_row.add_child(home_button)
		save_status = Label.new()
		save_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		save_status.hide()
		column.add_child(save_status)
	var resume := Button.new()
	resume.text = "Resume flight" if in_flight else "Back to home"
	resume.custom_minimum_size = Vector2(0, 44)
	resume.pressed.connect(func(): closed.emit())
	column.add_child(resume)
	resume.grab_focus()

func set_save_status(message: String) -> void:
	if is_instance_valid(save_status):
		save_status.text = message
		save_status.show()


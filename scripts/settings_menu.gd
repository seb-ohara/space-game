extends Control

const MAX_ZOOM := 1.8

signal closed
signal zoom_changed(value: float)
signal hangar_requested
signal graphics_quality_changed(value: int)
signal frame_cap_changed(value: int)
signal vsync_changed(enabled: bool)
signal control_mode_changed(value: int)
signal engine_volume_changed(value: float)

var initial_zoom := 1.0
var minimum_zoom := 0.05
var initial_graphics_quality := 2
var initial_frame_cap := 0
var initial_vsync := false
var initial_control_mode := 0
var initial_engine_volume := 0.7

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
	panel.custom_minimum_size = Vector2(500, 0)
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
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("e4f5ff"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Game paused  ·  Escape to return"
	subtitle.add_theme_color_override("font_color", Color("90afc0"))
	column.add_child(subtitle)
	var separator := HSeparator.new()
	column.add_child(separator)
	var hangar_button := Button.new()
	hangar_button.text = "Open Hangar"
	hangar_button.custom_minimum_size = Vector2(0, 40)
	hangar_button.focus_mode = Control.FOCUS_NONE
	hangar_button.pressed.connect(func(): hangar_requested.emit())
	column.add_child(hangar_button)
	var controls_row := HBoxContainer.new()
	column.add_child(controls_row)
	var controls_label := Label.new()
	controls_label.text = "CONTROL MODE"
	controls_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls_row.add_child(controls_label)
	var controls := OptionButton.new()
	controls.name = "ControlMode"
	controls.custom_minimum_size = Vector2(180, 0)
	controls.add_item("WASD flight")
	controls.add_item("RTS commands")
	controls.select(clampi(initial_control_mode, 0, 1))
	controls.item_selected.connect(func(index: int): control_mode_changed.emit(index))
	controls_row.add_child(controls)
	var controls_hint := Label.new()
	controls_hint.text = "RTS: WASD pans; Space recenters; click to command."
	controls_hint.add_theme_font_size_override("font_size", 12)
	controls_hint.add_theme_color_override("font_color", Color("90afc0"))
	column.add_child(controls_hint)
	var zoom_title := Label.new()
	zoom_title.text = "CAMERA ZOOM"
	zoom_title.add_theme_font_size_override("font_size", 13)
	zoom_title.add_theme_color_override("font_color", Color("a7c7d8"))
	column.add_child(zoom_title)
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 16)
	column.add_child(zoom_row)
	var slider := HSlider.new()
	slider.min_value = minf(minimum_zoom, initial_zoom)
	slider.max_value = MAX_ZOOM
	slider.step = 0.0
	slider.exp_edit = true
	slider.value = initial_zoom
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.add_child(slider)
	var zoom_value := Label.new()
	zoom_value.custom_minimum_size = Vector2(72, 0)
	zoom_value.text = "%.3f%%" % (initial_zoom * 100.0)
	zoom_row.add_child(zoom_value)
	slider.value_changed.connect(func(value: float):
		zoom_value.text = "%.3f%%" % (value * 100.0)
		zoom_changed.emit(value)
	)
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 12)
	column.add_child(audio_row)
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
	column.add_child(graphics_row)
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
	column.add_child(graphics_hint)
	var fps_title := Label.new()
	fps_title.text = "FRAME RATE LIMIT"
	fps_title.add_theme_font_size_override("font_size", 13)
	fps_title.add_theme_color_override("font_color", Color("a7c7d8"))
	column.add_child(fps_title)
	var fps_row := HBoxContainer.new()
	fps_row.add_theme_constant_override("separation", 12)
	column.add_child(fps_row)
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
	column.add_child(vsync)
	var fullscreen := CheckButton.new()
	fullscreen.text = " Fullscreen"
	var mode := DisplayServer.window_get_mode()
	fullscreen.button_pressed = mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	fullscreen.toggled.connect(func(enabled: bool):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	)
	column.add_child(fullscreen)
	var resume := Button.new()
	resume.text = "Resume flight"
	resume.custom_minimum_size = Vector2(0, 44)
	resume.focus_mode = Control.FOCUS_NONE
	resume.pressed.connect(func(): closed.emit())
	column.add_child(resume)


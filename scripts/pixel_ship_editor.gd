extends Control

enum Tool { PENCIL, ERASER, FILL, SAMPLE }

const CANVAS_SIZE := Vector2i(256, 256)
const MAX_HISTORY := 32
const PALETTES := {
	"Shipyard steel": ["182530", "2d4051", "4b6071", "738a9b", "aac0c8", "e1e8e5", "509ab4", "f4ae67"],
	"Copperworks": ["2e1c28", "522d36", "7d463e", "ab6852", "d88d62", "f5c498", "2f827d", "8ed0b9"],
	"Deep space": ["191831", "352948", "52406f", "7b619d", "ada0d1", "ede0f0", "4e9fa9", "e76c93"],
	"Signal lights": ["243246", "647585", "bccbd0", "fcf2d7", "ffcd60", "f47c4d", "ee576b", "74d6b1"],
}

var source: Image
var source_origin := Vector2i(-1, -1)
var image: Image
var ink := Color("738a9b")
var tool := Tool.PENCIL
var brush_width := 1
var mirror := true
var show_grid := true
var undo_stack: Array[Image] = []
var redo_stack: Array[Image] = []
var baseline: PackedByteArray
var stroke_button := MOUSE_BUTTON_NONE
var stroke_before: Image
var last_pixel := Vector2i(-1, -1)
var canvas_rect := Rect2()
var pixel_size := 1.0
var zoom := 1.0
var pan := Vector2.ZERO
var panning := false
var hover_pixel := Vector2i(-1, -1)
var canvas: Control
var silhouette: Control
var colour_value: Label
var image_texture: ImageTexture
var coordinates: Label
var color_picker: ColorPickerButton
var tool_buttons: Array[Button] = []
var swatches: GridContainer
var undo_button: Button
var redo_button: Button

func _ready() -> void:
	image = Image.create_empty(CANVAS_SIZE.x, CANVAS_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if source != null and not source.is_empty():
		var origin := source_origin
		if not Rect2i(Vector2i.ZERO, CANVAS_SIZE).encloses(Rect2i(origin, source.get_size())):
			origin = (CANVAS_SIZE - source.get_size()) / 2
		image.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), origin)
	baseline = image.get_data()
	image_texture = ImageTexture.create_from_image(image)

	var layout := HBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 18)
	add_child(layout)
	var workspace := VBoxContainer.new()
	workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 8)
	layout.add_child(workspace)
	canvas = Control.new()
	canvas.custom_minimum_size = Vector2(180, 180)
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.clip_contents = true
	canvas.focus_mode = Control.FOCUS_CLICK
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.mouse_default_cursor_shape = Control.CURSOR_CROSS
	canvas.draw.connect(_draw_canvas)
	canvas.resized.connect(canvas.queue_redraw)
	canvas.gui_input.connect(_canvas_input)
	canvas.mouse_exited.connect(func():
		hover_pixel = Vector2i(-1, -1)
		last_pixel = Vector2i(-1, -1)
		coordinates.text = ""
		canvas.queue_redraw()
	)
	workspace.add_child(canvas)

	var footer := HBoxContainer.new()
	workspace.add_child(footer)
	var help := Label.new()
	help.text = "Scroll to zoom · Middle drag to pan · Right drag to erase"
	help.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(help)
	coordinates = Label.new()
	footer.add_child(coordinates)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 246
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var tools := VBoxContainer.new()
	tools.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_theme_constant_override("separation", 8)
	scroll.add_child(tools)
	_label(tools, "Drawing tools", 20)
	var tool_grid := GridContainer.new()
	tool_grid.columns = 2
	tools.add_child(tool_grid)
	var group := ButtonGroup.new()
	for caption in ["Pencil (B)", "Eraser (E)", "Fill (F)", "Sample (I)"]:
		var index := tool_buttons.size()
		var button := _button(tool_grid, caption, func(): _select_tool(index))
		button.toggle_mode = true
		button.button_group = group
		tool_buttons.append(button)
	_select_tool(Tool.PENCIL)
	var brush := OptionButton.new()
	for pixels in [1, 2, 3, 5, 7]:
		brush.add_item("%d px brush" % pixels, pixels)
	brush.item_selected.connect(func(index: int):
		brush_width = brush.get_item_id(index)
		canvas.queue_redraw()
	)
	tools.add_child(brush)
	_check(tools, "Mirror across centre", true, func(enabled: bool):
		mirror = enabled
		canvas.queue_redraw()
	)
	_check(tools, "Show grid", true, func(enabled: bool):
		show_grid = enabled
		canvas.queue_redraw()
	)

	tools.add_child(HSeparator.new())
	_label(tools, "Colour palette", 20)
	var palettes := OptionButton.new()
	for palette in PALETTES:
		palettes.add_item(palette)
	palettes.item_selected.connect(func(index: int): _show_palette(palettes.get_item_text(index)))
	tools.add_child(palettes)
	swatches = GridContainer.new()
	swatches.columns = 4
	tools.add_child(swatches)
	var colour_row := HBoxContainer.new()
	tools.add_child(colour_row)
	colour_value = Label.new()
	colour_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colour_row.add_child(colour_value)
	color_picker = ColorPickerButton.new()
	color_picker.tooltip_text = "Choose a custom colour"
	color_picker.edit_alpha = false
	color_picker.custom_minimum_size = Vector2(78, 34)
	color_picker.color_changed.connect(_set_ink)
	colour_row.add_child(color_picker)
	_set_ink(ink)
	_show_palette(palettes.get_item_text(0))

	tools.add_child(HSeparator.new())
	var history := HBoxContainer.new()
	tools.add_child(history)
	undo_button = _button(history, "Undo", _undo)
	redo_button = _button(history, "Redo", _redo)
	undo_button.tooltip_text = "Ctrl or Cmd + Z"
	redo_button.tooltip_text = "Ctrl or Cmd + Shift + Z"
	_button(tools, "Fit artwork", _fit_artwork)
	_button(tools, "Show full canvas", func():
		zoom = 1.0
		pan = Vector2.ZERO
		canvas.queue_redraw()
	)
	_button(tools, "Clear canvas", _clear_canvas)
	tools.add_child(HSeparator.new())
	_label(tools, "Hull preview", 18)
	silhouette = Control.new()
	silhouette.custom_minimum_size.y = 136
	silhouette.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	silhouette.draw.connect(_draw_silhouette)
	silhouette.resized.connect(silhouette.queue_redraw)
	tools.add_child(silhouette)
	_update_history_buttons()
	canvas.resized.connect(_fit_artwork_on_first_resize)
	_fit_artwork_on_first_resize()

func _label(parent: Control, caption: String, font_size: int) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)

func _button(parent: Control, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _check(parent: Control, caption: String, enabled: bool, action: Callable) -> void:
	var check := CheckButton.new()
	check.text = caption
	check.button_pressed = enabled
	check.toggled.connect(action)
	parent.add_child(check)

func _show_palette(palette: String) -> void:
	for swatch in swatches.get_children():
		swatches.remove_child(swatch)
		swatch.queue_free()
	for hex in PALETTES[palette]:
		var colour := Color(hex)
		var swatch := _button(swatches, "", _set_ink.bind(colour))
		swatch.custom_minimum_size.x = 39
		swatch.tooltip_text = "#" + hex.to_upper()
		for state in ["normal", "hover", "pressed"]:
			var chip := StyleBoxFlat.new()
			chip.bg_color = colour.lightened(0.16) if state == "hover" else colour
			chip.border_color = Color("e5eaf0") if state != "normal" else Color("5a6c78")
			chip.set_border_width_all(1)
			swatch.add_theme_stylebox_override(state, chip)

func _set_ink(colour: Color) -> void:
	ink = colour
	color_picker.color = colour
	colour_value.text = "#" + colour.to_html(false).to_upper()
	canvas.queue_redraw()

func _select_tool(index: int) -> void:
	tool = index as Tool
	tool_buttons[index].button_pressed = true
	canvas.queue_redraw()

func is_dirty() -> bool:
	return image.get_data() != baseline

func to_ship() -> Array:
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		return []
	var cropped := image.get_region(used)
	return [{
		"type": "pixel_custom",
		"x": -floori(used.size.x / 16.0),
		"y": -floori(used.size.y / 16.0),
		"rotation": 0,
		"pixels": Marshalls.raw_to_base64(cropped.save_png_to_buffer()),
		"pixel_origin": [used.position.x, used.position.y],
	}]

func _record_change(before: Image) -> void:
	if before.get_data() == image.get_data():
		return
	undo_stack.append(before)
	if undo_stack.size() > MAX_HISTORY:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_history_buttons()

func _update_history_buttons() -> void:
	undo_button.disabled = undo_stack.is_empty()
	redo_button.disabled = redo_stack.is_empty()

func _undo() -> void:
	_finish_stroke()
	if undo_stack.is_empty():
		return
	redo_stack.append(image)
	image = undo_stack.pop_back()
	_refresh_image()
	_update_history_buttons()

func _redo() -> void:
	_finish_stroke()
	if redo_stack.is_empty():
		return
	undo_stack.append(image)
	image = redo_stack.pop_back()
	_refresh_image()
	_update_history_buttons()

func _clear_canvas() -> void:
	_finish_stroke()
	var before := image.duplicate()
	image.fill(Color.TRANSPARENT)
	_record_change(before)
	_refresh_image()

func _mirror_pixel(point: Vector2i) -> Vector2i:
	return Vector2i(CANVAS_SIZE.x - 1 - point.x, point.y)

func _in_canvas(point: Vector2i) -> bool:
	return Rect2i(Vector2i.ZERO, CANVAS_SIZE).has_point(point)

func _brush_rect(point: Vector2i) -> Rect2i:
	return Rect2i(point - Vector2i.ONE * floori((brush_width - 1) * 0.5), Vector2i.ONE * brush_width)

func _paint(point: Vector2i, colour: Color) -> void:
	var area := _brush_rect(point).intersection(Rect2i(Vector2i.ZERO, CANVAS_SIZE))
	image.fill_rect(area, colour)
	if mirror:
		image.fill_rect(Rect2i(_mirror_pixel(area.position + Vector2i(area.size.x - 1, 0)), area.size), colour)

func _paint_to(point: Vector2i) -> void:
	if last_pixel.x < 0:
		last_pixel = point
	var difference := point - last_pixel
	var steps := maxi(absi(difference.x), absi(difference.y))
	var colour := Color.TRANSPARENT if stroke_button == MOUSE_BUTTON_RIGHT or tool == Tool.ERASER else ink
	for i in range(steps + 1):
		var ratio := float(i) / maxi(steps, 1)
		_paint(Vector2i(Vector2(last_pixel).lerp(Vector2(point), ratio).round()), colour)
	last_pixel = point
	_refresh_image()

func _fill_region(seed: Vector2i, colour: Color) -> void:
	var target := image.get_pixelv(seed)
	if target == colour:
		return
	var remaining: Array[Vector2i] = [seed]
	image.set_pixelv(seed, colour)
	while not remaining.is_empty():
		var point: Vector2i = remaining.pop_back()
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbour: Vector2i = point + offset
			if not _in_canvas(neighbour):
				continue
			var neighbour_colour := image.get_pixelv(neighbour)
			if neighbour_colour == target or (target.a == 0.0 and neighbour_colour.a == 0.0):
				image.set_pixelv(neighbour, colour)
				remaining.append(neighbour)

func _fill(point: Vector2i) -> void:
	var before := image.duplicate()
	# Use the actual 8-bit swatch so marked pixels compare exactly during a fill.
	var colour := Color(ink.to_html())
	_fill_region(point, colour)
	if mirror:
		_fill_region(_mirror_pixel(point), colour)
	_record_change(before)
	_refresh_image()

func _finish_stroke() -> void:
	if stroke_button == MOUSE_BUTTON_NONE:
		return
	_record_change(stroke_before)
	stroke_before = null
	stroke_button = MOUSE_BUTTON_NONE
	last_pixel = Vector2i(-1, -1)

func _refresh_image() -> void:
	image_texture.update(image)
	canvas.queue_redraw()
	silhouette.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or get_viewport().gui_get_focus_owner() is LineEdit:
		return
	if event.is_command_or_control_pressed() and event.keycode in [KEY_Z, KEY_Y]:
		if event.shift_pressed or event.keycode == KEY_Y:
			_redo()
		else:
			_undo()
	elif not event.is_command_or_control_pressed() and event.keycode in [KEY_B, KEY_E, KEY_F, KEY_I]:
		_select_tool([KEY_B, KEY_E, KEY_F, KEY_I].find(event.keycode))
	else:
		return
	get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		panning = false
		_finish_stroke()

func _canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_update_canvas_geometry()
		var inside := canvas_rect.has_point(event.position)
		var point := Vector2i((event.position - canvas_rect.position) / pixel_size)
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before: Vector2 = (event.position - canvas_rect.position) / pixel_size
			zoom = clampf(zoom * (1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 24.0)
			_update_canvas_geometry()
			pan += event.position - (canvas_rect.position + before * pixel_size)
			_update_hover(event.position)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if not event.pressed and event.button_index == stroke_button:
				_finish_stroke()
			elif event.pressed and inside and stroke_button == MOUSE_BUTTON_NONE:
				canvas.grab_focus()
				if event.button_index == MOUSE_BUTTON_LEFT and tool == Tool.SAMPLE:
					var colour := image.get_pixelv(point)
					if colour.a > 0.0:
						_set_ink(Color(colour, 1.0))
						_select_tool(Tool.PENCIL)
				elif event.button_index == MOUSE_BUTTON_LEFT and tool == Tool.FILL:
					_fill(point)
				else:
					stroke_before = image.duplicate()
					stroke_button = event.button_index
					_paint_to(point)
		canvas.accept_event()
	elif event is InputEventMouseMotion:
		if panning:
			pan += event.relative
		_update_hover(event.position)
		if not panning and stroke_button != MOUSE_BUTTON_NONE:
			if hover_pixel.x >= 0:
				_paint_to(hover_pixel)
			else:
				last_pixel = Vector2i(-1, -1)
		canvas.accept_event()

func _update_hover(position: Vector2) -> void:
	_update_canvas_geometry()
	hover_pixel = Vector2i((position - canvas_rect.position) / pixel_size) if canvas_rect.has_point(position) else Vector2i(-1, -1)
	coordinates.text = "%d, %d   •   %d%%" % [hover_pixel.x, hover_pixel.y, roundi(zoom * 100.0)] if hover_pixel.x >= 0 else ""
	canvas.queue_redraw()

func _fit_artwork_on_first_resize() -> void:
	if canvas.size.x <= 180.0 or canvas.size.y <= 180.0:
		return
	canvas.resized.disconnect(_fit_artwork_on_first_resize)
	_fit_artwork()

func _fit_artwork() -> void:
	var used := image.get_used_rect()
	if used.size == Vector2i.ZERO:
		used = Rect2i((CANVAS_SIZE - Vector2i(80, 96)) / 2, Vector2i(80, 96))
	var focus := Rect2(used).grow(12.0)
	var fit := minf(canvas.size.x / focus.size.x, canvas.size.y / focus.size.y)
	var full_fit := minf(canvas.size.x / CANVAS_SIZE.x, canvas.size.y / CANVAS_SIZE.y)
	if full_fit <= 0.0:
		return
	zoom = clampf(fit / full_fit, 1.0, 18.0)
	pan = (Vector2(CANVAS_SIZE) * 0.5 - focus.get_center()) * full_fit * zoom
	canvas.queue_redraw()

func _update_canvas_geometry() -> void:
	var fit := minf(canvas.size.x / CANVAS_SIZE.x, canvas.size.y / CANVAS_SIZE.y)
	pixel_size = maxf(0.1, fit * zoom)
	var extent := Vector2(CANVAS_SIZE) * pixel_size
	canvas_rect = Rect2((canvas.size - extent) * 0.5 + pan, extent)

func _draw_canvas() -> void:
	_update_canvas_geometry()
	canvas.draw_rect(Rect2(Vector2.ZERO, canvas.size), Color("0b1521"))
	canvas.draw_rect(canvas_rect, Color("1c2a35"))
	canvas.draw_texture_rect(image_texture, canvas_rect, false)
	if show_grid:
		_draw_grid()
	if mirror:
		var axis_x := canvas_rect.get_center().x
		canvas.draw_line(Vector2(axis_x, canvas_rect.position.y), Vector2(axis_x, canvas_rect.end.y), Color("a98c64"), 1.0)
	if hover_pixel.x >= 0:
		var area := _brush_rect(hover_pixel) if tool in [Tool.PENCIL, Tool.ERASER] or stroke_button == MOUSE_BUTTON_RIGHT else Rect2i(hover_pixel, Vector2i.ONE)
		_draw_hover(area)
		if mirror and tool != Tool.SAMPLE:
			_draw_hover(Rect2i(_mirror_pixel(area.position + Vector2i(area.size.x - 1, 0)), area.size))

func _draw_grid() -> void:
	for axis in range(2):
		var other := 1 - axis
		var first := maxi(0, floori(-canvas_rect.position[axis] / pixel_size))
		var last := mini(CANVAS_SIZE[axis], ceili((canvas.size[axis] - canvas_rect.position[axis]) / pixel_size))
		for line in range(first, last + 1):
			if line % 8 != 0 and pixel_size < 5.0:
				continue
			var start := canvas_rect.position
			start[axis] += line * pixel_size
			var finish := start
			finish[other] += canvas_rect.size[other]
			canvas.draw_line(start, finish, Color(0.53, 0.69, 0.76, 0.23 if line % 8 == 0 else 0.12))

func _draw_hover(area: Rect2i) -> void:
	var rect := Rect2(canvas_rect.position + Vector2(area.position) * pixel_size, Vector2(area.size) * pixel_size)
	canvas.draw_rect(rect, Color("d8e8ee"), false, 1.0)

func _draw_silhouette() -> void:
	var area := Rect2(Vector2.ZERO, silhouette.size)
	silhouette.draw_rect(area, Color("0b1521"))
	silhouette.draw_rect(area, Color("344b59"), false, 1.0)
	var used := Rect2(image.get_used_rect())
	if not used.has_area():
		return
	var available := area.size - Vector2(20.0, 16.0)
	var fit := minf(available.x / used.size.x, available.y / used.size.y)
	var artwork_size := used.size * minf(fit, 3.0)
	silhouette.draw_texture_rect_region(image_texture, Rect2(area.get_center() - artwork_size * 0.5, artwork_size), used)

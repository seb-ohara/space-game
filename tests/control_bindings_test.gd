extends SceneTree

const BINDINGS := preload("res://scripts/key_bindings.gd")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const HANGAR := preload("res://scripts/hangar.gd")
const TEST_SETTINGS := "user://controls-rebinding-test.cfg"

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key, pressed := true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	return event

func _mouse(button: MouseButton, position := Vector2.ZERO, pressed := true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = position
	event.pressed = pressed
	return event

func _run() -> void:
	var config := ConfigFile.new()
	config.set_value("key_bindings", "weapon_2", KEY_M)
	BINDINGS.setup(config)
	assert(BINDINGS.pressed(_key(KEY_M), "weapon_2"), "Legacy integer bindings still load.")
	var shift_click := _mouse(MOUSE_BUTTON_LEFT)
	shift_click.shift_pressed = true
	assert(BINDINGS.pressed(shift_click, "flight_pan_drag") and not BINDINGS.pressed(shift_click, "flight_select"))
	assert(BINDINGS.conflict("flight_pan_drag", _mouse(MOUSE_BUTTON_LEFT)) == "flight_select")
	assert(BINDINGS.conflict("builder_place", _key(KEY_M)).is_empty(), "Flight and builder do not compete for the same input.")
	assert(BINDINGS.conflict("builder_place", _key(KEY_ESCAPE)) == "game_back")
	assert(not BINDINGS.accepts("flight_select", _mouse(MOUSE_BUTTON_WHEEL_UP)))
	assert(BINDINGS.accepts("flight_zoom_in", _mouse(MOUSE_BUTTON_WHEEL_UP)))
	assert(BINDINGS.released_trigger(_mouse(MOUSE_BUTTON_LEFT, Vector2.ZERO, false), shift_click))
	var shift := _key(KEY_SHIFT)
	shift.shift_pressed = true
	assert(BINDINGS.pressed(shift, "module_move_modifier"), "A standalone modifier works even if Godot reports its flag on press.")

	var game = load("res://main.tscn").instantiate()
	game.graphics_settings_path = TEST_SETTINGS
	root.add_child(game)
	await process_frame
	game._start_flight(GALAXY.create_map(123, 1), {}, {}, game.MODULES.generate_random_design(RandomNumberGenerator.new()))
	game.set_physics_process(false)
	game._open_settings()
	var settings: Control = game.settings_layer.get_child(0)
	settings._open_key_bindings()
	await process_frame
	settings.binding_buttons["flight_zoom_in"].pressed.emit()
	settings.binding_window.push_input(_mouse(MOUSE_BUTTON_WHEEL_DOWN, Vector2(12, 12)), true)
	assert(settings.rebinding_action == "flight_zoom_in", "Conflicts keep capture open.")
	settings.cancel_capture.pressed.emit()
	assert(settings.rebinding_action.is_empty())
	settings.binding_buttons["weapon_3"].pressed.emit()
	settings.binding_window.push_input(_mouse(MOUSE_BUTTON_XBUTTON1, Vector2(12, 12)), true)
	assert(settings.rebinding_action.is_empty(), "The binding window captures mouse buttons.")
	settings.binding_buttons["flight_zoom_in"].pressed.emit()
	var zoom_key := _key(KEY_U)
	zoom_key.alt_pressed = true
	settings.binding_window.push_input(zoom_key, true)
	assert(settings.rebinding_action.is_empty(), "The binding window captures key chords.")
	settings.binding_window.close_requested.emit()
	game._close_settings()
	await process_frame
	game.set_physics_process(false)
	var saved := ConfigFile.new()
	assert(saved.load(TEST_SETTINGS) == OK)
	BINDINGS.setup(saved)
	assert(BINDINGS.pressed(zoom_key, "flight_zoom_in") and not BINDINGS.pressed(_key(KEY_U), "flight_zoom_in"))
	assert(not BINDINGS.pressed(_key(KEY_3), "weapon_3"))
	var point := root.get_visible_rect().size * 0.5
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON1, point), true)
	assert(game.selected_weapon == 3, "A mouse button can activate a former keyboard-only action.")
	game._set_camera_zoom(sqrt(game._minimum_camera_zoom() * game._maximum_camera_zoom()))
	var old_zoom: float = game.camera_zoom_target
	root.push_input(_mouse(MOUSE_BUTTON_WHEEL_UP, point), true)
	assert(game.camera_zoom_target == old_zoom, "The old wheel binding no longer zooms.")
	root.push_input(zoom_key, true)
	assert(game.camera_zoom_target > old_zoom, "A key chord can activate a former mouse-only action.")
	BINDINGS.set_binding("flight_select", _mouse(MOUSE_BUTTON_XBUTTON2))
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON2, point), true)
	assert(game.rts_dragging)
	root.push_input(_mouse(MOUSE_BUTTON_LEFT, point, false), true)
	assert(game.rts_dragging, "Releasing the old button must not terminate the new drag.")
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON2, point, false), true)
	assert(not game.rts_dragging)
	BINDINGS.set_binding("game_back", _mouse(MOUSE_BUTTON_XBUTTON2))
	root.push_input(_key(KEY_ESCAPE), true)
	assert(not is_instance_valid(game.settings_layer))
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON2, point), true)
	assert(is_instance_valid(game.settings_layer))
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON2, point), true)
	assert(not is_instance_valid(game.settings_layer))
	game.free()
	BINDINGS.setup(ConfigFile.new())

	var hangar := HANGAR.new()
	root.add_child(hangar)
	await process_frame
	var builder := hangar.builder
	BINDINGS.set_binding("builder_place", _mouse(MOUSE_BUTTON_XBUTTON1))
	point = builder._grid_center()
	root.push_input(_mouse(MOUSE_BUTTON_LEFT, point), true)
	root.push_input(_mouse(MOUSE_BUTTON_LEFT, point, false), true)
	assert(builder.parts.is_empty())
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON1, point), true)
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON1, point, false), true)
	assert(builder.parts.size() == 1 and builder.edit_trigger == null)
	BINDINGS.set_binding("builder_undo", _mouse(MOUSE_BUTTON_XBUTTON2))
	root.push_input(_mouse(MOUSE_BUTTON_XBUTTON2, point), true)
	assert(builder.parts.is_empty())
	BINDINGS.set_binding("builder_place", _key(KEY_P))
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	root.push_input(_key(KEY_P), true)
	root.push_input(_key(KEY_P, false), true)
	assert(builder.parts.size() == 1 and builder.edit_trigger == null, "A key can place a part at the pointer.")
	BINDINGS.setup(ConfigFile.new())
	assert(BINDINGS.pressed(_mouse(MOUSE_BUTTON_LEFT), "builder_place"))
	hangar.free()
	DirAccess.remove_absolute(TEST_SETTINGS)
	print("Control binding checks passed")
	quit()

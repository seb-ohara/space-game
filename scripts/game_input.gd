extends RefCounted
## Transitional controller: operates on the game node, which still owns shared state.

var game

func _init(owner) -> void:
	game = owner

func _input(event: InputEvent) -> void:
	if not game.game_started:
		if is_instance_valid(game.settings_layer) and event.is_action_pressed("ui_cancel"):
			var menu = game.settings_layer.get_child(0)
			if menu.rebinding_action.is_empty() and not is_instance_valid(menu.binding_window):
				game._close_settings()
				game.get_viewport().set_input_as_handled()
		return
	if is_instance_valid(game.hangar_layer):
		return
	if is_instance_valid(game.settings_layer):
		var settings_menu: Control = game.settings_layer.get_child(0)
		if not settings_menu.rebinding_action.is_empty():
			return
	if game.camera_dragging:
		if event is InputEventMouseMotion:
			game._pan_camera(-event.relative)
			game._queue_flight_redraw()
			game.get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			game.camera_dragging = false
			game.get_viewport().set_input_as_handled()
			return
	if game.hyperjump_context_button.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			game._close_hyperjump_chart()
			game.get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and not game.hyperjump_context_button.get_global_rect().has_point(event.position):
			game._close_hyperjump_chart()
	if game.radial_menu_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game.radial_menu_open = false
			game.get_viewport().set_input_as_handled()
			game._queue_flight_redraw()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var distance: float = event.position.distance_to(game.radial_menu_position)
			game.radial_menu_open = false
			if event.button_index == MOUSE_BUTTON_LEFT and distance >= 18.0 and distance <= game.RADIAL_MENU_RADIUS:
				if event.position.y < game.radial_menu_position.y:
					game._toggle_sustained_boost()
			game.get_viewport().set_input_as_handled()
			game._queue_flight_redraw()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("cycle_target") and game.control_mode == 1 and not is_instance_valid(game.settings_layer) and not game.radial_menu_open:
		game._cycle_target()
		game.get_viewport().set_input_as_handled()
		game._queue_flight_redraw()
		return
	if event is InputEventKey and event.is_action("boost_recenter") and not event.echo and game.control_mode == 0 and game.hyperjump_time < 0.0:
		game._ensure_ship_cache()
		if game.has_flight_controls and not game.simulation_clock.paused and not is_instance_valid(game.settings_layer):
			if game.sustained_boost_enabled:
				if event.pressed:
					game._set_sustained_boost(false)
			elif event.pressed and not game.boost_charging:
				game.boost_charging = true
				game.boost_charge = 0.0
			elif not event.pressed and game.boost_charging:
				game._launch_boost()
			game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.is_action("fire") and not event.echo and game.control_mode == 0 and not is_instance_valid(game.settings_layer):
		game.firing = event.pressed and not game.simulation_clock.paused and not game._combat_locked()
		game.get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(game.fleet_context_menu) and game.fleet_context_menu.visible:
			game.fleet_context_menu.hide()
			game.get_viewport().set_input_as_handled()
			return
		if is_instance_valid(game.settings_layer):
			game._close_settings()
		else:
			game._open_settings()
		game.get_viewport().set_input_as_handled()
		return
	# Stop firing even when the pointer is over a menu control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if game.rts_dragging:
			game._finish_rts_selection(event.position)
		else:
			game.firing = false

func _unhandled_input(event: InputEvent) -> void:
	if game.radial_menu_open and event is InputEventMouseMotion:
		game.queue_redraw()
		return
	if event is InputEventMouseMotion and game.rts_dragging:
		game.rts_drag_end = event.position
		game._queue_flight_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed("recenter") or (game.control_mode == 1 and event.is_action_pressed("boost_recenter")):
			game.camera_following = true
		elif event.is_action_pressed("cycle_target"):
			game._cycle_target()
		else:
			var matched = false
			for weapon in range(1, 6):
				if event.is_action_pressed("weapon_%d" % weapon):
					game.selected_weapon = weapon
					matched = true
					break
			if not matched:
				return
		game.get_viewport().set_input_as_handled()
		game._queue_flight_redraw()
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step = pow(game.CAMERA_ZOOM_STEP, event.factor if event.factor > 0.0 else 1.0)
			var zoom_factor = step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step
			game.camera_zoom_target = clampf(game.camera_zoom_target * zoom_factor, game._minimum_camera_zoom(), game._maximum_camera_zoom())
			game.camera_zoom_focus = event.position
			game.get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			game.camera_dragging = true
			game.rts_dragging = false
			game.firing = false
			game.get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var system_index = game._system_at_screen(event.position)
			if system_index >= 0:
				game._show_hyperjump_context(system_index, event.position)
				game.get_viewport().set_input_as_handled()
				return
		if game.hyperjump_time >= 0.0 and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			game.get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			var margin = Vector2.ONE * (game.RADIAL_MENU_RADIUS + 4.0)
			game.radial_menu_position = event.position.clamp(margin, (game.get_viewport_rect().size - margin).max(margin))
			game.radial_menu_open = true
			game.rts_dragging = false
			game.firing = false
			game.get_viewport().set_input_as_handled()
			game._queue_flight_redraw()
			return
		if game.sustained_boost_enabled and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			game._steer_sustained_boost(event.position)
			game.get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			game.rts_dragging = true
			game.rts_drag_start = event.position
			game.rts_drag_end = event.position
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if not game.selected_fleet.is_empty():
				game._rts_issue_order(event.position)
			elif game.control_mode == 0:
				game._select_target_at(game._screen_to_world(event.position, false))
			game.get_viewport().set_input_as_handled()
			game._queue_flight_redraw()


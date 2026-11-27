extends RefCounted
## Transitional controller: operates on the game node, which still owns shared state.

const BINDINGS := preload("res://scripts/key_bindings.gd")
const TRACKPAD_PIXELS_PER_ZOOM_STEP := 32.0

var game
var drag_trigger: InputEvent
var last_pointer := Vector2.INF

func _init(owner) -> void:
	game = owner

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		last_pointer = event.position
	if is_instance_valid(game.hangar_layer):
		return
	var back := BINDINGS.pressed(event, "game_back") and BINDINGS.shortcut_allowed(event, game.get_viewport())
	if is_instance_valid(game.settings_layer):
		var menu: Control = game.settings_layer.get_child(0)
		if back and (not is_instance_valid(menu.binding_window) or not menu.binding_window.visible):
			game._close_settings()
			game.get_viewport().set_input_as_handled()
		return
	if not game.game_started:
		return
	if back and not game.order_target_request.is_empty():
		game._cancel_order_target()
		game.get_viewport().set_input_as_handled()
		return
	if game.camera_dragging or game.rts_dragging:
		if event is InputEventMouseMotion and game.camera_dragging:
			game._pan_camera(-event.relative)
			game._queue_flight_redraw()
			game.get_viewport().set_input_as_handled()
			return
		if BINDINGS.released_trigger(event, drag_trigger):
			if game.camera_dragging:
				game.camera_dragging = false
			else:
				game._finish_rts_selection(_pointer(event))
			drag_trigger = null
			game.get_viewport().set_input_as_handled()
			return
	if game.hyperjump_context_button.visible:
		if back:
			game._close_hyperjump_chart()
			game.get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and not game.hyperjump_context_button.get_global_rect().has_point(event.position):
			game._close_hyperjump_chart()
	if game.radial_menu_open:
		var select := BINDINGS.pressed(event, "flight_select")
		if back or select or BINDINGS.pressed(event, "flight_order") or BINDINGS.pressed(event, "flight_queue") or BINDINGS.pressed(event, "flight_radial"):
			var position := _pointer(event)
			var distance: float = position.distance_to(game.radial_menu_position)
			game.radial_menu_open = false
			if select and distance >= 18.0 and distance <= game.RADIAL_MENU_RADIUS and position.y < game.radial_menu_position.y:
				if game.hyperjump_time >= 0.0:
					game._cancel_hyperjump()
				else:
					game._toggle_sustained_boost()
			game.get_viewport().set_input_as_handled()
			game._queue_flight_redraw()
			return
	# Tab must be handled before GUI focus navigation; mouse shortcuts go through the GUI first.
	if event is InputEventKey and BINDINGS.pressed(event, "cycle_target") and not game.radial_menu_open:
		game._cycle_target()
		game.get_viewport().set_input_as_handled()
		game._queue_flight_redraw()
		return
	if back:
		game._open_settings()
		game.get_viewport().set_input_as_handled()

func _pointer(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return event.position
	return last_pointer if last_pointer.is_finite() else game.get_viewport().get_mouse_position()

func _unhandled_input(event: InputEvent) -> void:
	if game.radial_menu_open and event is InputEventMouseMotion:
		game.queue_redraw()
		return
	if event is InputEventMouseMotion and game.rts_dragging:
		game.rts_drag_end = event.position
		game._queue_flight_redraw()
		return
	if event is InputEventGesture:
		if game.radial_menu_open or game.rts_dragging or game.camera_dragging:
			return
		if event is InputEventPanGesture and not is_zero_approx(event.delta.y):
			var steps: float = -event.delta.y / TRACKPAD_PIXELS_PER_ZOOM_STEP
			_zoom_camera(pow(game.CAMERA_ZOOM_STEP, steps), event.position)
		elif event is InputEventMagnifyGesture and event.factor > 0.0 and not is_equal_approx(event.factor, 1.0):
			_zoom_camera(event.factor, event.position)
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed() or event.is_echo():
		return
	if BINDINGS.pressed(event, "recenter") or BINDINGS.pressed(event, "boost_recenter"):
		game._center_camera_on_selection()
	elif BINDINGS.pressed(event, "cycle_target"):
		game._cycle_target()
	else:
		for weapon in range(1, 6):
			if BINDINGS.pressed(event, "weapon_%d" % weapon):
				game.selected_weapon = weapon
				game.get_viewport().set_input_as_handled()
				game._queue_flight_redraw()
				return
		_handle_pointer_action(event)
		return
	game.get_viewport().set_input_as_handled()
	game._queue_flight_redraw()

func _handle_pointer_action(event: InputEvent) -> void:
	var position := _pointer(event)
	var order := BINDINGS.pressed(event, "flight_order")
	var queue := BINDINGS.pressed(event, "flight_queue")
	if order and not game.order_target_request.is_empty():
		game._pick_order_target(position)
	elif BINDINGS.pressed(event, "flight_zoom_in") or BINDINGS.pressed(event, "flight_zoom_out"):
		var step := pow(game.CAMERA_ZOOM_STEP, event.factor if BINDINGS.is_wheel(event) and event.factor > 0.0 else 1.0)
		_zoom_camera(step if BINDINGS.pressed(event, "flight_zoom_in") else 1.0 / step, position)
		return
	elif BINDINGS.pressed(event, "flight_pan_drag"):
		game.camera_dragging = true
		game.rts_dragging = false
		game.firing = false
		drag_trigger = event
	elif order or queue:
		var system_index: int = game._system_at_screen(position)
		if system_index >= 0:
			game._show_hyperjump_context(system_index, position)
		elif game.hyperjump_time < 0.0:
			if game.sustained_boost_enabled and not game.selected_fleet.is_empty():
				game._steer_sustained_boost(position)
			elif not game.selected_fleet.is_empty():
				game._rts_issue_order(position, queue)
			else:
				game._select_target_at(game._screen_to_world(position, false))
	elif BINDINGS.pressed(event, "flight_radial"):
		if game.selected_fleet.is_empty():
			game._show_order_notice("Select a ship first.")
		else:
			var margin: Vector2 = Vector2.ONE * (game.RADIAL_MENU_RADIUS + 4.0)
			game.radial_menu_position = position.clamp(margin, (game.get_viewport_rect().size - margin).max(margin))
			game.radial_menu_open = true
			game.rts_dragging = false
			game.firing = false
	elif BINDINGS.pressed(event, "flight_select"):
		if not game.camera_dragging:
			game.rts_dragging = true
			game.rts_drag_start = position
			game.rts_drag_end = position
			drag_trigger = event
	else:
		return
	game.get_viewport().set_input_as_handled()
	game._queue_flight_redraw()

func _zoom_camera(factor: float, focus: Vector2) -> void:
	game.camera_zoom_target = clampf(game.camera_zoom_target * factor, game._minimum_camera_zoom(), game._maximum_camera_zoom())
	game.camera_zoom_focus = focus
	game.get_viewport().set_input_as_handled()

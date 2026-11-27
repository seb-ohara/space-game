extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const FLIGHT := preload("res://main.tscn")
const STEP := 1.0 / 60.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := GALAXY.create_map(7419, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [
		_ship(Vector2.ZERO), _ship(Vector2(2200, 0))]})
	game.set_physics_process(false)
	game.set_process(false)
	await physics_frame
	var first: Dictionary = game.fleet[0]
	var wing: Dictionary = game.fleet[1]
	var start: PackedFloat64Array = first.galaxy_position
	game.camera_zoom = 0.01
	var original_camera: Vector2 = game._camera_center()
	_click(game._world_to_screen(game._ship_local(wing)))
	assert(game.active_fleet_index == 1 and game.selected_fleet == [1])
	assert(game._camera_center() == original_camera and game.camera_zoom == 0.01)
	_recenter()
	assert(game.camera_following and game._camera_center() == game._ship_local(wing))

	game.camera_zoom = 0.2
	var destination: Vector2 = game.ship_position + Vector2(300, 0)
	var empty_screen: Vector2 = game._world_to_screen(destination)
	_click(empty_screen)
	assert(game.selected_fleet.is_empty() and wing.orders.is_empty())
	assert(game._fleet_command_selection().is_empty())
	game._toggle_sustained_boost()
	assert(not game.sustained_boost_enabled)
	_click(game._world_to_screen(game.ship_position))
	_click(empty_screen, MOUSE_BUTTON_RIGHT)
	assert(first.orders.is_empty() and wing.orders.size() == 1)
	_toggle_boost(game)
	_click(empty_screen)
	assert(game.selected_fleet.is_empty() and game.sustained_boost_enabled and not game.boost_destination_active)
	_click(empty_screen, MOUSE_BUTTON_RIGHT)
	assert(not game.boost_destination_active)
	_click(game._world_to_screen(game.ship_position))
	_click(empty_screen, MOUSE_BUTTON_RIGHT)
	assert(game.sustained_boost_enabled and game.boost_destination.is_equal_approx(destination))
	_click(empty_screen + Vector2(0, 80))
	assert(game.selected_fleet.is_empty() and game.boost_destination_active and game.boost_destination.is_equal_approx(destination))
	_click(game._world_to_screen(game.ship_position))
	var boost_accel: float = game.BOOST_TRAVEL_ACCELERATION * game._current_ship().acceleration
	game.velocity = Vector2(game._boost_approach_speed(300.0, boost_accel), 0)
	for tick in range(96):
		game._step_flight(STEP)
		if not game.sustained_boost_enabled:
			break
	assert(game.active_fleet_index == 1 and game.selected_fleet == [1])
	assert(first.galaxy_position == start and first.navigation.mode == "idle")
	assert(not game.sustained_boost_enabled and game.velocity == Vector2.ZERO)
	assert(game.ship_position.is_equal_approx(destination))
	assert(wing.orders[0].state == "suspended")

	# Switching focus mid-boost does not transfer the destination or resume the old order early.
	_toggle_boost(game)
	destination = game.ship_position + Vector2(300, 0)
	_click(game._world_to_screen(destination), MOUSE_BUTTON_RIGHT)
	game.velocity = Vector2(480, 0)
	game.camera_zoom = 0.01
	_click(game._world_to_screen(game._ship_local(first)))
	assert(game.active_fleet_index == 0 and not game.sustained_boost_enabled)
	assert(wing.navigation.mode == "boost" and wing.navigation.has("target"))
	for tick in range(96):
		game._update_owned_fleet(STEP)
		if wing.navigation.mode == "idle":
			break
	assert(wing.navigation.mode == "idle" and wing.velocity == Vector2.ZERO)
	assert(STATE.relative(wing.galaxy_position, game.galaxy_origin).is_equal_approx(destination))

	# Exiting boost by hand keeps braking below normal cruise speed.
	_toggle_boost(game)
	var stats: Dictionary = game._current_ship()
	game.velocity = Vector2(game.top_speed * float(stats.speed) * 0.75, 0)
	_toggle_boost(game)
	for tick in range(60):
		game._step_flight(STEP)
		if not game.boost_decelerating:
			break
	assert(not game.boost_decelerating and game.velocity == Vector2.ZERO)

	# Drag selection keeps both ships available for a shared movement order.
	_recenter()
	game.camera_zoom = 0.025
	var first_screen: Vector2 = game._world_to_screen(game.ship_position)
	var wing_screen: Vector2 = game._world_to_screen(game._ship_local(wing))
	_mouse(first_screen.min(wing_screen) - Vector2(20, 20), MOUSE_BUTTON_LEFT, true)
	_mouse(first_screen.max(wing_screen) + Vector2(20, 20), MOUSE_BUTTON_LEFT, false)
	assert(game.active_fleet_index == 0 and game.selected_fleet == [0, 1])
	_click(first_screen + Vector2(0, 100), MOUSE_BUTTON_RIGHT)
	assert(first.orders.size() == 1 and wing.orders.size() == 1)
	assert(first.orders[0].type == "move" and wing.orders[0].type == "move")

	# Explicit move targeting also uses right click, while left click clears selection.
	empty_screen = first_screen + Vector2(0, -100)
	var old_order: Dictionary = first.orders[0].duplicate(true)
	game._open_fleet()
	game.fleet_list.select(0)
	game._fleet_panel_order("move", 0.0, false, false)
	_click(empty_screen)
	assert(game.selected_fleet.is_empty() and not game.order_target_request.is_empty() and first.orders[0] == old_order)
	_click(empty_screen, MOUSE_BUTTON_RIGHT)
	assert(game.order_target_request.is_empty() and first.orders.size() == 1 and first.orders[0] != old_order)

	_click(first_screen)
	assert(game.selected_fleet == [0])
	game._execute_hyperjump(0, 1)
	assert(game.hyperjump_time >= 0.0)
	var jump_target: PackedFloat64Array = game.hyperjump_galaxy_target.duplicate()
	_click(empty_screen)
	assert(game.selected_fleet.is_empty() and game.active_fleet_index == 0)
	assert(game.hyperjump_time >= 0.0 and game.hyperjump_destination == 1 and game.hyperjump_galaxy_target == jump_target)
	game.free()
	print("Fleet selection and boost checks passed")
	quit()

func _recenter() -> void:
	var event := InputEventKey.new()
	event.keycode = InputMap.action_get_events("boost_recenter")[0].keycode
	event.pressed = true
	root.push_input(event, true)

func _toggle_boost(game: Node) -> void:
	_click(game.get_viewport_rect().size * 0.5, MOUSE_BUTTON_MIDDLE)
	assert(game.radial_menu_open)
	_click(game.radial_menu_position - Vector2(0, 30))

func _click(position: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	_mouse(position, button, true)
	_mouse(position, button, false)

func _mouse(position: Vector2, button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _ship(position: Vector2) -> Dictionary:
	return {"name": "Test ship", "parts": MODULES.default_design(), "position": position, "heading": 0.0,
		"hull": 100.0, "shield": 0.0, "shield_delay": 0.0}

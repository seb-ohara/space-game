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
	var start: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var remote: Vector2 = map.systems[1].center - start
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": start, "fleet": [_ship(Vector2.ZERO), _ship(remote)]})
	game.set_physics_process(false)
	game.set_process(false)
	var pilot: Dictionary = game.fleet[0]
	var wing: Dictionary = game.fleet[1]
	var original: PackedFloat64Array = wing.galaxy_position
	assert(pilot.id != wing.id and game.ship_registry.find(wing.id) == wing)
	assert(wing.owner_id == "player" and not wing.design_id.is_empty())
	assert(game.fleet_views.is_empty())
	assert(game.ship_registry.nearby(original, 1000.0).size() == 1)
	wing.cargo.iron = 9
	game.iron = 3
	wing.navigation = {"mode": "move", "target": STATE.absolute(original, Vector2(2000, 0))}
	await physics_frame
	game._update_owned_fleet(STEP)
	assert(wing.galaxy_position[0] > original[0] and wing.galaxy_position[0] - original[0] < 1.0)
	var before_rebase: PackedFloat64Array = wing.galaxy_position
	var far_shift := Vector2(345678.375, -6823.625)
	game._rebase_world(far_shift)
	assert(wing.galaxy_position == before_rebase)
	game._update_owned_fleet(STEP)
	assert(wing.galaxy_position[0] > before_rebase[0])
	assert(not game.fleet_views.has(wing.id))

	game._execute_hyperjump(0, 1)
	var pilot_start := STATE.absolute(game.galaxy_origin, game.ship_position)
	game.heading = game.ship_position.direction_to(game.hyperjump_arrival).angle()
	var previous_velocity: Vector2 = wing.velocity
	game._switch_fleet_control(1)
	assert(game.fleet[game.active_fleet_index].id == wing.id and game.fleet.size() == 2)
	assert(game.iron == 9 and pilot.cargo.iron == 3 and game.velocity == previous_velocity and game.rts_move_active)
	assert(pilot.navigation.mode == "jump" and game.hyperjump_time < 0.0)
	for tick in range(30):
		game._update_owned_fleet(STEP)
	assert(pilot.navigation.time > 0.0 and pilot.galaxy_position != pilot_start)
	var jump_time: float = pilot.navigation.time
	game._switch_fleet_control(0)
	assert(game.hyperjump_time == jump_time and game.iron == 3)
	assert(STATE.snapshot(wing).size() == STATE.FIELDS.size() + STATE.ORDER_DEFAULTS.size() and not wing.has("collision_body"))
	game.free()
	_exercise_spawned_miner(map, start)
	print("Ship registry checks passed")
	quit()

func _exercise_spawned_miner(map: Dictionary, origin: Vector2) -> void:
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	var source := _ship(Vector2.ZERO)
	source.parts = MODULES.to_fine_grid([
		{"type": "retro_plain", "x": -1, "y": -1, "width": 3, "height": 3, "rotation": 0},
		{"type": "command_deck", "layer": "interior", "x": -1, "y": -1, "width": 3, "rotation": 0},
		{"type": "reactor", "layer": "interior", "x": 0, "y": 0, "rotation": 0},
		{"type": "engine", "x": 0, "y": 2, "rotation": 0},
	])
	source.admin = {"cargo": 12, "module_slots": [{"type": "miner", "x": 0.5, "y": 0.3}]}
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [source]})
	game.set_physics_process(false)
	game.set_process(false)
	game._open_fleet()
	assert(game.fleet_orders.type_select.get_item_text(game.fleet_orders.type_select.selected) == "Mine asteroids")
	assert(game.fleet_orders.repeat_check.button_pressed and game.fleet_orders.queue_button.disabled)
	game.fleet_designs.select(0)
	game._spawn_fleet_ship()
	assert(game.fleet.size() == 2 and game.active_fleet_index == 0)
	var wing: Dictionary = game.fleet[1]
	assert(wing.fleet_stats.mining_rate > 0 and wing.fleet_stats.cargo_capacity == 12)
	assert(wing.admin == game.fleet[0].admin and wing.cargo.iron == 0)
	for existing_rock: Dictionary in game.asteroids:
		existing_rock.iron = 0
	var rock_position: Vector2 = game._ship_local(wing) + Vector2(0, 900)
	var rock_id := "test-spawned-miner-rock"
	game._add_asteroid(rock_position, 160.0, 1.0, rock_id)
	var rock: Dictionary = game.live_rocks[rock_id]
	var initial_ore: int = rock.iron
	game.fleet_dialog.hide()
	game.camera_following = false
	game.camera_galaxy_position = STATE.absolute(game.galaxy_origin, rock_position)
	game.camera_zoom = 0.05
	var click_position: Vector2 = game._world_to_screen(rock_position) + Vector2(8.5, 0)
	game.selected_fleet.assign([1])
	_click(click_position)
	assert(game.selected_asteroid == rock.index and game.selected_fleet == [1])
	wing.heading = PI / 2.0
	wing.velocity = Vector2(0, 600)
	var start: Vector2 = game._ship_local(wing)
	for tick in range(180):
		game._update_owned_fleet(STEP)
	var after_contact: Vector2 = game._ship_local(wing)
	assert(after_contact.y > start.y + 100.0)
	assert(after_contact.y <= rock_position.y - rock.radius * 0.90 and wing.velocity.y < 1.0)
	assert(game.fleet_colliders[wing.id].body.position == after_contact)

	game._add_asteroid(after_contact, 20.0, 1.0, "test-nearer-depleted-rock")
	game.live_rocks["test-nearer-depleted-rock"].iron = 0
	game._open_fleet()
	game.fleet_list.select(1)
	game._fleet_panel_order("mine", 2.0, false, false)
	assert(game.order_target_request.is_empty() and wing.orders.size() == 1)
	assert(game.fleet_dialog.visible and game.fleet_orders.current_order.text == "Mine 2 iron")
	assert(wing.orders[0].target_entity_id == "" and game.selected_fleet == [1])
	game._update_owned_fleet(STEP)
	assert(wing.orders[0].target_entity_id == rock_id)
	var saw_mining_target := false
	for tick in range(240):
		game._update_owned_fleet(STEP)
		if game._fleet_mining_target(wing) == rock:
			saw_mining_target = true
		if wing.orders.is_empty():
			break
	assert(saw_mining_target and game._fleet_mining_target(wing).is_empty())
	assert(wing.last_order.state == "completed" and wing.cargo.iron == 2)
	assert(rock.iron == initial_ore - 2 and game.iron == 0 and game.active_fleet_index == 0)
	assert(game._selected_ship_cargo() == {"name": wing.name, "iron": 2, "tritium": 0, "capacity": 12, "contracts": 0})
	game.selected_fleet.clear()
	assert(game._selected_ship_cargo().is_empty())
	game._open_fleet()
	game.fleet_list.select(1)
	var camera_before_selection: Vector2 = game._camera_center()
	game.fleet_list.item_selected.emit(1)
	assert(game.active_fleet_index == 1 and game.selected_fleet == [1] and game.fleet_dialog.visible)
	assert(not game.camera_following and game._camera_center() == camera_before_selection)
	game.iron = 4
	assert(game._selected_ship_cargo().iron == 4)
	game._rts_issue_order(game._world_to_screen(game.ship_position + Vector2(500, 0)))
	assert(wing.orders.size() == 1 and wing.orders[0].type == "move")
	assert(not InputMap.has_action("flight_forward") and not InputMap.has_action("flight_left"))
	game._cancel_fleet_orders(1)
	game.fleet_dialog.hide()
	game.camera_zoom = 0.1
	# The miner should be able to work without moving from beyond its old reach.
	var mining_start: Vector2 = game.ship_position
	var distant_rock: Vector2 = mining_start + Vector2(1100, 0)
	var distant_id := "test-mining-at-range"
	game._add_asteroid(distant_rock, 100.0, 1.0, distant_id)
	game.live_rocks[distant_id].iron = 1
	var second_id := "test-next-deposit"
	rock.iron = 0
	game._add_asteroid(mining_start + Vector2(-410, 0), 100.0, 1.0, second_id)
	click_position = game._world_to_screen(distant_rock)
	assert(game.selected_weapon == 1)
	_click(click_position)
	assert(wing.orders.is_empty() and "Right-click" in game.order_status_label.text)
	game.iron = 12
	_click(click_position, MOUSE_BUTTON_RIGHT)
	assert(wing.orders.is_empty() and "Cargo hold is full" in game.order_status_label.text)
	game.iron = 4
	_click(click_position, MOUSE_BUTTON_RIGHT)
	assert(wing.orders.size() == 1 and wing.orders[0].type == "mine" and wing.orders[0].repeat)
	assert(wing.orders[0].target_entity_id == distant_id and game.selected_weapon == 1)
	var order_id: String = wing.orders[0].id
	game.tritium = 4
	assert(game._submit_fleet_order(1, "wait", null, 1.0, false, true))
	var second_target := ""
	for tick in range(480):
		game._step_flight(STEP)
		if wing.orders[0].type == "wait":
			break
		assert(wing.orders[0].id == order_id)
		if wing.orders[0].target_entity_id != distant_id:
			second_target = wing.orders[0].target_entity_id
			assert(wing.orders[0].progress.mined >= 1)
	assert(second_target == second_id and game.depleted_ore[distant_id] == 0)
	assert(game.iron == 8 and game.iron == wing.cargo.iron)
	assert(wing.last_order.id == order_id and wing.last_order.state == "completed")
	assert("Mined 4 iron" in wing.last_order.reason and wing.orders[0].type == "wait")
	assert(game.ship_position.distance_to(mining_start) < 1.0)
	game._open_fleet()
	var panel = game.fleet_orders
	assert("12 / 12" in panel.cargo_label.text and not panel.queue_button.disabled)
	panel.type_select.select(panel.ORDER_TYPES.find("stop"))
	panel.type_select.item_selected.emit(panel.type_select.selected)
	panel.queue_button.pressed.emit()
	assert(wing.orders.size() == 2 and "Stop ship" in panel.queue_label.text)
	panel.replace_button.pressed.emit()
	assert(wing.orders.size() == 1 and panel.current_order.text == "Stop ship" and not panel.queue_label.visible)
	assert(wing.last_order.type == "wait" and wing.last_order.state == "cancelled")
	game.free()

func _click(position: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		root.push_input(event, true)

func _ship(position: Vector2) -> Dictionary:
	return {"name": "Test ship", "parts": MODULES.default_design(), "position": position, "heading": 0.0,
		"hull": 100.0, "shield": 0.0, "shield_delay": 0.0}

extends SceneTree

const FLIGHT := preload("res://main.tscn")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const TUNING := preload("res://scripts/debug_tuning.gd")
const SEED := 7419

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sample := TUNING.new()
	for tick in 300:
		sample.sample(float(tick))
	assert(is_equal_approx(sample.average_speed(), 149.5))
	sample.sample(500.0)
	assert(is_equal_approx(sample.average_speed(), 149.5 + 500.0 / 300.0) and sample.peak_speed == 500.0)
	sample.reset_samples()
	assert(sample.average_speed() == 0.0 and sample.peak_speed == 0.0)

	var map := GALAXY.create_map(SEED, 5)
	var distance: float = map.systems[0].center.distance_to(map.systems[1].center)
	var game := FLIGHT.instantiate()
	root.add_child(game)
	current_scene = game
	game._start_flight(map, {}, {}, MODULES.default_design())
	game._register_ship({"name": "Railgun wing", "parts": MODULES.preset_design(MODULES.SMALL_FIGHTER),
		"position": game.ship_position + Vector2(1000, 0), "heading": 0.0, "hull": 95.0, "shield": 0.0, "shield_delay": 0.0,
		"admin": {"module_slots": [{"type": "railgun", "x": 0.5, "y": 0.3}]}})
	assert(game._debug_spawn_enemy_design({"parts": MODULES.default_design()}, 1, 600.0, true) == 0)
	game._set_simulation_rate(0)
	var campaign := game
	var position: Vector2 = campaign.ship_position
	var clock_before: float = campaign.elapsed
	campaign.iron = 17 # Unsaved campaign state should survive opening and closing Debug.
	_press_debug_button(campaign, "Debug · F8")
	await _finish_switch()
	game = current_scene
	assert(game != campaign and game.game_started and game.debug_sandbox and game.save_slot.is_empty())
	assert(game.debug_menu.visible and game.debug_menu.tabs.get_tab_count() == 5 and not game.is_physics_processing())
	assert(not campaign.visible and not campaign.can_process() and not campaign.is_physics_processing())
	assert(campaign.get_children().all(func(node: Node): return not node is CanvasLayer or not node.visible))
	var f8 := InputEventKey.new()
	f8.keycode = KEY_F8
	f8.pressed = true
	game.debug_menu.window_input.emit(f8)
	assert(not game.debug_menu.visible and game.is_physics_processing() and game.is_processing_unhandled_input())
	game._input(f8)
	assert(game.debug_menu.visible and not game.is_physics_processing())
	game._launch_debug_flight(0.5)
	await _finish_switch()
	game = current_scene
	var scaled_distance: float = game.solar_system.systems[0].center.distance_to(game.solar_system.systems[1].center)
	assert(is_equal_approx(scaled_distance, distance * 0.5))
	assert(is_equal_approx(distance, map.systems[0].center.distance_to(map.systems[1].center)))
	assert(game.solar_system.system_contents(0).edge == GALAXY.form_system(SEED, map.systems[0], GALAXY.VERSION).edge)
	assert(game.fleet.size() == 1)
	await _test_named_enemies(game)

	var base: Dictionary = game._custom_stats().duplicate()
	var speed_control: SpinBox = game.debug_menu.factor_fields.speed
	speed_control.value = 2.0
	assert(is_equal_approx(game._custom_stats().normal_speed, base.normal_speed * 2.0))
	assert(is_equal_approx(game.fleet[0].fleet_stats.normal_speed, base.normal_speed * 2.0))
	var kind: String = game.custom_parts[0].type
	game.debug_tuning.blocks[kind] = {"mass": 2.0}
	game._debug_refresh_tuning()
	assert(game._custom_stats().mass > base.mass)
	game._debug_set_velocity(1000.0, 30.0)
	assert(is_equal_approx(game.velocity.length(), 1000.0 * game.DISPLAY_KM_SPEED_UNIT))
	assert(is_equal_approx(rad_to_deg(game.angular_velocity), 30.0))
	game.player_hull = 1.0
	game._debug_refill()
	assert(game.player_hull == game._player_max_hull())
	game._spawn_enemy_wave()
	assert(not game.enemies.is_empty() and not game._enemy_waves_enabled())
	game.debug_tuning.waves = true
	assert(game._enemy_waves_enabled())

	var solar = game.solar_system
	var orbiters: Array = solar._build_system_orbiters(0, false)
	var planet = orbiters[0]
	var moon = null
	for orbiter in orbiters:
		if orbiter.parent != null:
			moon = orbiter
			break
	assert(moon != null)
	var center: Vector2 = solar.system_centers[0]
	var clock := 1234.0
	for orbiter in orbiters:
		solar._update_position(orbiter, center, clock)
	var original_planet: Vector2 = planet.center
	var original_moon: Vector2 = moon.center
	solar.set_orbit_rates(clock, 0.0, 0.0)
	for orbiter in orbiters:
		solar._update_position(orbiter, center, clock + 100.0)
	assert(planet.center == original_planet and moon.center == original_moon)

	game.debug_menu.hide()
	assert(game.is_physics_processing())
	await physics_frame
	await physics_frame
	assert(game.debug_tuning.average_speed() > 0.0)
	game._open_hangar()
	assert(game.hangar_layer.get_child(0).builder.library_read_only)
	game._close_hangar()
	await process_frame
	game._launch_debug_flight(2.0)
	await _finish_switch()
	game = current_scene
	assert(game.debug_spacing == 2.0 and game.debug_tuning.factor("speed") == 2.0)
	assert(game.debug_campaign_designs.size() == 1 and game.debug_campaign_designs[0].name == "Railgun wing")
	assert(game._save_galaxy() and game.save_slot.is_empty())
	_press_debug_button(game.debug_menu, "Return to campaign")
	game.debug_menu.confirm.confirmed.emit()
	await _finish_switch()
	assert(current_scene == campaign and campaign.game_started and campaign.visible and campaign.can_process())
	assert(campaign.iron == 17 and campaign.ship_position == position and campaign.elapsed == clock_before)
	assert(campaign.simulation_clock.paused and not campaign.is_physics_processing())
	assert(campaign.get_children().any(func(node: Node): return node is CanvasLayer and node.visible))
	# Keyboard entry follows the same path and Settings can also return to the campaign.
	campaign._set_simulation_rate(5)
	campaign._input(f8)
	await _finish_switch()
	assert(current_scene.debug_menu.visible and current_scene.debug_tuning.factor("speed") == 1.0)
	current_scene._save_from_settings(true)
	await _finish_switch()
	assert(current_scene == campaign and campaign.iron == 17)
	assert(campaign.is_physics_processing() and Engine.physics_ticks_per_second == campaign.SIMULATION_CLOCK.TICKS_PER_SECOND * 5)
	print("Debug flight checks passed")
	quit()

func _finish_switch() -> void:
	for frame in 3:
		await process_frame

func _test_named_enemies(game: Node) -> void:
	var menu = game.debug_menu
	var preset := {}
	for index in menu.enemy_designs.size():
		var entry: Dictionary = menu.enemy_designs[index]
		if entry.name == "Railgun wing":
			menu.enemy_picker.select(index)
		if entry.id == "preset/" + MODULES.SMALL_FIGHTER:
			preset = entry
	assert(menu.enemy_designs[menu.enemy_picker.selected].name == "Railgun wing" and not preset.is_empty())
	_press_debug_button(menu, "Spawn hostile ships")
	assert(game.enemies.size() == 1 and game.enemy_visuals.get_child_count() == 1)
	var enemy: Dictionary = game.enemies[0]
	assert(enemy.name == "Railgun wing" and enemy.hostile and enemy.alive and enemy.max_health == 95.0)
	assert(enemy.turrets.size() == 1 and enemy.turrets[0].part.turret == "railgun" and not enemy.hull_shapes.is_empty())
	var enemy_position: Vector2 = enemy.position
	assert(Vector2.from_angle(enemy.heading).dot(enemy_position.direction_to(game.ship_position)) > 0.99)
	enemy.fire_cooldown = 0.0
	game._update_combat(1.0 / 60.0)
	assert(game.projectiles.any(func(shot: Dictionary): return not shot.friendly and shot.get("kind", "") == "railgun"))
	assert(game._debug_spawn_enemy_design(preset, 2, 650.0, false) == 2)
	assert(game.enemies[1].turrets.is_empty() and game.enemies[2].turrets.is_empty())
	assert(game.enemies[1].position != game.enemies[2].position)
	assert(game._debug_spawn_enemy_design(preset, 1, 300.0, true) == 1 and game.enemies[3].turrets[0].part.turret == "laser")
	var hull := [{"type": "retro_plain", "fine_grid": true, "x": 0, "y": 0, "rotation": 0, "width": 4, "height": 4}]
	assert(game._debug_spawn_enemy_design({"name": "Hull target", "parts": hull}, 1, 450.0, false) == 1)
	var target: Dictionary = game.enemies[4]
	assert(game._enemy_hull_contact(target.position - Vector2(50, 0), target.position + Vector2(50, 0), target) != null)
	game._set_camera_zoom(game._minimum_camera_zoom())
	game._redraw_flight()
	await process_frame
	await process_frame
	_press_debug_button(menu, "Clear enemies and projectiles")
	assert(game.enemies.is_empty() and game.projectiles.is_empty() and game.enemy_visuals.get_child_count() == 0)

func _press_debug_button(menu: Node, caption: String) -> void:
	for button: Button in menu.find_children("*", "Button", true, false):
		if button.text == caption:
			button.pressed.emit()
			return
	assert(false, "Missing debug button: " + caption)

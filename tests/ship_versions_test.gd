extends SceneTree

const FLIGHT := preload("res://main.tscn")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const CATALOG := preload("res://scripts/ships/ship_version_catalog.gd")
const LIBRARY := preload("res://scripts/ship_design_library.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var normal_dir := OS.get_user_data_dir()
	var test_name := "drift-ship-versions-test-" + SAVES.new_id()
	ProjectSettings.set_setting("application/config/use_custom_user_dir", true)
	ProjectSettings.set_setting("application/config/custom_user_dir_name", test_name)
	var test_dir := OS.get_user_data_dir()
	assert(test_dir != normal_dir and test_dir.get_file() == test_name)
	assert(DirAccess.make_dir_recursive_absolute(test_dir) == OK)

	var map := GALAXY.create_map(7419, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var parts := MODULES.preset_design(MODULES.CARGO_SHIP)
	var fighter_parts := MODULES.preset_design(MODULES.SMALL_FIGHTER)
	_check_legacy_migration()
	var initial := {"active_ship": 0, "world_origin": origin, "fleet": [
		{"name": "Pilot", "parts": parts, "position": Vector2.ZERO, "heading": 0.0,
			"hull": 73.0, "shield": 20.0, "shield_delay": 0.0},
		{"name": "Wing", "parts": parts, "position": Vector2(3000, 1000), "heading": 0.0,
			"hull": 57.0, "shield": 15.0, "shield_delay": 0.0},
		{"name": "Fighter", "parts": fighter_parts, "position": Vector2(3000, -1000), "heading": 0.0,
			"hull": 57.0, "shield": 15.0, "shield_delay": 0.0},
	]}
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game._start_flight(map, {}, initial)
	game._set_simulation_rate(0)
	game.galaxy_name = "Ship version regression"
	var slot := SAVES.new_id()
	game.save_slot = slot
	# Versions and overrides survive even though their editing menu is suspended.
	assert(game._apply_ship_admin(0, {}, "Baseline"))
	assert(game._ship_admin_versions(game.fleet[0]).Baseline.is_empty())
	var changes := {"length_meters": MODULES.dimensions_meters(parts).y * 1.5,
		"speed": 25.0, "module_slots": [{"type": "miner", "x": 0.25, "y": 0.75}]}
	assert(game._apply_ship_admin(0, changes, "Mining test"))
	var versions: Dictionary = game._ship_admin_versions(game.fleet[0])
	assert(versions.size() == 2 and versions["Mining test"] == changes)
	assert(game._ship_capabilities(0).mining_rate > 0.0)
	assert(game._apply_ship_admin(0, {"speed": 30.0}))
	assert(game.fleet[0].admin.speed == 30.0 and versions["Mining test"].speed == 25.0)
	assert(not game._apply_ship_admin(0, {"speed": 40.0}, "mining test"))
	assert(not game._apply_ship_admin_version(2, "Mining test"))
	assert(game._set_default_ship_version(1, "Mining test"))
	assert(game.fleet[1].admin.is_empty())
	assert(game._apply_ship_admin_version(1, "Mining test"))
	assert(game.fleet[1].admin == versions["Mining test"] and game.fleet[0].admin.speed == 30.0)
	assert(game._apply_ship_admin_version(0, "Baseline"))
	assert(game.fleet[0].admin.is_empty() and game._ship_capabilities(0).mining_rate == 0.0)
	game.save_slot = ""
	assert(not game._apply_ship_admin(0, {"health": 1.0}, "Failed version"))
	assert(game.player_hull == 73.0 and game.fleet[0].admin.is_empty())
	assert(not game._ship_admin_versions(game.fleet[0]).has("Failed version"))
	assert(not game._set_default_ship_version(0, "Baseline"))
	game.free()

	var restored := FLIGHT.instantiate()
	root.add_child(restored)
	restored._load_game(slot)
	assert(restored.game_started and restored.fleet[0].admin.is_empty())
	assert(restored._ship_admin_versions(restored.fleet[0]) == versions)
	assert(restored.ship_version_catalog[MODULES.CARGO_SHIP].default == "Mining test")
	assert(restored.fleet[1].admin == versions["Mining test"] and restored.fleet[2].admin.is_empty())
	assert(not SAVES.read(slot).fleet[0].has("admin_versions"))
	restored._open_fleet()
	assert(restored.fleet_design_entries.is_empty(), "Legacy presets must not be offered to spawn")
	restored._open_hangar()
	assert(restored.hangar_layer.get_child(0).builder.parts.is_empty())
	assert(restored.fleet[0].parts == parts)
	restored._close_hangar()
	assert(restored._set_default_ship_version(0, ""))
	assert(SAVES.read(slot).ship_versions[MODULES.CARGO_SHIP].default.is_empty())
	restored.free()

	var editor_slot := _check_editor_start(map, parts)
	await process_frame
	assert(DirAccess.remove_absolute(LIBRARY.PATH) == OK)
	assert(SAVES.delete(slot))
	assert(SAVES.delete(editor_slot))
	assert(DirAccess.remove_absolute(SAVES.RECENT_PATH) == OK)
	assert(DirAccess.remove_absolute(SAVES.SAVE_DIR) == OK)
	assert(DirAccess.remove_absolute(test_dir) == OK)
	print("Ship version compatibility and editor launch checks passed")
	quit()

func _check_editor_start(map: Dictionary, legacy_parts: Array) -> String:
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game._start_new_game("Editor start regression", map, {})
	assert(not game.game_started and game.fleet.is_empty() and game.save_slot.is_empty())
	var editor = game.hangar_layer.get_child(0)
	var builder = editor.builder
	assert(builder.is_visible_in_tree() and builder.parts.is_empty())
	assert(builder._flight_performance().values().all(func(value: float) -> bool: return value == 0.0))
	builder._deploy()
	assert(not game.game_started, "An empty design cannot start a flight")
	var hull := MODULES.to_fine_grid([
		{"type": "retro_plain", "x": 0, "y": 0, "width": 3, "height": 3, "rotation": 0},
		{"type": "command_deck", "layer": "interior", "x": 0, "y": 0, "width": 3, "rotation": 0},
		{"type": "reactor", "layer": "interior", "x": 1, "y": 1, "rotation": 0},
		{"type": "engine", "x": 0, "y": 3, "rotation": 0},
	])
	builder.parts = hull
	assert(MODULES.stats(hull).thrust == 150.0)
	var one: Dictionary = builder._flight_performance()
	hull.append({"type": "engine", "fine_grid": true, "x": 8, "y": 12, "rotation": 0})
	var two: Dictionary = builder._flight_performance()
	for key in ["acceleration", "speed", "boost", "hyperdrive"]:
		assert(two[key] > one[key], key)
	assert(MODULES.validate(hull) == "" and MODULES.stats(hull).thrust == 300.0)
	assert(LIBRARY.write({"Legacy preset": legacy_parts, "My Design": hull}))
	editor._show_library()
	assert(editor.library_list.item_count == 1 and editor.library_list.get_item_text(0) == "My Design")
	editor._resume_editing()
	builder._deploy()
	assert(game.game_started and game.fleet.size() == 1 and game.custom_parts == hull)
	var flight: Dictionary = game._ship_capabilities(0)
	assert(is_equal_approx(two.speed * game.DISPLAY_KM_SPEED_UNIT, flight.normal_speed))
	assert(is_equal_approx(two.acceleration * game.DISPLAY_KM_SPEED_UNIT, flight.travel_acceleration))
	assert(is_equal_approx(two.boost * game.DISPLAY_KM_SPEED_UNIT, flight.boost))
	assert(is_equal_approx(two.hyperdrive * game.DISPLAY_KM_SPEED_UNIT, flight.hyperdrive))
	assert(SAVES.read(game.save_slot).fleet[0].parts == hull)
	var slot: String = game.save_slot
	game.free()
	return slot

func _check_legacy_migration() -> void:
	var first := {MODULES.CARGO_SHIP: {"Test": {"speed": 25.0}}}
	var second := {MODULES.CARGO_SHIP: {"test": {"speed": 30.0}}, MODULES.SMALL_FIGHTER: {"Test": {}}}
	var migrated := CATALOG.restore({"fleet": [{"admin_versions": first}, {"admin_versions": second}]})
	assert(CATALOG.valid(migrated))
	assert(migrated[MODULES.CARGO_SHIP].versions == {"Test": {"speed": 25.0}, "test (2)": {"speed": 30.0}})
	assert(migrated[MODULES.SMALL_FIGHTER].versions == {"Test": {}})

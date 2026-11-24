extends SceneTree

const LOADOUT = preload("res://scripts/ship_loadout.gd")
const MODULES = preload("res://scripts/ship_modules.gd")
const ADMIN = preload("res://scripts/ship_admin.gd")
const GAME = preload("res://scripts/game.gd")
const HANGAR = preload("res://scripts/hangar.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(LOADOUT.slots({}).size() == 4)
	assert(LOADOUT.slots({"module_slots": []}).is_empty())
	var slots := LOADOUT.resize_slots([], 2)
	assert(slots.size() == 2 and slots[0].type == "" and slots[1].type == "")
	slots[0].type = "laser"
	slots[0].x = 0.2
	assert(LOADOUT.slots({"module_slots": slots}) == slots)
	assert(LOADOUT.resize_slots(slots, 1).size() == 1)
	var bounds := Rect2(Vector2(-10, -20), Vector2(20, 40))
	assert(LOADOUT.local_position({"x": 0.0, "y": 1.0}, bounds, 2.0) == Vector2(-20, 40))
	assert(LOADOUT.local_position({"x": 0.5, "y": 0.5}, bounds, 1.0) == Vector2.ZERO)
	assert(LOADOUT.slots({"module_slots": [{"type": "unknown", "x": 4, "y": -2}]}) == [{"type": "", "x": 1.0, "y": 0.0}])
	var game = GAME.new()
	var parts := MODULES.preset_design(MODULES.SMALL_FIGHTER)
	var base: Dictionary = game._stats_with_admin(parts, {})
	var upgraded: Dictionary = game._stats_with_admin(parts, {"module_slots": [{"type": "shield"}, {"type": "shield_recharge"}]})
	assert(is_equal_approx(upgraded.shield, base.shield + 100.0))
	assert(is_equal_approx(upgraded.shield_recharge, base.shield_recharge + 2.0))
	game.free()
	var admin = ADMIN.new()
	admin.ships = [{"name": "Test", "values": {"length_meters": 16.0, "width": 8.0, "module_slots": slots}}]
	root.add_child(admin)
	assert(admin._slot_values().size() == 2)
	admin.place_slot(0, Vector2(0.25, 0.75))
	assert(admin._slot_values()[0].x == 0.25 and admin._slot_values()[0].y == 0.75)
	admin.slot_count.value = 3
	assert(admin._slot_values()[2].type == "")
	var emitted: Array = []
	admin.save_requested.connect(func(_index: int, changes: Dictionary): emitted.append(changes))
	await process_frame
	admin._save()
	assert(emitted.size() == 1 and emitted[0].module_slots.size() == 3)
	var file = FileAccess.open("user://loadout_test.tmp", FileAccess.WRITE)
	file.store_var(emitted[0])
	file.close()
	file = FileAccess.open("user://loadout_test.tmp", FileAccess.READ)
	var restored: Dictionary = file.get_var()
	file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://loadout_test.tmp"))
	assert(LOADOUT.slots(restored) == emitted[0].module_slots)
	admin.free()
	var hangar = HANGAR.new()
	hangar.current_parts = parts
	var cargo := MODULES.preset_design(MODULES.CARGO_SHIP)
	hangar.admin_ships = [
		{"name": "Test", "parts": parts, "values": {"length_meters": 16.0, "width": 8.0, "health": 100.0}},
		{"name": "Cargo", "parts": cargo, "values": {"length_meters": 60.0, "width": 20.0, "health": 100.0}},
	]
	hangar.current_ship_values = hangar.admin_ships[0].values
	root.add_child(hangar)
	await process_frame
	hangar.admin_view.show()
	hangar.ship_admin._select_ship(1)
	assert(hangar._preview_parts() == cargo)
	var rect: Rect2 = hangar._preview_ship_rect()
	var initial: Dictionary = hangar.ship_admin._slot_values()[0]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = rect.position + rect.size * Vector2(initial.x, initial.y)
	hangar._preview_input(click)
	assert(hangar.dragging_slot == 0)
	var motion := InputEventMouseMotion.new()
	motion.position = rect.position + rect.size * Vector2(0.45, 0.65)
	hangar._preview_input(motion)
	click.pressed = false
	click.position = motion.position
	hangar._preview_input(click)
	assert(hangar.dragging_slot == -1)
	var moved: Dictionary = hangar.ship_admin._slot_values()[0]
	assert(is_equal_approx(moved.x, 0.45) and is_equal_approx(moved.y, 0.65))
	var first_point: Vector2 = rect.position + rect.size * Vector2(moved.x, moved.y)
	var palette_data := {"module_type": "laser", "source_index": -1}
	assert(hangar.preview._can_drop_data(first_point, palette_data))
	hangar.preview._drop_data(first_point, palette_data)
	assert(hangar.ship_admin._slot_values()[0].type == "laser")
	var source: Dictionary = hangar._module_drag_data(first_point)
	var second: Dictionary = hangar.ship_admin._slot_values()[1]
	var second_point: Vector2 = rect.position + rect.size * Vector2(second.x, second.y)
	assert(hangar._can_drop_module(second_point, source))
	hangar._drop_module(second_point, source)
	assert(hangar.ship_admin._slot_values()[0].type == "")
	assert(hangar.ship_admin._slot_values()[1].type == "laser")
	var remove_module := InputEventMouseButton.new()
	remove_module.button_index = MOUSE_BUTTON_RIGHT
	remove_module.pressed = true
	remove_module.position = second_point
	hangar._preview_input(remove_module)
	assert(hangar.ship_admin._slot_values()[1].type == "")
	hangar.preview._drop_data(first_point, palette_data)
	assert(hangar.ship_admin._slot_values()[0].type == "laser")
	var saved: Array = []
	hangar.ship_admin.save_requested.connect(func(index: int, changes: Dictionary): saved.append([index, changes]))
	await process_frame
	hangar.ship_admin._save()
	assert(saved.size() == 1 and saved[0][0] == 1)
	assert(is_equal_approx(saved[0][1].module_slots[0].x, 0.45))
	assert(saved[0][1].module_slots[0].type == "laser")
	var remove_button: Button = hangar.ship_admin.slot_rows.get_child(0).get_child(1)
	remove_button.pressed.emit()
	assert(hangar.ship_admin._slot_values().size() == 3)
	assert(hangar.ship_admin._slot_values()[0].type == "")
	hangar.free()
	print("Ship loadout checks passed")
	quit()

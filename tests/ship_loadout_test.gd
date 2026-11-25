extends SceneTree

const LOADOUT = preload("res://scripts/ship_loadout.gd")
const MODULES = preload("res://scripts/ship_modules.gd")
const ADMIN = preload("res://scripts/ship_admin.gd")
const GAME = preload("res://scripts/game.gd")

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
	assert(LOADOUT.local_position({"x": 0.5, "y": 0.5}, bounds, 2.0) == Vector2.ZERO)
	assert(LOADOUT.slots({"module_slots": [{"type": "unknown", "x": 4, "y": -2}]}) == [{"type": "", "x": 1.0, "y": 0.0}])
	var game = GAME.new()
	var parts := MODULES.preset_design(MODULES.SMALL_FIGHTER)
	var base: Dictionary = game._stats_with_admin(parts, {})
	var upgraded: Dictionary = game._stats_with_admin(parts, {"module_slots": [{"type": "shield"}, {"type": "shield_recharge"}]})
	assert(is_equal_approx(upgraded.shield, base.shield + 100.0))
	assert(is_equal_approx(upgraded.shield_recharge, base.shield_recharge + 2.0))
	var built := MODULES.to_fine_grid([
		{"type": "retro_plain", "x": 0, "y": 0, "rotation": 0},
		{"type": "turret_base", "turret": "miner", "x": 1, "y": 0, "rotation": 0},
	])
	var profile: Dictionary = game._stats_with_admin(built, {})
	assert(profile.slots == [{"type": "miner", "x": 0.75, "y": 0.5}] and profile.mining_rate > 0)
	assert(game._stats_with_admin(built, {"module_slots": []}).mining_rate == 0.0)
	game.free()

	# The suspended admin panel remains available as a standalone component for compatibility.
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
	var restored: Variant = JSON.parse_string(JSON.stringify(emitted[0]))
	assert(LOADOUT.slots(restored) == emitted[0].module_slots)
	admin.free()
	print("Ship loadout checks passed")
	quit()

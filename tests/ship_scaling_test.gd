extends SceneTree

const MODULES = preload("res://scripts/ship_modules.gd")

func _initialize() -> void:
	var fighter := MODULES.preset_design(MODULES.SMALL_FIGHTER)
	var cargo := MODULES.preset_design(MODULES.CARGO_SHIP)
	_check_length(fighter, {}, 16.0)
	_check_length(cargo, {}, 60.0)
	_check_length(fighter, {"length_meters": 24.0}, 24.0)
	_check_length(cargo, {"length_meters": 90.0}, 90.0)
	var ratio := MODULES.bounds(cargo).size.y / MODULES.bounds(fighter).size.y
	assert(is_equal_approx(ratio, 60.0 / 16.0))
	print("Ship scaling checks passed; cargo/fighter length ratio: ", ratio)
	quit()

func _check_length(parts: Array, admin: Dictionary, expected: float) -> void:
	var bounds := MODULES.bounds(parts)
	var scale_factor := MODULES.length_scale(bounds.size.y / MODULES.WORLD_UNITS_PER_METER, admin)
	var part: Dictionary = parts[0]
	var rect := MODULES.preset_draw_rect(part, Vector2(part.x, part.y) * MODULES.CELL * scale_factor, scale_factor)
	assert(is_equal_approx(rect.size.y / MODULES.WORLD_UNITS_PER_METER, expected))
	assert(is_equal_approx(bounds.size.y * scale_factor / MODULES.WORLD_UNITS_PER_METER, expected))

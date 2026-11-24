extends Control

var drag_from_hardpoint: Callable
var can_drop_module: Callable
var drop_module: Callable

func _get_drag_data(at_position: Vector2) -> Variant:
	if not Input.is_key_pressed(KEY_SHIFT) or not drag_from_hardpoint.is_valid():
		return null
	var data: Variant = drag_from_hardpoint.call(at_position)
	if data != null:
		var ghost := Label.new()
		ghost.text = "Move module"
		set_drag_preview(ghost)
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return can_drop_module.is_valid() and can_drop_module.call(at_position, data)

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if drop_module.is_valid():
		drop_module.call(at_position, data)

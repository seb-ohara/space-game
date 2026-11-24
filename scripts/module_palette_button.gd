extends Button

const ICONS := preload("res://scripts/module_icons.gd")
var module_type := ""

func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_theme_constant_override("icon_max_width", 0)
	custom_minimum_size = Vector2(145, 34)
	tooltip_text = "Drag onto a hardpoint"

func _draw() -> void:
	ICONS.draw(self, Rect2(Vector2(8, (size.y - 20) * 0.5), Vector2(20, 20)), module_type, Color("62d8e7"))

func _get_drag_data(_at_position: Vector2) -> Variant:
	var ghost := Label.new()
	ghost.text = text.strip_edges()
	set_drag_preview(ghost)
	return {"module_type": module_type, "source_index": -1}

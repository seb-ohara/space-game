extends Button

var icon_kind := ""

func _draw() -> void:
	var center := size * 0.5
	var ink := Color("c8e9f5")
	match icon_kind:
		"fleet":
			for offset in [Vector2(0, -5), Vector2(-7, 5), Vector2(7, 5)]:
				var point: Vector2 = center + offset
				draw_polyline(PackedVector2Array([point + Vector2(0, -4), point + Vector2(-4, 4), point + Vector2(0, 2), point + Vector2(4, 4), point + Vector2(0, -4)]), ink, 1.5, true)
		"hangar":
			draw_polyline(PackedVector2Array([center + Vector2(-10, 8), center + Vector2(-10, -2), center + Vector2(0, -9), center + Vector2(10, -2), center + Vector2(10, 8), center + Vector2(-10, 8)]), ink, 1.5, true)
			draw_polyline(PackedVector2Array([center + Vector2(-5, 8), center + Vector2(-5, 1), center + Vector2(5, 1), center + Vector2(5, 8)]), ink, 1.5, true)
		"settings":
			draw_arc(center, 7, 0, TAU, 32, ink, 1.5, true)
			draw_arc(center, 2.5, 0, TAU, 20, ink, 1.5, true)
			for index in range(8):
				var direction := Vector2.from_angle(index * TAU / 8.0)
				draw_line(center + direction * 7, center + direction * 10, ink, 2.0, true)

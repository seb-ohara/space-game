extends RefCounted

# Small vector icons are shared by the palette and the hardpoint markers.
static func draw(canvas: CanvasItem, area: Rect2, kind: String, color: Color) -> void:
	var c := area.get_center()
	var s := minf(area.size.x, area.size.y) / 24.0
	match kind:
		"laser":
			canvas.draw_line(c + Vector2(-8, 7) * s, c + Vector2(5, -6) * s, color, 3.0 * s, true)
			canvas.draw_line(c + Vector2(3, -9) * s, c + Vector2(9, -9) * s, color, 2.0 * s, true)
			canvas.draw_line(c + Vector2(9, -9) * s, c + Vector2(9, -3) * s, color, 2.0 * s, true)
		"machine_gun":
			for y in [-5, 0, 5]:
				canvas.draw_line(c + Vector2(-8, y) * s, c + Vector2(6, y) * s, color, 2.5 * s, true)
				canvas.draw_circle(c + Vector2(8, y) * s, 1.2 * s, color)
		"missile":
			var points := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(5, -3) * s, c + Vector2(5, 6) * s, c + Vector2(0, 4) * s, c + Vector2(-5, 6) * s, c + Vector2(-5, -3) * s])
			canvas.draw_colored_polygon(points, color)
			canvas.draw_line(c + Vector2(0, 7) * s, c + Vector2(0, 10) * s, color, 2.0 * s, true)
		"railgun":
			for x in [-4, 4]:
				canvas.draw_line(c + Vector2(x, -9) * s, c + Vector2(x, 8) * s, color, 2.5 * s, true)
			canvas.draw_line(c + Vector2(-7, 7) * s, c + Vector2(7, 7) * s, color, 2.0 * s, true)
		"miner":
			canvas.draw_line(c + Vector2(-8, 7) * s, c + Vector2(5, -6) * s, color, 3.0 * s, true)
			canvas.draw_line(c + Vector2(2, -9) * s, c + Vector2(9, -2) * s, color, 2.0 * s, true)
			canvas.draw_circle(c + Vector2(8, 7) * s, 2.0 * s, color)
		"shield", "shield_recharge":
			var shield := PackedVector2Array([c + Vector2(0, -10) * s, c + Vector2(8, -7) * s, c + Vector2(7, 3) * s, c + Vector2(0, 10) * s, c + Vector2(-7, 3) * s, c + Vector2(-8, -7) * s])
			shield.append(shield[0])
			canvas.draw_polyline(shield, color, 2.0 * s, true)
			if kind == "shield_recharge":
				canvas.draw_line(c + Vector2(-4, 0) * s, c + Vector2(4, 0) * s, color, 2.0 * s, true)
				canvas.draw_line(c + Vector2(0, -4) * s, c + Vector2(0, 4) * s, color, 2.0 * s, true)
		_:
			canvas.draw_line(c + Vector2(-5, 0) * s, c + Vector2(5, 0) * s, color, 2.0 * s, true)
			canvas.draw_line(c + Vector2(0, -5) * s, c + Vector2(0, 5) * s, color, 2.0 * s, true)

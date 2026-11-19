extends RefCounted

const MODULES := preload("res://scripts/ship_modules.gd")
const TEXEL_SIZE := MODULES.CELL / 16.0
const DECK_HEIGHT := 80
const ENGINE_HEIGHT := 50
const ARMOUR_HEIGHT := 123
const DETAIL_HEIGHT := 155
const COCKPIT_HEIGHT := 187

static func bake(material: ShaderMaterial, parts: Array, bounds: Rect2, part_scale: float) -> void:
	var center := bounds.get_center()
	# Include side-mounted details and some empty space for samples along the sun ray.
	var area := Rect2(bounds.position - center, bounds.size).grow(MODULES.CELL * 1.25)
	for part in parts:
		if MODULES.is_decoration(part) and part.type == "retro_antenna":
			var location := Vector2(part.x, part.y) * MODULES.CELL - center
			area = area.merge(Rect2(location - Vector2.ONE * MODULES.CELL * 0.5, Vector2.ONE * MODULES.CELL))
	var size := Vector2i((area.size / TEXEL_SIZE).ceil())
	var heights := PackedByteArray()
	heights.resize(size.x * size.y)
	var masks := {}
	for part in parts:
		var offset := Vector2(part.x, part.y) * MODULES.CELL - center
		var kind: String = part.type
		if MODULES.is_decoration(part):
			if not masks.has(kind):
				var texture: Texture2D = MODULES.DECORATION_TEXTURES[kind]
				masks[kind] = texture.get_image()
			var span := Vector2(MODULES.footprint(part).size) * MODULES.CELL
			var texture_center := offset + (span - Vector2.ONE * MODULES.CELL) * 0.5
			if kind == "retro_antenna":
				var antenna_size := MODULES.DECORATION_TEXTURES.retro_antenna.get_size()
				span = Vector2(antenna_size.x / antenna_size.y, 1.0) * MODULES.CELL
			if kind == "retro_bridge":
				var texture_size := MODULES.DECORATION_TEXTURES.retro_bridge.get_size()
				span = Vector2(1.4, 1.4 * texture_size.y / texture_size.x) * MODULES.CELL
			var pose := Transform2D(int(part.rotation) * PI / 2.0, Vector2(-1.0 if part.get("flip_x", false) else 1.0, 1.0), 0.0, Vector2.ZERO)
			var normalized_part := Transform2D(Vector2.RIGHT / span, Vector2.DOWN / span, -texture_center / span)
			var sample_uv := Transform2D(0.0, Vector2.ONE * 0.5) * pose.affine_inverse() * normalized_part
			var polygons := MODULES.material_polygons(part, offset)
			if kind == "retro_antenna":
				var half := span * 0.5
				var antenna_polygon := PackedVector2Array()
				for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					antenna_polygon.append(texture_center + pose * (corner * half))
				polygons = [antenna_polygon]
				var inverse_pose := pose.affine_inverse()
				var translate := Transform2D(0.0, -texture_center)
				var normalize := Transform2D(Vector2.RIGHT / span, Vector2.DOWN / span, Vector2.ONE * 0.5)
				sample_uv = normalize * inverse_pose * translate
			if kind == "retro_bridge":
				var half := span * 0.5
				polygons = [PackedVector2Array([offset + Vector2(-half.x, -half.y), offset + Vector2(half.x, -half.y), offset + Vector2(half.x, half.y), offset + Vector2(-half.x, half.y)])]
			for polygon in polygons:
				if kind == "cockpit":
					_stamp(heights, size, area.position, polygon, DECK_HEIGHT)
				var height := COCKPIT_HEIGHT if kind in ["cockpit", "armour_panel", "radar_dish"] else DETAIL_HEIGHT
				_stamp(heights, size, area.position, polygon, height, masks[kind], sample_uv)
		elif MODULES.is_exterior_structure(part) or MODULES.is_armour_overlay(part):
			var height := DECK_HEIGHT
			if MODULES.is_armour_overlay(part):
				height = DETAIL_HEIGHT
			elif MODULES.is_armour(kind) or MODULES.CARGO_TEXTURES.has(kind):
				height = ARMOUR_HEIGHT
			elif kind in MODULES.MAIN_ENGINE_TYPES:
				height = ENGINE_HEIGHT
			for polygon in MODULES.structural_polygons(part, offset):
				_stamp(heights, size, area.position, polygon, height)
			if part.has("turret"):
				var hub := PackedVector2Array()
				for spoke in range(12):
					hub.append(offset + Vector2.from_angle(TAU * float(spoke) / 12.0) * 11.0)
				_stamp(heights, size, area.position, hub, DETAIL_HEIGHT)
	var softened := _bevel_heights(heights, size)
	var pixels := PackedByteArray()
	pixels.resize(heights.size() * 2)
	for i in range(heights.size()):
		pixels[i * 2] = softened[i]
		pixels[i * 2 + 1] = heights[i]
	var image := Image.create_from_data(size.x, size.y, false, Image.FORMAT_RG8, pixels)
	material.set_shader_parameter("relief_map", ImageTexture.create_from_image(image))
	material.set_shader_parameter("relief_origin", area.position * part_scale)
	material.set_shader_parameter("relief_size", Vector2(size) * TEXEL_SIZE * part_scale)

static func _stamp(heights: PackedByteArray, size: Vector2i, origin: Vector2, polygon: PackedVector2Array, height: int, mask: Image = null, sample_uv: Transform2D = Transform2D.IDENTITY) -> void:
	# Each material section is convex, so each scan line covers one span.
	var points := PackedVector2Array()
	var top := INF
	var bottom := -INF
	for vertex in polygon:
		var point := (vertex - origin) / TEXEL_SIZE
		points.append(point)
		top = minf(top, point.y)
		bottom = maxf(bottom, point.y)
	var mask_size := Vector2(mask.get_size()) if mask != null else Vector2.ZERO
	for y in range(maxi(0, ceili(top - 0.5)), mini(size.y, ceili(bottom - 0.5))):
		var scan_y := float(y) + 0.5
		var left := INF
		var right := -INF
		for i in range(points.size()):
			var a := points[i]
			var b := points[(i + 1) % points.size()]
			if (a.y > scan_y) == (b.y > scan_y):
				continue
			var cross_x := lerpf(a.x, b.x, (scan_y - a.y) / (b.y - a.y))
			left = minf(left, cross_x)
			right = maxf(right, cross_x)
		var row := y * size.x
		for x in range(maxi(0, ceili(left - 0.5)), mini(size.x, ceili(right - 0.5))):
			if height <= heights[row + x]:
				continue
			if mask != null:
				var local_position := origin + Vector2(float(x) + 0.5, scan_y) * TEXEL_SIZE
				var uv := sample_uv * local_position
				var pixel := Vector2i((uv * mask_size).clamp(Vector2.ZERO, mask_size - Vector2.ONE))
				if mask.get_pixelv(pixel).a < 0.5:
					continue
			heights[row + x] = height

static func _bevel_heights(heights: PackedByteArray, size: Vector2i) -> PackedByteArray:
	# Soften height steps for normals. Keep the original heights for crisp contact shadows.
	var horizontal := heights.duplicate()
	for y in range(size.y):
		var row := y * size.x
		for x in range(1, size.x - 1):
			var index := row + x
			horizontal[index] = (heights[index - 1] + heights[index] * 2 + heights[index + 1]) >> 2
	var bevels := horizontal.duplicate()
	for y in range(1, size.y - 1):
		var row := y * size.x
		for x in range(size.x):
			var index := row + x
			bevels[index] = (horizontal[index - size.x] + horizontal[index] * 2 + horizontal[index + size.x]) >> 2
	return bevels

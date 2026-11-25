extends RefCounted

const MODULES := preload("res://scripts/ship_modules.gd")
const TEXEL_SIZE := MODULES.CELL / 16.0
const DECK_HEIGHT := 80
const ENGINE_HEIGHT := 50
const ARMOUR_HEIGHT := 123
const DETAIL_HEIGHT := 155
const COCKPIT_HEIGHT := 187
const SPRITE_EDGE_HEIGHT := 55
const SPRITE_RISE := 125

static func bake(material: ShaderMaterial, parts: Array, bounds: Rect2, part_scale: float) -> void:
	var center := bounds.get_center()
	# Include side-mounted details and some empty space for samples along the sun ray.
	var area := Rect2(bounds.position - center, bounds.size).grow(MODULES.CELL * 1.25)
	for part in parts:
		if MODULES.is_decoration(part) and part.type == "retro_antenna":
			var location := MODULES.mount_position(part) - center
			area = area.merge(Rect2(location - Vector2.ONE * MODULES.CELL * 0.5, Vector2.ONE * MODULES.CELL))
	var size := Vector2i((area.size / TEXEL_SIZE).ceil())
	var heights := PackedByteArray()
	heights.resize(size.x * size.y)
	var sprite_heights := PackedByteArray()
	var masks := {}
	for part in parts:
		var offset := MODULES.part_position(part) - center
		var kind: String = part.type
		if MODULES.PRESET_TEXTURES.has(kind):
			# Bake the fitted sprite's alpha silhouette separately from its attachments.
			if sprite_heights.is_empty():
				sprite_heights.resize(heights.size())
			var texture: Texture2D = MODULES.preset_texture(part)
			var rect := MODULES.preset_draw_rect(part, offset)
			var drawn_size := rect.size
			var top_left := rect.position
			var polygon := PackedVector2Array([top_left, top_left + Vector2(drawn_size.x, 0), top_left + drawn_size, top_left + Vector2(0, drawn_size.y)])
			var sample_uv := Transform2D(Vector2.RIGHT / drawn_size, Vector2.DOWN / drawn_size, -top_left / drawn_size)
			var mask: Image = texture.diffuse_texture.get_image() if texture is CanvasTexture else texture.get_image()
			_stamp(sprite_heights, size, area.position, polygon, SPRITE_EDGE_HEIGHT, mask, sample_uv, true)
		elif MODULES.is_decoration(part):
			if not masks.has(kind):
				var texture: Texture2D = MODULES.DECORATION_TEXTURES[kind]
				masks[kind] = texture.get_image()
			var cell_size := MODULES.cell_size_for(part)
			var span := Vector2(MODULES.footprint(part).size) * cell_size
			var texture_center := offset + (span - Vector2.ONE * cell_size) * 0.5
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
				polygons = [PackedVector2Array([texture_center + Vector2(-half.x, -half.y), texture_center + Vector2(half.x, -half.y), texture_center + Vector2(half.x, half.y), texture_center + Vector2(-half.x, half.y)])]
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
					hub.append(MODULES.mount_position(part) - center + Vector2.from_angle(TAU * float(spoke) / 12.0) * 11.0)
				_stamp(heights, size, area.position, hub, DETAIL_HEIGHT)
	if not sprite_heights.is_empty():
		_raise_sprite_hull(heights, sprite_heights, size)
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
	material.set_shader_parameter("hull_half_size", bounds.size * 0.5 * part_scale)

static func _raise_sprite_hull(heights: PackedByteArray, silhouette: PackedByteArray, size: Vector2i) -> void:
	# Estimate the depth inside the silhouette with a two-pass distance transform.
	# Narrow wings stay low while the broader fuselage rises to cast shadows.
	var distances := PackedInt32Array()
	distances.resize(silhouette.size())
	var stride := size.x
	for y in range(1, size.y - 1):
		for x in range(1, size.x - 1):
			var index := y * stride + x
			if silhouette[index] == 0:
				continue
			distances[index] = mini(
				mini(distances[index - 1], distances[index - stride]) + 3,
				mini(distances[index - stride - 1], distances[index - stride + 1]) + 4)
	var furthest := 0
	for y in range(size.y - 2, 0, -1):
		for x in range(size.x - 2, 0, -1):
			var index := y * stride + x
			if silhouette[index] == 0:
				continue
			var from_below := mini(
				mini(distances[index + 1], distances[index + stride]) + 3,
				mini(distances[index + stride - 1], distances[index + stride + 1]) + 4)
			distances[index] = mini(distances[index], from_below)
			furthest = maxi(furthest, distances[index])
	var crest := clampi(furthest, 15, 54)
	for index in range(silhouette.size()):
		if silhouette[index] > 0:
			var depth := float(distances[index])
			var hull_rise := SPRITE_RISE * smoothstep(0.0, float(crest), depth)
			var detail_rise := (silhouette[index] - SPRITE_EDGE_HEIGHT) * smoothstep(3.0, 10.0, depth)
			heights[index] = maxi(heights[index], SPRITE_EDGE_HEIGHT + roundi(hull_rise + detail_rise))

static func _stamp(heights: PackedByteArray, size: Vector2i, origin: Vector2, polygon: PackedVector2Array, height: int, mask: Image = null, sample_uv: Transform2D = Transform2D.IDENTITY, sprite_relief := false) -> void:
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
			if height <= heights[row + x] and not sprite_relief:
				continue
			var raised_height := height
			if mask != null:
				var local_position := origin + Vector2(float(x) + 0.5, scan_y) * TEXEL_SIZE
				var uv := sample_uv * local_position
				var pixel := Vector2i((uv * mask_size).clamp(Vector2.ZERO, mask_size - Vector2.ONE))
				var texel := mask.get_pixelv(pixel)
				if texel.a < 0.5:
					continue
				if sprite_relief:
					# Bright cockpit and panel details add a small step above the hull profile.
					raised_height += roundi(36.0 * smoothstep(0.32, 0.75, texel.get_luminance()))
			heights[row + x] = maxi(heights[row + x], raised_height)

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

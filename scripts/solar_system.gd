extends Node2D

const WORLD_SIZE := Vector2(1360000.0, 560000.0)
const WORLD_BOUNDS := Rect2(Vector2.ZERO, WORLD_SIZE)
const SUN_POSITION := Vector2(266000.0, 280000.0)
const SUN_RADIUS := 20000.0
const PLANET_ORBIT := 109000.0
const PLANET_PHASE := -0.4
const START_OFFSET := Vector2(-6030.0, 1800.0)
const ORBIT_COLOR := Color(0.52, 0.73, 0.85, 0.36)
const BODY_SHADER := preload("res://scripts/celestial_body.gdshader")
enum BodyKind { SUN, TERRESTRIAL, MOON, BLUE_DWARF, GAS_GIANT, ICE_PLANET }

const SYSTEMS := [
	{"name": "Sol", "center": SUN_POSITION, "radius": SUN_RADIUS, "extent": 2.65,
		"kind": BodyKind.SUN, "color": Color("ffd292"), "chart_radius": 234000.0},
	{"name": "Azure", "center": Vector2(1126000.0, 258000.0), "radius": 9000.0, "extent": 2.9,
		"kind": BodyKind.BLUE_DWARF, "color": Color("a2ddff"), "chart_radius": 95000.0},
]
const ORBITERS := [
	{"star": 0, "orbit": PLANET_ORBIT, "phase": PLANET_PHASE, "period": 2400.0, "segments": 1536,
		"radius": 5500.0, "extent": 1.06, "kind": BodyKind.TERRESTRIAL, "color": Color("65d3d6")},
	{"star": 0, "parent": 0, "orbit": 10800.0, "phase": 2.85, "period": 320.0, "segments": 384,
		"radius": 1320.0, "extent": 1.015, "kind": BodyKind.MOON, "color": Color("b9c5e1")},
	{"star": 0, "orbit": 207000.0, "phase": -1.22, "period": 6100.0, "segments": 2048,
		"radius": 9600.0, "extent": 1.045, "kind": BodyKind.GAS_GIANT, "color": Color("eaaa76")},
	{"star": 1, "orbit": 72000.0, "phase": 2.16, "period": 2650.0, "segments": 1024,
		"radius": 5400.0, "extent": 1.055, "kind": BodyKind.ICE_PLANET, "color": Color("c7c7f1")},
]

class Orbiter:
	var center := Vector2.ZERO
	var visual: ColorRect
	var track: Line2D

var stars: Array[ColorRect] = []
var orbiters: Array[Orbiter] = []
var last_zoom := 0.0
var planet_map_dots := PackedVector2Array()
var moon_map_dots := PackedVector2Array()

static func starting_position() -> Vector2:
	return SUN_POSITION + Vector2.from_angle(PLANET_PHASE) * PLANET_ORBIT + START_OFFSET

func _ready() -> void:
	var dot_texture := _make_dot_texture()
	planet_map_dots = _make_map_dots(48)
	moon_map_dots = _make_map_dots(12)
	var noise := FastNoiseLite.new()
	noise.seed = 29473
	noise.frequency = 0.017
	noise.fractal_octaves = 5
	var surface := NoiseTexture2D.new()
	surface.noise = noise
	surface.seamless = true
	for system: Dictionary in SYSTEMS:
		var star := _make_body(system, surface)
		star.position = system.center - star.size * 0.5
		stars.append(star)
	for definition: Dictionary in ORBITERS:
		var orbiter := Orbiter.new()
		orbiter.track = _make_orbit(definition.orbit, definition.segments, dot_texture)
		orbiter.visual = _make_body(definition, surface)
		move_child(orbiter.track, stars.size() + orbiters.size())
		orbiters.append(orbiter)
	_update_positions(0.0)

func update_view(clock: float, camera: Transform2D, visible_world: Rect2) -> void:
	transform = camera
	_update_positions(clock)
	var zoom := camera.x.length()
	for index in stars.size():
		var center: Vector2 = SYSTEMS[index].center
		var nearest := center.clamp(visible_world.position, visible_world.end)
		stars[index].visible = center.distance_squared_to(nearest) < pow(stars[index].size.x * 0.5, 2)
	for index in orbiters.size():
		var orbiter := orbiters[index]
		var definition: Dictionary = ORBITERS[index]
		if zoom != last_zoom:
			_size_orbit_dots(orbiter.track, definition.orbit, zoom)
		orbiter.track.visible = _orbit_intersects_view(orbiter.track.position, definition.orbit, orbiter.track.width, visible_world)
		orbiter.visual.visible = visible_world.intersects(Rect2(orbiter.visual.position, orbiter.visual.size))
		if orbiter.visual.visible:
			var star_center: Vector2 = SYSTEMS[definition.star].center
			(orbiter.visual.material as ShaderMaterial).set_shader_parameter("sunward", orbiter.center.direction_to(star_center))
	last_zoom = zoom

func nearest_system(point: Vector2) -> int:
	var closest := 0
	var best_distance := INF
	for index in SYSTEMS.size():
		var distance := point.distance_squared_to(SYSTEMS[index].center)
		if distance < best_distance:
			closest = index
			best_distance = distance
	return closest

func local_chart_at(point: Vector2, system_index: int) -> Rect2:
	var system: Dictionary = SYSTEMS[system_index]
	var half := Vector2.ONE * float(system.chart_radius)
	var chart := Rect2(system.center - half, half * 2.0)
	return chart if chart.has_point(point) else WORLD_BOUNDS

func light_direction_at(point: Vector2) -> Vector2:
	var direction := Vector2.ZERO
	var total_weight := 0.0
	for system: Dictionary in SYSTEMS:
		var offset: Vector2 = system.center - point
		var distance := maxf(offset.length(), system.radius)
		var weight := pow(float(system.radius) / distance, 2)
		direction += offset / distance * weight
		total_weight += weight
	return direction / total_weight

func draw_minimap(canvas: CanvasItem, chart: Transform2D, system_index: int) -> void:
	var map_scale := chart.x.x
	for index in orbiters.size():
		var definition: Dictionary = ORBITERS[index]
		if system_index >= 0 and definition.star != system_index:
			continue
		var track_radius := float(definition.orbit) * map_scale
		if track_radius < 2.0:
			continue
		canvas.draw_set_transform(chart * orbiters[index].track.position, 0.0, Vector2.ONE * track_radius)
		canvas.draw_multiline(moon_map_dots if definition.has("parent") else planet_map_dots, ORBIT_COLOR)
	canvas.draw_set_transform(Vector2.ZERO)
	for index in SYSTEMS.size():
		if system_index < 0 or index == system_index:
			var system: Dictionary = SYSTEMS[index]
			canvas.draw_circle(chart * system.center, maxf(2.5, system.radius * map_scale), system.color)
	for index in orbiters.size():
		var definition: Dictionary = ORBITERS[index]
		if system_index < 0 or definition.star == system_index:
			canvas.draw_circle(chart * orbiters[index].center, maxf(1.15, definition.radius * map_scale), definition.color)

func _update_positions(clock: float) -> void:
	for index in orbiters.size():
		var orbiter := orbiters[index]
		var definition: Dictionary = ORBITERS[index]
		var parent_center: Vector2 = orbiters[definition.parent].center if definition.has("parent") else SYSTEMS[definition.star].center
		orbiter.center = parent_center + _orbit_offset(clock, definition.phase, definition.period, definition.orbit)
		orbiter.track.position = parent_center
		orbiter.visual.position = orbiter.center - orbiter.visual.size * 0.5

func _orbit_offset(clock: float, phase: float, period: float, radius: float) -> Vector2:
	return Vector2.from_angle(phase + TAU * fposmod(clock, period) / period) * radius

func _orbit_intersects_view(center: Vector2, radius: float, width: float, view: Rect2) -> bool:
	var nearest := center.clamp(view.position, view.end)
	var farthest := (center - view.position).abs().max((center - view.end).abs())
	return center.distance_squared_to(nearest) <= pow(radius + width, 2) and farthest.length_squared() >= pow(radius - width, 2)

func _make_orbit(radius: float, segments: int, dot_texture: Texture2D) -> Line2D:
	var orbit := Line2D.new()
	var points := PackedVector2Array()
	for index in range(segments):
		points.append(Vector2.from_angle(TAU * index / segments) * radius)
	orbit.points = points
	orbit.closed = true
	orbit.default_color = ORBIT_COLOR
	orbit.texture = dot_texture
	orbit.texture_mode = Line2D.LINE_TEXTURE_TILE
	orbit.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	orbit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(orbit)
	return orbit

func _size_orbit_dots(orbit: Line2D, radius: float, zoom: float) -> void:
	var circumference := TAU * radius
	var dot_count := maxf(1.0, roundf(circumference * zoom / 15.0))
	orbit.width = circumference / (dot_count * 4.0)

func _make_dot_texture() -> ImageTexture:
	var image := Image.create_empty(32, 8, false, Image.FORMAT_RGBA8)
	var center := Vector2(image.get_size() - Vector2i.ONE) * 0.5
	for row in range(image.get_height()):
		for column in range(image.get_width()):
			var alpha := 1.0 - smoothstep(2.0, 3.7, Vector2(column, row).distance_to(center))
			image.set_pixel(column, row, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _make_map_dots(count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count):
		var angle := TAU * index / count
		points.append(Vector2.from_angle(angle))
		points.append(Vector2.from_angle(angle + TAU / count * 0.16))
	return points

func _make_body(definition: Dictionary, surface: Texture2D) -> ColorRect:
	var body := ColorRect.new()
	body.size = Vector2.ONE * float(definition.radius) * float(definition.extent) * 2.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var appearance := ShaderMaterial.new()
	appearance.shader = BODY_SHADER
	appearance.set_shader_parameter("surface_noise", surface)
	appearance.set_shader_parameter("body_kind", definition.kind)
	appearance.set_shader_parameter("disc_extent", definition.extent)
	body.material = appearance
	add_child(body)
	return body

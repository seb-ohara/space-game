extends Node2D

const WORLD_SIZE := Vector2(60000.0, 42000.0)
const SUN_POSITION := WORLD_SIZE * 0.5
const SUN_RADIUS := 2300.0
const PLANET_RADIUS := 1280.0
const MOON_RADIUS := 265.0
const PLANET_ORBIT := 14500.0
const MOON_ORBIT := 2250.0
const PLANET_PERIOD := 1200.0
const MOON_PERIOD := 160.0
const PLANET_PHASE := -0.4
const MOON_PHASE := 2.85
const START_OFFSET := Vector2(-1630.0, 490.0)
const SUN_COLOR := Color("ffc277")
const PLANET_COLOR := Color("65d3d6")
const MOON_COLOR := Color("b9c5e1")
const ORBIT_COLOR := Color(0.52, 0.73, 0.85, 0.36)
const BODY_SHADER := preload("res://scripts/celestial_body.gdshader")

var planet_position := Vector2.ZERO
var moon_position := Vector2.ZERO
var planet_path: Line2D
var moon_path: Line2D
var sun: ColorRect
var planet: ColorRect
var moon: ColorRect
var last_zoom := 0.0
var planet_map_dots := PackedVector2Array()
var moon_map_dots := PackedVector2Array()

static func starting_position() -> Vector2:
	return SUN_POSITION + Vector2.from_angle(PLANET_PHASE) * PLANET_ORBIT + START_OFFSET

func _ready() -> void:
	var dot_texture := _make_dot_texture()
	planet_path = _make_orbit(PLANET_ORBIT, 1024, dot_texture)
	planet_path.position = SUN_POSITION
	moon_path = _make_orbit(MOON_ORBIT, 256, dot_texture)
	planet_map_dots = _make_map_dots(48)
	moon_map_dots = _make_map_dots(12)
	var noise := FastNoiseLite.new()
	noise.seed = 29473
	noise.frequency = 0.017
	noise.fractal_octaves = 5
	var surface := NoiseTexture2D.new()
	surface.noise = noise
	surface.seamless = true
	sun = _make_body(SUN_RADIUS, 2.3, 0, surface)
	sun.position = SUN_POSITION - sun.size * 0.5
	planet = _make_body(PLANET_RADIUS, 1.06, 1, surface)
	moon = _make_body(MOON_RADIUS, 1.015, 2, surface)
	_update_positions(0.0)

func update_view(clock: float, camera: Transform2D, visible_world: Rect2) -> void:
	transform = camera
	_update_positions(clock)
	var zoom := camera.x.length()
	if zoom != last_zoom:
		last_zoom = zoom
		_size_orbit_dots(planet_path, PLANET_ORBIT, zoom)
		_size_orbit_dots(moon_path, MOON_ORBIT, zoom)
	planet_path.visible = _orbit_intersects_view(SUN_POSITION, PLANET_ORBIT, planet_path.width, visible_world)
	moon_path.visible = _orbit_intersects_view(planet_position, MOON_ORBIT, moon_path.width, visible_world)
	sun.visible = visible_world.intersects(Rect2(sun.position, sun.size))
	planet.visible = visible_world.intersects(Rect2(planet.position, planet.size))
	moon.visible = visible_world.intersects(Rect2(moon.position, moon.size))
	if planet.visible:
		_light_body(planet, planet_position)
	if moon.visible:
		_light_body(moon, moon_position)

func draw_minimap(canvas: CanvasItem, map_rect: Rect2) -> void:
	var map_scale := map_rect.size / WORLD_SIZE
	var sun_marker := map_rect.position + SUN_POSITION * map_scale
	var planet_marker := map_rect.position + planet_position * map_scale
	var moon_marker := map_rect.position + moon_position * map_scale
	canvas.draw_set_transform(sun_marker, 0.0, map_scale * PLANET_ORBIT)
	canvas.draw_multiline(planet_map_dots, ORBIT_COLOR)
	canvas.draw_set_transform(planet_marker, 0.0, map_scale * MOON_ORBIT)
	canvas.draw_multiline(moon_map_dots, ORBIT_COLOR)
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_circle(sun_marker, 4.0, SUN_COLOR)
	canvas.draw_circle(planet_marker, 2.8, PLANET_COLOR)
	canvas.draw_circle(moon_marker, 1.65, MOON_COLOR)

func _update_positions(clock: float) -> void:
	planet_position = SUN_POSITION + _orbit_offset(clock, PLANET_PHASE, PLANET_PERIOD, PLANET_ORBIT)
	moon_position = planet_position + _orbit_offset(clock, MOON_PHASE, MOON_PERIOD, MOON_ORBIT)
	moon_path.position = planet_position
	planet.position = planet_position - planet.size * 0.5
	moon.position = moon_position - moon.size * 0.5

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

func _make_body(radius: float, extent: float, kind: int, surface: Texture2D) -> ColorRect:
	var body := ColorRect.new()
	body.size = Vector2.ONE * radius * extent * 2.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var appearance := ShaderMaterial.new()
	appearance.shader = BODY_SHADER
	appearance.set_shader_parameter("surface_noise", surface)
	appearance.set_shader_parameter("body_kind", kind)
	appearance.set_shader_parameter("disc_extent", extent)
	body.material = appearance
	add_child(body)
	return body

func _light_body(body: ColorRect, center: Vector2) -> void:
	(body.material as ShaderMaterial).set_shader_parameter("sunward", center.direction_to(SUN_POSITION))

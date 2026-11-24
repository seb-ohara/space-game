extends Control

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const CLOUD := preload("res://scripts/galaxy_cloud.gd")
const INK := Color("081322")
const GRID := Color("21374b")
const TEXT := Color("a5bdcb")
const AMBER := Color("f3c78e")

var background_stars := PackedVector2Array()
var galaxy := {}
var formed := {}
var star_count := 0
var featured := -1
var cloud := CLOUD.new()
var foreground := Node2D.new()
var chart_camera := Transform2D.IDENTITY

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 31575
	for i in 230:
		background_stars.append(Vector2(rng.randf(), rng.randf()))
	clip_contents = true
	add_child(cloud)
	add_child(foreground)
	foreground.draw.connect(_draw_foreground)
	resized.connect(_refresh)
	_refresh()

func show_progress(data: Dictionary, placed: int, populated: Dictionary, index: int = -1) -> void:
	if not is_same(galaxy, data):
		cloud.configure(data)
	galaxy = data
	star_count = placed
	formed = populated
	featured = index
	_refresh()

func _refresh() -> void:
	queue_redraw()
	foreground.queue_redraw()
	if galaxy.is_empty() or (galaxy.systems.size() == 1 and featured == 0 and not GALAXY.is_wide_version(galaxy.generator_version)):
		cloud.hide()
		return
	var reserve := clampf(size.y * 0.30, 100.0, 180.0)
	var chart := Rect2(Vector2(24.0, 38.0), size - Vector2(48.0, reserve + 60.0))
	var world_size: Vector2 = galaxy.world_size
	var chart_scale := minf(chart.size.x / world_size.x, chart.size.y / world_size.y)
	chart_camera = Transform2D(0.0, Vector2.ONE * chart_scale, 0.0, chart.get_center() - world_size * chart_scale * 0.5)
	var growth := 1.31
	if star_count < galaxy.systems.size():
		var furthest := 0.0
		# Sol is placed first, while the remaining stars are revealed from the center out.
		if star_count > 1 and cloud.configured:
			furthest = ((galaxy.systems[star_count - 1].center - cloud.galaxy_center) / cloud.galaxy_scale).length()
		growth = maxf(0.12 + 0.20 * float(star_count) / galaxy.systems.size(), furthest + 0.14)
	cloud.show_cloud(chart_camera, 1.1 if chart_scale > 0.0 else 0.0, growth)

func _draw() -> void:
	if size.x < 100.0 or size.y < 120.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	for i in background_stars.size():
		var point := background_stars[i] * size
		draw_circle(point, 1.3 if i % 21 == 0 else 0.65, Color("b4cce6", 0.39 if i % 7 == 0 else 0.22), true, -1.0, true)

func _draw_foreground() -> void:
	if size.x < 100.0 or size.y < 120.0:
		return
	if galaxy.is_empty():
		_draw_atlas()
	else:
		_draw_map()
	foreground.draw_rect(Rect2(Vector2.ZERO, size), GRID, false, 1.0)

func _draw_atlas() -> void:
	# Draw the same orbital language used in the generation preview.
	var origin := size * Vector2(0.49, 0.48)
	var radius := minf(size.x, size.y) * 0.41
	for i in 5:
		foreground.draw_arc(origin, radius * (0.24 + i * 0.19), 0.0, TAU, 100, Color("2b485c"), 1.0, true)
	foreground.draw_line(origin - Vector2(radius, 0), origin + Vector2(radius, 0), GRID, 1.0, true)
	foreground.draw_line(origin - Vector2(0, radius), origin + Vector2(0, radius), GRID, 1.0, true)
	_draw_star(origin, AMBER, 12.0)
	var worlds := [Color("a5d9ff"), Color("d5a583"), Color("aface4")]
	for i in worlds.size():
		var point := origin + Vector2.from_angle(-0.8 + float(i) * 1.53) * radius * (0.43 + i * 0.19)
		foreground.draw_circle(point, 4.3 + i * 1.6, worlds[i], true, -1.0, true)
		foreground.draw_arc(point, 12.0 + i * 3.0, 0.0, TAU, 32, Color(worlds[i], 0.36), 1.0, true)

func _draw_map() -> void:
	var systems: Array = galaxy.systems
	if systems.size() == 1 and featured == 0 and not GALAXY.is_wide_version(galaxy.generator_version):
		var frame := Rect2(Vector2(20.0, size.y - 89.0), Vector2(size.x - 40.0, 76.0))
		_draw_system(frame, systems[0], formed[0], true)
		return
	var inset_height := clampf(size.y * 0.30, 100.0, 180.0)
	var chart_scale := chart_camera.x.length()
	if chart_scale <= 0.0:
		return
	foreground.draw_string(ThemeDB.fallback_font, Vector2(20.0, 25.0), "Galaxy map", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
	if int(galaxy.generator_version) == GALAXY.SPIRAL_VERSION and systems.size() > 1:
		_draw_spiral(chart_camera * (galaxy.world_size * 0.5), chart_scale)
	var small_points := systems.size() > 90
	var marker_size := 1.42 if small_points else 2.5
	for i in star_count:
		var star: Dictionary = systems[i]
		var point: Vector2 = chart_camera * star.center
		var tint: Color = star.color
		if i == 0 or i == featured:
			_draw_star(point, tint, 3.6 if i == 0 else 3.2)
			if i == featured:
				foreground.draw_arc(point, 7.5, 0.0, TAU, 20, Color(tint, 0.54), 1.0, true)
			foreground.draw_string(ThemeDB.fallback_font, point + Vector2(10.0, 5.0), star.name, HORIZONTAL_ALIGNMENT_LEFT, maxf(1.0, size.x - point.x - 22.0), 13, tint)
		elif formed.has(i):
			foreground.draw_circle(point, marker_size, tint, true, -1.0, true)
		else:
			foreground.draw_circle(point, marker_size * 0.8, Color(tint, 0.48), true, -1.0, true)

	if featured >= 0:
		var inset := Rect2(Vector2(20.0, size.y - inset_height - 13.0), Vector2(size.x - 40.0, inset_height))
		_draw_system(inset, systems[featured], formed[featured])

func _draw_spiral(center: Vector2, chart_scale: float) -> void:
	var pattern: Dictionary = galaxy.spiral
	var scale_factor: Vector2 = pattern.scale * chart_scale
	_draw_star(center, Color("caaf8f", 0.58), 3.0)
	for arm in 2:
		var points := PackedVector2Array()
		for step in range(65):
			var radius := lerpf(GALAXY.ARM_START, 1.0, float(step) / 64.0)
			points.append(center + GALAXY.spiral_point(radius, arm, pattern.rotation, pattern.winding) * scale_factor)
		foreground.draw_polyline(points, Color(GRID, 0.78), 1.0, true)

func _draw_system(frame: Rect2, star: Dictionary, contents: Dictionary, full_view := false) -> void:
	var top := frame.position.y
	foreground.draw_line(frame.position, frame.position + Vector2(frame.size.x, 0.0), GRID, 1.0)
	var origin := frame.position + Vector2(frame.size.x * 0.25, frame.size.y * 0.52)
	var edge := maxf(150000.0, float(contents.edge))
	var scale_factor := minf(frame.size.y * 0.45, frame.size.x * 0.23) / edge
	if full_view:
		origin = Vector2(size.x * 0.5, top * 0.52)
		scale_factor = minf(top, size.x) * 0.43 / edge
		foreground.draw_string(ThemeDB.fallback_font, Vector2(20.0, 25.0), "System map", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
	if contents.has("frost_line_au") and float(contents.ice_line) < edge:
		foreground.draw_arc(origin, maxf(0.0, float(contents.ice_line) * scale_factor), 0.0, TAU, 96, Color("508eaa", 0.56), 1.0, true)
	var moons := 0
	for planet: Dictionary in contents.planets:
		var point := _draw_orbit(origin, planet, scale_factor, GRID)
		var marker_size := clampf(float(planet.radius) / 3500.0, 1.6, 4.3) * (1.5 if full_view else 1.0)
		foreground.draw_circle(point, marker_size, planet.color, true, -1.0, true)
		if planet.get("rings", false):
			foreground.draw_set_transform(point, float(planet.axis_angle), Vector2(1.0, float(planet.ring_tilt)))
			foreground.draw_arc(Vector2.ZERO, marker_size * 1.8, 0.0, TAU, 24, Color(planet.color, 0.75), 1.0, true)
			foreground.draw_set_transform(Vector2.ZERO)
		moons += planet.moons.size()
		for moon: Dictionary in planet.moons:
			var moon_point := _draw_orbit(point, moon, scale_factor, Color(GRID, 0.74))
			foreground.draw_circle(moon_point, 1.2 if full_view else 0.85, moon.color, true, -1.0, true)
	for belt: Dictionary in contents.belts:
		# Show the short occupied arc, rather than a complete orbital ring.
		var belt_radius := float(belt.orbit) * scale_factor
		var half_angle: float = GALAXY.asteroid_field_half_angle(belt)
		for i in 16:
			var angle := float(belt.phase) + lerpf(-half_angle, half_angle, float(i) / 15.0)
			var point := origin + Vector2.from_angle(angle) * belt_radius
			foreground.draw_circle(point, 0.85 if full_view else 0.65, Color(AMBER, 0.73), true, -1.0, true)
	_draw_star(origin, star.color, clampf(float(star.radius) * scale_factor * 0.60, 3.2, 15.0))
	var text_x := frame.position.x + frame.size.x * (0.0 if full_view else 0.51)
	var text_width := frame.end.x - text_x
	var name_y := top + maxf(19.0, (frame.size.y - 43.0) * 0.5)
	foreground.draw_string(ThemeDB.fallback_font, Vector2(text_x, name_y), star.name, HORIZONTAL_ALIGNMENT_LEFT, text_width, 18, star.color)
	foreground.draw_string(ThemeDB.fallback_font, Vector2(text_x, name_y + 17.0), star.get("stage", "Stellar system"), HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, TEXT)
	var summary := "%d worlds · %d moons · %d fields" % [contents.planets.size(), moons, contents.belts.size()]
	foreground.draw_string(ThemeDB.fallback_font, Vector2(text_x, name_y + 33.0), summary, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, TEXT)
	var history: Array = contents.get("history", [])
	if not history.is_empty() or contents.has("frost_line_au"):
		var detail: String = history[0] if not history.is_empty() else "Frost line · %.2f AU" % contents.frost_line_au
		foreground.draw_string(ThemeDB.fallback_font, Vector2(text_x, name_y + 49.0), detail, HORIZONTAL_ALIGNMENT_LEFT, text_width, 12, AMBER)

func _draw_orbit(focus: Vector2, body: Dictionary, chart_scale: float, color: Color) -> Vector2:
	var major := float(body.orbit) * chart_scale
	var e := float(body.get("eccentricity", 0.0))
	var angle := float(body.get("orbit_angle", 0.0))
	var minor := major * sqrt(1.0 - e * e)
	var center := focus + Vector2(-major * e, 0.0).rotated(angle)
	var points := PackedVector2Array()
	var segments := clampi(ceili(major * 1.6), 14, 96)
	for i in range(segments + 1):
		points.append(center + (Vector2.from_angle(i * TAU / segments) * Vector2(major, minor)).rotated(angle))
	foreground.draw_polyline(points, color, 1.0, true)
	var anomaly := GALAXY.eccentric_anomaly(float(body.phase), e)
	return center + (Vector2.from_angle(anomaly) * Vector2(major, minor)).rotated(angle)

func _draw_star(center: Vector2, tint: Color, radius: float) -> void:
	foreground.draw_circle(center, radius * 2.7, Color(tint, 0.075), true, -1.0, true)
	foreground.draw_circle(center, radius * 1.8, Color(tint, 0.17), true, -1.0, true)
	foreground.draw_circle(center, radius, tint, true, -1.0, true)
	foreground.draw_circle(center, radius * 0.55, tint.lerp(Color.WHITE, 0.6), true, -1.0, true)

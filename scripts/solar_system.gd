extends Node2D

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const PLANET_ORBIT_SPEED_SCALE := 0.025
const MOON_ORBIT_SPEED_SCALE := 0.075
const MIN_TRACK_RADIUS_PIXELS := 3.0
const ORBIT_COLOR := Color(0.52, 0.73, 0.85, 0.36)
const BODY_SHADER := preload("res://scripts/celestial_body.gdshader")
# Orbit tracks stay drawn further out than the old cutoff, then body markers and
# names take over so worlds remain identifiable at system and stellar scales.
const ORBIT_MIN_ZOOM := 0.00003
const BODY_MIN_ZOOM := 0.000004
const ICON_BODY_FADE_NEAR := 3.5
const ICON_BODY_FADE_FAR := 8.5
const ICON_ORBIT_FADE_START := 18.0
const ICON_ORBIT_FADE_END := 38.0
const MOON_ICON_ORBIT_FADE_NEAR := 8.0
const MOON_ICON_ORBIT_FADE_FAR := 18.0
const PLANET_ICON_RADIUS := 3.0
const MOON_ICON_RADIUS := 2.0
const MINIMAP_LABEL_SIZE := 11
const MINIMAP_MOON_MARKER_ORBIT := 4.0
const MINIMAP_MOON_LABEL_ORBIT := 9.0

class Orbiter:
	var definition: Dictionary
	var parent: Orbiter
	var center := Vector2.ZERO
	var center_x := 0.0
	var center_y := 0.0
	var visual: ColorRect
	var track: Line2D
	var segments := 0
	var axes := Vector2.ZERO
	var eccentricity := 0.0
	var orbit_angle := 0.0
	var center_offset := Vector2.ZERO
	var circumference := 0.0
	var body_radius := 1.0
	var icon_orbit := 0.0
	var label := ""
	var icon_alpha := 0.0

var galaxy: Dictionary
var systems: Array[Dictionary]
var world_bounds: Rect2
var contents_by_system := {}
var visible_orbiters := {}
var stars := {}
var star_layer := Node2D.new()
var orbit_layer := Node2D.new()
var system_centers := PackedVector2Array()
var origin_x := 0.0
var origin_y := 0.0
var last_lookup := Vector2.INF
var last_nearest := 0
var minimap_transform := Transform2D()
var minimap_rect := Rect2()
var minimap_points := PackedVector2Array()
var minimap_colors := PackedColorArray()
var minimap_system_indices := PackedInt32Array()
var minimap_orbiters := {}
var dot_texture: ImageTexture
var surface: NoiseTexture2D
# Offsets keep the displayed phase continuous when rates are edited mid-flight.
var planet_rate := 1.0
var moon_rate := 1.0
var planet_clock_offset := 0.0
var moon_clock_offset := 0.0

func set_orbit_rates(clock: float, planets: float, moons: float) -> void:
	planet_clock_offset += clock * (planet_rate - planets)
	moon_clock_offset += clock * (moon_rate - moons)
	planet_rate = planets
	moon_rate = moons

func configure(data: Dictionary, formed_systems: Dictionary) -> void:
	galaxy = data
	systems = data.systems
	contents_by_system = formed_systems
	minimap_orbiters.clear()
	set_origin(0.0, 0.0)

func set_origin(x: float, y: float) -> void:
	origin_x = x
	origin_y = y
	system_centers.resize(systems.size())
	for index in systems.size():
		var center: Vector2 = systems[index].center
		system_centers[index] = local_point(center.x, center.y)
		if stars.has(index):
			var star: ColorRect = stars[index]
			star.position = system_centers[index] - star.size * 0.5
	world_bounds = Rect2(local_point(0.0, 0.0), galaxy.world_size)
	last_lookup = Vector2.INF
	minimap_rect = Rect2()

func local_point(x: float, y: float) -> Vector2:
	return Vector2(x - origin_x, y - origin_y)

func system_contents(index: int) -> Dictionary:
	if not contents_by_system.has(index):
		contents_by_system[index] = GALAXY.form_system(galaxy.seed, systems[index], galaxy.generator_version)
	return contents_by_system[index]

func starting_position() -> Vector2:
	if GALAXY.is_wide_version(galaxy.generator_version):
		return system_centers[0] + GALAXY.starter_offset(GALAXY.VERSION)
	return GALAXY.starting_position(galaxy)

func hyperjump_arrival(source_index: int, destination_index: int) -> Vector2:
	var arrival := hyperjump_arrival_coordinates(source_index, destination_index)
	return local_point(arrival[0], arrival[1])

func hyperjump_arrival_coordinates(source_index: int, destination_index: int) -> PackedFloat64Array:
	var center: Vector2 = systems[destination_index].center
	var approach := center.direction_to(systems[source_index].center)
	var radius := float(system_contents(destination_index).edge) + GALAXY.ARRIVAL_MARGIN
	if GALAXY.is_wide_version(galaxy.generator_version):
		return PackedFloat64Array([center.x + approach.x * radius, center.y + approach.y * radius])
	var arrival := center + approach * radius
	return PackedFloat64Array([arrival.x, arrival.y])

func _ready() -> void:
	add_child(star_layer)
	add_child(orbit_layer)
	dot_texture = _make_dot_texture()
	var noise := FastNoiseLite.new()
	noise.seed = 29473
	noise.frequency = 0.017
	noise.fractal_octaves = 5
	surface = NoiseTexture2D.new()
	surface.noise = noise
	surface.seamless = true

func _create_orbiter(definition: Dictionary, parent: Orbiter, with_visuals: bool) -> Orbiter:
	var orbiter := Orbiter.new()
	orbiter.definition = definition
	orbiter.parent = parent
	orbiter.orbit_angle = float(definition.get("orbit_angle", 0.0))
	orbiter.eccentricity = float(definition.get("eccentricity", 0.0))
	var major := float(definition.orbit)
	var minor := major * sqrt(1.0 - orbiter.eccentricity * orbiter.eccentricity)
	orbiter.axes = Vector2(major, minor)
	orbiter.center_offset = Vector2(-major * orbiter.eccentricity, 0.0).rotated(orbiter.orbit_angle)
	if with_visuals:
		orbiter.circumference = PI * (3.0 * (major + minor) - sqrt((3.0 * major + minor) * (major + 3.0 * minor)))
		orbiter.body_radius = float(definition.radius) * float(definition.extent)
		orbiter.track = _make_orbit(dot_texture)
		orbiter.track.rotation = orbiter.orbit_angle
		orbiter.visual = _make_body(definition, self)
		orbiter.visual.top_level = true
	return orbiter

func _build_system_orbiters(index: int, with_visuals: bool = true) -> Array[Orbiter]:
	var orbiters: Array[Orbiter] = []
	var system_name := str(systems[index].name).to_upper()
	var planets: Array = system_contents(index).planets
	for planet_index in planets.size():
		var definition: Dictionary = planets[planet_index]
		var planet := _create_orbiter(definition, null, with_visuals)
		planet.label = "%s %s" % [system_name, _roman(planet_index + 1)]
		orbiters.append(planet)
		var moons: Array = definition.moons
		for moon_index in moons.size():
			var moon := _create_orbiter(moons[moon_index], planet, with_visuals)
			moon.label = "%s%s" % [planet.label, _moon_suffix(moon_index)]
			orbiters.append(moon)
	# Gate the whole system's markers on its innermost planetary orbit so outer
	# worlds do not keep their names after the rest of the system has faded out.
	var icon_orbit := orbiters[0].axes.x if not orbiters.is_empty() else 0.0
	for orbiter in orbiters:
		orbiter.icon_orbit = icon_orbit
	return orbiters

static func _roman(value: int) -> String:
	var values := [10, 9, 5, 4, 1]
	var symbols := ["X", "IX", "V", "IV", "I"]
	var text := ""
	var remaining := value
	for index in values.size():
		while remaining >= values[index]:
			text += symbols[index]
			remaining -= values[index]
	return text

static func _moon_suffix(index: int) -> String:
	if index < 26:
		return char(97 + index)
	return char(97 + index % 26) + str(index / 26 + 1)

func update_view(clock: float, camera: Transform2D, camera_center: Vector2, screen_center: Vector2, visible_world: Rect2) -> void:
	transform = camera
	var zoom := camera.x.length()
	var render_stars := zoom >= 0.00004
	var render_tracks := zoom >= ORBIT_MIN_ZOOM or systems.size() <= 5
	var render_bodies := zoom >= BODY_MIN_ZOOM
	if not render_stars and not render_tracks and not render_bodies and stars.is_empty() and visible_orbiters.is_empty():
		return
	var orbit_view := visible_world.grow((GALAXY.MAX_DISC_RADIUS + 100000.0) * GALAXY.orbit_scale_for(galaxy.generator_version))
	for index in systems.size():
		var center := system_centers[index]
		var show_star := render_stars and orbit_view.has_point(center)
		if show_star:
			var extent := float(systems[index].radius) * float(systems[index].extent)
			var nearest := center.clamp(visible_world.position, visible_world.end)
			show_star = center.distance_squared_to(nearest) < extent * extent
		if show_star and not stars.has(index):
			var star := _make_body(systems[index], star_layer)
			star.position = center - star.size * 0.5
			stars[index] = star
		elif not show_star and stars.has(index):
			stars[index].free()
			stars.erase(index)
		var show_orbiters := (render_tracks or render_bodies) and orbit_view.has_point(center)
		if not show_orbiters:
			if visible_orbiters.has(index):
				for orbiter: Orbiter in visible_orbiters[index]:
					orbiter.track.free()
					orbiter.visual.free()
				visible_orbiters.erase(index)
			continue
		if not visible_orbiters.has(index):
			visible_orbiters[index] = _build_system_orbiters(index)
		for orbiter: Orbiter in visible_orbiters[index]:
			_update_position(orbiter, center, clock)
			_update_orbit_track(orbiter, zoom, visible_world, render_tracks)
			var body_bounds := Rect2(orbiter.center - orbiter.visual.size * 0.5, orbiter.visual.size)
			orbiter.visual.visible = render_bodies and maxf(orbiter.visual.size.x, orbiter.visual.size.y) * zoom >= 0.6 \
				and visible_world.intersects(body_bounds)
			if orbiter.visual.visible:
				orbiter.visual.scale = Vector2.ONE * zoom
				orbiter.visual.position = Vector2(
					screen_center.x + (orbiter.center_x - camera_center.x - orbiter.visual.size.x * 0.5) * zoom,
					screen_center.y + (orbiter.center_y - camera_center.y - orbiter.visual.size.y * 0.5) * zoom)
				(orbiter.visual.material as ShaderMaterial).set_shader_parameter("sunward", orbiter.center.direction_to(center))
			_update_icon(orbiter, zoom)

func nearest_system(point: Vector2) -> int:
	if point == last_lookup:
		return last_nearest
	var closest := 0
	var best_distance := INF
	for index in system_centers.size():
		var distance := point.distance_squared_to(system_centers[index])
		if distance < best_distance:
			closest = index
			best_distance = distance
	last_lookup = point
	last_nearest = closest
	return closest

func light_direction_at(point: Vector2) -> Vector2:
	return point.direction_to(system_centers[nearest_system(point)])

func draw_minimap(canvas: CanvasItem, chart: Transform2D, map_rect: Rect2, clock: float) -> void:
	var map_scale := chart.x.x
	var orbit_reach := (GALAXY.MAX_DISC_RADIUS + 100000.0) * GALAXY.orbit_scale_for(galaxy.generator_version) * map_scale
	var show_orbits := orbit_reach >= MIN_TRACK_RADIUS_PIXELS
	var dot_cloud := systems.size() > 128 and not show_orbits
	_update_minimap_stars(chart, map_rect, dot_cloud)

	var planets: Array[Dictionary] = []
	var moons: Array[Dictionary] = []
	if show_orbits:
		_minimap_bodies(canvas, chart, map_rect, clock, orbit_reach, planets, moons)
	else:
		minimap_orbiters.clear()

	var star_labels: Array[Dictionary] = []
	var occupied: Array[Rect2] = [Rect2(map_rect.get_center() - Vector2.ONE * 9.0, Vector2.ONE * 18.0)]
	if dot_cloud and not minimap_points.is_empty():
		canvas.draw_multiline_colors(minimap_points, minimap_colors, 1.0, true)
	var label_cells := {}
	for index in minimap_system_indices:
		var system := systems[index]
		var point := chart * system_centers[index]
		var radius := clampf(system.radius * map_scale, 2.5, 7.0)
		if dot_cloud:
			# Keep all the dots, but only offer one name per cell in crowded views.
			var cell := Vector2i((point - map_rect.position) / Vector2(42.0, 24.0))
			if label_cells.has(cell):
				continue
			label_cells[cell] = true
		else:
			_draw_minimap_marker(canvas, map_rect, point, radius, system.color, occupied)
		var name := str(system.name) if show_orbits else "%s system" % system.name
		star_labels.append({"point": point, "radius": radius, "name": name, "color": system.color})
	for marker in planets + moons:
		_draw_minimap_marker(canvas, map_rect, marker.point, marker.radius, marker.color, occupied)
	for label in star_labels + planets + moons:
		if not label.name.is_empty():
			_draw_minimap_label(canvas, map_rect.grow(-3.0), label, occupied)

func _update_minimap_stars(chart: Transform2D, map_rect: Rect2, dot_cloud: bool) -> void:
	if minimap_transform == chart and minimap_rect == map_rect:
		return
	minimap_transform = chart
	minimap_rect = map_rect
	minimap_points.clear()
	minimap_colors.clear()
	minimap_system_indices.clear()
	var marker_area := map_rect.grow(-2.0)
	for index in systems.size():
		var point := chart * system_centers[index]
		if not marker_area.has_point(point):
			continue
		minimap_system_indices.append(index)
		if dot_cloud:
			minimap_points.append(point - Vector2(0.56, 0.0))
			minimap_points.append(point + Vector2(0.56, 0.0))
			minimap_colors.append(systems[index].color)

func _minimap_bodies(canvas: CanvasItem, chart: Transform2D, map_rect: Rect2, clock: float, orbit_reach: float,
		planets: Array[Dictionary], moons: Array[Dictionary]) -> void:
	var system_area := map_rect.grow(orbit_reach)
	var track_area := map_rect.grow(-1.0)
	var marker_area := map_rect.grow(-2.0)
	for index in minimap_orbiters.keys():
		if not system_area.has_point(chart * system_centers[index]):
			minimap_orbiters.erase(index)
	for index in systems.size():
		var star_center := system_centers[index]
		if not system_area.has_point(chart * star_center):
			continue
		# The ship-centered minimap can see systems outside a panned camera's view.
		# Build only their motion data, without allocating world-rendering nodes.
		if not minimap_orbiters.has(index):
			minimap_orbiters[index] = _build_system_orbiters(index, false)
		for orbiter: Orbiter in minimap_orbiters[index]:
			var moon := orbiter.parent != null
			var axes := orbiter.axes * chart.x.x
			if axes.x < (MINIMAP_MOON_MARKER_ORBIT if moon else MIN_TRACK_RADIUS_PIXELS):
				continue
			_update_position(orbiter, star_center, clock)
			var focus := orbiter.parent.center if moon else star_center
			var orbit_center := chart * focus + orbiter.center_offset * chart.x.x
			_draw_minimap_orbit(canvas, track_area, orbit_center, axes, orbiter.orbit_angle, moon)
			var point := chart * orbiter.center
			if marker_area.has_point(point):
				var radius := clampf(orbiter.definition.radius * chart.x.x, 1.4 if moon else 2.0, 5.0)
				var name := "" if moon and axes.x < MINIMAP_MOON_LABEL_ORBIT else orbiter.label
				var markers := moons if moon else planets
				markers.append({"point": point, "radius": radius, "name": name, "color": orbiter.definition.color})

func _draw_minimap_orbit(canvas: CanvasItem, area: Rect2, center: Vector2, axes: Vector2, angle: float, moon: bool) -> void:
	if not _orbit_intersects_view(center, axes, 1.0, area):
		return
	# Increase sampling on close passes so large orbits don't turn into long chords.
	var segments := clampi(ceili(PI * sqrt(axes.x / 0.7)), 24, 2048)
	var ellipse := Transform2D(angle, axes, 0.0, center)
	var lines := PackedVector2Array()
	var start := ellipse * Vector2.RIGHT
	for step in range(1, segments + 1):
		var end := ellipse * Vector2.from_angle(TAU * step / segments)
		_append_clipped_minimap_segment(lines, area, start, end)
		start = end
	if not lines.is_empty():
		canvas.draw_multiline(lines, Color(ORBIT_COLOR, 0.25 if moon else 0.46), 1.0, true)

static func _append_clipped_minimap_segment(lines: PackedVector2Array, area: Rect2, start: Vector2, end: Vector2) -> void:
	var delta := end - start
	var enter := 0.0
	var exit := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if start[axis] < area.position[axis] or start[axis] > area.end[axis]:
				return
			continue
		var a := (area.position[axis] - start[axis]) / delta[axis]
		var b := (area.end[axis] - start[axis]) / delta[axis]
		enter = maxf(enter, minf(a, b))
		exit = minf(exit, maxf(a, b))
		if enter >= exit:
			return
	lines.append(start + delta * enter)
	lines.append(start + delta * exit)

func _draw_minimap_marker(canvas: CanvasItem, map_rect: Rect2, point: Vector2, radius: float, color: Color,
		occupied: Array[Rect2]) -> void:
	var clearance := (point - map_rect.position).min(map_rect.end - point)
	var visible_radius := minf(radius, minf(clearance.x, clearance.y) - 1.0)
	if visible_radius > 0.0:
		canvas.draw_circle(point, visible_radius, color, true, -1.0, true)
		occupied.append(Rect2(point - Vector2.ONE * visible_radius, Vector2.ONE * visible_radius * 2.0))

func _draw_minimap_label(canvas: CanvasItem, area: Rect2, label: Dictionary, occupied: Array[Rect2]) -> void:
	var font := ThemeDB.fallback_font
	var text: String = label.name
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINIMAP_LABEL_SIZE)
	var gap := float(label.radius) + 4.0
	var offsets := [Vector2(gap, -text_size.y * 0.5), Vector2(-gap - text_size.x, -text_size.y * 0.5),
		Vector2(-text_size.x * 0.5, gap), Vector2(-text_size.x * 0.5, -gap - text_size.y)]
	for offset: Vector2 in offsets:
		var bounds := Rect2(label.point + offset, text_size).grow(1.0)
		if not area.encloses(bounds) or occupied.any(func(rect: Rect2) -> bool: return rect.intersects(bounds)):
			continue
		occupied.append(bounds)
		var baseline: Vector2 = label.point + offset + Vector2(0.0, font.get_ascent(MINIMAP_LABEL_SIZE))
		var tint: Color = label.color
		canvas.draw_string(font, baseline + Vector2.ONE, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINIMAP_LABEL_SIZE, Color("0b1927"))
		canvas.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, MINIMAP_LABEL_SIZE, tint.lerp(Color.WHITE, 0.65))
		return

func draw_belt_markers(canvas: CanvasItem, camera: Transform2D, viewport: Rect2) -> void:
	var zoom := camera.x.length()
	if zoom < 0.00012 or zoom > 0.012:
		return
	var tint := Color("eec08c")
	for index in visible_orbiters:
		var star_center := system_centers[index]
		for belt in system_contents(index).belts:
			var anchor := camera * (star_center + Vector2.from_angle(belt.phase) * float(belt.orbit))
			if not viewport.grow(32.0).has_point(anchor):
				continue
			var marker := PackedVector2Array([anchor + Vector2(0, -5), anchor + Vector2(5, 0),
				anchor + Vector2(0, 5), anchor + Vector2(-5, 0), anchor + Vector2(0, -5)])
			canvas.draw_polyline(marker, tint, 1.0, true)
			canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(10, 4), "Asteroid field", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)

func _update_position(orbiter: Orbiter, star_center: Vector2, clock: float) -> void:
	var definition := orbiter.definition
	var parent := orbiter.parent
	var parent_x := parent.center_x if parent != null else star_center.x
	var parent_y := parent.center_y if parent != null else star_center.y
	var orbit_clock := (clock * moon_rate + moon_clock_offset) * MOON_ORBIT_SPEED_SCALE if parent != null \
		else (clock * planet_rate + planet_clock_offset) * PLANET_ORBIT_SPEED_SCALE
	var anomaly := GALAXY.eccentric_anomaly(float(definition.phase) + TAU * fposmod(orbit_clock, definition.period) / definition.period, orbiter.eccentricity)
	if orbiter.track != null:
		orbiter.track.position = Vector2(parent_x, parent_y) + orbiter.center_offset
	var offset_x := cos(anomaly) * orbiter.axes.x
	var offset_y := sin(anomaly) * orbiter.axes.y
	var orbit_angle := orbiter.orbit_angle
	orbiter.center_x = parent_x + orbiter.center_offset.x + offset_x * cos(orbit_angle) - offset_y * sin(orbit_angle)
	orbiter.center_y = parent_y + orbiter.center_offset.y + offset_x * sin(orbit_angle) + offset_y * cos(orbit_angle)
	orbiter.center = Vector2(orbiter.center_x, orbiter.center_y)

func _orbit_intersects_view(center: Vector2, axes: Vector2, width: float, view: Rect2) -> bool:
	var nearest := center.clamp(view.position, view.end)
	var farthest := (center - view.position).abs().max((center - view.end).abs())
	return center.distance_squared_to(nearest) <= pow(axes.x + width, 2) and farthest.length_squared() >= pow(maxf(0.0, axes.y - width), 2)

func _make_orbit(dot_texture: Texture2D) -> Line2D:
	var orbit := Line2D.new()
	orbit.closed = true
	orbit.default_color = ORBIT_COLOR
	orbit.texture = dot_texture
	orbit.texture_mode = Line2D.LINE_TEXTURE_TILE
	orbit.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	orbit.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	orbit_layer.add_child(orbit)
	return orbit

func _update_icon(orbiter: Orbiter, zoom: float) -> void:
	var orbit_fade := smoothstep(ICON_ORBIT_FADE_START, ICON_ORBIT_FADE_END, orbiter.icon_orbit * zoom)
	var body_fade := 1.0 - smoothstep(ICON_BODY_FADE_NEAR, ICON_BODY_FADE_FAR, orbiter.body_radius * zoom)
	var alpha := orbit_fade * body_fade
	# Moons only surface once their planet has become a marker and their own
	# orbit has separated on screen, keeping labels out of the way while the
	# full disc is still readable.
	if orbiter.parent != null:
		alpha *= orbiter.parent.icon_alpha * smoothstep(MOON_ICON_ORBIT_FADE_NEAR, MOON_ICON_ORBIT_FADE_FAR, orbiter.axes.x * zoom)
	orbiter.icon_alpha = alpha

func has_body_icons() -> bool:
	for index in visible_orbiters:
		for orbiter: Orbiter in visible_orbiters[index]:
			if orbiter.icon_alpha > 0.01:
				return true
	return false

func draw_body_icons(canvas: CanvasItem, camera: Transform2D, viewport: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var planet_labels: Array[Dictionary] = []
	var moon_labels: Array[Dictionary] = []
	for index in visible_orbiters:
		for orbiter: Orbiter in visible_orbiters[index]:
			if orbiter.icon_alpha <= 0.01:
				continue
			var point := camera * orbiter.center
			if not viewport.grow(70.0).has_point(point):
				continue
			var alpha := clampf(orbiter.icon_alpha, 0.0, 1.0)
			var tint: Color = orbiter.definition.color
			var moon := orbiter.parent != null
			var icon_radius := MOON_ICON_RADIUS if moon else PLANET_ICON_RADIUS
			canvas.draw_circle(point, icon_radius * 2.8, Color(tint, 0.08 * alpha), true, -1.0, true)
			canvas.draw_circle(point, icon_radius * 1.55, Color(tint, 0.17 * alpha), true, -1.0, true)
			canvas.draw_circle(point, icon_radius, Color(tint, 0.94 * alpha), true, -1.0, true)
			canvas.draw_circle(point - Vector2(icon_radius * 0.3, icon_radius * 0.3), maxf(0.7, icon_radius * 0.4), Color(1.0, 1.0, 1.0, 0.55 * alpha), true, -1.0, true)
			if not moon and bool(orbiter.definition.get("rings", false)):
				canvas.draw_set_transform(point, float(orbiter.definition.get("axis_angle", 0.0)), Vector2(1.0, 0.34))
				canvas.draw_arc(Vector2.ZERO, icon_radius * 2.1, 0.0, TAU, 24, Color(tint.lerp(Color.WHITE, 0.35), 0.55 * alpha), 1.0, true)
				canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var label_data := {"point": point, "radius": icon_radius, "alpha": alpha, "tint": tint,
				"text": orbiter.label, "font_size": 10 if moon else 11}
			if moon:
				moon_labels.append(label_data)
			else:
				planet_labels.append(label_data)
	# Planet names claim space first, then moon names only draw where they fit.
	var placed: Array[Rect2] = []
	for label_data in planet_labels + moon_labels:
		var text_size := font.get_string_size(str(label_data.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(label_data.font_size))
		var gap: float = float(label_data.radius) + 6.0
		var candidates := [
			Vector2(gap, 4.0), Vector2(gap, -8.0), Vector2(gap, 16.0),
			Vector2(-gap - text_size.x, 4.0), Vector2(-gap - text_size.x, -8.0), Vector2(-gap - text_size.x, 16.0)]
		var placed_position := Vector2.INF
		for candidate: Vector2 in candidates:
			var label_position: Vector2 = label_data.point + candidate
			var bounds := Rect2(label_position + Vector2(0.0, -text_size.y + 2.0), text_size)
			if not viewport.grow(4.0).encloses(bounds):
				continue
			var clear := true
			for occupied in placed:
				if occupied.grow(3.0).intersects(bounds):
					clear = false
					break
			if clear:
				placed_position = label_position
				placed.append(bounds)
				break
		if placed_position == Vector2.INF:
			continue
		var alpha: float = label_data.alpha
		var label_color := Color((label_data.tint as Color).lerp(Color.WHITE, 0.62), 0.95 * alpha)
		canvas.draw_string(font, placed_position + Vector2(1.0, 1.0), str(label_data.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(label_data.font_size), Color(0.005, 0.02, 0.045, 0.72 * alpha))
		canvas.draw_string(font, placed_position, str(label_data.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(label_data.font_size), label_color)

func _update_orbit_track(orbiter: Orbiter, zoom: float, visible_world: Rect2, render_tracks: bool) -> void:
	var screen_radius := orbiter.axes.x * zoom
	var dot_count := maxf(1.0, roundf(orbiter.circumference * zoom / 15.0))
	var width := orbiter.circumference / (dot_count * 4.0)
	var track := orbiter.track
	track.visible = render_tracks and screen_radius >= MIN_TRACK_RADIUS_PIXELS and _orbit_intersects_view(track.position, orbiter.axes, width, visible_world)
	if not track.visible:
		return
	var segments := 128 if screen_radius <= 256.0 else (512 if screen_radius <= 4096.0 else 2048)
	if orbiter.segments != segments:
		var points := PackedVector2Array()
		points.resize(segments)
		for index in segments:
			points[index] = Vector2.from_angle(TAU * index / segments) * orbiter.axes
		track.points = points
		orbiter.segments = segments
	if not is_equal_approx(track.width, width):
		track.width = width

func _make_dot_texture() -> ImageTexture:
	var image := Image.create_empty(32, 8, false, Image.FORMAT_RGBA8)
	var center := Vector2(image.get_size() - Vector2i.ONE) * 0.5
	for row in range(image.get_height()):
		for column in range(image.get_width()):
			var alpha := 1.0 - smoothstep(2.0, 3.7, Vector2(column, row).distance_to(center))
			image.set_pixel(column, row, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)

func _make_body(definition: Dictionary, parent: Node2D) -> ColorRect:
	var body := ColorRect.new()
	body.size = Vector2.ONE * float(definition.radius) * float(definition.extent) * 2.0
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var appearance := ShaderMaterial.new()
	appearance.shader = BODY_SHADER
	appearance.set_shader_parameter("surface_noise", surface)
	appearance.set_shader_parameter("body_kind", definition.kind)
	appearance.set_shader_parameter("disc_extent", definition.extent)
	if definition.has("stage"):
		var tint: Color = definition.color
		appearance.set_shader_parameter("stellar_style", definition.kind)
		appearance.set_shader_parameter("surface_dark", tint.darkened(0.39))
		appearance.set_shader_parameter("surface_light", tint.lerp(Color.WHITE, 0.40))
		appearance.set_shader_parameter("atmosphere_color", tint)
	for key in ["surface_style", "surface_dark", "surface_light", "atmosphere_color", "surface_seed", "surface_scale", "axis_angle", "rings", "ring_tilt"]:
		if definition.has(key):
			appearance.set_shader_parameter(key, definition[key])
	appearance.set_shader_parameter("atmosphere_strength", definition.get("atmosphere", 0.0))
	body.material = appearance
	parent.add_child(body)
	return body

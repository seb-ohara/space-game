extends Node2D

const SYSTEM_SPACING_SCALE := 10.0
const WORLD_PADDING := Vector2(880000.0, 720000.0)
const SYSTEM_BOUNDS := Rect2(WORLD_PADDING, Vector2(1360000.0, 560000.0))
const WORLD_SIZE := (SYSTEM_BOUNDS.size + WORLD_PADDING * 2.0) * SYSTEM_SPACING_SCALE
const WORLD_BOUNDS := Rect2(Vector2.ZERO, WORLD_SIZE)
const SUN_POSITION := (WORLD_PADDING + Vector2(266000.0, 280000.0)) * SYSTEM_SPACING_SCALE
const SUN_RADIUS := 20000.0
const PLANET_ORBIT := 109000.0
const PLANET_PHASE := -0.4
const START_OFFSET := Vector2(-6030.0, 1800.0)
const HYPERJUMP_ARRIVAL_MARGIN := 2400.0
const ORBIT_LAYOUT_SEED := 804272
const MIN_PLANET_ORBIT_GAP := 6000.0
const MIN_TRACK_RADIUS_PIXELS := 6.0
const ORBIT_COLOR := Color(0.52, 0.73, 0.85, 0.36)
const BODY_SHADER := preload("res://scripts/celestial_body.gdshader")
enum BodyKind { SUN, TERRESTRIAL, MOON, BLUE_DWARF, GAS_GIANT, ICE_PLANET }

const SYSTEMS := [
	{"name": "Sol", "center": SUN_POSITION, "radius": SUN_RADIUS, "extent": 2.65,
		"kind": BodyKind.SUN, "color": Color("ffd292")},
	{"name": "Azure", "center": (WORLD_PADDING + Vector2(1126000.0, 258000.0)) * SYSTEM_SPACING_SCALE, "radius": 9000.0, "extent": 2.9,
		"kind": BodyKind.BLUE_DWARF, "color": Color("a2ddff")},
	{"name": "Vesper", "center": Vector2(520000.0, 390000.0) * SYSTEM_SPACING_SCALE, "radius": 11500.0, "extent": 2.9,
		"kind": BodyKind.BLUE_DWARF, "color": Color("a2ddff")},
	{"name": "Ember", "center": Vector2(515000.0, 1610000.0) * SYSTEM_SPACING_SCALE, "radius": 15500.0, "extent": 2.65,
		"kind": BodyKind.SUN, "color": Color("ffd292")},
	{"name": "Meridian", "center": Vector2(2590000.0, 410000.0) * SYSTEM_SPACING_SCALE, "radius": 18500.0, "extent": 2.65,
		"kind": BodyKind.SUN, "color": Color("ffd292")},
]
const PLANET_STYLES := [
	{"radius": 5500.0, "extent": 1.06, "kind": BodyKind.TERRESTRIAL, "color": Color("65d3d6")},
	{"radius": 9600.0, "extent": 1.045, "kind": BodyKind.GAS_GIANT, "color": Color("eaaa76")},
	{"radius": 5400.0, "extent": 1.055, "kind": BodyKind.ICE_PLANET, "color": Color("c7c7f1")},
]
const EXISTING_PLANETS := {
	0: [{"orbit": PLANET_ORBIT, "style": 0, "phase": PLANET_PHASE, "period": 2400.0},
		{"orbit": 207000.0, "style": 1, "phase": -1.22, "period": 6100.0}],
	1: [{"orbit": 72000.0, "style": 2, "phase": 2.16, "period": 2650.0}],
}

static var orbit_definitions := _generate_orbit_layout()

class Orbiter:
	var center := Vector2.ZERO
	var visual: ColorRect
	var track: Line2D
	var segments := 0
	var axes := Vector2.ZERO
	var eccentricity := 0.0
	var center_offset := Vector2.ZERO
	var circumference := 0.0

var stars: Array[ColorRect] = []
var orbiters: Array[Orbiter] = []
var planet_map_dots := PackedVector2Array()
var moon_map_dots := PackedVector2Array()

static func _generate_orbit_layout() -> Array[Dictionary]:
	var layout: Array[Dictionary] = []
	var orbit_rng := RandomNumberGenerator.new()
	var shape_rng := RandomNumberGenerator.new()
	for system_index in SYSTEMS.size():
		orbit_rng.seed = ORBIT_LAYOUT_SEED + system_index
		shape_rng.seed = ORBIT_LAYOUT_SEED + 1000 + system_index
		var planet_count := orbit_rng.randi_range(3, 6)
		var moon_hosts := _choose_moon_hosts(orbit_rng, planet_count, system_index == 0)
		var existing_planets: Array = EXISTING_PLANETS.get(system_index, [])
		var inner_edge := _body_extent(SYSTEMS[system_index])
		var generated_bands: Array[Dictionary] = []
		for planet_index in planet_count:
			var planet: Dictionary
			var gap_weight := 0.0
			if planet_index < existing_planets.size():
				var existing: Dictionary = existing_planets[planet_index]
				planet = PLANET_STYLES[existing.style].duplicate()
				planet.orbit = existing.orbit
				planet.phase = existing.phase
				planet.period = existing.period
			else:
				planet = PLANET_STYLES[orbit_rng.randi_range(0, PLANET_STYLES.size() - 1)].duplicate()
				planet.radius *= orbit_rng.randf_range(0.8, 1.1)
				gap_weight = orbit_rng.randf_range(0.25, 2.0)
				planet.phase = orbit_rng.randf_range(0.0, TAU)
			planet.star = system_index
			var parent_index := layout.size()
			layout.append(planet)
			var reach := _body_extent(planet)
			if planet_index in moon_hosts:
				var preserve_moon := system_index == 0 and planet_index == 0
				reach = _append_moons(layout, orbit_rng, shape_rng, planet, parent_index, preserve_moon)
			if planet_index < existing_planets.size():
				inner_edge = float(planet.orbit) + reach
			else:
				generated_bands.append({"planet": planet, "reach": reach, "weight": gap_weight})
		_space_generated_planets(generated_bands, inner_edge, _system_orbit_limit(system_index))
	return layout

static func _space_generated_planets(bands: Array[Dictionary], inner_edge: float, outer_limit: float) -> void:
	var required_space := 0.0
	var total_weight := 0.0
	for band in bands:
		required_space += 2.0 * float(band.reach) + MIN_PLANET_ORBIT_GAP
		total_weight += float(band.weight)
	var extra_space := maxf(0.0, outer_limit - inner_edge - required_space)
	var edge := inner_edge
	for band in bands:
		var gap := MIN_PLANET_ORBIT_GAP + extra_space * float(band.weight) / total_weight
		var reach := float(band.reach)
		var planet: Dictionary = band.planet
		planet.orbit = edge + gap + reach
		planet.period = 2300.0 * pow(float(planet.orbit) / 90000.0, 1.5)
		edge = float(planet.orbit) + reach

static func _system_orbit_limit(system_index: int) -> float:
	var center: Vector2 = SYSTEMS[system_index].center
	var edge := minf(minf(center.x, WORLD_SIZE.x - center.x), minf(center.y, WORLD_SIZE.y - center.y))
	for other_index in SYSTEMS.size():
		if other_index != system_index:
			edge = minf(edge, center.distance_to(SYSTEMS[other_index].center) * 0.48)
	return edge / SYSTEM_SPACING_SCALE - 12000.0 - HYPERJUMP_ARRIVAL_MARGIN

static func _choose_moon_hosts(orbit_rng: RandomNumberGenerator, planet_count: int, keep_starter_moon: bool) -> Array[int]:
	var host_count := orbit_rng.randi_range(1, planet_count - 1)
	var hosts: Array[int] = []
	if keep_starter_moon:
		hosts.append(0)
	var candidates: Array[int] = []
	for planet_index in range(hosts.size(), planet_count):
		candidates.append(planet_index)
	while hosts.size() < host_count:
		var picked := orbit_rng.randi_range(0, candidates.size() - 1)
		hosts.append(candidates[picked])
		candidates.remove_at(picked)
	return hosts

static func _append_moons(layout: Array[Dictionary], orbit_rng: RandomNumberGenerator, shape_rng: RandomNumberGenerator, planet: Dictionary, parent_index: int, preserve_moon: bool) -> float:
	var eccentricity := shape_rng.randf_range(0.23, 0.37)
	var angle := shape_rng.randf_range(0.0, TAU)
	var reach := _body_extent(planet)
	var first_periapsis := maxf(12000.0, reach + 4000.0) + shape_rng.randf_range(1200.0, 3900.0)
	var orbit := first_periapsis / (1.0 - eccentricity)
	for moon_index in orbit_rng.randi_range(1, 3):
		var moon := {"star": planet.star, "parent": parent_index, "orbit": orbit,
			"eccentricity": eccentricity, "orbit_angle": angle,
			"phase": orbit_rng.randf_range(0.0, TAU), "period": 320.0 * pow(orbit / 10800.0, 1.5),
			"radius": orbit_rng.randf_range(680.0, 1450.0), "extent": 1.015,
			"kind": BodyKind.MOON, "color": Color("b9c5e1")}
		if preserve_moon and moon_index == 0:
			moon.phase = 2.85
			moon.radius = 1320.0
		layout.append(moon)
		reach = _outer_orbit_radius(moon) + _body_extent(moon)
		orbit += shape_rng.randf_range(5500.0, 8300.0)
	return reach

static func _body_extent(body: Dictionary) -> float:
	return float(body.radius) * float(body.extent)

static func _outer_orbit_radius(body: Dictionary) -> float:
	return float(body.orbit) * (1.0 + float(body.get("eccentricity", 0.0)))

static func starting_position() -> Vector2:
	return SUN_POSITION + Vector2.from_angle(PLANET_PHASE) * PLANET_ORBIT + START_OFFSET

static func hyperjump_arrival(source_index: int, destination_index: int) -> Vector2:
	var destination: Dictionary = SYSTEMS[destination_index]
	var center: Vector2 = destination.center
	var system_edge := _body_extent(destination)
	for orbiter: Dictionary in orbit_definitions:
		if orbiter.star != destination_index:
			continue
		var orbit_reach := _outer_orbit_radius(orbiter)
		var parent_index := int(orbiter.get("parent", -1))
		while parent_index >= 0:
			var parent: Dictionary = orbit_definitions[parent_index]
			orbit_reach += _outer_orbit_radius(parent)
			parent_index = int(parent.get("parent", -1))
		system_edge = maxf(system_edge, orbit_reach + _body_extent(orbiter))
	var approach := center.direction_to(SYSTEMS[source_index].center)
	return center + approach * (system_edge + HYPERJUMP_ARRIVAL_MARGIN)

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
	for definition: Dictionary in orbit_definitions:
		var orbiter := Orbiter.new()
		orbiter.track = _make_orbit(dot_texture)
		orbiter.track.rotation = float(definition.get("orbit_angle", 0.0))
		orbiter.eccentricity = float(definition.get("eccentricity", 0.0))
		var major := float(definition.orbit)
		var minor := major * sqrt(1.0 - orbiter.eccentricity * orbiter.eccentricity)
		orbiter.axes = Vector2(major, minor)
		orbiter.center_offset = Vector2(-major * orbiter.eccentricity, 0.0).rotated(orbiter.track.rotation)
		orbiter.circumference = PI * (3.0 * (major + minor) - sqrt((3.0 * major + minor) * (major + 3.0 * minor)))
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
		var definition: Dictionary = orbit_definitions[index]
		_update_orbit_track(orbiter, zoom, visible_world)
		orbiter.visual.visible = visible_world.intersects(Rect2(orbiter.visual.position, orbiter.visual.size))
		if orbiter.visual.visible:
			var star_center: Vector2 = SYSTEMS[definition.star].center
			(orbiter.visual.material as ShaderMaterial).set_shader_parameter("sunward", orbiter.center.direction_to(star_center))

func nearest_system(point: Vector2) -> int:
	var closest := 0
	var best_distance := INF
	for index in SYSTEMS.size():
		var distance := point.distance_squared_to(SYSTEMS[index].center)
		if distance < best_distance:
			closest = index
			best_distance = distance
	return closest

func light_direction_at(point: Vector2) -> Vector2:
	var star_center: Vector2 = SYSTEMS[nearest_system(point)].center
	return point.direction_to(star_center)

func draw_minimap(canvas: CanvasItem, chart: Transform2D) -> void:
	var map_scale := chart.x.x
	for index in orbiters.size():
		var definition: Dictionary = orbit_definitions[index]
		var orbiter := orbiters[index]
		if orbiter.axes.x * map_scale < 2.0:
			continue
		canvas.draw_set_transform(chart * orbiter.track.position, orbiter.track.rotation, orbiter.axes * map_scale)
		canvas.draw_multiline(moon_map_dots if definition.has("parent") else planet_map_dots, ORBIT_COLOR)
	canvas.draw_set_transform(Vector2.ZERO)
	for system: Dictionary in SYSTEMS:
		canvas.draw_circle(chart * system.center, maxf(2.5, system.radius * map_scale), system.color)
	for index in orbiters.size():
		var definition: Dictionary = orbit_definitions[index]
		if not definition.has("parent") or float(definition.orbit) * map_scale >= 2.0:
			canvas.draw_circle(chart * orbiters[index].center, maxf(1.15, definition.radius * map_scale), definition.color)

func _update_positions(clock: float) -> void:
	for index in orbiters.size():
		var orbiter := orbiters[index]
		var definition: Dictionary = orbit_definitions[index]
		var parent_center: Vector2 = orbiters[definition.parent].center if definition.has("parent") else SYSTEMS[definition.star].center
		var anomaly := _orbit_anomaly(clock, definition.phase, definition.period, orbiter.eccentricity)
		orbiter.track.position = parent_center + orbiter.center_offset
		var offset := Vector2.from_angle(anomaly) * orbiter.axes
		orbiter.center = orbiter.track.position + offset.rotated(orbiter.track.rotation)
		orbiter.visual.position = orbiter.center - orbiter.visual.size * 0.5

func _orbit_anomaly(clock: float, phase: float, period: float, eccentricity: float) -> float:
	var mean_anomaly := phase + TAU * fposmod(clock, period) / period
	if eccentricity == 0.0:
		return mean_anomaly
	var anomaly := mean_anomaly
	for iteration in range(3):
		anomaly -= (anomaly - eccentricity * sin(anomaly) - mean_anomaly) / (1.0 - eccentricity * cos(anomaly))
	return anomaly

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
	add_child(orbit)
	return orbit

func _update_orbit_track(orbiter: Orbiter, zoom: float, visible_world: Rect2) -> void:
	var screen_radius := orbiter.axes.x * zoom
	var dot_count := maxf(1.0, roundf(orbiter.circumference * zoom / 15.0))
	var width := orbiter.circumference / (dot_count * 4.0)
	var track := orbiter.track
	track.visible = screen_radius >= MIN_TRACK_RADIUS_PIXELS and _orbit_intersects_view(track.position, orbiter.axes, width, visible_world)
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

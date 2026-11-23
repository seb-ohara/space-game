extends Node2D

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const PLANET_ORBIT_SPEED_SCALE := 0.025
const MOON_ORBIT_SPEED_SCALE := 0.75
const MIN_TRACK_RADIUS_PIXELS := 6.0
const ORBIT_COLOR := Color(0.52, 0.73, 0.85, 0.36)
const BODY_SHADER := preload("res://scripts/celestial_body.gdshader")

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
	var center_offset := Vector2.ZERO
	var circumference := 0.0

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
var minimap_points := PackedVector2Array()
var minimap_colors := PackedColorArray()
var dot_texture: ImageTexture
var surface: NoiseTexture2D

func configure(data: Dictionary, formed_systems: Dictionary) -> void:
	galaxy = data
	systems = data.systems
	contents_by_system = formed_systems
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
	minimap_points.clear()

func local_point(x: float, y: float) -> Vector2:
	return Vector2(x - origin_x, y - origin_y)

func system_contents(index: int) -> Dictionary:
	if not contents_by_system.has(index):
		contents_by_system[index] = GALAXY.form_system(galaxy.seed, systems[index], galaxy.generator_version)
	return contents_by_system[index]

func starting_position() -> Vector2:
	if galaxy.generator_version == GALAXY.VERSION:
		return system_centers[0] + GALAXY.starter_offset(GALAXY.VERSION)
	return GALAXY.starting_position(galaxy)

func hyperjump_arrival(source_index: int, destination_index: int) -> Vector2:
	var arrival := hyperjump_arrival_coordinates(source_index, destination_index)
	return local_point(arrival[0], arrival[1])

func hyperjump_arrival_coordinates(source_index: int, destination_index: int) -> PackedFloat64Array:
	var center: Vector2 = systems[destination_index].center
	var approach := center.direction_to(systems[source_index].center)
	var radius := float(system_contents(destination_index).edge) + GALAXY.ARRIVAL_MARGIN
	if galaxy.generator_version == GALAXY.VERSION:
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

func _create_orbiter(definition: Dictionary, parent: Orbiter = null) -> Orbiter:
	var orbiter := Orbiter.new()
	orbiter.definition = definition
	orbiter.parent = parent
	orbiter.track = _make_orbit(dot_texture)
	orbiter.track.rotation = float(definition.get("orbit_angle", 0.0))
	orbiter.eccentricity = float(definition.get("eccentricity", 0.0))
	var major := float(definition.orbit)
	var minor := major * sqrt(1.0 - orbiter.eccentricity * orbiter.eccentricity)
	orbiter.axes = Vector2(major, minor)
	orbiter.center_offset = Vector2(-major * orbiter.eccentricity, 0.0).rotated(orbiter.track.rotation)
	orbiter.circumference = PI * (3.0 * (major + minor) - sqrt((3.0 * major + minor) * (major + 3.0 * minor)))
	orbiter.visual = _make_body(definition, self)
	orbiter.visual.top_level = true
	return orbiter

func _build_system_orbiters(index: int) -> Array[Orbiter]:
	var orbiters: Array[Orbiter] = []
	for definition in system_contents(index).planets:
		var planet := _create_orbiter(definition)
		orbiters.append(planet)
		for moon in definition.moons:
			orbiters.append(_create_orbiter(moon, planet))
	return orbiters

func update_view(clock: float, camera: Transform2D, camera_center: Vector2, screen_center: Vector2, visible_world: Rect2) -> void:
	transform = camera
	var zoom := camera.x.length()
	var render_stars := zoom >= 0.00004
	var render_orbits := zoom >= 0.00011 or systems.size() <= 5
	if not render_stars and not render_orbits and stars.is_empty() and visible_orbiters.is_empty():
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
		var show_orbits := render_orbits and orbit_view.has_point(center)
		if not show_orbits:
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
			_update_orbit_track(orbiter, zoom, visible_world)
			orbiter.visual.visible = visible_world.intersects(Rect2(orbiter.center - orbiter.visual.size * 0.5, orbiter.visual.size))
			if orbiter.visual.visible:
				orbiter.visual.scale = Vector2.ONE * zoom
				orbiter.visual.position = Vector2(
					screen_center.x + (orbiter.center_x - camera_center.x - orbiter.visual.size.x * 0.5) * zoom,
					screen_center.y + (orbiter.center_y - camera_center.y - orbiter.visual.size.y * 0.5) * zoom)
				(orbiter.visual.material as ShaderMaterial).set_shader_parameter("sunward", orbiter.center.direction_to(center))

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

func draw_minimap(canvas: CanvasItem, chart: Transform2D) -> void:
	var map_scale := chart.x.x
	if systems.size() > 128:
		if minimap_transform != chart or minimap_points.is_empty():
			minimap_transform = chart
			minimap_points.clear()
			minimap_colors.clear()
			for index in systems.size():
				var point := chart * system_centers[index]
				minimap_points.append(point - Vector2(0.56, 0.0))
				minimap_points.append(point + Vector2(0.56, 0.0))
				minimap_colors.append(systems[index].color)
		canvas.draw_multiline_colors(minimap_points, minimap_colors, 1.0, true)
	else:
		var star_marker := 1.65 if systems.size() > 24 else 2.5
		for index in systems.size():
			var system := systems[index]
			canvas.draw_circle(chart * system_centers[index], maxf(star_marker, system.radius * map_scale), system.color)
	for index in visible_orbiters:
		for orbiter: Orbiter in visible_orbiters[index]:
			if orbiter.axes.x * map_scale < 2.0:
				continue
			canvas.draw_circle(chart * orbiter.center, maxf(1.2, orbiter.definition.radius * map_scale), orbiter.definition.color)

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
			canvas.draw_string(ThemeDB.fallback_font, anchor + Vector2(10, 4), "Asteroid belt", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)

func _update_position(orbiter: Orbiter, star_center: Vector2, clock: float) -> void:
	var definition := orbiter.definition
	var parent := orbiter.parent
	var parent_x := parent.center_x if parent != null else star_center.x
	var parent_y := parent.center_y if parent != null else star_center.y
	var speed_scale := MOON_ORBIT_SPEED_SCALE if parent != null else PLANET_ORBIT_SPEED_SCALE
	var anomaly := GALAXY.eccentric_anomaly(float(definition.phase) + TAU * fposmod(clock * speed_scale, definition.period) / definition.period, orbiter.eccentricity)
	orbiter.track.position = Vector2(parent_x, parent_y) + orbiter.center_offset
	var offset_x := cos(anomaly) * orbiter.axes.x
	var offset_y := sin(anomaly) * orbiter.axes.y
	var orbit_angle := orbiter.track.rotation
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

extends SceneTree

const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const FLIGHT := preload("res://main.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map := GALAXY.create_map(7419, 2)
	var origin: Vector2 = map.systems[0].center + GALAXY.starter_offset(GALAXY.VERSION)
	var remote: Vector2 = map.systems[1].center - origin
	var game := FLIGHT.instantiate()
	root.add_child(game)
	game.engine_audio.volume = 0.0
	game._start_flight(map, {}, {"active_ship": 0, "world_origin": origin, "fleet": [
		_ship(Vector2.ZERO), _ship(Vector2(350, 0)), _ship(remote), _ship(remote)]})
	game._set_simulation_rate(0)
	game.set_process(false)
	var nearby: Dictionary = game.fleet[1]
	var lead: Dictionary = game.fleet[2]
	var wing: Dictionary = game.fleet[3]
	var formation_offset := Vector2(300.25, -61.75)
	wing.galaxy_position = STATE.absolute(lead.galaxy_position, formation_offset)
	assert(remote.length() > game.FLEET_COLLIDER_EXIT_RANGE)
	assert(game.fleet_colliders.has(nearby.id) and not game.fleet_colliders.has(lead.id))
	game._redraw_flight()
	assert(not game.fleet_views.has(lead.id) and not game.fleet_views.has(wing.id))

	# View a distant fleet without changing the active ship or unpausing flight.
	game.camera_following = false
	game.camera_galaxy_position = lead.galaxy_position.duplicate()
	game._set_camera_zoom(game._minimum_camera_zoom())
	game._redraw_flight()
	var center := root.get_visible_rect().size * 0.5
	assert(game._fleet_ship_at_screen(center) in [2, 3])
	assert(not game.fleet_views.has(lead.id) and not game.fleet_views.has(wing.id), "Tiny ships should use map icons.")

	var detail_zoom := minf(0.5, game._maximum_camera_zoom())
	game._set_camera_zoom(detail_zoom)
	game._redraw_flight()
	assert(game.active_fleet_index == 0 and game.simulation_clock.paused)
	assert(game.fleet_colliders.has(nearby.id) and not game.fleet_colliders.has(wing.id))
	assert(not game.fleet_views.has(nearby.id) and game.fleet_views.has(lead.id) and game.fleet_views.has(wing.id))
	assert(game.fleet_views[lead.id].visual.visible and game.fleet_views[wing.id].visual.visible)
	assert(game.fleet_views[lead.id].visual.position.is_equal_approx(center))
	var wing_screen := center + formation_offset * detail_zoom
	assert(game.fleet_views[wing.id].visual.position.distance_to(wing_screen) < 0.01, "Do not round the ship's position before projecting it.")

	# Cursor-anchored zoom keeps a distant hull in the same spot on screen.
	game.camera_zoom_focus = wing_screen
	game.camera_zoom_target = detail_zoom * 0.8
	game.last_render_usec = Time.get_ticks_usec() - 100000
	game._process(0.1)
	assert(game.camera_zoom < detail_zoom)
	assert(game.fleet_views[wing.id].visual.position.distance_to(wing_screen) < 0.01)

	# Select from inside the visible hull, not just the small map icon hitbox.
	var bounds := MODULES.bounds(wing.parts)
	var shapes: Array[PackedVector2Array] = game._fleet_hull_shapes(wing.parts, bounds, wing.ship_scale)
	var offset := Vector2.ZERO
	for shape in shapes:
		var inside := Vector2.ZERO
		for point in shape:
			inside += point
		inside /= float(shape.size())
		if inside.length() > offset.length() and Geometry2D.is_point_in_polygon(inside, shape):
			offset = inside
	var hull_pixel: Vector2 = wing_screen + offset.rotated(float(wing.heading) + PI / 2.0) * game.camera_zoom
	assert(hull_pixel.distance_to(wing_screen) > 8.0 and game._fleet_ship_at_screen(hull_pixel) == 3)

	game._set_camera_zoom(game._minimum_camera_zoom())
	game._redraw_flight()
	assert(not game.fleet_views.has(lead.id) and not game.fleet_views.has(wing.id))
	game._set_camera_zoom(detail_zoom)
	game._redraw_flight()
	assert(game.fleet_views[wing.id].visual.visible, "Zooming back in should restore the hull while paused.")
	var before_switch: Vector2 = game.fleet_views[wing.id].visual.position
	game._switch_fleet_control(3)
	game._redraw_flight()
	assert(game.active_fleet_index == 3 and not game.fleet_views.has(wing.id))
	assert(game.player_visual.position.distance_to(before_switch) < 0.01, "Rebasing physics must not shift the remote camera.")
	assert(game.fleet_views.has(lead.id) and game.fleet_colliders.has(lead.id) and not game.fleet_colliders.has(nearby.id))
	game.free()
	print("Fleet visibility, remote zoom and hull selection checks passed")
	quit()

func _ship(position: Vector2) -> Dictionary:
	return {"name": "Test ship", "parts": MODULES.default_design(), "position": position,
		"heading": 0.0, "hull": 100.0, "shield": 0.0, "shield_delay": 0.0}

extends RefCounted
## Transitional controller: operates on the game node, which still owns shared state.

var game

func _init(owner) -> void:
	game = owner

func _draw_hud(size: Vector2) -> void:
	var font = ThemeDB.fallback_font
	game.draw_string(font, Vector2(30, 17), "FPS  %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9f0fb"))
	if game.ENEMY_SHIPS_ENABLED:
		game.draw_rect(Rect2(Vector2(size.x / 2.0 - 120.0, 24.0), Vector2(240.0, 54.0)), Color(0.025, 0.06, 0.1, 0.88))
		game.draw_string(font, Vector2(size.x / 2.0 - 110.0, 47.0), "WAVE %d" % game.wave_number, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 16, Color("e4f5ff"))
	var map_rect = Rect2(Vector2(30, 30), Vector2(240, 168))
	game.draw_rect(map_rect.grow(8), Color(0.025, 0.06, 0.1, 0.88))
	game.draw_rect(map_rect, Color(0.05, 0.11, 0.16, 0.95))
	for i in range(1, 4):
		var x = map_rect.position.x + map_rect.size.x * i / 4.0
		var y = map_rect.position.y + map_rect.size.y * i / 4.0
		game.draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.3, 0.55, 0.65, 0.2))
		game.draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.3, 0.55, 0.65, 0.2))
	game.draw_rect(map_rect, Color(0.35, 0.65, 0.75, 0.6), false, 1.0)
	var nearby_system = game.solar_system.nearest_system(game.ship_position)
	var chart_bounds = game.solar_system.world_bounds
	var chart_scale = game._fit_chart(map_rect.size, chart_bounds) * 0.87
	var chart = Transform2D(0.0, Vector2.ONE * chart_scale, 0.0, map_rect.get_center() - chart_bounds.get_center() * chart_scale)
	game.solar_system.draw_minimap(game, chart)
	for i in range(game.fleet.size()):
		if i != game.active_fleet_index:
			var position: Vector2 = game._ship_local(game.fleet[i])
			if chart_bounds.has_point(position):
				game.draw_circle(chart * position, 3.0, Color("87e5bf"))
	var view_size = size / game.camera_zoom
	var camera_view = Rect2(game._camera_center() - view_size * 0.5, view_size).intersection(chart_bounds)
	if camera_view.has_area():
		var view_marker_size = (camera_view.size * chart_scale).max(Vector2.ONE * 4.0)
		game.draw_rect(Rect2(chart * camera_view.get_center() - view_marker_size * 0.5, view_marker_size), Color(0.48, 0.78, 0.91, 0.7), false, 1.0)
	var map_hint = "SCROLL ZOOM  ·  SHIFT-DRAG PAN  ·  %s CENTER SHIP" % InputMap.action_get_events("recenter")[0].as_text().to_upper()
	if game.hyperjump_time < 0.0:
		game.draw_string(font, Vector2(30, 221), map_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6cbdc"))
	if game.solar_system.systems.size() > 1:
		game.draw_string(font, Vector2(30, 241), "ZOOM OUT AND RIGHT-CLICK A SYSTEM TO JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6cbdc"))
	var neutral_count = 0
	var hostile_count = 0
	for i in range(game.enemies.size()):
		var enemy: Dictionary = game.enemies[i]
		if not enemy.alive:
			continue
		if enemy.hostile:
			hostile_count += 1
		else:
			neutral_count += 1
		if chart_bounds.has_point(enemy.position):
			var marker_color = game.HOSTILE_SHIP_COLOR if enemy.hostile else game.NEUTRAL_SHIP_COLOR
			game.draw_circle(chart * enemy.position, 3.5 if i == game.selected_enemy else 2.5, marker_color)
	var wave_status = "%d NEUTRAL  ·  %d HOSTILE" % [neutral_count, hostile_count]
	if game.enemy_wave_timer >= 0.0:
		wave_status = "NEXT WAVE IN %d" % int(ceil(game.enemy_wave_timer))
	if game.ENEMY_SHIPS_ENABLED:
		game.draw_string(font, Vector2(size.x / 2.0 - 110.0, 67.0), wave_status, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 11, Color("91aebe"))
	if game.hyperjump_time >= 0.0 or game.elapsed < game.hyperjump_arrival_until:
		var navigation_text = "Arrived in %s" % game.solar_system.systems[nearby_system].name
		if game.hyperjump_time >= 0.0:
			navigation_text = "Hyperjump to %s" % game.solar_system.systems[game.hyperjump_destination].name
		var navigation_position = Vector2(size.x * 0.5 - 170.0, 92.0)
		game.draw_rect(Rect2(navigation_position, Vector2(340.0, 38.0)), Color("102434"))
		game.draw_string(font, navigation_position + Vector2(0.0, 25.0), navigation_text, HORIZONTAL_ALIGNMENT_CENTER, 340.0, 16, game.HYPERJUMP_COLOR)
	if chart_bounds.has_point(game.ship_position):
		var player_on_map = chart * game.ship_position
		if game.hyperjump_time >= 0.0:
			game.draw_dashed_line(player_on_map, chart * game.hyperjump_arrival, Color(game.HYPERJUMP_COLOR, 0.55), 1.0, 4.0)
		var forward = Vector2.from_angle(game.heading)
		var side = forward.orthogonal()
		game.draw_colored_polygon(PackedVector2Array([player_on_map + forward * 7.0, player_on_map - forward * 5.0 + side * 4.0, player_on_map - forward * 5.0 - side * 4.0]), Color("e0f9ff"))
	if game.hyperjump_time < 0.0:
		var charge_position = Vector2(30, size.y - 205)
		var boost_label = "BOOST" if game.has_flight_controls else "FLIGHT OFFLINE"
		if game.control_mode == 1 and game.has_flight_controls:
			boost_label = "RTS COMMAND MODE"
		if game.sustained_boost_enabled:
			boost_label = "BOOST  ·  CLICK TO CHANGE DESTINATION" if game.boost_destination_active else "BOOST  ·  CLICK A DESTINATION"
		game.draw_string(font, charge_position + Vector2(0, -6), boost_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6bce8") if game.has_flight_controls else Color("ffb58c"))
		game.draw_rect(Rect2(charge_position, Vector2(250, 7)), Color("192638"))
		game.draw_rect(Rect2(charge_position, Vector2(250.0 * game.boost_charge, 7)), Color("91a5ff"))
	var bar_left = Vector2(30, size.y - 136)
	game.draw_rect(Rect2(bar_left + Vector2(-10, -24), Vector2(290, 82)), Color(0.025, 0.06, 0.1, 0.88))
	game.draw_string(font, bar_left + Vector2(0, -5), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8bcfff"))
	game.draw_rect(Rect2(bar_left, Vector2(250, 12)), Color("122b40"))
	game.draw_rect(Rect2(bar_left, Vector2(250.0 * game.player_shield / maxf(game._player_max_shield(), 1.0), 12)), Color("4caeff"))
	game.draw_string(font, bar_left + Vector2(0, 31), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dce9e8"))
	game.draw_rect(Rect2(bar_left + Vector2(0, 36), Vector2(250, 12)), Color("302025"))
	game.draw_rect(Rect2(bar_left + Vector2(0, 36), Vector2(250.0 * game.player_hull / maxf(game._player_max_hull(), 1.0), 12)), Color("d76d69"))
	game.draw_string(font, bar_left + Vector2(253, 11), "%d" % int(ceil(game.player_shield)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a9dcff"))
	game.draw_string(font, bar_left + Vector2(253, 47), "%d" % int(ceil(game.player_hull)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f0c6c1"))
	var weapon_name: String = game.WEAPON_SLOTS[game.selected_weapon - 1].name
	var weapon_color = Color("ffd078")
	if game.selected_weapon == 3 and game.cached_turret_mounts.any(func(mount: Dictionary) -> bool: return mount.turret == game.MODULES.CRUISER_MACHINE_LASER):
		weapon_name = "MACHINE LASER"
		weapon_color = game.CRUISER_LASER_COLOR
	game.draw_string(font, Vector2(size.x - 235, 170), "WEAPON %d: %s" % [game.selected_weapon, weapon_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, weapon_color)
	game._draw_resources(size, font)
	var speed_text = game._format_speed(game.velocity.length())
	game.draw_string(font, Vector2(size.x - 230, 102), speed_text, HORIZONTAL_ALIGNMENT_RIGHT, 200, 24, Color("d9e9f3"))
	game.draw_string(font, Vector2(size.x - 230, 120), "SPEED (SCALED)", HORIZONTAL_ALIGNMENT_RIGHT, 200, 10, Color("7192a7"))

func _format_speed(world_units_per_second: float) -> String:
	var metres_per_second = world_units_per_second / game.MODULES.WORLD_UNITS_PER_METER * game.DISPLAY_SPEED_SCALE
	if metres_per_second >= 1000.0:
		return "%.2f km/s" % (metres_per_second / 1000.0)
	return "%.1f m/s" % metres_per_second

func _draw_resources(size: Vector2, font: Font) -> void:
	var origin = Vector2(size.x - 300, size.y - 150)
	var panel = Rect2(origin, Vector2(270, 112))
	game.draw_rect(panel, Color(0.025, 0.06, 0.1, 0.92))
	game.draw_rect(panel, Color(0.23, 0.39, 0.48, 0.65), false, 1.0)
	game.draw_string(font, origin + Vector2(18, 22), "CARGO  %d / %d" % [game.iron + game.tritium, int(game._custom_stats().cargo)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("88a7b9"))
	game.draw_line(origin + Vector2(18, 32), origin + Vector2(252, 32), Color(0.4, 0.6, 0.7, 0.18), 1.0)
	var iron_icon = origin + Vector2(25, 54)
	game.draw_colored_polygon(PackedVector2Array([iron_icon + Vector2(0, -7), iron_icon + Vector2(7, 0), iron_icon + Vector2(0, 7), iron_icon + Vector2(-7, 0)]), Color("d39b73"))
	game.draw_string(font, origin + Vector2(42, 59), "IRON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c4d5dd"))
	game.draw_string(font, origin + Vector2(154, 59), "%d" % game.iron, HORIZONTAL_ALIGNMENT_RIGHT, 96, 17, Color("f1d3b8"))
	var tritium_icon = origin + Vector2(25, 87)
	game.draw_arc(tritium_icon, 7.0, 0.0, TAU, 24, Color("c994ff"), 1.5, true)
	game.draw_circle(tritium_icon, 2.5, Color("e7cdff"))
	game.draw_string(font, origin + Vector2(42, 92), "TRITIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c4d5dd"))
	game.draw_string(font, origin + Vector2(154, 92), "%d" % game.tritium, HORIZONTAL_ALIGNMENT_RIGHT, 96, 17, Color("dfb8ff"))


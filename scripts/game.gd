extends Node2D

# Movement values are deliberately collected here for quick feel adjustments.
@export_group("Flight feel")
@export var top_speed := 850.0
@export var acceleration := 2150.0
@export var drag := 2.8
@export var turn_speed := MODULES.BASE_TURN_SPEED

const WORLD_SIZE := Vector2(10000.0, 7000.0)
const MODULES := preload("res://scripts/ship_modules.gd")
const SHIP_BUILDER := preload("res://scripts/ship_builder.gd")
const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")
const PULSE_DRIVE_TEXTURE := preload("res://engine-art/pulse-drive-exhaust.png")
const PULSE_DRIVE_FRAME_SIZE := Vector2(48.0, 56.0)
const PULSE_DRIVE_NOZZLE := Vector2(24.0, 3.0)
const PULSE_DRIVE_COLUMNS := 10
const PULSE_DRIVE_FRAME_COUNT := 60
const PULSE_DRIVE_FPS := 20.0
const SHIELD_MARGIN := 26.0
const SHIELD_IMPACT_DURATION := 0.36
const WEAPON_RANGE := 1100.0
const TARGET_RANGE := 1800.0
const ENEMY_DETECTION_RANGE := 1800.0
const ENEMY_SPEED := 270.0
const ENEMY_ACCELERATION := 750.0
const ENEMY_PART_SCALE := 0.75
const ENEMY_MIN_COMBAT_RANGE := 320.0
const ENEMY_PREFERRED_RANGE := 460.0
const ENEMY_FIRE_RANGE := 650.0
const BOOST_CHARGE_SECONDS := 2.5
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var selected_enemy := -1
var selected_weapon := 1
var firing := false
var laser_active := false
var machine_gun_active := false
var machine_gun_cooldown := 0.0
var rocket_cooldown := 0.0
var rocket_pending := false
var rocket_pending_target: Dictionary = {}
var turret_angles: Dictionary = {}
const TURRET_AIM_TOLERANCE := 0.08
var auto_approach := false
var debris: Array[Dictionary] = []
var tritium_drops: Array[Dictionary] = []
var tritium_pickup_effects: Array[Dictionary] = []
var tritium := 0
var player_fire_cooldown := 0.0
var player_hull := 100.0
var player_shield := 100.0
var player_shield_delay := 0.0
var shield_impacts: Array[Dictionary] = []
var hull_impacts: Array[Dictionary] = []
var invulnerability := 0.0
var enemy_wave_timer := -1.0
var wave_number := 0
var settings_layer: CanvasLayer = null
var builder_layer: CanvasLayer = null
var custom_parts: Array = MODULES.default_design()
var ship_cache_ready := false
var cached_ship_stats: Dictionary = {}
var cached_ship_bounds := Rect2()
var cached_engines: Array = []

var ship_position := Vector2.ZERO
var velocity := Vector2.ZERO
var heading := -PI / 2.0
var angular_velocity := 0.0
var thrust := 0.0
var boost_charging := false
var boost_charge := 0.0
var boost_time := 0.0
var boost_duration := 0.0
var boost_power := 0.0
var world_offset := Vector2.ZERO
var stars: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var asteroids: Array[Dictionary] = []
var selected_asteroid := -1
var mining := false
var iron := 0
var mining_progress := 0.0
var camera_zoom := 1.0
var graphics_quality := 2
var frame_cap := 0
var vsync_enabled := false
var graphics_settings_path := "user://graphics_settings.cfg"

func _ready() -> void:
	_load_graphics_settings()
	_load_custom_ship()
	player_hull = _player_max_hull()
	player_shield = _player_max_shield()
	_create_top_controls()
	rng.randomize()
	ship_position = WORLD_SIZE / 2.0
	_spawn_enemy_wave()
	_generate_asteroid_field()
	for i in range(190):
		stars.append({"position": Vector2(rng.randf(), rng.randf()), "depth": rng.randf_range(0.15, 1.0), "phase": rng.randf_range(0.0, TAU)})

func _load_graphics_settings() -> void:
	var config := ConfigFile.new()
	if config.load(graphics_settings_path) == OK:
		graphics_quality = clampi(int(config.get_value("graphics", "quality", 2)), 0, 2)
		var saved_cap := int(config.get_value("graphics", "frame_cap", 0))
		frame_cap = saved_cap if saved_cap == 0 or (saved_cap >= 30 and saved_cap <= 240) else 0
		vsync_enabled = bool(config.get_value("graphics", "vsync", false))
	_apply_graphics_settings()

func _apply_graphics_settings() -> void:
	Engine.max_fps = frame_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _save_graphics_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "frame_cap", frame_cap)
	config.set_value("graphics", "vsync", vsync_enabled)
	if config.save(graphics_settings_path) != OK:
		push_warning("Graphics settings could not be saved; they will apply for this session.")

func _create_top_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var settings_button := Button.new()
	settings_button.text = "Settings  ⚙"
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -168
	settings_button.offset_top = 22
	settings_button.offset_right = -30
	settings_button.offset_bottom = 62
	settings_button.pressed.connect(_open_settings)
	layer.add_child(settings_button)

func _open_settings() -> void:
	firing = false
	if is_instance_valid(settings_layer):
		return
	boost_charging = false
	boost_charge = 0.0
	set_physics_process(false)
	set_process_unhandled_input(false)
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 20
	add_child(settings_layer)
	var menu: Control = SETTINGS_MENU.new()
	menu.initial_zoom = camera_zoom
	menu.initial_graphics_quality = graphics_quality
	menu.initial_frame_cap = frame_cap
	menu.initial_vsync = vsync_enabled
	settings_layer.add_child(menu)
	menu.graphics_quality_changed.connect(func(value: int):
		graphics_quality = clampi(value, 0, 2)
		_save_graphics_settings()
		queue_redraw()
	)
	menu.frame_cap_changed.connect(func(value: int):
		frame_cap = value
		_apply_graphics_settings()
		_save_graphics_settings()
	)
	menu.vsync_changed.connect(func(enabled: bool):
		vsync_enabled = enabled
		_apply_graphics_settings()
		_save_graphics_settings()
	)
	menu.build_requested.connect(_open_builder_from_settings)
	menu.zoom_changed.connect(func(value: float):
		camera_zoom = value
		queue_redraw()
	)
	menu.closed.connect(_close_settings)

func _close_settings() -> void:
	if not is_instance_valid(settings_layer):
		return
	settings_layer.queue_free()
	settings_layer = null
	set_physics_process(true)
	set_process_unhandled_input(true)

func _load_custom_ship() -> void:
	var path := "user://custom_ship.json"
	if not FileAccess.file_exists(path) and OS.has_feature("editor"):
		path = "res://custom_ship.json"
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Array:
		var migrated: Array = MODULES.migrate_legacy(data)
		if MODULES.validate(migrated, false, false) == "":
			custom_parts = migrated
			ship_cache_ready = false

func _open_builder_from_settings() -> void:
	_close_settings()
	set_physics_process(false)
	set_process_unhandled_input(false)
	builder_layer = CanvasLayer.new()
	builder_layer.layer = 20
	add_child(builder_layer)
	var builder: Control = SHIP_BUILDER.new()
	builder.initial_parts = custom_parts.duplicate(true)
	builder.base_turn_speed = turn_speed
	builder_layer.add_child(builder)
	builder.closed.connect(_close_builder)
	builder.deploy.connect(_deploy_custom_ship)

func _close_builder() -> void:
	if not is_instance_valid(builder_layer):
		return
	builder_layer.queue_free()
	builder_layer = null
	set_physics_process(true)
	set_process_unhandled_input(true)

func _deploy_custom_ship(parts: Array) -> void:
	if MODULES.validate(parts) != "":
		return
	custom_parts = parts.duplicate(true)
	ship_cache_ready = false
	turret_angles.clear()
	rocket_pending = false
	var file := FileAccess.open("user://custom_ship.json", FileAccess.WRITE)
	if file == null and OS.has_feature("editor"):
		file = FileAccess.open("res://custom_ship.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(custom_parts))
	else:
		push_warning("Custom ship could not be saved to disk; it remains available for this session.")
	# A newly launched design starts with its own full hull and shield.
	player_hull = _player_max_hull()
	player_shield = _player_max_shield()
	player_shield_delay = 0.0
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	thrust = 0.0
	boost_time = 0.0
	boost_charging = false
	laser_active = false
	machine_gun_active = false
	_close_builder()
	queue_redraw()

func _ensure_ship_cache() -> void:
	if ship_cache_ready:
		return
	cached_ship_stats = MODULES.stats(custom_parts)
	cached_ship_bounds = MODULES.bounds(custom_parts)
	cached_engines.clear()
	var center := cached_ship_bounds.get_center()
	for part in custom_parts:
		if part.type in ["engine", "thruster"]:
			var angle := float(int(part.rotation)) * PI / 2.0
			var direction := Vector2.DOWN.rotated(angle)
			var main_engine: bool = part.type == "engine"
			var nozzle_offset := MODULES.ENGINE_NOZZLE_OFFSET if main_engine else 0.40
			var pos := Vector2(part.x, part.y) * MODULES.CELL - center + direction * MODULES.CELL * nozzle_offset
			cached_engines.append({"nozzle": Transform2D(angle, pos), "size": 1.0 if main_engine else 0.65})
	ship_cache_ready = true

func _custom_stats() -> Dictionary:
	_ensure_ship_cache()
	return cached_ship_stats

func _current_ship() -> Dictionary:
	var totals := _custom_stats()
	return {"speed": totals.speed, "acceleration": totals.acceleration, "turn": totals.maneuver, "drag": 1.0}

func _player_max_hull() -> float:
	return _custom_stats().health

func _player_max_shield() -> float:
	return _custom_stats().shield

func _cargo_available() -> bool:
	return iron + tritium < int(_custom_stats().cargo)

func _ship_size() -> Vector2:
	_ensure_ship_cache()
	return cached_ship_bounds.size

func _ship_half_length() -> float:
	return _ship_size().y / 2.0

func _spawn_enemy_wave() -> void:
	wave_number += 1
	enemies.clear()
	selected_enemy = -1
	var enemy_count := mini(2 + wave_number, 12)
	var health_multiplier := 1.0 + 0.12 * float(wave_number - 1)
	var shield_multiplier := 1.0 + 0.08 * float(wave_number - 1)
	var fire_interval := maxf(0.65, 1.0 - 0.035 * float(wave_number - 1))
	var enemy_speed := ENEMY_SPEED * minf(1.35, 1.0 + 0.025 * float(wave_number - 1))
	for i in range(enemy_count):
		var design := MODULES.generate_random_design(rng, true)
		var stats := MODULES.stats(design)
		var bounds := MODULES.bounds(design)
		var dimensions := bounds.size * ENEMY_PART_SCALE
		var radius := dimensions.length() * 0.5
		var center := bounds.get_center()
		var exterior: Array[Dictionary] = []
		var turrets: Array[Dictionary] = []
		for part in design:
			if MODULES.is_interior(part):
				continue
			var module := {"part": part, "offset": (Vector2(part.x, part.y) * MODULES.CELL - center) * ENEMY_PART_SCALE}
			exterior.append(module)
			if part.has("turret"):
				turrets.append(module)
		var max_health := clampf(float(stats.health) / 5.0, 80.0, 140.0) * health_multiplier
		var max_shield := float(stats.shield) * (70.0 / 60.0) * shield_multiplier
		var margin := maxf(35.0, radius)
		var position := Vector2.ZERO
		# Spawn just inside a randomly selected world edge.
		for attempt in range(80):
			match rng.randi_range(0, 3):
				0: position = Vector2(margin, rng.randf_range(margin, WORLD_SIZE.y - margin))
				1: position = Vector2(WORLD_SIZE.x - margin, rng.randf_range(margin, WORLD_SIZE.y - margin))
				2: position = Vector2(rng.randf_range(margin, WORLD_SIZE.x - margin), margin)
				3: position = Vector2(rng.randf_range(margin, WORLD_SIZE.x - margin), WORLD_SIZE.y - margin)
			var separated := true
			for existing in enemies:
				if position.distance_to(existing.position) < radius + float(existing.radius) + 40.0:
					separated = false
					break
			if separated:
				break
		var facing := rng.randf_range(0.0, TAU)
		enemies.append({
			"position": position, "heading": facing, "aim_angle": facing, "velocity": Vector2.ZERO,
			"health": max_health, "max_health": max_health, "shield": max_shield, "max_shield": max_shield,
			"shield_delay": 0.0, "fire_cooldown": rng.randf_range(0.2, 1.0), "fire_interval": fire_interval,
			"speed": enemy_speed * clampf(float(stats.speed) / 0.85, 0.82, 1.18),
			"avoid_side": 1.0 if i % 2 == 0 else -1.0, "alive": true,
			"dimensions": dimensions, "radius": radius, "exterior": exterior, "turrets": turrets, "next_turret": 0,
		})
	enemy_wave_timer = -1.0

func _cycle_target() -> void:
	auto_approach = false
	var candidates: Array[Dictionary] = []
	for i in range(enemies.size()):
		if enemies[i].alive:
			var distance: float = ship_position.distance_to(enemies[i].position)
			if distance <= TARGET_RANGE:
				candidates.append({"type": "enemy", "index": i, "distance": distance})
	for i in range(asteroids.size()):
		if asteroids[i].iron > 0:
			var distance: float = ship_position.distance_to(asteroids[i].position)
			if distance <= TARGET_RANGE:
				candidates.append({"type": "asteroid", "index": i, "distance": distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.type != b.type:
			return a.type == "enemy"
		return a.distance < b.distance
	)
	if candidates.is_empty():
		selected_enemy = -1
		selected_asteroid = -1
		laser_active = false
		machine_gun_active = false
		return
	var next := 0
	for i in range(candidates.size()):
		var target: Dictionary = candidates[i]
		if (target.type == "enemy" and target.index == selected_enemy) or (target.type == "asteroid" and target.index == selected_asteroid):
			next = (i + 1) % candidates.size()
			break
	var target: Dictionary = candidates[next]
	selected_enemy = target.index if target.type == "enemy" else -1
	selected_asteroid = target.index if target.type == "asteroid" else -1
	laser_active = false
	machine_gun_active = false
	mining = false
	mining_progress = 0.0

func _break_up_enemy(enemy: Dictionary) -> void:
	var count := rng.randi_range(1, 3)
	var start_angle := rng.randf_range(0.0, TAU)
	for i in range(count):
		var angle := start_angle + TAU * float(i) / float(count) + rng.randf_range(-0.25, 0.25)
		var direction := Vector2.from_angle(angle)
		tritium_drops.append({"position": enemy.position + direction * 24.0, "velocity": direction * rng.randf_range(35.0, 70.0), "phase": rng.randf_range(0.0, TAU), "attracted": false})
	var rotation: float = enemy.heading + PI / 2.0
	for module in enemy.exterior:
		var offset: Vector2 = module.offset.rotated(rotation)
		var direction := offset.normalized().rotated(rng.randf_range(-0.7, 0.7))
		if offset.is_zero_approx():
			direction = Vector2.from_angle(rng.randf_range(0.0, TAU))
		debris.append({
			"position": enemy.position + offset, "velocity": direction * rng.randf_range(15.0, 75.0),
			"rotation": rotation, "spin": rng.randf_range(-2.2, 2.2), "part": module.part,
			"life": rng.randf_range(2.8, 4.5),
		})

func _update_debris(delta: float) -> void:
	for i in range(debris.size() - 1, -1, -1):
		debris[i].position += debris[i].velocity * delta
		debris[i].rotation += debris[i].spin * delta
		debris[i].life -= delta
		if debris[i].life <= 0.0:
			debris.remove_at(i)

func _collect_tritium(delta: float) -> void:
	var magnet_radius := maxf(260.0, _ship_half_length() + 200.0)
	for i in range(tritium_drops.size() - 1, -1, -1):
		var drop: Dictionary = tritium_drops[i]
		if not _cargo_available():
			drop.attracted = false
			drop.velocity = Vector2.ZERO
			continue
		var to_ship: Vector2 = ship_position - drop.position
		if to_ship.length() <= magnet_radius:
			drop.attracted = true
		if drop.attracted:
			var desired_velocity := to_ship.normalized() * 460.0
			drop.velocity = (drop.velocity as Vector2).move_toward(desired_velocity, 950.0 * delta)
		else:
			drop.velocity *= exp(-2.4 * delta)
		var previous: Vector2 = drop.position
		drop.position += drop.velocity * delta
		# Check the swept path to avoid skipping over a fast-moving pickup.
		if drop.attracted and Geometry2D.get_closest_point_to_segment(ship_position, previous, drop.position).distance_to(ship_position) <= 22.0:
			tritium += 1
			tritium_pickup_effects.append({"position": drop.position, "life": 0.65})
			tritium_drops.remove_at(i)
	for i in range(tritium_pickup_effects.size() - 1, -1, -1):
		tritium_pickup_effects[i].life -= delta
		if tritium_pickup_effects[i].life <= 0.0:
			tritium_pickup_effects.remove_at(i)

func _segment_ellipse_hit(start: Vector2, end: Vector2, center: Vector2, ship_heading: float, radii: Vector2) -> Variant:
	# Transform the swept shot into a unit circle so impacts match the rotated rim.
	var rotation := -(ship_heading + PI / 2.0)
	var local_start := (start - center).rotated(rotation) / radii
	var local_end := (end - center).rotated(rotation) / radii
	var movement := local_end - local_start
	var a := movement.length_squared()
	var c := local_start.length_squared() - 1.0
	if c <= 0.0:
		return start
	if a < 0.000001:
		return null
	var b := 2.0 * local_start.dot(movement)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var t := (-b - sqrt(discriminant)) / (2.0 * a)
	if t < 0.0 or t > 1.0:
		return null
	return start.lerp(end, t)

func _enemy_hull_radius(enemy: Dictionary, direction: Vector2) -> float:
	if direction.is_zero_approx():
		return float(enemy.radius)
	var local := direction.normalized().rotated(-float(enemy.heading) - PI / 2.0)
	var half_size: Vector2 = enemy.dimensions * 0.5
	return 1.0 / (local / half_size).length()

func _enemy_shot_contact(start: Vector2, end: Vector2, enemy: Dictionary) -> Variant:
	if enemy.shield > 0.0:
		var radii: Vector2 = enemy.dimensions * 0.5 + Vector2.ONE * SHIELD_MARGIN
		return _segment_ellipse_hit(start, end, enemy.position, enemy.heading, radii)
	return _enemy_hull_contact(start, end, enemy)

func _enemy_hull_contact(start: Vector2, end: Vector2, enemy: Dictionary) -> Variant:
	var rotation := -float(enemy.heading) - PI / 2.0
	var local_start := (start - (enemy.position as Vector2)).rotated(rotation)
	var step := (end - start).rotated(rotation)
	var half_cell := Vector2.ONE * MODULES.CELL * ENEMY_PART_SCALE * 0.5
	var first_hit := INF
	# Clip the shot against the occupied exterior cells in ship coordinates.
	for module in enemy.exterior:
		var low: Vector2 = module.offset - half_cell
		var high: Vector2 = module.offset + half_cell
		var entry := 0.0
		var exit := 1.0
		for axis in range(2):
			if is_zero_approx(step[axis]):
				if local_start[axis] < low[axis] or local_start[axis] > high[axis]:
					exit = -1.0
					break
				continue
			var near := (low[axis] - local_start[axis]) / step[axis]
			var far := (high[axis] - local_start[axis]) / step[axis]
			entry = maxf(entry, minf(near, far))
			exit = minf(exit, maxf(near, far))
		if entry <= exit:
			first_hit = minf(first_hit, entry)
	return start.lerp(end, first_hit) if first_hit < INF else null

func _make_spark_rays(direction: float) -> Array[Dictionary]:
	var rays: Array[Dictionary] = []
	var ray_count := rng.randi_range(4, 8) if graphics_quality == 2 else (3 if graphics_quality == 1 else 1)
	for i in range(ray_count):
		rays.append({"angle": direction + rng.randf_range(-1.25, 1.25), "speed": rng.randf_range(32.0, 95.0), "length": rng.randf_range(4.0, 13.0), "width": rng.randf_range(1.0, 2.4)})
	return rays

func _hull_hit(enemy_index: int, contact: Vector2, center: Vector2, ship_heading: float) -> void:
	var local_point := (contact - center).rotated(-(ship_heading + PI / 2.0))
	var direction := local_point.angle() if local_point.length_squared() > 0.001 else -PI / 2.0
	hull_impacts.append({"enemy": enemy_index, "position": local_point, "life": 0.5, "rays": _make_spark_rays(direction)})

func _draw_hull_impacts(enemy_index: int) -> void:
	for impact in hull_impacts:
		if impact.enemy != enemy_index:
			continue
		var progress: float = 1.0 - impact.life / 0.5
		var fade := 1.0 - smoothstep(0.0, 1.0, progress)
		var point: Vector2 = impact.position
		draw_circle(point, 7.0 + 5.0 * progress, Color(1.0, 0.30, 0.08, 0.30 * fade))
		draw_circle(point, 3.0 * fade, Color(1.0, 0.92, 0.62, fade))
		for ray_data in impact.rays:
			var ray := Vector2.from_angle(ray_data.angle)
			var distance: float = progress * ray_data.speed * 0.5
			var tip: float = distance + ray_data.length * fade
			draw_line(point + ray * distance, point + ray * tip, Color(1.0, 0.62, 0.23, fade), ray_data.width, true)

func _shield_hit(enemy_index: int, incoming_position: Vector2, center: Vector2, ship_heading: float) -> void:
	var local_direction := (incoming_position - center).rotated(-(ship_heading + PI / 2.0))
	if local_direction.length_squared() < 0.001:
		local_direction = Vector2.UP
	var angle := local_direction.angle()
	shield_impacts.append({"enemy": enemy_index, "angle": angle, "life": SHIELD_IMPACT_DURATION, "rays": _make_spark_rays(angle)})

func _draw_shield_impacts(enemy_index: int, dimensions: Vector2) -> void:
	var half_size := dimensions * 0.5 + Vector2.ONE * SHIELD_MARGIN
	for impact in shield_impacts:
		if impact.enemy != enemy_index:
			continue
		var direction := Vector2.from_angle(impact.angle)
		var angle := atan2(direction.y / half_size.y, direction.x / half_size.x)
		var progress: float = 1.0 - impact.life / SHIELD_IMPACT_DURATION
		var fade := 1.0 - smoothstep(0.15, 1.0, progress)
		for ring in range(2 if graphics_quality == 2 else 1):
			var wave := clampf(progress * 1.25 - float(ring) * 0.2, 0.0, 1.0)
			if ring == 1 and progress < 0.16:
				continue
			var width := 0.08 + wave * 0.44
			var radius := half_size + Vector2.ONE * float(ring) * 5.0
			var points := PackedVector2Array()
			var segments := 24 if graphics_quality == 2 else 12
			for i in range(segments + 1):
				var t := angle - width + float(i) / float(segments) * width * 2.0
				points.append(Vector2(cos(t) * radius.x, sin(t) * radius.y))
			var opacity := fade * (1.0 - wave * 0.35)
			draw_polyline(points, Color(0.15, 0.55, 1.0, 0.18 * opacity), 7.0, true)
			draw_polyline(points, Color(0.52, 0.89, 1.0, 0.9 * opacity), 2.5 - float(ring) * 0.7, true)
		var spark_fade := 1.0 - smoothstep(0.0, 0.4, progress)
		var hit_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		for ray_data in impact.rays:
			var ray := Vector2.from_angle(ray_data.angle)
			var inner: float = 2.0 + progress * ray_data.speed * 0.65
			var tip: float = inner + ray_data.length * spark_fade
			draw_line(hit_point + ray * inner, hit_point + ray * tip, Color(0.78, 0.96, 1.0, spark_fade), ray_data.width, true)

func _enemy_steering(enemy: Dictionary, intended: Vector2) -> Vector2:
	if intended.length_squared() < 0.001:
		return Vector2.ZERO
	var forward := intended.normalized()
	var side := forward.orthogonal() * float(enemy.avoid_side)
	var nearest_distance := INF
	var obstacle_position := Vector2.ZERO
	var obstacle_radius := 0.0
	var position: Vector2 = enemy.position
	# Check a short corridor ahead rather than only reacting after a collision.
	for asteroid in asteroids:
		if asteroid.iron <= 0:
			continue
		var offset: Vector2 = asteroid.position - position
		var clearance: float = asteroid.radius * 0.9 + float(enemy.radius) + 35.0
		var forward_distance := offset.dot(forward)
		if forward_distance < -30.0 or forward_distance > 250.0 + clearance:
			continue
		if absf(offset.dot(side)) < clearance and forward_distance < nearest_distance:
			nearest_distance = forward_distance
			obstacle_position = asteroid.position
			obstacle_radius = clearance
	for other in enemies:
		if is_same(other, enemy) or not other.alive:
			continue
		var offset: Vector2 = other.position - position
		var forward_distance := offset.dot(forward)
		var clearance := float(enemy.radius) + float(other.radius) + 24.0
		if forward_distance < -20.0 or forward_distance > 90.0 + clearance:
			continue
		if absf(offset.dot(side)) < clearance and forward_distance < nearest_distance:
			nearest_distance = forward_distance
			obstacle_position = other.position
			obstacle_radius = clearance
	if nearest_distance == INF:
		return forward
	var away := (position - obstacle_position).normalized()
	if away.length_squared() < 0.001:
		away = -forward
	# When an obstacle is off-centre, prefer the side already offering more room.
	var lateral := (position - obstacle_position).dot(forward.orthogonal())
	if absf(lateral) > obstacle_radius * 0.18:
		side = forward.orthogonal() * signf(lateral)
	return (forward * 0.45 + side * 1.15 + away * 0.55).normalized()

func _enemy_combat_velocity(enemy: Dictionary, away: Vector2, distance: float, extra_range: float) -> Vector2:
	var speed: float = enemy.speed
	var preferred_range := ENEMY_PREFERRED_RANGE + extra_range
	var player_outward_speed := velocity.dot(away)
	var radial_speed := (preferred_range - distance) * 1.8 + player_outward_speed
	var tangent := away.orthogonal() * float(enemy.avoid_side)
	var orbit_speed := speed * 0.6 * (1.0 - smoothstep(preferred_range, preferred_range + 220.0, distance))
	var position: Vector2 = enemy.position
	var edge_margin := Vector2.ONE * 180.0
	var inward := (position.clamp(edge_margin, WORLD_SIZE - edge_margin) - position) / edge_margin.x
	var intended := away * clampf(radial_speed, -speed, speed) + tangent * orbit_speed + inward * speed
	var steered := _enemy_steering(enemy, intended) * minf(intended.length(), speed)
	# Obstacle steering can turn inward. Limit closing speed as the fighter nears the player.
	var minimum_range := ENEMY_MIN_COMBAT_RANGE + extra_range
	var min_outward_speed := clampf(player_outward_speed + (minimum_range - distance) * 2.0, -speed, speed * 0.8)
	var outward_speed := maxf(steered.dot(away), min_outward_speed)
	var sideways_limit := sqrt(maxf(0.0, speed * speed - outward_speed * outward_speed))
	return away * outward_speed + tangent * clampf(steered.dot(tangent), -sideways_limit, sideways_limit)

func _turret_key(part: Dictionary) -> Vector2i:
	return Vector2i(int(part.x), int(part.y))

func _turret_angle(part: Dictionary) -> float:
	var rest_angle := heading + float(int(part.get("rotation", 0))) * PI / 2.0
	return float(turret_angles.get(_turret_key(part), rest_angle))

func _update_turrets(delta: float) -> void:
	for part in custom_parts:
		var kind: String = part.get("turret", "")
		if kind not in MODULES.TURRETS:
			continue
		var current := _turret_angle(part)
		var desired := heading + float(int(part.get("rotation", 0))) * PI / 2.0
		var target_position := _screen_to_world(get_viewport().get_mouse_position())
		var tracking := (kind == "laser" and selected_weapon == 1) or (kind == "miner" and selected_weapon == 2) or (kind == "machine_gun" and selected_weapon == 3) or (kind == "missile" and selected_weapon == 4)
		if tracking:
			var direction := target_position - _turret_world_position(part)
			if direction.length_squared() > 0.001:
				desired = direction.angle()
		var speed: float = MODULES.TYPES[kind].turret_turn_speed
		var change := clampf(angle_difference(current, desired), -speed * delta, speed * delta)
		turret_angles[_turret_key(part)] = wrapf(current + change, -PI, PI)

func _turret_is_aimed(part: Dictionary, target_position: Vector2) -> bool:
	var to_target := target_position - _turret_world_position(part)
	return to_target.length_squared() > 0.001 and absf(angle_difference(_turret_angle(part), to_target.angle())) <= TURRET_AIM_TOLERANCE

func _has_aimed_turret(kind: String, target_position: Vector2) -> bool:
	for part in custom_parts:
		if part.get("turret", "") == kind and _turret_is_aimed(part, target_position):
			return true
	return false

func _aimed_mining_rate(target_position: Vector2) -> float:
	var rate := 0.0
	for part in custom_parts:
		if part.get("turret", "") == "miner" and _turret_is_aimed(part, target_position):
			rate += float(MODULES.TYPES.miner.mining)
	return rate

func _fire_enemy_turret(enemy: Dictionary) -> void:
	var turrets: Array = enemy.turrets
	if turrets.is_empty():
		return
	var mount: Dictionary = turrets[enemy.next_turret]
	enemy.next_turret = (int(enemy.next_turret) + 1) % turrets.size()
	var aim_angle: float = enemy.aim_angle
	var direction := Vector2.from_angle(aim_angle)
	var origin: Vector2 = enemy.position + mount.offset.rotated(float(enemy.heading) + PI / 2.0)
	var shot := {"position": origin + direction * 13.0, "velocity": direction * 800.0, "friendly": false}
	var cadence := 1.0
	match mount.part.turret:
		"machine_gun":
			shot.merge({"kind": "bullet", "damage": 5.0})
			shot.velocity = direction * 1050.0
			cadence = 0.55
		"missile":
			shot.merge({"kind": "rocket", "damage": 16.0, "rocket_heading": aim_angle, "age": 0.0})
			shot.velocity = direction * 300.0
			cadence = 1.7
	projectiles.append(shot)
	enemy.fire_cooldown = rng.randf_range(0.65, 1.05) * float(enemy.fire_interval) * cadence

func _update_combat(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	player_shield_delay = maxf(0.0, player_shield_delay - delta)
	if player_shield_delay <= 0.0:
		player_shield = minf(_player_max_shield(), player_shield + 10.0 * delta)
	for i in range(shield_impacts.size() - 1, -1, -1):
		shield_impacts[i].life -= delta
		if shield_impacts[i].life <= 0.0:
			shield_impacts.remove_at(i)
	for i in range(hull_impacts.size() - 1, -1, -1):
		hull_impacts[i].life -= delta
		if hull_impacts[i].life <= 0.0:
			hull_impacts.remove_at(i)
	player_fire_cooldown = maxf(0.0, player_fire_cooldown - delta)
	machine_gun_cooldown = maxf(0.0, machine_gun_cooldown - delta)
	rocket_cooldown = maxf(0.0, rocket_cooldown - delta)
	var living := 0
	var player_half_size := _ship_size() * 0.5
	var player_rotation := heading + PI / 2.0
	for enemy in enemies:
		if not enemy.alive:
			continue
		living += 1
		enemy.shield_delay = maxf(0.0, enemy.shield_delay - delta)
		if enemy.shield_delay <= 0.0:
			enemy.shield = minf(enemy.max_shield, enemy.shield + enemy.max_shield * 0.1 * delta)
		var to_player: Vector2 = ship_position - enemy.position
		var distance := to_player.length()
		var away := -to_player / distance if distance > 0.01 else -Vector2.from_angle(enemy.heading)
		# Leave room for large custom hulls along the fighter's approach.
		var hull_clearance := player_half_size.dot(away.rotated(-player_rotation).abs()) + _enemy_hull_radius(enemy, away) + 100.0
		var extra_range := maxf(0.0, hull_clearance - ENEMY_MIN_COMBAT_RANGE)
		var aim := to_player
		if distance > 0.01:
			aim = to_player + velocity * minf(distance / 800.0, 1.0) * 0.65
			enemy.aim_angle = aim.angle()
			enemy.heading = lerp_angle(enemy.heading, aim.angle(), 1.0 - exp(-4.0 * delta))
		var desired_velocity := _enemy_combat_velocity(enemy, away, distance, extra_range)
		var current_velocity: Vector2 = enemy.velocity
		enemy.velocity = current_velocity.move_toward(desired_velocity, ENEMY_ACCELERATION * delta)
		enemy.position += enemy.velocity * delta
		enemy.fire_cooldown -= delta
		var in_firing_range := distance >= ENEMY_MIN_COMBAT_RANGE + extra_range and distance <= ENEMY_FIRE_RANGE + extra_range
		if in_firing_range and enemy.fire_cooldown <= 0.0 and absf(angle_difference(enemy.heading, aim.angle())) < 0.25:
			_fire_enemy_turret(enemy)
	var aim_position := _screen_to_world(get_viewport().get_mouse_position())
	if firing and selected_weapon == 1 and player_fire_cooldown <= 0.0:
		var fired := false
		for part in custom_parts:
			if part.get("turret", "") == "laser" and _turret_is_aimed(part, aim_position):
				var origin := _turret_world_position(part)
				var direction := Vector2.from_angle(_turret_angle(part))
				projectiles.append({"position": origin + direction * 16.0, "velocity": direction * 800.0, "friendly": true, "damage": MODULES.TYPES[part.turret].weapon})
				fired = true
		if fired:
			player_fire_cooldown = 0.4
	if firing and selected_weapon == 3 and machine_gun_cooldown <= 0.0:
		var fired := false
		for part in custom_parts:
			if part.get("turret", "") == "machine_gun" and _turret_is_aimed(part, aim_position):
				var origin := _turret_world_position(part)
				var direction := Vector2.from_angle(_turret_angle(part)).rotated(rng.randf_range(-0.035, 0.035))
				projectiles.append({"position": origin + direction * 16.0, "velocity": direction * 1200.0 + velocity * 0.25, "friendly": true, "damage": 4.0, "kind": "bullet"})
				fired = true
		if fired:
			machine_gun_cooldown = 0.10
	if firing and selected_weapon == 4 and rocket_cooldown <= 0.0:
		var fired := false
		for part in custom_parts:
			if part.get("turret", "") == "missile" and _turret_is_aimed(part, aim_position):
				var origin := _turret_world_position(part)
				var direction := Vector2.from_angle(_turret_angle(part))
				projectiles.append({"position": origin + direction * 16.0, "velocity": direction * 300.0 + velocity, "friendly": true, "damage": MODULES.TYPES.missile.weapon, "kind": "rocket", "target": {}, "rocket_heading": direction.angle(), "age": 0.0})
				fired = true
		if fired:
			rocket_cooldown = 1.2
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		if shot.get("kind", "") == "rocket":
			_update_rocket(shot, delta)
		var previous: Vector2 = shot.position
		shot.position += shot.velocity * delta
		var hit := false
		if shot.friendly:
			var hit_index := -1
			var hit_point: Variant = null
			var closest := INF
			for j in range(enemies.size()):
				var enemy: Dictionary = enemies[j]
				if not enemy.alive:
					continue
				var broad_radius := float(enemy.radius) + SHIELD_MARGIN
				var segment_center: Vector2 = (previous + shot.position) * 0.5
				var broad_distance := broad_radius + previous.distance_to(shot.position) * 0.5
				if segment_center.distance_squared_to(enemy.position) > broad_distance * broad_distance:
					continue
				var contact: Variant = _enemy_shot_contact(previous, shot.position, enemy)
				if contact != null and previous.distance_squared_to(contact) < closest:
					closest = previous.distance_squared_to(contact)
					hit_index = j
					hit_point = contact
			if hit_index >= 0:
				var enemy: Dictionary = enemies[hit_index]
				var damage: float = shot.get("damage", 35.0)
				var absorbed: float = minf(enemy.shield, damage)
				if absorbed > 0.0:
					_shield_hit(hit_index, hit_point, enemy.position, enemy.heading)
				else:
					_hull_hit(hit_index, hit_point, enemy.position, enemy.heading)
				enemy.shield -= absorbed
				enemy.shield_delay = 4.0
				enemy.health -= damage - absorbed
				hit = true
				if enemy.health <= 0:
					enemy.alive = false
					_break_up_enemy(enemy)
					if selected_enemy == hit_index:
						selected_enemy = -1
						laser_active = false
						machine_gun_active = false
		elif invulnerability <= 0.0:
			var radii := _ship_size() * 0.5 + Vector2.ONE * SHIELD_MARGIN if player_shield > 0.0 else _ship_size() * 0.35
			var contact: Variant = _segment_ellipse_hit(previous, shot.position, ship_position, heading, radii)
			if contact != null:
				var damage := float(shot.get("damage", 10.0))
				var absorbed := minf(player_shield, damage)
				if absorbed > 0.0:
					_shield_hit(-1, contact, ship_position, heading)
				else:
					_hull_hit(-1, contact, ship_position, heading)
				player_shield -= absorbed
				player_shield_delay = 4.0
				player_hull -= damage - absorbed
				hit = true
				if player_hull <= 0:
					player_hull = _player_max_hull()
					player_shield = _player_max_shield()
					player_shield_delay = 0.0
					shield_impacts.clear()
					hull_impacts.clear()
					ship_position = WORLD_SIZE / 2.0
					velocity = Vector2.ZERO
					selected_asteroid = -1
					selected_enemy = -1
					laser_active = false
					machine_gun_active = false
					mining = false
					invulnerability = 3.0
		if hit or not Rect2(Vector2.ZERO, WORLD_SIZE).has_point(shot.position):
			projectiles.remove_at(i)
	if living == 0:
		if enemy_wave_timer < 0.0:
			enemy_wave_timer = 12.0
		else:
			enemy_wave_timer -= delta
			if enemy_wave_timer <= 0.0:
				_spawn_enemy_wave()

func _generate_asteroid_field() -> void:
	asteroids.clear()
	const ZONE_COLUMNS := 4
	const ZONE_ROWS := 3
	var zone_size := WORLD_SIZE / Vector2(ZONE_COLUMNS, ZONE_ROWS)
	var home_zone := Vector2i(int(ship_position.x / zone_size.x), int(ship_position.y / zone_size.y))
	# Keep a large asteroid close enough to discover without placing it on the ship.
	var starter_radius := rng.randf_range(145.0, 210.0)
	var ship_extent := maxf(_ship_size().x, _ship_size().y) * 0.5
	var starter_position := ship_position + Vector2(maxf(420.0, ship_extent + starter_radius + 100.0), -120.0)
	starter_position = starter_position.clamp(Vector2.ZERO + Vector2.ONE * starter_radius, WORLD_SIZE - Vector2.ONE * starter_radius)
	_add_asteroid(starter_position, starter_radius)
	# A sparse field of one to three large asteroids per world region.
	for zone_y in range(ZONE_ROWS):
		for zone_x in range(ZONE_COLUMNS):
			var zone := Vector2i(zone_x, zone_y)
			var count := rng.randi_range(1, 3) - (1 if zone == home_zone else 0)
			var zone_origin := Vector2(zone) * zone_size
			for i in range(count):
				var radius := rng.randf_range(145.0, 210.0)
				for attempt in range(100):
					var position := zone_origin + Vector2(rng.randf_range(radius, zone_size.x - radius), rng.randf_range(radius, zone_size.y - radius))
					if position.distance_to(ship_position) < ship_extent + radius + 100.0:
						continue
					var clear := true
					for other in asteroids:
						if position.distance_to(other.position) < radius + float(other.radius) + 100.0:
							clear = false
							break
					if clear:
						_add_asteroid(position, radius)
						break

func _add_asteroid(position: Vector2, radius: float) -> void:
	var shape := PackedVector2Array()
	var inner := PackedVector2Array()
	var faces: Array[Color] = []
	var vertex_count := rng.randi_range(14, 19)
	var base := Color.from_hsv(rng.randf_range(0.055, 0.12), rng.randf_range(0.08, 0.22), rng.randf_range(0.30, 0.40))
	for i in range(vertex_count):
		var angle := TAU * float(i) / vertex_count
		var point := Vector2.from_angle(angle) * radius * rng.randf_range(0.80, 1.0)
		shape.append(point)
		inner.append(point * rng.randf_range(0.42, 0.57) + Vector2(-radius * 0.07, -radius * 0.08))
		var light := clampf(0.85 - 0.25 * sin(angle) - 0.17 * cos(angle) + rng.randf_range(-0.10, 0.10), 0.48, 1.2)
		faces.append(Color(base.r * light, base.g * light, base.b * light))
	var craters: Array[Dictionary] = []
	for i in range(rng.randi_range(3, 6)):
		var center := Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius * rng.randf_range(0.06, 0.42)
		craters.append({"position": center, "radius": radius * rng.randf_range(0.045, 0.11)})
	var specks: Array[Dictionary] = []
	for i in range(rng.randi_range(16, 27)):
		var center := Vector2.from_angle(rng.randf_range(0.0, TAU)) * radius * sqrt(rng.randf()) * 0.68
		specks.append({"position": center, "size": rng.randf_range(0.7, 2.0), "light": rng.randf() > 0.55})
	var capacity := int(round(radius * radius / 42.25))
	asteroids.append({"position": position, "radius": radius, "shape": shape, "inner": inner, "faces": faces, "base": base, "craters": craters, "specks": specks, "iron": capacity, "max_iron": capacity})

func _draw_asteroid(asteroid: Dictionary) -> void:
	var center: Vector2 = asteroid.position
	var radius: float = asteroid.radius
	var shape: PackedVector2Array = asteroid.shape
	var inner: PackedVector2Array = asteroid.inner
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point)
	# At a distance, individual grains and crater outlines are too small to see.
	if graphics_quality == 0 or radius * camera_zoom <= (90.0 if graphics_quality == 1 else 45.0):
		draw_colored_polygon(points, asteroid.base)
		var simplified_inner := PackedVector2Array()
		for point in inner:
			simplified_inner.append(center + point)
		draw_colored_polygon(simplified_inner, asteroid.base.lightened(0.10))
		return
	# Dark rim and offset shadow give the rock a solid silhouette.
	draw_colored_polygon(points, Color("282b30"))
	for i in range(shape.size()):
		var next := (i + 1) % shape.size()
		var facet := PackedVector2Array([center + shape[i], center + shape[next], center + inner[next], center + inner[i]])
		draw_colored_polygon(facet, asteroid.faces[i])
	var inner_points := PackedVector2Array()
	for point in inner:
		inner_points.append(center + point)
	draw_colored_polygon(inner_points, asteroid.base.lightened(0.10))
	# Fine rocky grain and shallow, shaded impact craters.
	for speck in asteroid.specks:
		var shade := Color(0.82, 0.77, 0.67, 0.20) if speck.light else Color(0.08, 0.08, 0.09, 0.25)
		draw_circle(center + speck.position, speck.size, shade)
	for crater in asteroid.craters:
		var p: Vector2 = center + crater.position
		var r: float = crater.radius
		draw_circle(p + Vector2(1, 1) * radius * 0.015, r * 1.12, Color(0.75, 0.71, 0.62, 0.22))
		draw_circle(p, r, Color(0.12, 0.13, 0.14, 0.55))
		draw_arc(p, r * 0.82, PI * 0.95, PI * 1.9, 12, Color(0.07, 0.08, 0.09, 0.38), maxf(1.0, radius * 0.018), true)
	draw_polyline(points + PackedVector2Array([points[0]]), Color(0.08, 0.09, 0.11, 0.85), maxf(1.5, radius * 0.025), true)
	draw_line(points[0], points[1], Color(0.85, 0.82, 0.74, 0.22), 1.5, true)

func _screen_to_world(point: Vector2) -> Vector2:
	return ((point - get_viewport_rect().size / 2.0) / camera_zoom + ship_position).clamp(Vector2.ZERO, WORLD_SIZE)

func _input(event: InputEvent) -> void:
	if is_instance_valid(builder_layer):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			var builder := builder_layer.get_child(0)
			if builder.has_open_design_dialog():
				builder.close_design_dialog()
			else:
				_close_builder()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		if not is_instance_valid(settings_layer):
			if event.pressed and not boost_charging:
				boost_charging = true
				boost_charge = 0.0
			elif not event.pressed and boost_charging:
				_launch_boost()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(settings_layer):
			_close_settings()
		else:
			_open_settings()
		get_viewport().set_input_as_handled()
		return
	# Stop firing even when the pointer is over a menu control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		firing = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		firing = false
		
func _has_turret(kind: String) -> bool:
	return custom_parts.any(func(part: Dictionary) -> bool: return part.get("turret", "") == kind)

func _valid_enemy_target() -> bool:
	return selected_enemy >= 0 and selected_enemy < enemies.size() and enemies[selected_enemy].alive

func _fire_rockets() -> void:
	if not _valid_enemy_target() or not _has_turret("missile") or rocket_cooldown > 0.0:
		return
	if ship_position.distance_to(enemies[selected_enemy].position) > WEAPON_RANGE:
		return
	rocket_pending = true
	rocket_pending_target = enemies[selected_enemy]
	_try_launch_rockets()

func _try_launch_rockets() -> void:
	if not rocket_pending:
		return
	if not _valid_enemy_target() or not is_same(enemies[selected_enemy], rocket_pending_target) or not _has_turret("missile"):
		rocket_pending = false
		return
	var enemy: Dictionary = enemies[selected_enemy]
	if ship_position.distance_to(enemy.position) > WEAPON_RANGE:
		rocket_pending = false
		return
	var fired := false
	for part in custom_parts:
		if part.get("turret", "") == "missile" and _turret_is_aimed(part, enemy.position):
			var origin := _turret_world_position(part)
			var direction := Vector2.from_angle(_turret_angle(part))
			projectiles.append({"position": origin + direction * 16.0, "velocity": direction * 300.0 + velocity, "friendly": true, "damage": MODULES.TYPES.missile.weapon, "kind": "rocket", "target": enemy, "rocket_heading": direction.angle(), "age": 0.0})
			fired = true
	if fired:
		rocket_pending = false
		rocket_cooldown = 1.2

func _update_rocket(shot: Dictionary, delta: float) -> void:
	shot.age += delta
	var rocket_heading: float = shot.rocket_heading
	# Limited angular speed and acceleration preserve momentum and allow overshoots.
	var target: Dictionary = shot.get("target", {})
	if shot.age > 0.18 and (not shot.friendly or target.get("alive", false)):
		var target_position: Vector2 = target.position if shot.friendly else ship_position
		var to_target: Vector2 = target_position - shot.position
		if to_target.length_squared() > 1.0:
			rocket_heading += clampf(angle_difference(rocket_heading, to_target.angle()), -1.6 * delta, 1.6 * delta)
	shot.rocket_heading = rocket_heading
	var current_velocity: Vector2 = shot.velocity
	shot.velocity = current_velocity.move_toward(Vector2.from_angle(rocket_heading) * 720.0, 330.0 * delta)

func _mining_range(asteroid: Dictionary) -> float:
	return asteroid.radius + maxf(650.0, _ship_half_length() + 35.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_TAB:
				_cycle_target()
			KEY_1, KEY_KP_1:
				selected_weapon = 1
			KEY_2, KEY_KP_2:
				selected_weapon = 2
			KEY_3, KEY_KP_3:
				selected_weapon = 3
			KEY_4, KEY_KP_4:
				selected_weapon = 4
			_:
				return
		get_viewport().set_input_as_handled()
		queue_redraw()
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_zoom = minf(camera_zoom * 1.12, SETTINGS_MENU.MAX_ZOOM)
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_zoom = maxf(camera_zoom / 1.12, SETTINGS_MENU.MIN_ZOOM)
			queue_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			firing = true
			return

func _launch_boost() -> void:
	boost_charging = false
	boost_power = boost_charge
	boost_duration = lerpf(0.85, 2.0, boost_power)
	boost_time = boost_duration
	var speed_factor: float = _current_ship().speed
	var launch_speed := lerpf(1200.0, 1800.0, boost_power) * speed_factor
	velocity += Vector2.from_angle(heading) * launch_speed
	auto_approach = false
	boost_charge = 0.0

func _player_collision_discs() -> Array[Vector2]:
	var size := _ship_size()
	var radius := minf(size.x * 0.43, size.y * 0.34)
	var extent := maxf(0.0, size.y * 0.48 - radius)
	var count := maxi(1, int(ceil(2.0 * extent / (radius * 1.6))) + 1) if extent > 0.0 else 1
	var discs: Array[Vector2] = []
	for i in range(count):
		var along := lerpf(-extent, extent, float(i) / float(count - 1)) if count > 1 else 0.0
		discs.append(Vector2(0, along).rotated(heading + PI / 2.0))
	return discs

func _resolve_ship_collisions() -> void:
	var previous_position := ship_position
	var size := _ship_size()
	var player_radius := minf(size.x * 0.43, size.y * 0.34)
	var discs := _player_collision_discs()
	# A few relaxation passes resolve contacts without doing detailed off-screen drawing.
	for pass_index in range(3):
		for asteroid in asteroids:
			if asteroid.iron <= 0:
				continue
			var rock_radius: float = asteroid.radius * 0.90
			if ship_position.distance_squared_to(asteroid.position) < pow(size.y * 0.5 + rock_radius, 2):
				for offset in discs:
					var difference: Vector2 = ship_position + offset - asteroid.position
					var limit := player_radius + rock_radius
					if difference.length_squared() >= limit * limit:
						continue
					var distance := difference.length()
					var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
					ship_position += normal * (limit - distance)
					var inward := velocity.dot(normal)
					if inward < 0.0:
						velocity -= normal * inward
			for enemy in enemies:
				if not enemy.alive:
					continue
				var difference: Vector2 = enemy.position - asteroid.position
				var broad_limit := float(enemy.radius) + rock_radius
				if difference.length_squared() >= broad_limit * broad_limit:
					continue
				var limit := _enemy_hull_radius(enemy, difference) + rock_radius
				if difference.length_squared() < limit * limit:
					var distance := difference.length()
					var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
					enemy.position += normal * (limit - distance)
		for i in range(enemies.size()):
			var enemy: Dictionary = enemies[i]
			if not enemy.alive:
				continue
			for offset in discs:
				var difference: Vector2 = ship_position + offset - enemy.position
				var limit := player_radius + _enemy_hull_radius(enemy, difference)
				if difference.length_squared() >= limit * limit:
					continue
				var distance := difference.length()
				var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
				var overlap := limit - distance
				var player_share := 0.10
				ship_position += normal * overlap * player_share
				enemy.position -= normal * overlap * (1.0 - player_share)
				var inward := velocity.dot(normal)
				if inward < 0.0:
					velocity -= normal * inward
				var enemy_velocity: Vector2 = enemy.velocity
				var enemy_inward := enemy_velocity.dot(normal)
				if enemy_inward > 0.0:
					enemy.velocity = enemy_velocity - normal * enemy_inward
			for j in range(i + 1, enemies.size()):
				var other: Dictionary = enemies[j]
				if not other.alive:
					continue
				var difference: Vector2 = enemy.position - other.position
				var limit := _enemy_hull_radius(enemy, difference) + _enemy_hull_radius(other, difference)
				if difference.length_squared() < limit * limit:
					var distance := difference.length()
					var normal := difference / distance if distance > 0.001 else Vector2.from_angle(float(i + j) * 1.7)
					var separation := normal * (limit - distance) * 0.5
					enemy.position += separation
					other.position -= separation
			enemy.position = (enemy.position as Vector2).clamp(Vector2.ZERO, WORLD_SIZE)
		ship_position = ship_position.clamp(Vector2.ZERO, WORLD_SIZE)
	world_offset += ship_position - previous_position

func _steer_heading(direction: Vector2, max_turn_rate: float, delta: float) -> void:
	var turn_acceleration := max_turn_rate * 3.0
	var desired_rate := 0.0
	var error := 0.0
	if direction.length_squared() > 0.0001:
		error = angle_difference(heading, direction.angle())
		# Slow down in time to settle on the requested direction.
		desired_rate = signf(error) * minf(max_turn_rate, sqrt(2.0 * turn_acceleration * absf(error)))
	angular_velocity = move_toward(angular_velocity, desired_rate, turn_acceleration * delta)
	var step := angular_velocity * delta
	if direction.length_squared() > 0.0001 and signf(step) == signf(error) and absf(step) >= absf(error):
		heading = direction.angle()
		angular_velocity = 0.0
	else:
		heading = wrapf(heading + step, -PI, PI)

func _update_flight_motion(direction: Vector2, target_speed: float, ship_acceleration: float, ship_turn_speed: float, ship_drag: float, boosting: bool, delta: float) -> void:
	var engine_power := 1.0 if direction != Vector2.ZERO else 0.0
	var turn_rate := ship_turn_speed * (0.5 if boosting else 1.0)
	_steer_heading(direction, turn_rate, delta)
	if direction != Vector2.ZERO:
		var forward := Vector2.from_angle(heading)
		if boosting:
			# Steering adds a little thrust along the nose without erasing the boost's momentum.
			velocity += forward * ship_acceleration * 0.12 * delta
			velocity *= exp(-0.42 * delta)
		else:
			# Sideways momentum fades gradually as the main engine pushes along the nose.
			var forward_speed := velocity.dot(forward)
			var sideways := velocity - forward * forward_speed
			sideways *= exp(-0.55 * delta)
			if forward_speed < target_speed:
				forward_speed = minf(target_speed, forward_speed + ship_acceleration * delta)
			else:
				forward_speed = move_toward(forward_speed, target_speed, ship_acceleration * 0.35 * delta)
			velocity = forward * forward_speed + sideways
			if velocity.length() > target_speed:
				velocity = velocity.normalized() * move_toward(velocity.length(), target_speed, ship_acceleration * 0.6 * delta)
	elif boosting:
		velocity *= exp(-0.42 * delta)
	else:
		velocity *= exp(-drag * ship_drag * delta)
	if not boosting and direction == Vector2.ZERO and velocity.length() < 0.5:
		velocity = Vector2.ZERO
	thrust = move_toward(thrust, engine_power, delta * 5.0)

func _update_manual_flight(turn_input: float, accelerating: bool, braking: bool, speed_limit: float, ship_acceleration: float, ship_turn_speed: float, boosting: bool, delta: float) -> void:
	var max_turn_rate := ship_turn_speed * (0.5 if boosting else 1.0)
	angular_velocity = move_toward(angular_velocity, turn_input * max_turn_rate, max_turn_rate * 3.0 * delta)
	heading = wrapf(heading + angular_velocity * delta, -PI, PI)
	var engine_power := 0.0
	if braking:
		velocity = velocity.move_toward(Vector2.ZERO, ship_acceleration * delta)
	elif boosting:
		if accelerating:
			velocity += Vector2.from_angle(heading) * ship_acceleration * 0.12 * delta
			engine_power = 1.0
		velocity *= exp(-0.42 * delta)
	elif accelerating:
		var forward := Vector2.from_angle(heading)
		var forward_speed := velocity.dot(forward)
		var sideways := (velocity - forward * forward_speed) * exp(-0.55 * delta)
		forward_speed = move_toward(forward_speed, speed_limit, ship_acceleration * delta)
		velocity = forward * forward_speed + sideways
		if velocity.length() > speed_limit:
			velocity = velocity.normalized() * move_toward(velocity.length(), speed_limit, ship_acceleration * 0.6 * delta)
		engine_power = 1.0
	else:
		# Turning alone retains momentum while the ship rotates.
		velocity *= exp(-0.55 * delta)
	thrust = move_toward(thrust, engine_power, delta * 5.0)

func _physics_process(delta: float) -> void:
	elapsed += delta
	_update_turrets(delta)
	var turn_input := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var accelerating := Input.is_key_pressed(KEY_W)
	var braking := Input.is_key_pressed(KEY_S)
	var manual_control := turn_input != 0.0 or accelerating or braking
	var input_direction := Vector2.ZERO
	if boost_charging:
		boost_charge = minf(1.0, boost_charge + delta / BOOST_CHARGE_SECONDS)
	var boosting := boost_time > 0.0
	if boosting:
		boost_time = maxf(0.0, boost_time - delta)
	var ship: Dictionary = _current_ship()
	var ship_acceleration := acceleration * float(ship.acceleration)
	var ship_turn_speed := turn_speed * float(ship.turn)
	var speed_limit := top_speed * float(ship.speed)
	# The mining beam follows the pointer and operates while the fire button is held.
	mining = false
	laser_active = firing and selected_weapon == 2
	selected_asteroid = -1
	if laser_active:
		var aim_position := _screen_to_world(get_viewport().get_mouse_position())
		for i in range(asteroids.size() - 1, -1, -1):
			if asteroids[i].iron > 0 and aim_position.distance_to(asteroids[i].position) <= asteroids[i].radius:
				selected_asteroid = i
				break
	if laser_active and selected_asteroid >= 0:
		var asteroid: Dictionary = asteroids[selected_asteroid]
		var mining_range := _mining_range(asteroid)
		if ship_position.distance_to(asteroid.position) <= mining_range:
			var mining_rate := _aimed_mining_rate(asteroid.position)
			mining = mining_rate > 0.0
			mining_progress += delta * mining_rate
			while mining_progress >= 1.0 and asteroid.iron > 0 and _cargo_available():
				mining_progress -= 1.0
				asteroid.iron -= 1
				iron += 1
			if not _cargo_available():
				mining = false
				mining_progress = minf(mining_progress, 1.0)
			if asteroid.iron <= 0:
				selected_asteroid = -1
				laser_active = false
				machine_gun_active = false
				mining = false
				mining_progress = 0.0
	if manual_control:
		_update_manual_flight(turn_input, accelerating, braking, speed_limit, ship_acceleration, ship_turn_speed, boosting, delta)
	else:
		_update_flight_motion(input_direction, speed_limit, ship_acceleration, ship_turn_speed, float(ship.drag), boosting, delta)
	var movement := velocity * delta
	ship_position += movement
	world_offset += movement
	# Keep the ship inside the large play area.
	ship_position = ship_position.clamp(Vector2.ZERO, WORLD_SIZE)
	if ship_position.x <= 0.0 or ship_position.x >= WORLD_SIZE.x:
		velocity.x = 0.0
	if ship_position.y <= 0.0 or ship_position.y >= WORLD_SIZE.y:
		velocity.y = 0.0
	_update_combat(delta)
	_resolve_ship_collisions()
	_collect_tritium(delta)
	_update_debris(delta)
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("070e20"))
	# Faint colored haze and layered stars provide a sense of motion.
	if graphics_quality > 0:
		draw_circle(size * Vector2(0.78, 0.22), size.x * 0.32, Color(0.08, 0.13, 0.28, 0.12))
	if graphics_quality == 2:
		draw_circle(size * Vector2(0.2, 0.8), size.x * 0.25, Color(0.04, 0.16, 0.2, 0.09))
	var star_count := mini(stars.size(), 55 if graphics_quality == 0 else (110 if graphics_quality == 1 else 190))
	for star_index in range(star_count):
		var star: Dictionary = stars[star_index]
		var depth: float = star.depth
		var p: Vector2 = star.position * size - world_offset * depth * 0.12
		p = Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y))
		var alpha: float = (0.25 + depth * 0.5) * (0.85 + 0.15 * sin(elapsed * 1.5 + star.phase))
		draw_circle(p, 0.5 + depth * 1.1, Color(0.7, 0.85, 1.0, alpha))
	# Skip detailed drawing outside the camera while keeping world simulation active.
	var visible_world := Rect2(ship_position - size / (2.0 * camera_zoom), size / camera_zoom).grow(220.0)
	# World objects are drawn relative to a camera centered on the ship.
	draw_set_transform(size / 2.0 - ship_position * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
	for asteroid in asteroids:
		if asteroid.iron > 0 and visible_world.has_point(asteroid.position):
			_draw_asteroid(asteroid)
	if selected_asteroid >= 0:
		var selected: Dictionary = asteroids[selected_asteroid]
		draw_arc(selected.position, selected.radius + 10.0, 0.0, TAU, 48, Color(0.45, 0.9, 1.0, 0.75), 2.0, true)
		if mining:
			var bar_size := Vector2(maxf(selected.radius * 1.5, 65.0), 7.0)
			var bar_position: Vector2 = selected.position + Vector2(-bar_size.x / 2.0, -selected.radius - 24.0)
			draw_rect(Rect2(bar_position, bar_size), Color(0.03, 0.06, 0.09, 0.9))
			draw_rect(Rect2(bar_position, Vector2(bar_size.x * float(selected.iron) / float(selected.max_iron), bar_size.y)), Color("e3ad79"))
			draw_rect(Rect2(bar_position, bar_size), Color(0.8, 0.88, 0.9, 0.8), false, 1.0)

	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if not enemy.alive or not visible_world.has_point(enemy.position):
			continue
		draw_set_transform(size / 2.0 - ship_position * camera_zoom + enemy.position * camera_zoom, enemy.heading + PI / 2.0, Vector2.ONE * camera_zoom)
		var enemy_size: Vector2 = enemy.dimensions
		_draw_enemy_ship(enemy, i)
		_draw_shield_impacts(i, enemy_size)
		_draw_hull_impacts(i)
		draw_set_transform(size / 2.0 - ship_position * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
		if selected_enemy == i:
			var marker_radius := float(enemy.radius) + 16.0
			draw_arc(enemy.position, marker_radius, 0, TAU, 48, Color(1.0, 0.32, 0.24, 0.9), 2.0, true)
			var bar_position: Vector2 = enemy.position + Vector2(-35, -marker_radius - 26.0)
			if enemy.max_shield > 0.0:
				draw_rect(Rect2(bar_position, Vector2(70, 5)), Color(0.03, 0.07, 0.12, 0.9))
				draw_rect(Rect2(bar_position, Vector2(70.0 * enemy.shield / enemy.max_shield, 5)), Color("58b6ff"))
			bar_position.y += 9.0
			draw_rect(Rect2(bar_position, Vector2(70, 5)), Color(0.12, 0.03, 0.03, 0.9))
			draw_rect(Rect2(bar_position, Vector2(70.0 * enemy.health / enemy.max_health, 5)), Color("f27065"))
	for piece in debris:
		if not visible_world.has_point(piece.position):
			continue
		draw_set_transform(size / 2.0 - ship_position * camera_zoom + piece.position * camera_zoom, piece.rotation, Vector2.ONE * camera_zoom)
		var alpha: float = minf(1.0, piece.life / 1.5)
		MODULES.draw_part(self, piece.part, Vector2.ZERO, ENEMY_PART_SCALE, alpha)
		draw_set_transform(size / 2.0 - ship_position * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
	_draw_ship()
	draw_set_transform(size / 2.0 - ship_position * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
	for shot in projectiles:
		if not visible_world.has_point(shot.position):
			continue
		var direction: Vector2 = shot.velocity.normalized()
		if shot.get("kind", "") == "rocket":
			draw_line(shot.position - direction * 20.0, shot.position - direction * 8.0, Color("ff934f"), 4.0, true)
			draw_line(shot.position - direction * 9.0, shot.position + direction * 5.0, Color("d9dce0"), 6.0, true)
		elif shot.get("kind", "") == "bullet":
			draw_line(shot.position - direction * 12.0, shot.position, Color("ffd078"), 2.5, true)
		else:
			var color := Color("8af4ff") if shot.friendly else Color("ff7562")
			draw_line(shot.position - direction * 16.0, shot.position, color, 4.0, true)
			draw_circle(shot.position, 3.0, Color.WHITE)
	_draw_mining_beams()
	# Draw collectibles above the hull so their final movement is visible.
	draw_set_transform(size / 2.0 - ship_position * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
	# Three rotating elliptical electron paths give each collectible an atom silhouette.
	for drop in tritium_drops:
		if not visible_world.has_point(drop.position):
			continue
		var center: Vector2 = drop.position
		var phase: float = elapsed * 2.4 + drop.phase
		draw_circle(center, 24.0, Color(0.58, 0.21, 0.95, 0.10))
		draw_circle(center, 7.0, Color(0.70, 0.36, 1.0, 0.32))
		draw_circle(center, 3.5, Color("ead4ff"))
		for orbit in range(3):
			var angle := phase * 0.35 + float(orbit) * PI / 3.0
			var points := PackedVector2Array()
			for step in range(33):
				var t := TAU * float(step) / 32.0
				points.append(center + Vector2(cos(t) * 19.0, sin(t) * 7.5).rotated(angle))
			draw_polyline(points, Color(0.76, 0.45, 1.0, 0.8), 1.7, true)
			var electron_angle := phase + float(orbit) * TAU / 3.0
			var electron := center + Vector2(cos(electron_angle) * 19.0, sin(electron_angle) * 7.5).rotated(angle)
			draw_circle(electron, 2.6, Color("f3dfff"))
	for effect in tritium_pickup_effects:
		if not visible_world.has_point(effect.position):
			continue
		var progress: float = 1.0 - effect.life / 0.65
		var alpha: float = 1.0 - progress
		var center: Vector2 = effect.position
		draw_arc(center, 7.0 + progress * 25.0, 0.0, TAU, 32, Color(0.82, 0.55, 1.0, alpha), 2.0, true)
		for i in range(6):
			var direction := Vector2.from_angle(TAU * float(i) / 6.0 + 0.3)
			var particle_position := center + direction * (8.0 + progress * 28.0)
			draw_circle(particle_position, 2.5 * alpha, Color(0.94, 0.8, 1.0, alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_hud(size)
	_draw_aim_indicators(size)

func _draw_aim_indicators(size: Vector2) -> void:
	if is_instance_valid(settings_layer) or is_instance_valid(builder_layer) or get_viewport().gui_get_hovered_control() != null:
		return
	var pointer := get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(pointer):
		return
	var aim_position := _screen_to_world(pointer)
	var kinds := ["laser", "miner", "machine_gun", "missile"]
	var colors := [Color("8af4ff"), Color("91dce8"), Color("ffd078"), Color("ffc095")]
	var color: Color = colors[selected_weapon - 1]
	for part in custom_parts:
		if part.get("turret", "") != kinds[selected_weapon - 1]:
			continue
		var origin := _turret_world_position(part)
		var direction := Vector2.from_angle(_turret_angle(part))
		var distance := origin.distance_to(aim_position)
		var start := size / 2.0 + (origin + direction * 20.0 - ship_position) * camera_zoom
		var tip := size / 2.0 + (origin + direction * distance - ship_position) * camera_zoom
		var line_color := color
		line_color.a = 0.28
		draw_line(start, tip, line_color, 1.0, true)
		draw_arc(tip, 5.0, 0.0, TAU, 20, color, 1.5, true)

func _draw_mining_beams() -> void:
	if not mining or selected_asteroid < 0 or selected_asteroid >= asteroids.size():
		return
	var selected: Dictionary = asteroids[selected_asteroid]
	for part in custom_parts:
		if part.get("turret", "") != "miner" or not _turret_is_aimed(part, selected.position):
			continue
		var origin := _turret_world_position(part)
		var beam_start := origin + Vector2.from_angle(_turret_angle(part)) * MODULES.MINING_TURRET_MUZZLE_OFFSET
		var beam_direction: Vector2 = (selected.position - beam_start).normalized()
		var beam_end: Vector2 = selected.position - beam_direction * selected.radius * 0.75
		draw_line(beam_start, beam_end, Color(0.2, 0.8, 1.0, 0.25), 11.0, true)
		draw_line(beam_start, beam_end, Color(0.65, 0.96, 1.0, 0.95), 3.0, true)
		draw_circle(beam_end, 5.0 + sin(elapsed * 18.0) * 2.0, Color(0.8, 0.98, 1.0, 0.85))

func _turret_world_position(part: Dictionary) -> Vector2:
	_ensure_ship_cache()
	return ship_position + (Vector2(part.x, part.y) * MODULES.CELL - cached_ship_bounds.get_center()).rotated(heading + PI / 2.0)

func _draw_engine_exhaust(ship_transform: Transform2D) -> void:
	var boost_remaining := boost_time / boost_duration if boost_time > 0.0 and boost_duration > 0.0 else 0.0
	var flame := maxf(thrust, 0.85 * minf(boost_remaining * 5.0, 1.0))
	if flame <= 0.01 and not boost_charging:
		return
	var frame := floori(elapsed * PULSE_DRIVE_FPS) % PULSE_DRIVE_FRAME_COUNT
	@warning_ignore("integer_division")
	var frame_cell := Vector2(frame % PULSE_DRIVE_COLUMNS, frame / PULSE_DRIVE_COLUMNS)
	var source := Rect2(frame_cell * PULSE_DRIVE_FRAME_SIZE, PULSE_DRIVE_FRAME_SIZE)
	var length := flame * (1.0 + boost_remaining * lerpf(0.55, 1.55, boost_power))
	var width := lerpf(0.65, 1.0, flame) * (1.0 + boost_remaining * 0.15)
	var tint := Color(1.0, 1.0, 1.0, minf(flame * 2.0, 1.0))
	for engine in cached_engines:
		var nozzle: Transform2D = engine.nozzle
		draw_set_transform_matrix(ship_transform * nozzle)
		if boost_charging:
			draw_circle(Vector2.ZERO, 5.0 + boost_charge * 12.0, Color(0.35, 0.55, 1.0, 0.2 + 0.35 * boost_charge))
		if flame > 0.01:
			var scale := Vector2(width, length) * float(engine.size)
			var destination := Rect2(-PULSE_DRIVE_NOZZLE * scale, PULSE_DRIVE_FRAME_SIZE * scale)
			draw_texture_rect_region(PULSE_DRIVE_TEXTURE, destination, source, tint)

func _draw_enemy_ship(enemy: Dictionary, index: int) -> void:
	var turret_angle := angle_difference(enemy.heading, enemy.aim_angle)
	for module in enemy.exterior:
		if module.part.type != "engine":
			continue
		var offset: Vector2 = module.offset
		var nozzle := offset + Vector2.DOWN * MODULES.CELL * ENEMY_PART_SCALE * MODULES.ENGINE_NOZZLE_OFFSET
		var flame_length := 16.0 + 3.0 * sin(elapsed * 23.0 + offset.x)
		draw_colored_polygon(PackedVector2Array([nozzle + Vector2(-5, 0), nozzle + Vector2(0, flame_length), nozzle + Vector2(5, 0)]), Color(1.0, 0.32, 0.13, 0.8))
	for module in enemy.exterior:
		MODULES.draw_part(self, module.part, module.offset, ENEMY_PART_SCALE, 1.0, Color.WHITE, turret_angle)
		_draw_part_shield_glow(module.part, module.offset, enemy.dimensions, ENEMY_PART_SCALE, index, turret_angle)

func _draw_custom_ship() -> void:
	var center := cached_ship_bounds.get_center()
	for part in custom_parts:
		if MODULES.is_interior(part):
			continue
		var position := Vector2(part.x, part.y) * MODULES.CELL - center
		var turret_angle := _turret_angle(part) - heading if part.get("turret", "") in MODULES.TURRETS else 0.0
		MODULES.draw_part(self, part, position, 1.0, 1.0, Color.WHITE, turret_angle)
		_draw_part_shield_glow(part, position, cached_ship_bounds.size, 1.0, -1, turret_angle)

func _draw_part_shield_glow(part: Dictionary, position: Vector2, dimensions: Vector2, part_scale: float, enemy_index: int, turret_angle: float) -> void:
	if graphics_quality == 0:
		return
	for impact in shield_impacts:
		if impact.enemy != enemy_index:
			continue
		var radii := dimensions * 0.5 + Vector2.ONE * SHIELD_MARGIN
		var direction := Vector2.from_angle(impact.angle)
		var angle := atan2(direction.y / radii.y, direction.x / radii.x)
		var point := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var progress: float = 1.0 - impact.life / SHIELD_IMPACT_DURATION
		var strength := maxf(0.0, 1.0 - position.distance_to(point) / 100.0) * (1.0 - progress) * 0.8
		if strength > 0.01:
			MODULES.draw_part(self, part, position, part_scale, strength, Color(0.32, 0.75, 1.0), turret_angle)

func _draw_ship() -> void:
	_ensure_ship_cache()
	var ship_transform := Transform2D(heading + PI / 2.0, Vector2.ONE * camera_zoom, 0.0, get_viewport_rect().size / 2.0)
	_draw_engine_exhaust(ship_transform)
	draw_set_transform_matrix(ship_transform)
	_draw_custom_ship()
	_draw_shield_impacts(-1, cached_ship_bounds.size)
	_draw_hull_impacts(-1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hud(size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(30, 17), "FPS  %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9f0fb"))
	var wave_status := "NEXT WAVE IN %d" % int(ceil(enemy_wave_timer)) if enemy_wave_timer >= 0.0 else "%d ENEMIES REMAINING" % enemies.filter(func(enemy: Dictionary) -> bool: return enemy.alive).size()
	draw_rect(Rect2(Vector2(size.x / 2.0 - 120.0, 24.0), Vector2(240.0, 54.0)), Color(0.025, 0.06, 0.1, 0.88))
	draw_string(font, Vector2(size.x / 2.0 - 110.0, 47.0), "WAVE %d" % wave_number, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 16, Color("e4f5ff"))
	draw_string(font, Vector2(size.x / 2.0 - 110.0, 67.0), wave_status, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 11, Color("91aebe"))
	var map_rect := Rect2(Vector2(30, 30), Vector2(240, 168))
	draw_rect(map_rect.grow(8), Color(0.025, 0.06, 0.1, 0.88))
	draw_rect(map_rect, Color(0.05, 0.11, 0.16, 0.95))
	for i in range(1, 4):
		var x := map_rect.position.x + map_rect.size.x * i / 4.0
		var y := map_rect.position.y + map_rect.size.y * i / 4.0
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.3, 0.55, 0.65, 0.2))
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.3, 0.55, 0.65, 0.2))
	draw_rect(map_rect, Color(0.35, 0.65, 0.75, 0.6), false, 1.0)
	for asteroid in asteroids:
		if asteroid.iron > 0:
			draw_circle(map_rect.position + asteroid.position / WORLD_SIZE * map_rect.size, 1.5, Color("b7896b"))
	for i in range(enemies.size()):
		if enemies[i].alive:
			var enemy_on_map: Vector2 = map_rect.position + enemies[i].position / WORLD_SIZE * map_rect.size
			draw_circle(enemy_on_map, 3.5 if i == selected_enemy else 2.5, Color("ff7668") if i == selected_enemy else Color("e2524c"))
	var player_on_map := map_rect.position + ship_position / WORLD_SIZE * map_rect.size
	var forward := Vector2.from_angle(heading)
	var side := forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([player_on_map + forward * 7.0, player_on_map - forward * 5.0 + side * 4.0, player_on_map - forward * 5.0 - side * 4.0]), Color("e0f9ff"))
	draw_string(font, Vector2(30, size.y - 35), "WASD   FLY    ·    1 LASER  2 MINE  3 GUN  4 ROCKET    ·    MOUSE AIM + LEFT CLICK FIRE    ·    SPACE BOOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("91aebe"))
	var charge_position := Vector2(30, size.y - 205)
	draw_string(font, charge_position + Vector2(0, -6), "BOOST  ·  HOLD SPACE, RELEASE TO LAUNCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6bce8"))
	draw_rect(Rect2(charge_position, Vector2(250, 7)), Color("192638"))
	draw_rect(Rect2(charge_position, Vector2(250.0 * boost_charge, 7)), Color("91a5ff"))
	var bar_left := Vector2(30, size.y - 136)
	draw_rect(Rect2(bar_left + Vector2(-10, -24), Vector2(290, 82)), Color(0.025, 0.06, 0.1, 0.88))
	draw_string(font, bar_left + Vector2(0, -5), "SHIELD", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8bcfff"))
	draw_rect(Rect2(bar_left, Vector2(250, 12)), Color("122b40"))
	draw_rect(Rect2(bar_left, Vector2(250.0 * player_shield / maxf(_player_max_shield(), 1.0), 12)), Color("4caeff"))
	draw_string(font, bar_left + Vector2(0, 31), "HULL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dce9e8"))
	draw_rect(Rect2(bar_left + Vector2(0, 36), Vector2(250, 12)), Color("302025"))
	draw_rect(Rect2(bar_left + Vector2(0, 36), Vector2(250.0 * player_hull / maxf(_player_max_hull(), 1.0), 12)), Color("d76d69"))
	draw_string(font, bar_left + Vector2(253, 11), "%d" % int(ceil(player_shield)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a9dcff"))
	draw_string(font, bar_left + Vector2(253, 47), "%d" % int(ceil(player_hull)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f0c6c1"))
	var weapon_names := ["LASER", "MINING LASER", "MACHINE GUN", "ROCKET"]
	draw_string(font, Vector2(size.x - 235, 170), "WEAPON %d: %s" % [selected_weapon, weapon_names[selected_weapon - 1]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd078"))
	_draw_resources(size, font)
	var speed_text := "%03d" % int(velocity.length())
	draw_string(font, Vector2(size.x - 115, 102), speed_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("d9e9f3"))
	draw_string(font, Vector2(size.x - 115, 120), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("7192a7"))

func _draw_resources(size: Vector2, font: Font) -> void:
	var origin := Vector2(size.x - 300, size.y - 150)
	var panel := Rect2(origin, Vector2(270, 112))
	draw_rect(panel, Color(0.025, 0.06, 0.1, 0.92))
	draw_rect(panel, Color(0.23, 0.39, 0.48, 0.65), false, 1.0)
	draw_string(font, origin + Vector2(18, 22), "CARGO  %d / %d" % [iron + tritium, int(_custom_stats().cargo)], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("88a7b9"))
	draw_line(origin + Vector2(18, 32), origin + Vector2(252, 32), Color(0.4, 0.6, 0.7, 0.18), 1.0)
	var iron_icon := origin + Vector2(25, 54)
	draw_colored_polygon(PackedVector2Array([iron_icon + Vector2(0, -7), iron_icon + Vector2(7, 0), iron_icon + Vector2(0, 7), iron_icon + Vector2(-7, 0)]), Color("d39b73"))
	draw_string(font, origin + Vector2(42, 59), "IRON", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c4d5dd"))
	draw_string(font, origin + Vector2(154, 59), "%d" % iron, HORIZONTAL_ALIGNMENT_RIGHT, 96, 17, Color("f1d3b8"))
	var tritium_icon := origin + Vector2(25, 87)
	draw_arc(tritium_icon, 7.0, 0.0, TAU, 24, Color("c994ff"), 1.5, true)
	draw_circle(tritium_icon, 2.5, Color("e7cdff"))
	draw_string(font, origin + Vector2(42, 92), "TRITIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c4d5dd"))
	draw_string(font, origin + Vector2(154, 92), "%d" % tritium, HORIZONTAL_ALIGNMENT_RIGHT, 96, 17, Color("dfb8ff"))

extends Node2D

class ShipVisual extends Node2D:
	var exhaust: Node2D
	var details: Node2D
	var effects: Node2D
	var has_shield_glow := false
	var engine_lights: Array[PointLight2D] = []

class ExhaustParticle:
	var origin: Vector2
	var velocity: Vector2
	var streak: Vector2
	var born: float
	var lifetime: float
	var radius: float
	var opacity: float

# Movement values are deliberately collected here for quick feel adjustments.
@export_group("Flight feel")
@export var top_speed := 390.0
@export var acceleration := 380.0
@export var drag := 0.32
@export var turn_speed := MODULES.BASE_TURN_SPEED

const SOLAR_SYSTEM := preload("res://scripts/solar_system.gd")
const WORLD_SIZE := SOLAR_SYSTEM.WORLD_SIZE
const MODULES := preload("res://scripts/ship_modules.gd")
const HANGAR := preload("res://scripts/hangar.gd")
const SHIP_LIBRARY := preload("res://scripts/ship_design_library.gd")
const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")
const ROCKET_ENGINE_AUDIO := preload("res://scripts/rocket_engine_audio.gd")
const SHIP_SUNLIGHT := preload("res://scripts/ship_sunlight.gdshader")
const SHIP_RELIEF := preload("res://scripts/ship_relief.gd")
const FLEET_COLLISION_LAYER := 1
const FLEET_COLLISION_MARGIN := 0.5
const SHIELD_MARGIN := 26.0
const SHIELD_IMPACT_DURATION := 0.36
const ASTEROID_IMPACT_INDEX := -2
const TARGET_RANGE := 1800.0
const ENEMY_DETECTION_RANGE := 1800.0
const ENEMY_SPEED := 270.0
const ENEMY_ACCELERATION := 390.0
const ENEMY_PART_SCALE := 0.75
const ENEMY_MIN_COMBAT_RANGE := 320.0
const ENEMY_PREFERRED_RANGE := 460.0
const ENEMY_FIRE_RANGE := 650.0
const NEUTRAL_SHIP_COLOR := Color("9bbfd0")
const HOSTILE_SHIP_COLOR := Color("ff7668")
const BOOST_CHARGE_SECONDS := 2.5
const BOOST_TRAVEL_SPEED := 6141.25
const BOOST_TRAVEL_ACCELERATION := 6200.0
const HYPERJUMP_COLOR := Color("9ee9ff")
const HYPERJUMP_TRAVEL_SPEED := 25500.0
const HYPERJUMP_TRAVEL_ACCELERATION := 23500.0
const EXHAUST_PARTICLE_MIN_ZOOM := 0.12
const EXHAUST_PARTICLE_LIMIT := 1600
const ENGINE_TRAIL_LIFETIME := 2.8
const BOOST_TRAIL_LIFETIME := 6.0
const ENGINE_TRAIL_INTERVAL := 0.05
const ENGINE_IGNITION_RATE := 9.0
const ENGINE_FADE_RATE := 5.0
const RADIAL_MENU_RADIUS := 72.0
const EXHAUST_SPARK_HOT := Color("fff2c4")
const EXHAUST_SPARK_COOL := Color("fa602f")
const EXHAUST_PLUME_HOT := Color("ff873d")
const EXHAUST_PLUME_COOL := Color("b14431")
const RTS_CAMERA_SPEED := 700.0
const CAMERA_ZOOM_STEP := 1.28
const MAP_LABEL_ZOOM := 0.004
const STAR_PARALLAX_FULL_ZOOM := 0.12
const RTS_DOCKING_DISTANCE := 24.0
const RTS_APPROACH_RATE := 0.9
const TRAVEL_APPROACH_RATE := 1.6
const THROTTLE_RAMP := 2.2
const MACHINE_GUN_FLASH_DURATION := 0.06
const CRUISER_LASER_COLOR := Color("65ffc2")
const CRUISER_LASER_SPEED := 1700.0
const CRUISER_LASER_DAMAGE := 4.0
const CRUISER_TURRET_TURN_SPEED := 3.2
const CRUISER_BARREL_RECOIL_DURATION := 0.09
const CRUISER_BARREL_RECOIL_DISTANCE := 7.2
const RAILGUN_SPEED := 3400.0
const RAILGUN_COOLDOWN := 1.45
const ROCKET_COOLDOWN := 1.2
const ROCKET_EJECTION_SPEED := 220.0
const ROCKET_IGNITION_DELAY := 0.14
const ROCKET_ACCELERATION := 1800.0
const ROCKET_TOP_SPEED := 1350.0
const ENEMY_ROCKET_SPEED_FACTOR := 0.78
const ROCKET_TAIL_OFFSET := 9.0
const ROCKET_SMOKE_SPACING := 14.0
const ROCKET_SMOKE_LIFETIME := 0.44
const ROCKET_RECOIL_DURATION := 0.24
const ROCKET_FLASH_DURATION := 0.16
const ROCKET_BLAST_DURATION := 0.27
const WEAPON_SLOTS := [
	{"name": "LASER", "turrets": ["laser"], "color": Color("8af4ff")},
	{"name": "MINING LASER", "turrets": ["miner"], "color": Color("91dce8")},
	{"name": "MACHINE GUN", "turrets": ["machine_gun", "retro_machine_gun", "long_machine_gun", MODULES.CRUISER_MACHINE_LASER], "color": Color("ffd078")},
	{"name": "ROCKET", "turrets": ["missile"], "color": Color("ffc095")},
	{"name": "RAILGUN", "turrets": ["railgun"], "color": Color("d3bcff")},
]
var fleet: Array[Dictionary] = []
var active_fleet_index := 0
var fleet_visuals: Node2D
var fleet_dialog: AcceptDialog
var fleet_list: ItemList
var fleet_designs: OptionButton
var fleet_status: Label
var fleet_context_menu: PopupMenu
var fleet_context_index := -1
var fleet_click_index := -1
var fleet_click_start := Vector2.ZERO
var fleet_design_entries: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var rocket_smoke: Array[Dictionary] = []
var rocket_blasts: Array[Dictionary] = []
var selected_enemy := -1
var selected_weapon := 1
var firing := false
var laser_active := false
var machine_gun_active := false
var machine_gun_cooldown := 0.0
var player_machine_gun_shots: Dictionary = {}
var player_rocket_launches: Dictionary = {}
var rocket_cooldown := 0.0
var railgun_cooldown := 0.0
var turret_angles: Dictionary = {}
const TURRET_AIM_TOLERANCE := 0.08
var auto_approach := false
var control_mode := 0
var rts_selected := false
var rts_dragging := false
var rts_drag_start := Vector2.ZERO
var rts_drag_end := Vector2.ZERO
var rts_move_active := false
var rts_destination := Vector2.ZERO
var rts_attack_active := false
var sustained_boost_enabled := false
var sustained_boost_direction := Vector2.ZERO
var boost_destination_active := false
var boost_destination := Vector2.ZERO
var boost_decelerating := false
var boost_button: Button
var hyperjump_context_button: Button
var hyperjump_context_destination := -1
var hyperjump_arrival_until := 0.0
var hyperjump_time := -1.0
var hyperjump_destination := -1
var hyperjump_arrival := Vector2.ZERO
var radial_menu_open := false
var radial_menu_position := Vector2.ZERO
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
var hangar_layer: CanvasLayer = null
var world_background: Node2D
var solar_system: SOLAR_SYSTEM
var asteroid_visuals: Node2D
var asteroid_effects: Node2D
var enemy_visuals: Node2D
var debris_visual: Node2D
var exhaust_particles_visual: Node2D
var exhaust_particles: Array[ExhaustParticle] = []
var exhaust_rng := RandomNumberGenerator.new()
var player_visual: ShipVisual
var player_fleet_body: CharacterBody2D
var custom_parts: Array = MODULES.default_design()
var ship_cache_ready := false
var cached_ship_stats: Dictionary = {}
var cached_ship_bounds := Rect2()
var cached_turret_mounts: Array[Dictionary] = []
var cached_engines: Array[Dictionary] = []
var cached_hull_shapes: Array[PackedVector2Array] = []
var cached_armour_borders: Dictionary = {}
var has_flight_controls := false

var ship_position := Vector2.ZERO
var ship_motion_remainder := Vector2.ZERO
var velocity := Vector2.ZERO
var heading := -PI / 2.0
var angular_velocity := 0.0
var thrust := 0.0
var engine_throttle_target := 0.0
var engine_boost_target := 0.0
var engine_flame := 0.0
var engine_overdrive := 0.0
var boost_charging := false
var boost_charge := 0.0
var boost_time := 0.0
var boost_duration := 0.0
var boost_power := 0.0
var stars: Array[Dictionary] = []
var starfield_camera_center := Vector2.ZERO
var starfield_offset := Vector2.ZERO
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var asteroids: Array[Dictionary] = []
var selected_asteroid := -1
var mining_asteroid := -1
var mining := false
var iron := 0
var mining_progress := 0.0
var camera_zoom := 0.65
var camera_zoom_target := camera_zoom
var camera_zoom_focus := Vector2.ZERO
var camera_position := Vector2.ZERO
var camera_following := true
var camera_dragging := false
var graphics_quality := 2
var frame_cap := 0
var vsync_enabled := false
var graphics_settings_path := "user://graphics_settings.cfg"
var engine_light_texture: GradientTexture2D
var engine_audio := ROCKET_ENGINE_AUDIO.new()
@onready var heritage_gun_audio: AudioStreamPlayer = $HeritageGunAudio

func _ready() -> void:
	_load_graphics_settings()
	engine_audio.name = "RocketEngineAudio"
	add_child(engine_audio)
	player_fleet_body = CharacterBody2D.new()
	player_fleet_body.collision_layer = 0
	player_fleet_body.collision_mask = FLEET_COLLISION_LAYER
	add_child(player_fleet_body)
	_load_custom_ship()
	_create_flight_visuals()
	player_hull = _player_max_hull()
	player_shield = _player_max_shield()
	_create_top_controls()
	rng.randomize()
	ship_position = SOLAR_SYSTEM.starting_position()
	fleet.append({"name": "Ship 1", "parts": custom_parts.duplicate(true), "position": ship_position, "heading": heading, "hull": player_hull, "shield": player_shield, "shield_delay": player_shield_delay})
	starfield_camera_center = _camera_center()
	_spawn_enemy_wave()
	for star_index in range(190):
		stars.append({
			"position": Vector2(rng.randf(), rng.randf()),
			"depth": rng.randf_range(0.15, 1.0),
			"tint": Color("adcaff").lerp(Color("ffe2ba"), rng.randf()),
			"phase": rng.randf_range(0.0, TAU),
			"twinkle_speed": rng.randf_range(0.45, 1.4),
			"twinkle_strength": rng.randf_range(0.04, 0.16),
		})
	get_viewport().size_changed.connect(_queue_flight_redraw)
	_queue_flight_redraw()

func _create_flight_visuals() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.85))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	engine_light_texture = GradientTexture2D.new()
	engine_light_texture.gradient = gradient
	engine_light_texture.width = 128
	engine_light_texture.height = 128
	engine_light_texture.fill = GradientTexture2D.FILL_RADIAL
	engine_light_texture.fill_from = Vector2(0.5, 0.5)
	engine_light_texture.fill_to = Vector2(1.0, 0.5)
	# Keep the world and ship layers behind the game's foreground drawing.
	world_background = _add_draw_layer(self, _draw_background)
	world_background.show_behind_parent = true
	solar_system = SOLAR_SYSTEM.new()
	world_background.add_child(solar_system)
	asteroid_visuals = Node2D.new()
	world_background.add_child(asteroid_visuals)
	asteroid_effects = _add_draw_layer(asteroid_visuals, _draw_asteroid_effects)
	exhaust_particles_visual = _add_draw_layer(world_background, _draw_exhaust_particles)
	var exhaust_material := CanvasItemMaterial.new()
	exhaust_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	exhaust_particles_visual.material = exhaust_material
	fleet_visuals = Node2D.new()
	world_background.add_child(fleet_visuals)
	enemy_visuals = Node2D.new()
	world_background.add_child(enemy_visuals)
	debris_visual = _add_draw_layer(world_background, _draw_debris)
	player_visual = _add_ship_visual(world_background,
		_draw_engine_exhaust, _draw_custom_ship, _draw_player_details, _draw_player_effects)

func _add_draw_layer(parent: Node, draw_layer: Callable, layer: Node2D = Node2D.new()) -> Node2D:
	parent.add_child(layer)
	layer.draw.connect(func(): draw_layer.call(layer))
	return layer

func _add_sunlit_ship_layer(parent: Node, hull: Callable, visual: Node2D) -> void:
	_add_draw_layer(parent, hull, visual)
	var sunlight := ShaderMaterial.new()
	sunlight.shader = SHIP_SUNLIGHT
	visual.material = sunlight

func _add_ship_visual(parent: Node, exhaust: Callable, hull: Callable, details: Callable, effects: Callable) -> ShipVisual:
	var visual := ShipVisual.new()
	_add_sunlit_ship_layer(parent, hull, visual)
	visual.exhaust = _add_draw_layer(visual, exhaust)
	visual.exhaust.show_behind_parent = true
	visual.details = _add_draw_layer(visual, details)
	visual.details.use_parent_material = true
	visual.effects = _add_draw_layer(visual, effects)
	return visual

func _add_engine_light(visual: ShipVisual, nozzle: Transform2D) -> void:
	var light := PointLight2D.new()
	light.texture = engine_light_texture
	light.color = Color(1.0, 0.56, 0.24)
	light.texture_scale = 1.35
	light.position = nozzle * Vector2(0.0, 6.0)
	light.energy = 0.0
	visual.add_child(light)
	visual.engine_lights.append(light)

func _set_engine_lighting(visual: ShipVisual, strength: float) -> void:
	for index in range(visual.engine_lights.size()):
		var light := visual.engine_lights[index]
		light.visible = strength > 0.01
		light.energy = strength * (0.65 + 0.08 * sin(elapsed * 19.0 + float(index) * 2.3))

func _queue_flight_redraw() -> void:
	var viewport_size := get_viewport_rect().size
	var zoom := Vector2.ONE * camera_zoom
	var camera := _world_transform()
	var view := Rect2(-camera.origin / camera_zoom, viewport_size / camera_zoom)
	var visible_world := view.grow(220.0)
	solar_system.update_view(elapsed, camera, view)
	asteroid_visuals.transform = camera
	exhaust_particles_visual.transform = camera
	exhaust_particles_visual.queue_redraw()
	var detail_threshold := 90.0 if graphics_quality == 1 else 45.0
	for asteroid in asteroids:
		var rock: Node2D = asteroid.visual
		rock.visible = asteroid.iron > 0 and visible_world.has_point(asteroid.position)
		if rock.visible:
			var detailed: bool = graphics_quality > 0 and asteroid.radius * camera_zoom > detail_threshold
			if detailed != asteroid.detailed:
				asteroid.detailed = detailed
				rock.queue_redraw()
	var glowing_ships := {}
	if graphics_quality > 0:
		for impact in shield_impacts:
			glowing_ships[impact.enemy] = true
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var visual: ShipVisual = enemy_visuals.get_child(i)
		visual.visible = enemy.alive and visible_world.has_point(enemy.position)
		if visual.visible:
			var position_on_screen: Vector2 = camera * enemy.position
			var pose := Transform2D(enemy.heading + PI / 2.0, zoom, 0.0, position_on_screen)
			_redraw_ship_visual(visual, pose, enemy.position, glowing_ships.has(i))
			_set_engine_lighting(visual, _enemy_engine_power(enemy))
	for i in range(fleet.size()):
		var parked: Dictionary = fleet[i]
		var visual: Node2D = parked.get("visual")
		if is_instance_valid(visual):
			visual.visible = i != active_fleet_index and visible_world.grow(float(parked.get("radius", 0.0))).has_point(parked.position)
			if visual.visible:
				var pose := Transform2D(float(parked.heading) + PI / 2.0, zoom, 0.0, camera * parked.position)
				_update_sunlit_ship_pose(visual, pose, parked.position)
				if parked.has_beacon:
					visual.queue_redraw()
	_redraw_ship_visual(player_visual, Transform2D(heading + PI / 2.0, zoom, 0.0, camera * ship_position), ship_position, glowing_ships.has(-1))
	_set_engine_lighting(player_visual, engine_flame * (1.0 + 0.5 * engine_overdrive))
	var camera_center := _camera_center()
	var parallax := smoothstep(MAP_LABEL_ZOOM, STAR_PARALLAX_FULL_ZOOM, camera_zoom)
	starfield_offset += (camera_center - starfield_camera_center) * parallax * 0.001
	starfield_camera_center = camera_center
	world_background.queue_redraw()
	if not asteroids.is_empty():
		asteroid_effects.queue_redraw()
	debris_visual.queue_redraw()
	queue_redraw()

func _update_sunlit_ship_pose(visual: Node2D, pose: Transform2D, world_position: Vector2) -> void:
	visual.transform = pose
	var sunlight := visual.material as ShaderMaterial
	var sun_direction := solar_system.light_direction_at(world_position)
	sunlight.set_shader_parameter("sun_direction", sun_direction.rotated(-pose.get_rotation()))

func _redraw_ship_visual(visual: ShipVisual, pose: Transform2D, world_position: Vector2, has_shield_glow: bool) -> void:
	_update_sunlit_ship_pose(visual, pose, world_position)
	# Keep the hull commands until a glow changes their colors or is cleared.
	if has_shield_glow or visual.has_shield_glow:
		visual.queue_redraw()
	visual.has_shield_glow = has_shield_glow
	visual.exhaust.queue_redraw()
	visual.details.queue_redraw()
	visual.effects.queue_redraw()

func _world_transform() -> Transform2D:
	var screen_center := get_viewport_rect().size * 0.5
	return Transform2D(0.0, Vector2.ONE * camera_zoom, 0.0, screen_center - _camera_center() * camera_zoom)

func _camera_center() -> Vector2:
	return ship_position if camera_following else camera_position

func _fit_chart(size: Vector2, bounds: Rect2) -> float:
	return minf(size.x / bounds.size.x, size.y / bounds.size.y)

func _minimum_camera_zoom() -> float:
	return _fit_chart(get_viewport_rect().size, SOLAR_SYSTEM.WORLD_BOUNDS) * 0.9

func _set_camera_zoom(value: float) -> void:
	camera_zoom = value
	camera_zoom_target = value

func _pan_camera(offset: Vector2) -> void:
	camera_position = (_camera_center() + offset / camera_zoom).clamp(Vector2.ZERO, WORLD_SIZE)
	camera_following = false

func _process(delta: float) -> void:
	if camera_zoom == camera_zoom_target:
		return
	var previous_zoom := camera_zoom
	var zoom_blend := 1.0 - exp(-20.0 * delta)
	camera_zoom = previous_zoom * pow(camera_zoom_target / previous_zoom, zoom_blend)
	if absf(camera_zoom / camera_zoom_target - 1.0) < 0.001:
		camera_zoom = camera_zoom_target
	if not camera_following:
		var offset := camera_zoom_focus - get_viewport_rect().size * 0.5
		camera_position = (camera_position + offset * (1.0 / previous_zoom - 1.0 / camera_zoom)).clamp(Vector2.ZERO, WORLD_SIZE)
	_queue_flight_redraw()

func _visible_world(camera: Transform2D) -> Rect2:
	return Rect2(-camera.origin / camera_zoom, get_viewport_rect().size / camera_zoom).grow(220.0)

func _load_graphics_settings() -> void:
	var config := ConfigFile.new()
	if config.load(graphics_settings_path) == OK:
		graphics_quality = clampi(int(config.get_value("graphics", "quality", 2)), 0, 2)
		var saved_cap := int(config.get_value("graphics", "frame_cap", 0))
		frame_cap = saved_cap if saved_cap == 0 or (saved_cap >= 30 and saved_cap <= 240) else 0
		vsync_enabled = bool(config.get_value("graphics", "vsync", false))
		control_mode = clampi(int(config.get_value("controls", "mode", 0)), 0, 1)
		engine_audio.volume = clampf(float(config.get_value("audio", "engine_volume", 0.7)), 0.0, 1.0)
	_apply_graphics_settings()

func _apply_graphics_settings() -> void:
	Engine.max_fps = frame_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _save_graphics_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "frame_cap", frame_cap)
	config.set_value("graphics", "vsync", vsync_enabled)
	config.set_value("controls", "mode", control_mode)
	config.set_value("audio", "engine_volume", engine_audio.volume)
	if config.save(graphics_settings_path) != OK:
		push_warning("Settings could not be saved; they will apply for this session.")

func _create_top_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_add_top_button(layer, "Fleet", -650, -500, "Spawn ships and switch control.", _open_fleet)
	boost_button = _add_top_button(layer, "Boost", -488, -340, "Enable Boost, then click a destination. Toggle to exit.", _toggle_sustained_boost)
	boost_button.name = "Boost"
	hyperjump_context_button = Button.new()
	hyperjump_context_button.text = "Initiate Hyper Jump"
	hyperjump_context_button.visible = false
	hyperjump_context_button.focus_mode = Control.FOCUS_NONE
	hyperjump_context_button.custom_minimum_size = Vector2(190, 40)
	hyperjump_context_button.pressed.connect(_initiate_context_hyperjump)
	layer.add_child(hyperjump_context_button)
	_add_top_button(layer, "Hangar", -326, -182, "Choose, design, and launch ships.", _open_hangar)
	_add_top_button(layer, "Settings  ⚙", -168, -30, "", _open_settings)

func _add_top_button(layer: CanvasLayer, label: String, left: float, right: float, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = left
	button.offset_top = 22
	button.offset_right = right
	button.offset_bottom = 62
	button.pressed.connect(action)
	layer.add_child(button)
	return button

func _open_fleet() -> void:
	if is_instance_valid(hangar_layer) or is_instance_valid(settings_layer):
		return
	if not is_instance_valid(fleet_dialog):
		_create_fleet_dialog()
	_refresh_fleet_designs()
	_refresh_fleet_list()
	fleet_status.text = "Parked ships hold position and are inactive until selected. Fleet lasts for this session."
	fleet_dialog.popup_centered()

func _create_fleet_dialog() -> void:
	fleet_dialog = AcceptDialog.new()
	fleet_dialog.title = "Fleet"
	fleet_dialog.size = Vector2i(540, 440)
	fleet_dialog.get_ok_button().text = "Close"
	add_child(fleet_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	fleet_dialog.add_child(column)
	var title := Label.new()
	title.text = "Your ships"
	column.add_child(title)
	fleet_list = ItemList.new()
	fleet_list.custom_minimum_size = Vector2(480, 170)
	fleet_list.item_activated.connect(func(_index: int): _take_fleet_control())
	column.add_child(fleet_list)
	var control_button := Button.new()
	control_button.text = "Take control of selected ship"
	control_button.pressed.connect(_take_fleet_control)
	column.add_child(control_button)
	var label := Label.new()
	label.text = "Spawn a ship near the controlled ship"
	column.add_child(label)
	fleet_designs = OptionButton.new()
	column.add_child(fleet_designs)
	var spawn_button := Button.new()
	spawn_button.text = "Spawn selected design"
	spawn_button.pressed.connect(_spawn_fleet_ship)
	column.add_child(spawn_button)
	fleet_status = Label.new()
	fleet_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(fleet_status)

func _refresh_fleet_designs() -> void:
	fleet_designs.clear()
	fleet_design_entries.clear()
	fleet_design_entries.append({"name": "Current ship design", "parts": custom_parts.duplicate(true)})
	for name in MODULES.PRESET_NAMES:
		fleet_design_entries.append({"name": name, "parts": MODULES.preset_design(MODULES.PRESET_NAMES[name])})
	var library: Variant = SHIP_LIBRARY.read()
	if library is Dictionary:
		var names: Array = library.keys()
		names.sort()
		for ship_name in names:
			var parts := SHIP_LIBRARY.restore_design(library[ship_name])
			if not parts.is_empty() and MODULES.validate(parts) == "":
				fleet_design_entries.append({"name": str(ship_name), "parts": parts})
	for design in fleet_design_entries:
		fleet_designs.add_item(design.name)

func _refresh_fleet_list() -> void:
	fleet_list.clear()
	for i in range(fleet.size()):
		var ship: Dictionary = fleet[i]
		fleet_list.add_item("%s%s" % [ship.name, "  ·  controlled" if i == active_fleet_index else "  ·  parked"])
	fleet_list.select(active_fleet_index)

func _save_active_fleet_ship() -> void:
	var ship: Dictionary = fleet[active_fleet_index]
	ship.parts = custom_parts.duplicate(true)
	ship.position = ship_position
	ship.heading = heading
	ship.hull = player_hull
	ship.shield = player_shield
	ship.shield_delay = player_shield_delay

func _draw_parked_ship(canvas: CanvasItem, ship: Dictionary) -> void:
	var parts: Array = ship.parts
	var center: Vector2 = MODULES.bounds(parts).get_center()
	var borders: Dictionary = MODULES.armour_borders(parts)
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		if MODULES.is_exterior_structure(part):
			MODULES.draw_part(canvas, part, Vector2(part.x, part.y) * MODULES.CELL - center)
			if borders.has(index):
				MODULES.draw_armour_border(canvas, borders[index], -center)
	for index in borders:
		var part: Dictionary = parts[index]
		if MODULES.is_armour_overlay(part):
			MODULES.draw_part(canvas, part, Vector2(part.x, part.y) * MODULES.CELL - center)
			MODULES.draw_armour_border(canvas, borders[index], -center)
	for part in parts:
		var position := Vector2(part.x, part.y) * MODULES.CELL - center
		if MODULES.is_decoration(part):
			MODULES.draw_part(canvas, part, position)
		if part.type == "preset_light_gunship":
			MODULES.draw_light_gunship_beacon(canvas, part, position, MODULES.navigation_light_brightness(elapsed))
		if part.has("turret"):
			MODULES.draw_mounted_turret(canvas, part.turret, position, 1.0, 1.0, Color.WHITE, 0.0, 0.0)

func _park_fleet_ship(index: int) -> void:
	var ship: Dictionary = fleet[index]
	if is_instance_valid(ship.get("visual")):
		ship.visual.hide()
		ship.visual.queue_free()
	var visual := Node2D.new()
	var bounds := MODULES.bounds(ship.parts)
	_add_sunlit_ship_layer(fleet_visuals, _draw_parked_ship.bind(ship), visual)
	SHIP_RELIEF.bake(visual.material, ship.parts, bounds, 1.0)
	ship.visual = visual
	ship.radius = bounds.size.length() * 0.5
	ship.has_beacon = ship.parts.any(func(part: Dictionary) -> bool: return part.type == "preset_light_gunship")
	var body := StaticBody2D.new()
	body.collision_layer = FLEET_COLLISION_LAYER
	body.collision_mask = 0
	body.position = ship.position
	body.rotation = float(ship.heading) + PI / 2.0
	_add_fleet_collision_shapes(body, ship.parts, bounds)
	add_child(body)
	ship.collision_body = body
	visual.queue_redraw()

func _add_fleet_collision_shapes(body: PhysicsBody2D, parts: Array, bounds: Rect2) -> void:
	var center := bounds.get_center()
	for part in parts:
		if not MODULES.is_exterior_structure(part):
			continue
		var offset := Vector2(part.x, part.y) * MODULES.CELL - center
		var polygons: Array[PackedVector2Array] = []
		if MODULES.PRESET_TEXTURES.has(part.type):
			polygons = MODULES.preset_alpha_polygons(part, offset)
		else:
			polygons = MODULES.structural_polygons(part, offset)
		for polygon in polygons:
			if polygon.size() < 3:
				continue
			var collider := CollisionPolygon2D.new()
			collider.polygon = polygon
			body.add_child(collider)

func _spawn_fleet_ship() -> void:
	if hyperjump_time >= 0.0:
		fleet_status.text = "Wait until the hyperjump finishes before spawning a ship."
		return
	var selected := fleet_designs.selected
	if selected < 0 or selected >= fleet_design_entries.size():
		return
	var design: Dictionary = fleet_design_entries[selected]
	var parts: Array = design.parts.duplicate(true)
	var error: String = MODULES.validate(parts)
	if error != "":
		fleet_status.text = "This design cannot fly: " + error
		return
	_save_active_fleet_ship()
	var radius := MODULES.bounds(parts).size.length() * 0.5
	var distance := cached_ship_bounds.size.length() * 0.5 + radius + 100.0
	var position := ship_position
	var clear := false
	# Search outward in all directions, including near the edge of the world.
	for attempt in range((fleet.size() + 1) * 16):
		var ring := int(attempt / 16)
		var angle := heading + PI / 2.0 + TAU * float(attempt % 16) / 16.0
		position = ship_position + Vector2.RIGHT.rotated(angle) * (distance + float(ring) * (radius * 2.0 + 100.0))
		if position.x < 0.0 or position.y < 0.0 or position.x > WORLD_SIZE.x or position.y > WORLD_SIZE.y:
			continue
		clear = true
		for other in fleet:
			var other_radius := MODULES.bounds(other.parts).size.length() * 0.5
			if position.distance_to(other.position) < radius + other_radius + 50.0:
				clear = false
				break
		if clear:
			break
	if not clear:
		fleet_status.text = "No room to spawn here. Move away from the world edge and try again."
		return
	var stats: Dictionary = MODULES.stats(parts)
	var name := "%s · %d" % [design.name, fleet.size() + 1]
	fleet.append({"name": name, "parts": parts, "position": position, "heading": heading, "hull": float(stats.health), "shield": float(stats.shield), "shield_delay": 0.0})
	_park_fleet_ship(fleet.size() - 1)
	_refresh_fleet_list()
	fleet_list.select(fleet.size() - 1)
	fleet_status.text = "Spawned %s. Select it and take control to fly it." % name
	_queue_flight_redraw()

func _take_fleet_control() -> void:
	var selected := fleet_list.get_selected_items()
	if not selected.is_empty():
		_switch_fleet_control(selected[0])

func _switch_fleet_control(index: int) -> void:
	if index < 0 or index >= fleet.size() or index == active_fleet_index:
		return
	if hyperjump_time >= 0.0:
		if is_instance_valid(fleet_status):
			fleet_status.text = "Wait until the hyperjump finishes before switching ships."
		return
	_save_active_fleet_ship()
	_park_fleet_ship(active_fleet_index)
	if sustained_boost_enabled:
		_set_sustained_boost(false)
	active_fleet_index = index
	var ship: Dictionary = fleet[active_fleet_index]
	var parked_body: StaticBody2D = ship.collision_body
	remove_child(parked_body)
	parked_body.queue_free()
	ship.erase("collision_body")
	custom_parts = ship.parts.duplicate(true)
	ship_position = ship.position
	ship_motion_remainder = Vector2.ZERO
	heading = ship.heading
	player_hull = ship.hull
	player_shield = ship.shield
	player_shield_delay = ship.shield_delay
	ship_cache_ready = false
	velocity = Vector2.ZERO
	angular_velocity = 0.0
	thrust = 0.0
	_reset_player_exhaust()
	boost_time = 0.0
	boost_charging = false
	boost_decelerating = false
	rts_move_active = false
	rts_attack_active = false
	auto_approach = false
	firing = false
	laser_active = false
	machine_gun_active = false
	mining = false
	selected_enemy = -1
	selected_asteroid = -1
	mining_asteroid = -1
	for i in range(shield_impacts.size() - 1, -1, -1):
		if shield_impacts[i].enemy == -1:
			shield_impacts.remove_at(i)
	for i in range(hull_impacts.size() - 1, -1, -1):
		if hull_impacts[i].enemy == -1:
			hull_impacts.remove_at(i)
	turret_angles.clear()
	player_machine_gun_shots.clear()
	player_rocket_launches.clear()
	camera_following = true
	camera_position = ship_position
	starfield_camera_center = ship_position
	_ensure_ship_cache()
	if is_instance_valid(fleet_dialog):
		_refresh_fleet_designs()
		_refresh_fleet_list()
		fleet_status.text = "Controlling %s. Other ships hold position." % ship.name
	_queue_flight_redraw()

func _set_sustained_boost(enabled: bool, direction := Vector2.ZERO) -> void:
	_ensure_ship_cache()
	if enabled and (not has_flight_controls or float(_current_ship().speed) <= 0.0):
		return
	boost_decelerating = not enabled and sustained_boost_enabled
	sustained_boost_enabled = enabled
	sustained_boost_direction = direction
	boost_destination_active = false
	boost_charging = false
	boost_charge = 0.0
	boost_time = 0.0
	rts_dragging = false
	rts_move_active = false
	rts_attack_active = false
	firing = false
	if is_instance_valid(boost_button):
		boost_button.text = "Exit Boost" if enabled else "Boost"
	_queue_flight_redraw()

func _toggle_sustained_boost() -> void:
	_set_sustained_boost(not sustained_boost_enabled)

func _steer_sustained_boost(screen_position: Vector2) -> void:
	boost_destination = _screen_to_world(screen_position)
	boost_destination_active = true
	rts_destination = boost_destination
	rts_move_active = true
	sustained_boost_direction = (boost_destination - ship_position).normalized()
	_queue_flight_redraw()

func _boost_acceleration(boost_speed: float, boost_acceleration: float) -> float:
	var speed_fraction := clampf(velocity.length() / maxf(boost_speed, 0.01), 0.0, 1.0)
	return boost_acceleration * lerpf(0.12, 0.65, speed_fraction)

func _at_flight_destination(distance: float, radius: float, max_speed: float) -> bool:
	return distance < radius and velocity.length_squared() < max_speed * max_speed

func _update_boost_destination(boost_speed: float, boost_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	var to_destination := boost_destination - ship_position
	var distance := to_destination.length()
	if _at_flight_destination(distance, 4.0, 5.0):
		ship_position = boost_destination
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		_set_sustained_boost(false)
		boost_decelerating = false
		thrust = move_toward(thrust, 0.0, delta * 5.0)
		return
	sustained_boost_direction = to_destination.normalized()
	_steer_heading(to_destination if distance > RTS_DOCKING_DISTANCE else Vector2.ZERO, ship_turn_speed, delta)
	var alignment := smoothstep(0.1, 0.95, Vector2.from_angle(heading).dot(sustained_boost_direction))
	var arrival_speed := minf(distance * TRAVEL_APPROACH_RATE, sqrt(2.0 * boost_acceleration * distance) * 0.8)
	var speed := minf(boost_speed, arrival_speed)
	var desired_velocity := sustained_boost_direction * speed * lerpf(1.0, alignment, smoothstep(RTS_DOCKING_DISTANCE, 160.0, distance))
	engine_boost_target = _navigation_exhaust(sustained_boost_direction, desired_velocity.length(), alignment, delta)
	var movement_acceleration := _boost_acceleration(boost_speed, boost_acceleration) if desired_velocity.length() > velocity.length() else boost_acceleration
	velocity = velocity.move_toward(desired_velocity, movement_acceleration * delta)
	thrust = move_toward(thrust, alignment if speed > 5.0 else 0.0, delta * THROTTLE_RAMP)

func _can_hyperjump() -> bool:
	var ship := _current_ship()
	return has_flight_controls and float(ship.speed) > 0.0

func _close_hyperjump_chart() -> void:
	hyperjump_context_button.hide()
	hyperjump_context_destination = -1

func _hyperjump_pick_radius(system: Dictionary) -> float:
	return maxf(24.0, float(system.radius) * camera_zoom + 12.0)

func _system_at_screen(point: Vector2) -> int:
	if camera_zoom >= MAP_LABEL_ZOOM:
		return -1
	var camera := _world_transform()
	for index in SOLAR_SYSTEM.SYSTEMS.size():
		var system: Dictionary = SOLAR_SYSTEM.SYSTEMS[index]
		var center := camera * (system.center as Vector2)
		var radius := maxf(6.0, float(system.radius) * camera_zoom)
		var label_bounds := Rect2(center + Vector2(-90.0, radius + 5.0), Vector2(180.0, 36.0))
		if point.distance_to(center) <= _hyperjump_pick_radius(system) or label_bounds.has_point(point):
			return index
	return -1

func _show_hyperjump_context(destination: int, screen_position: Vector2) -> void:
	hyperjump_context_destination = destination
	var available := _can_hyperjump() and destination != solar_system.nearest_system(ship_position) and hyperjump_time < 0.0
	hyperjump_context_button.disabled = not available
	hyperjump_context_button.tooltip_text = "Travel to %s" % SOLAR_SYSTEM.SYSTEMS[destination].name if available else "Choose another system with a flight-capable ship."
	var button_size := Vector2(190, 40)
	hyperjump_context_button.position = screen_position.clamp(Vector2.ZERO, (get_viewport_rect().size - button_size).max(Vector2.ZERO))
	hyperjump_context_button.size = button_size
	hyperjump_context_button.show()

func _initiate_context_hyperjump() -> void:
	var destination := hyperjump_context_destination
	_close_hyperjump_chart()
	if destination >= 0:
		_execute_hyperjump(solar_system.nearest_system(ship_position), destination)

func _execute_hyperjump(source: int, destination: int) -> void:
	if source == destination or not _can_hyperjump() or hyperjump_time >= 0.0:
		return
	hyperjump_destination = destination
	hyperjump_arrival = SOLAR_SYSTEM.hyperjump_arrival(source, destination)
	_set_sustained_boost(false)
	boost_decelerating = false
	rts_move_active = false
	rts_attack_active = false
	firing = false
	hyperjump_arrival_until = 0.0
	hyperjump_time = 0.0
	boost_button.disabled = true
	_queue_flight_redraw()

func _update_hyperjump(jump_speed: float, jump_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	hyperjump_time += delta
	var to_destination := hyperjump_arrival - ship_position
	var distance := to_destination.length()
	if _at_flight_destination(distance, 4.0, 5.0):
		ship_position = hyperjump_arrival
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		hyperjump_time = -1.0
		boost_button.disabled = false
		hyperjump_arrival_until = elapsed + 3.0
		thrust = 0.0
		return
	_steer_heading(to_destination, ship_turn_speed, delta)
	var alignment := smoothstep(0.94, 0.995, Vector2.from_angle(heading).dot(to_destination.normalized()))
	var arrival_speed := minf(distance * TRAVEL_APPROACH_RATE, sqrt(2.0 * jump_acceleration * distance) * 0.8)
	var course := to_destination.normalized()
	var desired_velocity := course * minf(jump_speed, arrival_speed) * alignment
	engine_boost_target = _navigation_exhaust(course, desired_velocity.length(), alignment, delta)
	velocity = velocity.move_toward(desired_velocity, jump_acceleration * delta)
	thrust = move_toward(thrust, alignment if arrival_speed > 5.0 else 0.0, delta * 5.0)

func _open_settings() -> void:
	firing = false
	rts_dragging = false
	radial_menu_open = false
	camera_dragging = false
	if is_instance_valid(settings_layer):
		return
	_close_hyperjump_chart()
	boost_charging = false
	boost_charge = 0.0
	set_physics_process(false)
	engine_audio.silence()
	heritage_gun_audio.stop()
	set_process_unhandled_input(false)
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 20
	add_child(settings_layer)
	var menu: Control = SETTINGS_MENU.new()
	_set_camera_zoom(camera_zoom)
	menu.initial_zoom = camera_zoom
	menu.minimum_zoom = _minimum_camera_zoom()
	menu.initial_graphics_quality = graphics_quality
	menu.initial_frame_cap = frame_cap
	menu.initial_vsync = vsync_enabled
	menu.initial_control_mode = control_mode
	menu.initial_engine_volume = engine_audio.volume
	settings_layer.add_child(menu)
	menu.engine_volume_changed.connect(func(value: float):
		engine_audio.volume = value
		_save_graphics_settings()
	)
	menu.control_mode_changed.connect(func(value: int):
		if sustained_boost_enabled:
			_set_sustained_boost(false)
		control_mode = clampi(value, 0, 1)
		camera_following = true
		rts_selected = false
		rts_dragging = false
		rts_move_active = false
		rts_attack_active = false
		firing = false
		_save_graphics_settings()
		_queue_flight_redraw()
	)
	menu.graphics_quality_changed.connect(func(value: int):
		graphics_quality = clampi(value, 0, 2)
		_save_graphics_settings()
		_queue_flight_redraw()
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
	menu.hangar_requested.connect(_open_hangar)
	menu.zoom_changed.connect(func(value: float):
		_set_camera_zoom(value)
		_queue_flight_redraw()
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
			MODULES.add_legacy_command_deck(migrated)
			custom_parts = migrated
			ship_cache_ready = false

func _open_hangar() -> void:
	if is_instance_valid(hangar_layer):
		return
	if sustained_boost_enabled:
		_set_sustained_boost(false)
	_close_settings()
	_close_hyperjump_chart()
	firing = false
	rts_dragging = false
	radial_menu_open = false
	camera_dragging = false
	boost_charging = false
	boost_charge = 0.0
	engine_audio.silence()
	heritage_gun_audio.stop()
	set_physics_process(false)
	set_process_unhandled_input(false)
	hangar_layer = CanvasLayer.new()
	hangar_layer.layer = 20
	add_child(hangar_layer)
	var hangar := HANGAR.new()
	hangar.current_parts = custom_parts.duplicate(true)
	hangar.preview_draw = _draw_parked_ship
	hangar.closed.connect(_close_hangar)
	hangar.launch_requested.connect(_deploy_custom_ship)
	hangar_layer.add_child(hangar)

func _close_hangar() -> void:
	if not is_instance_valid(hangar_layer):
		return
	hangar_layer.queue_free()
	hangar_layer = null
	set_physics_process(true)
	set_process_unhandled_input(true)

func _deploy_custom_ship(parts: Array) -> void:
	if MODULES.validate(parts) != "":
		return
	custom_parts = parts.duplicate(true)
	ship_cache_ready = false
	turret_angles.clear()
	player_machine_gun_shots.clear()
	player_rocket_launches.clear()
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
	boost_decelerating = false
	angular_velocity = 0.0
	thrust = 0.0
	_reset_player_exhaust()
	boost_time = 0.0
	boost_charging = false
	rts_move_active = false
	rts_attack_active = false
	firing = false
	laser_active = false
	machine_gun_active = false
	hyperjump_time = -1.0
	hyperjump_arrival_until = 0.0
	boost_button.disabled = false
	_save_active_fleet_ship()
	_close_hangar()
	_queue_flight_redraw()

func _ensure_ship_cache() -> void:
	if ship_cache_ready:
		return
	cached_ship_stats = MODULES.stats(custom_parts)
	cached_ship_bounds = MODULES.bounds(custom_parts)
	has_flight_controls = MODULES.has_command_deck(custom_parts)
	cached_engines.clear()
	cached_turret_mounts.clear()
	for light in player_visual.engine_lights:
		light.queue_free()
	player_visual.engine_lights.clear()
	var center := cached_ship_bounds.get_center()
	SHIP_RELIEF.bake(player_visual.material, custom_parts, cached_ship_bounds, 1.0)
	player_visual.queue_redraw()
	for collider in player_fleet_body.get_children():
		player_fleet_body.remove_child(collider)
		collider.queue_free()
	_add_fleet_collision_shapes(player_fleet_body, custom_parts, cached_ship_bounds)
	cached_hull_shapes.clear()
	cached_armour_borders = MODULES.armour_borders(custom_parts)
	var uses_shaped_hull := custom_parts.any(func(part: Dictionary) -> bool:
		return MODULES.is_exterior_structure(part) and (part.type in ["wedge_half", "armor_wedge"] or MODULES.footprint(part).size != Vector2i.ONE)
	)
	for part in custom_parts:
		if part.has("turret"):
			cached_turret_mounts.append(part)
		if MODULES.PRESET_TEXTURES.has(part.type):
			# Match the sprite fitting used by draw_part, then place each outlet at
			# the centre of the engine bell in the original image coordinates.
			var source_size: Vector2 = MODULES.preset_texture(part).get_size()
			var sprite_rect := MODULES.preset_draw_rect(part, Vector2(part.x, part.y) * MODULES.CELL - center)
			var fit := sprite_rect.size.x / source_size.x
			var origin := sprite_rect.position
			var outlets: Array = []
			var source_flare_size := Vector2.ONE
			var individual_flare_sizes: Array[Vector2] = []
			match part.type:
				"pixel_custom":
					_add_pixel_engine_nozzles(MODULES.preset_texture(part).get_image(), origin, fit)
				"preset_frigate":
					outlets = [Vector2(220, 1120), Vector2(394, 1120)]
					source_flare_size = Vector2(5.5, 2.0)
				"preset_scout":
					outlets = [Vector2(77, 496), Vector2(190, 496)]
					source_flare_size = Vector2(2.2, 1.15)
				"preset_pixel_starter":
					outlets = [Vector2(6, 62), Vector2(25, 62)]
					source_flare_size = Vector2(0.40, 0.25)
				"preset_starter_2":
					outlets = [Vector2(15.5, 99), Vector2(34.5, 99)]
					source_flare_size = Vector2(0.60, 0.38)
				"preset_light_gunship":
					outlets = [Vector2(9.5, 109), Vector2(28.5, 109)]
					source_flare_size = Vector2(0.60, 0.38)
				"preset_light_destroyer", MODULES.LIGHT_CRUISER:
					# The outer bells end three pixels ahead of the inner pair.
					outlets = [Vector2(8.5, 165), Vector2(19.5, 168), Vector2(42.5, 168), Vector2(53.5, 165)]
					var outer_flare := Vector2(0.78, 0.42)
					var inner_flare := Vector2(0.96, 0.52)
					individual_flare_sizes = [outer_flare, inner_flare, inner_flare, outer_flare]
				MODULES.HD_LIGHT_CRUISER:
					outlets = [Vector2(53, 830), Vector2(109, 843), Vector2(221, 843), Vector2(277, 830)]
					var outer_flare := Vector2(4.0, 2.1)
					var inner_flare := Vector2(4.8, 2.6)
					individual_flare_sizes = [outer_flare, inner_flare, inner_flare, outer_flare]
				"preset_armoured_starter":
					outlets = [Vector2(169, 1464), Vector2(591, 1464)]
					source_flare_size = Vector2(9.5, 6.0)
			for i in range(outlets.size()):
				var size := source_flare_size if individual_flare_sizes.is_empty() else individual_flare_sizes[i]
				cached_engines.append({"nozzle": Transform2D(0.0, origin + outlets[i] * fit), "size": size * fit})
			if MODULES.CRUISER_TURRET_LAYOUTS.has(part.type):
				var mounts: Array = MODULES.CRUISER_TURRET_LAYOUTS[part.type].mounts
				for index in range(mounts.size()):
					cached_turret_mounts.append({
						"x": part.x, "y": part.y, "type": part.type, "turret": MODULES.CRUISER_MACHINE_LASER,
						"cruiser_index": index, "local_position": origin + mounts[index] * fit, "pixel_scale": fit,
					})
		if uses_shaped_hull and MODULES.is_exterior_structure(part):
			cached_hull_shapes.append_array(MODULES.material_polygons(part, Vector2(part.x, part.y) * MODULES.CELL - center))
		if MODULES.ENGINE_NOZZLE_OFFSETS.has(part.type):
			var angle := float(int(part.rotation)) * PI / 2.0
			var pos := Vector2(part.x, part.y) * MODULES.CELL - center
			if part.type in MODULES.MAIN_ENGINE_TYPES:
				for outlet in MODULES.engine_nozzles(part, pos):
					cached_engines.append({"nozzle": Transform2D(angle, outlet.position), "size": Vector2(outlet.width, 1.0)})
			else:
				pos += Vector2.DOWN.rotated(angle) * MODULES.CELL * MODULES.ENGINE_NOZZLE_OFFSETS[part.type]
				cached_engines.append({"nozzle": Transform2D(angle, pos), "size": Vector2.ONE * 0.65})
	for engine in cached_engines:
		_add_engine_light(player_visual, engine.nozzle)
	ship_cache_ready = true

func _add_pixel_engine_nozzles(image: Image, origin: Vector2, fit: float) -> void:
	# Custom artwork has no hardpoints. Use the widest solid runs along the stern.
	var hull := image.get_used_rect()
	if not hull.has_area():
		return
	var last_row := hull.end.y - 1
	var outlets: Array[Vector2i] = []
	var start := -1
	for x in range(hull.position.x, hull.end.x + 1):
		if x < hull.end.x and image.get_pixel(x, last_row).a > 0.0:
			if start < 0:
				start = x
		elif start >= 0:
			outlets.append(Vector2i(start, x - start))
			start = -1
	outlets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y > b.y if a.y != b.y else a.x < b.x)
	for i in range(mini(outlets.size(), 4)):
		var outlet := outlets[i]
		var center := Vector2(outlet.x + outlet.y * 0.5, hull.end.y)
		var width := clampf(outlet.y * 0.08, 0.28, 0.95)
		var length := clampf(outlet.y * 0.055, 0.22, 0.62)
		cached_engines.append({"nozzle": Transform2D(0.0, origin + center * fit), "size": Vector2(width, length) * fit})

func _custom_stats() -> Dictionary:
	_ensure_ship_cache()
	return cached_ship_stats

func _current_ship() -> Dictionary:
	var totals := _custom_stats()
	return {"speed": totals.speed, "acceleration": totals.acceleration, "turn": totals.maneuver}

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
	for visual in enemy_visuals.get_children():
		enemy_visuals.remove_child(visual)
		visual.queue_free()
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
		var engines: Array[Dictionary] = []
		for part in design:
			if not MODULES.is_exterior_structure(part):
				continue
			var offset := (Vector2(part.x, part.y) * MODULES.CELL - center) * ENEMY_PART_SCALE
			var module := {"part": part, "offset": offset}
			exterior.append(module)
			if part.has("turret"):
				turrets.append(module)
			if part.type in MODULES.MAIN_ENGINE_TYPES:
				var angle := float(int(part.rotation)) * PI / 2.0
				for outlet in MODULES.engine_nozzles(part, offset, ENEMY_PART_SCALE):
					engines.append({
						"nozzle": Transform2D(angle, outlet.position),
						"size": Vector2(outlet.width, 0.60),
						"phase": offset.x,
					})
		var max_health := clampf(float(stats.health) / 5.0, 80.0, 140.0) * health_multiplier
		var max_shield := float(stats.shield) * (70.0 / 60.0) * shield_multiplier
		var margin := maxf(35.0, radius)
		var position := Vector2.ZERO
		for attempt in range(80):
			position = ship_position + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(2600.0, 4000.0)
			if not Rect2(Vector2.ONE * margin, WORLD_SIZE - Vector2.ONE * margin * 2.0).has_point(position):
				continue
			var separated := true
			for existing in enemies:
				if position.distance_to(existing.position) < radius + float(existing.radius) + 40.0:
					separated = false
					break
			if separated:
				break
		position = position.clamp(Vector2.ONE * margin, WORLD_SIZE - Vector2.ONE * margin)
		var facing := rng.randf_range(0.0, TAU)
		var enemy := {
			"position": position, "heading": facing, "aim_angle": facing, "velocity": Vector2.ZERO,
			"angular_velocity": 0.0, "turn_speed": turn_speed * float(stats.maneuver),
			"hostile": false, "patrol_destination": ship_position, "patrol_origin": ship_position,
			"health": max_health, "max_health": max_health, "shield": max_shield, "max_shield": max_shield,
			"shield_delay": 0.0, "fire_cooldown": rng.randf_range(0.2, 1.0), "fire_interval": fire_interval,
			"speed": enemy_speed * clampf(float(stats.speed) / 0.85, 0.82, 1.18),
			"avoid_side": 1.0 if i % 2 == 0 else -1.0, "alive": true,
			"dimensions": dimensions, "radius": radius, "exterior": exterior, "turrets": turrets, "engines": engines, "next_turret": 0,
		}
		enemies.append(enemy)
		var visual := _add_ship_visual(enemy_visuals, _draw_enemy_exhaust.bind(enemy),
			_draw_enemy_hull.bind(enemy, i), _draw_enemy_turrets.bind(enemy, i), _draw_enemy_effects.bind(enemy, i))
		SHIP_RELIEF.bake(visual.material, design, bounds, ENEMY_PART_SCALE)
		for engine in engines:
			_add_engine_light(visual, engine.nozzle)
	enemy_wave_timer = -1.0

func _cycle_target() -> void:
	auto_approach = false
	var candidates: Array[Dictionary] = []
	for i in range(enemies.size()):
		if enemies[i].alive:
			var distance: float = ship_position.distance_to(enemies[i].position)
			if distance <= TARGET_RANGE:
				candidates.append({"type": "enemy", "index": i, "distance": distance})
	if control_mode != 1:
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

func _select_target_at(world_position: Vector2) -> void:
	selected_enemy = -1
	selected_asteroid = -1
	# Pick frontmost objects first and give small ships some click tolerance when zoomed out.
	var ship_padding := 6.0 / camera_zoom
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if not enemy.alive:
			continue
		var offset: Vector2 = world_position - enemy.position
		var local_point := offset.rotated(-float(enemy.heading) - PI / 2.0)
		var dimensions: Vector2 = enemy.dimensions
		if Rect2(-dimensions * 0.5, dimensions).grow(ship_padding).has_point(local_point):
			selected_enemy = i
			return
	for i in range(asteroids.size() - 1, -1, -1):
		var asteroid: Dictionary = asteroids[i]
		if asteroid.iron > 0 and Geometry2D.is_point_in_polygon(world_position - asteroid.position, asteroid.shape):
			selected_asteroid = i
			return

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

func _segment_polygon_hit(start: Vector2, end: Vector2, shape: PackedVector2Array) -> Variant:
	if Geometry2D.is_point_in_polygon(start, shape):
		return start
	var closest := INF
	var nearest: Variant = null
	for i in range(shape.size()):
		var contact: Variant = Geometry2D.segment_intersects_segment(start, end, shape[i], shape[(i + 1) % shape.size()])
		if contact != null and start.distance_squared_to(contact) < closest:
			closest = start.distance_squared_to(contact)
			nearest = contact
	return nearest

func _asteroid_shot_contact(start: Vector2, end: Vector2) -> Variant:
	var midpoint := (start + end) * 0.5
	var half_length := start.distance_to(end) * 0.5
	var closest := INF
	var nearest: Variant = null
	for asteroid in asteroids:
		if asteroid.iron <= 0:
			continue
		var center: Vector2 = asteroid.position
		var reach := half_length + float(asteroid.radius)
		if midpoint.distance_squared_to(center) > reach * reach:
			continue
		var local_start := start - center
		var contact: Variant = _segment_polygon_hit(local_start, end - center, asteroid.shape)
		if contact != null and local_start.distance_squared_to(contact) < closest:
			closest = local_start.distance_squared_to(contact)
			nearest = center + contact
	return nearest

func _player_shot_contact(start: Vector2, end: Vector2) -> Variant:
	var half_size := _ship_size() * 0.5
	if player_shield > 0.0:
		return _segment_ellipse_hit(start, end, ship_position, heading, half_size + Vector2.ONE * SHIELD_MARGIN)
	if cached_hull_shapes.is_empty():
		return _segment_ellipse_hit(start, end, ship_position, heading, half_size * 0.7)
	var rotation := heading + PI / 2.0
	var local_start := (start - ship_position).rotated(-rotation)
	var local_end := (end - ship_position).rotated(-rotation)
	var best_distance := INF
	var nearest := Vector2.ZERO
	for shape in cached_hull_shapes:
		var contact: Variant = _segment_polygon_hit(local_start, local_end, shape)
		if contact != null and local_start.distance_squared_to(contact) < best_distance:
			best_distance = local_start.distance_squared_to(contact)
			nearest = contact
	return nearest.rotated(rotation) + ship_position if best_distance < INF else null

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
	_add_surface_impact(enemy_index, local_point, local_point)

func _add_surface_impact(target_index: int, point: Vector2, direction: Vector2) -> void:
	var angle := direction.angle() if direction.length_squared() > 0.001 else -PI / 2.0
	hull_impacts.append({"enemy": target_index, "position": point, "life": 0.5, "rays": _make_spark_rays(angle)})

func _draw_hull_impacts(enemy_index: int, canvas: CanvasItem) -> void:
	for impact in hull_impacts:
		if impact.enemy != enemy_index:
			continue
		var progress: float = 1.0 - impact.life / 0.5
		var fade := 1.0 - smoothstep(0.0, 1.0, progress)
		var point: Vector2 = impact.position
		canvas.draw_circle(point, 7.0 + 5.0 * progress, Color(1.0, 0.30, 0.08, 0.30 * fade))
		canvas.draw_circle(point, 3.0 * fade, Color(1.0, 0.92, 0.62, fade))
		for ray_data in impact.rays:
			var ray := Vector2.from_angle(ray_data.angle)
			var distance: float = progress * ray_data.speed * 0.5
			var tip: float = distance + ray_data.length * fade
			canvas.draw_line(point + ray * distance, point + ray * tip, Color(1.0, 0.62, 0.23, fade), ray_data.width, true)

func _shield_hit(enemy_index: int, incoming_position: Vector2, center: Vector2, ship_heading: float) -> void:
	var local_direction := (incoming_position - center).rotated(-(ship_heading + PI / 2.0))
	if local_direction.length_squared() < 0.001:
		local_direction = Vector2.UP
	var angle := local_direction.angle()
	shield_impacts.append({"enemy": enemy_index, "angle": angle, "life": SHIELD_IMPACT_DURATION, "rays": _make_spark_rays(angle)})

func _draw_shield_impacts(enemy_index: int, dimensions: Vector2, canvas: CanvasItem) -> void:
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
			canvas.draw_polyline(points, Color(0.15, 0.55, 1.0, 0.18 * opacity), 7.0, true)
			canvas.draw_polyline(points, Color(0.52, 0.89, 1.0, 0.9 * opacity), 2.5 - float(ring) * 0.7, true)
		var spark_fade := 1.0 - smoothstep(0.0, 0.4, progress)
		var hit_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		for ray_data in impact.rays:
			var ray := Vector2.from_angle(ray_data.angle)
			var inner: float = 2.0 + progress * ray_data.speed * 0.65
			var tip: float = inner + ray_data.length * spark_fade
			canvas.draw_line(hit_point + ray * inner, hit_point + ray * tip, Color(0.78, 0.96, 1.0, spark_fade), ray_data.width, true)

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

func _update_neutral_ship(enemy: Dictionary, delta: float) -> void:
	var position: Vector2 = enemy.position
	var destination: Vector2 = enemy.patrol_destination
	if position.distance_squared_to(destination) < 180.0 * 180.0:
		const PATROL_MARGIN := 300.0
		destination = enemy.patrol_origin + Vector2.from_angle(rng.randf_range(0.0, TAU)) * rng.randf_range(650.0, 2900.0)
		var margin := Vector2.ONE * PATROL_MARGIN
		destination = destination.clamp(margin, WORLD_SIZE - margin)
		enemy.patrol_destination = destination
	var direction := _enemy_steering(enemy, destination - position)
	var current_velocity: Vector2 = enemy.velocity
	enemy.velocity = current_velocity.move_toward(direction * float(enemy.speed) * 0.45, ENEMY_ACCELERATION * delta)
	enemy.position += enemy.velocity * delta
	_steer_other_ship(enemy, direction, delta)
	enemy.aim_angle = enemy.heading

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

func _turret_key(part: Dictionary) -> Vector3i:
	return Vector3i(int(part.x), int(part.y), int(part.get("cruiser_index", -1)))

func _turret_angle(part: Dictionary) -> float:
	var rest_angle := heading + float(int(part.get("rotation", 0))) * PI / 2.0
	return float(turret_angles.get(_turret_key(part), rest_angle))

func _update_turrets(delta: float) -> void:
	_ensure_ship_cache()
	var target_position := _aim_world_position()
	var tracked_turrets: Array = WEAPON_SLOTS[selected_weapon - 1].turrets
	for part in cached_turret_mounts:
		var kind: String = part.turret
		var current := _turret_angle(part)
		var desired := heading + float(int(part.get("rotation", 0))) * PI / 2.0
		if kind in tracked_turrets:
			var direction := target_position - _turret_world_position(part)
			if direction.length_squared() > 0.001:
				desired = direction.angle()
		var speed: float = CRUISER_TURRET_TURN_SPEED if kind == MODULES.CRUISER_MACHINE_LASER else MODULES.TYPES[kind].turret_turn_speed
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

func _next_machine_gun_shot(previous: Dictionary) -> Dictionary:
	return {"barrel": 1 - int(previous.get("barrel", 1)), "fired_at": elapsed}

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
		"machine_gun", "retro_machine_gun", "long_machine_gun":
			var burst := _next_machine_gun_shot(mount.get("machine_gun_shot", {}))
			mount.machine_gun_shot = burst
			shot.position = origin + MODULES.machine_gun_muzzle_offset(burst.barrel, aim_angle + PI / 2.0, ENEMY_PART_SCALE, mount.part.turret == "long_machine_gun", mount.part.turret == "retro_machine_gun")
			shot.merge({"kind": "bullet", "damage": 5.0})
			shot.velocity = direction * 1050.0
			cadence = 0.55
		"missile":
			shot = _make_rocket(origin, aim_angle, enemy.velocity, false, 16.0, ENEMY_PART_SCALE)
			mount.rocket_launched_at = elapsed
			cadence = 1.7
	projectiles.append(shot)
	enemy.fire_cooldown = rng.randf_range(0.65, 1.05) * float(enemy.fire_interval) * cadence

func _update_combat(delta: float) -> void:
	invulnerability = maxf(0.0, invulnerability - delta)
	var recharge_time := maxf(0.0, delta - player_shield_delay)
	player_shield_delay = maxf(0.0, player_shield_delay - delta)
	if recharge_time > 0.0:
		var ship := _custom_stats()
		player_shield = minf(ship.shield, player_shield + ship.shield_recharge * recharge_time)
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
	railgun_cooldown = maxf(0.0, railgun_cooldown - delta)
	_expire_rocket_effects()
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
		if not enemy.hostile:
			_update_neutral_ship(enemy, delta)
			continue
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
			_steer_other_ship(enemy, aim, delta)
		var desired_velocity := _enemy_combat_velocity(enemy, away, distance, extra_range)
		var current_velocity: Vector2 = enemy.velocity
		enemy.velocity = current_velocity.move_toward(desired_velocity, ENEMY_ACCELERATION * delta)
		enemy.position += enemy.velocity * delta
		enemy.fire_cooldown -= delta
		var in_firing_range := distance >= ENEMY_MIN_COMBAT_RANGE + extra_range and distance <= ENEMY_FIRE_RANGE + extra_range
		if in_firing_range and enemy.fire_cooldown <= 0.0 and absf(angle_difference(enemy.heading, aim.angle())) < 0.25:
			_fire_enemy_turret(enemy)
	var aim_position := _aim_world_position()
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
		var heritage_fired := false
		for part in cached_turret_mounts:
			if part.turret in WEAPON_SLOTS[2].turrets and _turret_is_aimed(part, aim_position):
				var key := _turret_key(part)
				var burst := _next_machine_gun_shot(player_machine_gun_shots.get(key, {}))
				player_machine_gun_shots[key] = burst
				var angle := _turret_angle(part)
				var origin := _turret_world_position(part)
				if part.turret == MODULES.CRUISER_MACHINE_LASER:
					var muzzle := origin + MODULES.cruiser_laser_muzzle_offset(part, burst.barrel, angle + PI / 2.0, _cruiser_barrel_recoil(burst))
					projectiles.append({
						"position": muzzle, "muzzle": muzzle, "velocity": Vector2.from_angle(angle) * CRUISER_LASER_SPEED,
						"friendly": true, "damage": CRUISER_LASER_DAMAGE, "kind": MODULES.CRUISER_MACHINE_LASER,
					})
				else:
					var muzzle := origin + MODULES.machine_gun_muzzle_offset(burst.barrel, angle + PI / 2.0, 1.0, part.turret == "long_machine_gun", part.turret == "retro_machine_gun")
					var direction := Vector2.from_angle(angle).rotated(rng.randf_range(-0.035, 0.035))
					projectiles.append({"position": muzzle, "velocity": direction * 1200.0 + velocity * 0.25, "friendly": true, "damage": 4.0, "kind": "bullet"})
				fired = true
				heritage_fired = heritage_fired or part.turret == "retro_machine_gun"
		if custom_parts.any(func(part: Dictionary) -> bool: return part.type == "preset_frigate"):
			# The artwork has fixed forward-facing guns, so their shots follow the ship's heading.
			var forward := Vector2.from_angle(heading)
			var ship_rotation := heading + PI / 2.0
			for muzzle: Vector2 in [Vector2(-100, -495), Vector2(100, -495), Vector2(-100, -220), Vector2(100, -220)]:
				var muzzle_world := ship_position + muzzle.rotated(ship_rotation)
				projectiles.append({"position": muzzle_world, "velocity": forward * 1200.0 + velocity * 0.25, "friendly": true, "damage": 4.0, "kind": "bullet"})
			fired = true
			heritage_fired = true
		if fired:
			machine_gun_cooldown = 0.10
		if heritage_fired:
			heritage_gun_audio.pitch_scale = randf_range(0.96, 1.04)
			heritage_gun_audio.play()
	if firing and selected_weapon == 4 and rocket_cooldown <= 0.0:
		var fired := false
		for part in custom_parts:
			if part.get("turret", "") == "missile" and _turret_is_aimed(part, aim_position):
				var origin := _turret_world_position(part)
				projectiles.append(_make_rocket(origin, _turret_angle(part), velocity, true, MODULES.TYPES.missile.weapon))
				player_rocket_launches[_turret_key(part)] = elapsed
				fired = true
		if fired:
			rocket_cooldown = ROCKET_COOLDOWN
	if firing and selected_weapon == 5 and railgun_cooldown <= 0.0:
		var fired := false
		for part in custom_parts:
			if part.get("turret", "") == "railgun" and _turret_is_aimed(part, aim_position):
				var direction := Vector2.from_angle(_turret_angle(part))
				var muzzle := _turret_world_position(part) + direction * MODULES.RAILGUN_MUZZLE_OFFSET
				projectiles.append({"kind": "railgun", "position": muzzle, "velocity": direction * RAILGUN_SPEED,
					"friendly": true, "damage": MODULES.TYPES.railgun.weapon, "muzzle": muzzle})
				fired = true
		if fired:
			railgun_cooldown = RAILGUN_COOLDOWN
	for i in range(projectiles.size() - 1, -1, -1):
		var shot: Dictionary = projectiles[i]
		var is_rocket: bool = shot.get("kind", "") == "rocket"
		if is_rocket:
			_update_rocket(shot, delta)
		var previous: Vector2 = shot.position
		var end: Vector2 = previous + shot.velocity * delta
		shot.position = end
		var asteroid_contact: Variant = _asteroid_shot_contact(previous, end)
		var impact_point: Variant = asteroid_contact
		var closest := previous.distance_squared_to(asteroid_contact) if asteroid_contact != null else INF
		var hit := false
		if shot.friendly:
			var hit_index := -1
			var hit_point: Variant = null
			var segment_center := (previous + end) * 0.5
			var half_length := previous.distance_to(end) * 0.5
			for j in range(enemies.size()):
				var enemy: Dictionary = enemies[j]
				if not enemy.alive:
					continue
				var broad_radius := float(enemy.radius) + SHIELD_MARGIN
				var broad_distance := broad_radius + half_length
				if segment_center.distance_squared_to(enemy.position) > broad_distance * broad_distance:
					continue
				var contact: Variant = _enemy_shot_contact(previous, end, enemy)
				if contact != null and previous.distance_squared_to(contact) < closest:
					closest = previous.distance_squared_to(contact)
					hit_index = j
					hit_point = contact
			if hit_index >= 0:
				impact_point = hit_point
				var enemy: Dictionary = enemies[hit_index]
				enemy.hostile = true
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
			var contact: Variant = _player_shot_contact(previous, end)
			if contact != null and previous.distance_squared_to(contact) < closest:
				impact_point = contact
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
					if sustained_boost_enabled:
						_set_sustained_boost(false)
					_close_hyperjump_chart()
					hyperjump_time = -1.0
					boost_button.disabled = false
					hyperjump_arrival_until = 0.0
					player_hull = _player_max_hull()
					player_shield = _player_max_shield()
					player_shield_delay = 0.0
					shield_impacts.clear()
					hull_impacts.clear()
					ship_position = SOLAR_SYSTEM.starting_position()
					ship_motion_remainder = Vector2.ZERO
					velocity = Vector2.ZERO
					_reset_player_exhaust()
					boost_decelerating = false
					selected_asteroid = -1
					selected_enemy = -1
					mining_asteroid = -1
					laser_active = false
					machine_gun_active = false
					player_machine_gun_shots.clear()
					player_rocket_launches.clear()
					mining = false
					invulnerability = 3.0
		if not hit and asteroid_contact != null:
			_add_surface_impact(ASTEROID_IMPACT_INDEX, asteroid_contact, previous - end)
			hit = true
		if is_rocket:
			_emit_rocket_smoke(shot, previous, impact_point if hit else end, delta)
			if hit:
				rocket_blasts.append({"position": impact_point, "born": elapsed})
		if hit or not Rect2(Vector2.ZERO, WORLD_SIZE).has_point(end):
			projectiles.remove_at(i)
	if living == 0:
		if enemy_wave_timer < 0.0:
			enemy_wave_timer = 12.0
		else:
			enemy_wave_timer -= delta
			if enemy_wave_timer <= 0.0:
				_spawn_enemy_wave()

func _generate_asteroid_field() -> void:
	for asteroid in asteroids:
		var visual: Node2D = asteroid.visual
		asteroid_visuals.remove_child(visual)
		visual.queue_free()
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
	var asteroid := {"position": position, "radius": radius, "shape": shape, "inner": inner, "faces": faces, "base": base, "craters": craters, "specks": specks, "iron": capacity, "max_iron": capacity, "detailed": false}
	var visual := _add_draw_layer(asteroid_visuals, func(canvas: CanvasItem): _draw_asteroid(asteroid, canvas))
	asteroid_visuals.move_child(visual, asteroid_effects.get_index())
	asteroid.visual = visual
	asteroids.append(asteroid)

func _draw_asteroid(asteroid: Dictionary, canvas: CanvasItem) -> void:
	var center: Vector2 = asteroid.position
	var radius: float = asteroid.radius
	var shape: PackedVector2Array = asteroid.shape
	var inner: PackedVector2Array = asteroid.inner
	var points := PackedVector2Array()
	for point in shape:
		points.append(center + point)
	# At a distance, individual grains and crater outlines are too small to see.
	if not asteroid.detailed:
		canvas.draw_colored_polygon(points, asteroid.base)
		var simplified_inner := PackedVector2Array()
		for point in inner:
			simplified_inner.append(center + point)
		canvas.draw_colored_polygon(simplified_inner, asteroid.base.lightened(0.10))
		return
	# Dark rim and offset shadow give the rock a solid silhouette.
	canvas.draw_colored_polygon(points, Color("282b30"))
	for i in range(shape.size()):
		var next := (i + 1) % shape.size()
		var facet := PackedVector2Array([center + shape[i], center + shape[next], center + inner[next], center + inner[i]])
		canvas.draw_colored_polygon(facet, asteroid.faces[i])
	var inner_points := PackedVector2Array()
	for point in inner:
		inner_points.append(center + point)
	canvas.draw_colored_polygon(inner_points, asteroid.base.lightened(0.10))
	# Fine rocky grain and shallow, shaded impact craters.
	for speck in asteroid.specks:
		var shade := Color(0.82, 0.77, 0.67, 0.20) if speck.light else Color(0.08, 0.08, 0.09, 0.25)
		canvas.draw_circle(center + speck.position, speck.size, shade)
	for crater in asteroid.craters:
		var p: Vector2 = center + crater.position
		var r: float = crater.radius
		canvas.draw_circle(p + Vector2(1, 1) * radius * 0.015, r * 1.12, Color(0.75, 0.71, 0.62, 0.22))
		canvas.draw_circle(p, r, Color(0.12, 0.13, 0.14, 0.55))
		canvas.draw_arc(p, r * 0.82, PI * 0.95, PI * 1.9, 12, Color(0.07, 0.08, 0.09, 0.38), maxf(1.0, radius * 0.018), true)
	canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(0.08, 0.09, 0.11, 0.85), maxf(1.5, radius * 0.025), true)
	canvas.draw_line(points[0], points[1], Color(0.85, 0.82, 0.74, 0.22), 1.5, true)

func _screen_to_world(point: Vector2, clamp_to_world: bool = true) -> Vector2:
	var world_position := _world_transform().affine_inverse() * point
	return world_position.clamp(Vector2.ZERO, WORLD_SIZE) if clamp_to_world else world_position

func _aim_world_position() -> Vector2:
	if control_mode == 1 and rts_attack_active:
		if selected_enemy >= 0 and selected_enemy < enemies.size() and enemies[selected_enemy].alive:
			return enemies[selected_enemy].position
		if selected_asteroid >= 0 and selected_asteroid < asteroids.size() and asteroids[selected_asteroid].iron > 0:
			return asteroids[selected_asteroid].position
	return _screen_to_world(get_viewport().get_mouse_position())

func _fleet_ship_at_screen(screen_position: Vector2) -> int:
	var world_position := _screen_to_world(screen_position, false)
	for i in range(fleet.size() - 1, -1, -1):
		var ship: Dictionary = fleet[i]
		var parts: Array = custom_parts if i == active_fleet_index else ship.parts
		var position: Vector2 = ship_position if i == active_fleet_index else ship.position
		var ship_heading: float = heading if i == active_fleet_index else float(ship.heading)
		var bounds: Rect2 = MODULES.bounds(parts)
		var local := (world_position - position).rotated(-ship_heading - PI / 2.0)
		if bounds.size.length() * camera_zoom < 16.0 and screen_position.distance_to(_world_transform() * position) <= 8.0:
			return i
		if not Rect2(-bounds.size * 0.5, bounds.size).has_point(local):
			continue
		for part in parts:
			if not MODULES.is_exterior_structure(part):
				continue
			var offset := Vector2(part.x, part.y) * MODULES.CELL - bounds.get_center()
			for polygon in MODULES.structural_polygons(part, offset):
				if Geometry2D.is_point_in_polygon(local, polygon):
					return i
	return -1

func _show_fleet_context(index: int, screen_position: Vector2) -> void:
	if index < 0 or index >= fleet.size():
		return
	if not is_instance_valid(fleet_context_menu):
		fleet_context_menu = PopupMenu.new()
		add_child(fleet_context_menu)
		fleet_context_menu.id_pressed.connect(func(id: int):
			if id == 1:
				_switch_fleet_control(fleet_context_index)
		)
	fleet_context_index = index
	fleet_context_menu.clear()
	fleet_context_menu.add_item(str(fleet[index].name), 0)
	fleet_context_menu.set_item_disabled(0, true)
	fleet_context_menu.add_separator()
	fleet_context_menu.add_item("Already under your control" if index == active_fleet_index else "Take control", 1)
	fleet_context_menu.set_item_disabled(2, index == active_fleet_index or hyperjump_time >= 0.0)
	var menu_position := screen_position.clamp(Vector2.ZERO, (get_viewport_rect().size - Vector2(240, 90)).max(Vector2.ZERO))
	fleet_context_menu.position = Vector2i(menu_position)
	fleet_context_menu.popup()

func _rts_issue_order(screen_position: Vector2) -> void:
	var previous_enemy := selected_enemy
	var previous_asteroid := selected_asteroid
	_select_target_at(_screen_to_world(screen_position, false))
	if selected_enemy >= 0 or (selected_weapon == 2 and selected_asteroid >= 0):
		rts_attack_active = true
		rts_move_active = false
	else:
		selected_enemy = previous_enemy
		selected_asteroid = previous_asteroid
		rts_move_active = true
		rts_destination = _screen_to_world(screen_position)
	mining_progress = 0.0

func _finish_rts_selection(screen_position: Vector2) -> void:
	rts_dragging = false
	rts_drag_end = screen_position
	var selection := Rect2(rts_drag_start, rts_drag_end - rts_drag_start).abs()
	var ship_screen := _world_transform() * ship_position
	var ship_radius := maxf(_ship_size().length() * 0.5 * camera_zoom, 12.0)
	if selection.size.length() > 8.0:
		rts_selected = selection.intersects(Rect2(ship_screen - Vector2.ONE * ship_radius, Vector2.ONE * ship_radius * 2.0))
	elif screen_position.distance_to(ship_screen) <= ship_radius:
		rts_selected = true
	elif rts_selected:
		_rts_issue_order(screen_position)
	_queue_flight_redraw()

func _input(event: InputEvent) -> void:
	if is_instance_valid(hangar_layer):
		return
	if fleet_click_index >= 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var clicked_index := fleet_click_index
		fleet_click_index = -1
		if event.position.distance_to(fleet_click_start) <= 8.0:
			rts_dragging = false
			firing = false
			_show_fleet_context(clicked_index, event.position)
			get_viewport().set_input_as_handled()
			return
	if camera_dragging:
		if event is InputEventMouseMotion:
			_pan_camera(-event.relative)
			_queue_flight_redraw()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			camera_dragging = false
			get_viewport().set_input_as_handled()
			return
	if hyperjump_context_button.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_hyperjump_chart()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and not hyperjump_context_button.get_global_rect().has_point(event.position):
			_close_hyperjump_chart()
	if radial_menu_open:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			radial_menu_open = false
			get_viewport().set_input_as_handled()
			_queue_flight_redraw()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			var distance: float = event.position.distance_to(radial_menu_position)
			radial_menu_open = false
			if event.button_index == MOUSE_BUTTON_LEFT and distance >= 18.0 and distance <= RADIAL_MENU_RADIUS:
				if event.position.y < radial_menu_position.y:
					_toggle_sustained_boost()
			get_viewport().set_input_as_handled()
			_queue_flight_redraw()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and control_mode == 1 and not is_instance_valid(settings_layer) and not radial_menu_open:
		_cycle_target()
		get_viewport().set_input_as_handled()
		_queue_flight_redraw()
		return
	if event is InputEventKey and event.keycode == KEY_SPACE and not event.echo and control_mode == 0 and hyperjump_time < 0.0:
		_ensure_ship_cache()
		if has_flight_controls and not is_instance_valid(settings_layer):
			if sustained_boost_enabled:
				if event.pressed:
					_set_sustained_boost(false)
			elif event.pressed and not boost_charging:
				boost_charging = true
				boost_charge = 0.0
			elif not event.pressed and boost_charging:
				_launch_boost()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(fleet_context_menu) and fleet_context_menu.visible:
			fleet_context_menu.hide()
			get_viewport().set_input_as_handled()
			return
		if is_instance_valid(settings_layer):
			_close_settings()
		else:
			_open_settings()
		get_viewport().set_input_as_handled()
		return
	# Stop firing even when the pointer is over a menu control.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if control_mode == 1 and rts_dragging:
			_finish_rts_selection(event.position)
		else:
			firing = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		firing = false
		rts_dragging = false
		radial_menu_open = false
		camera_dragging = false
		fleet_click_index = -1
		
func _make_rocket(origin: Vector2, angle: float, carrier_velocity: Vector2, friendly: bool, damage: float, scale_factor: float = 1.0) -> Dictionary:
	var forward := Vector2.from_angle(angle)
	var drift := carrier_velocity.limit_length(460.0) * 0.35
	return {
		"kind": "rocket", "friendly": friendly, "damage": damage,
		"position": origin + forward * (MODULES.ROCKET_MUZZLE_OFFSET * scale_factor + ROCKET_TAIL_OFFSET),
		"velocity": forward * ROCKET_EJECTION_SPEED + drift, "launch_drift": drift,
		"rocket_heading": angle, "rocket_speed": ROCKET_EJECTION_SPEED, "age": 0.0,
		"smoke_distance": 0.0,
	}

func _update_rocket(shot: Dictionary, delta: float) -> void:
	shot.age += delta
	var powered_time := clampf(shot.age - ROCKET_IGNITION_DELAY, 0.0, delta)
	var rocket_heading: float = shot.rocket_heading
	# Hostile rockets start steering after ignition and retain a limited turn rate.
	if not shot.friendly and powered_time > 0.0:
		var to_target: Vector2 = ship_position - shot.position
		if to_target.length_squared() > 1.0:
			var turn_limit := 1.6 * powered_time
			rocket_heading += clampf(angle_difference(rocket_heading, to_target.angle()), -turn_limit, turn_limit)
	shot.rocket_heading = rocket_heading
	var speed_factor := 1.0 if shot.friendly else ENEMY_ROCKET_SPEED_FACTOR
	shot.rocket_speed = move_toward(shot.rocket_speed, ROCKET_TOP_SPEED * speed_factor, ROCKET_ACCELERATION * speed_factor * powered_time)
	shot.velocity = Vector2.from_angle(rocket_heading) * shot.rocket_speed + shot.launch_drift * exp(-shot.age * 4.5)

func _emit_rocket_smoke(shot: Dictionary, start: Vector2, end: Vector2, delta: float) -> void:
	if shot.age <= ROCKET_IGNITION_DELAY:
		return
	var powered_fraction := clampf((shot.age - ROCKET_IGNITION_DELAY) / delta, 0.0, 1.0)
	var travel := end - start
	var spacing := ROCKET_SMOKE_SPACING
	var remaining := float(shot.smoke_distance) + travel.length() * powered_fraction
	var direction := travel.normalized()
	var tail_offset := Vector2.from_angle(shot.rocket_heading) * ROCKET_TAIL_OFFSET
	while remaining >= spacing:
		remaining -= spacing
		var position := end - direction * remaining - tail_offset
		rocket_smoke.append({"position": position, "born": elapsed})
	shot.smoke_distance = remaining

func _expire_rocket_effects() -> void:
	while not rocket_smoke.is_empty() and elapsed - rocket_smoke[0].born >= ROCKET_SMOKE_LIFETIME:
		rocket_smoke.pop_front()
	while not rocket_blasts.is_empty() and elapsed - rocket_blasts[0].born >= ROCKET_BLAST_DURATION:
		rocket_blasts.pop_front()

func _mining_range(asteroid: Dictionary) -> float:
	return asteroid.radius + maxf(650.0, _ship_half_length() + 35.0)

func _unhandled_input(event: InputEvent) -> void:
	if radial_menu_open and event is InputEventMouseMotion:
		queue_redraw()
		return
	if control_mode == 1 and event is InputEventMouseMotion and rts_dragging:
		rts_drag_end = event.position
		_queue_flight_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if control_mode != 1:
					return
				camera_following = true
			KEY_F:
				camera_following = true
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
			KEY_5, KEY_KP_5:
				selected_weapon = 5
			_:
				return
		get_viewport().set_input_as_handled()
		_queue_flight_redraw()
		return
	if event is InputEventMouseButton:
		if not event.pressed:
			return
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := pow(CAMERA_ZOOM_STEP, event.factor if event.factor > 0.0 else 1.0)
			var zoom_factor := step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step
			camera_zoom_target = clampf(camera_zoom_target * zoom_factor, _minimum_camera_zoom(), SETTINGS_MENU.MAX_ZOOM)
			camera_zoom_focus = event.position
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed:
			camera_dragging = true
			rts_dragging = false
			firing = false
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var system_index := _system_at_screen(event.position)
			if system_index >= 0:
				_show_hyperjump_context(system_index, event.position)
				get_viewport().set_input_as_handled()
				return
		if hyperjump_time >= 0.0 and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			var margin := Vector2.ONE * (RADIAL_MENU_RADIUS + 4.0)
			radial_menu_position = event.position.clamp(margin, (get_viewport_rect().size - margin).max(margin))
			radial_menu_open = true
			rts_dragging = false
			firing = false
			get_viewport().set_input_as_handled()
			_queue_flight_redraw()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_ship := _fleet_ship_at_screen(event.position)
			if clicked_ship >= 0:
				fleet_click_index = clicked_ship
				fleet_click_start = event.position
				if control_mode == 1:
					rts_dragging = true
					rts_drag_start = event.position
					rts_drag_end = event.position
				get_viewport().set_input_as_handled()
				return
		if sustained_boost_enabled and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_steer_sustained_boost(event.position)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if control_mode == 1:
				rts_dragging = true
				rts_drag_start = event.position
				rts_drag_end = event.position
			else:
				firing = true
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if control_mode == 1:
				if rts_selected:
					_rts_issue_order(event.position)
			else:
				_select_target_at(_screen_to_world(event.position, false))
			get_viewport().set_input_as_handled()
			_queue_flight_redraw()

func _launch_boost() -> void:
	_ensure_ship_cache()
	if not has_flight_controls or float(_current_ship().speed) <= 0.0:
		boost_charging = false
		boost_charge = 0.0
		if sustained_boost_enabled:
			_set_sustained_boost(false)
		return
	boost_charging = false
	boost_decelerating = false
	boost_power = boost_charge
	boost_duration = lerpf(0.85, 2.0, boost_power)
	boost_time = boost_duration
	if not cached_engines.is_empty():
		engine_audio.play_boost(boost_power)
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

func _stretched_hull_push(center: Vector2, radius: float) -> Vector2:
	var rotation := heading + PI / 2.0
	var local := (center - ship_position).rotated(-rotation)
	var push := Vector2.ZERO
	for shape in cached_hull_shapes:
		var nearest_distance := INF
		var nearest := Vector2.ZERO
		var edge_normal := Vector2.ZERO
		var winding := signf((shape[1] - shape[0]).cross(shape[2] - shape[1]))
		for i in range(shape.size()):
			var a := shape[i]
			var b := shape[(i + 1) % shape.size()]
			var point := Geometry2D.get_closest_point_to_segment(local, a, b)
			var distance := local.distance_squared_to(point)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = point
				edge_normal = (b - a).orthogonal().normalized() * winding
		var inside := Geometry2D.is_point_in_polygon(local, shape)
		var distance := sqrt(nearest_distance)
		var depth := radius + distance if inside else radius - distance
		if depth <= 0.0 or depth * depth <= push.length_squared():
			continue
		var normal := (nearest - local) / distance if distance > 0.001 else -edge_normal
		if inside and distance > 0.001:
			normal = -normal
		push = normal * depth
	return push.rotated(rotation)

func _push_player(push: Vector2) -> void:
	ship_position += push
	var direction := push.normalized()
	var inward := velocity.dot(direction)
	if inward < 0.0:
		velocity -= direction * inward

func _advance_player(delta: float) -> void:
	var origin := ship_position
	var motion := velocity * delta
	if velocity != Vector2.ZERO:
		motion += ship_motion_remainder
	var target := origin + motion
	_move_player_against_fleet(target)
	ship_motion_remainder = motion - (target - origin) if ship_position == target else Vector2.ZERO

func _move_player_against_fleet(target: Vector2) -> void:
	target = target.clamp(Vector2.ZERO, WORLD_SIZE)
	if fleet.size() <= 1:
		ship_position = target
		return
	player_fleet_body.position = ship_position
	player_fleet_body.rotation = heading + PI / 2.0
	var motion := target - ship_position
	# Sweep the full motion, then allow the unblocked component to slide along the hull.
	for attempt in range(2):
		var hit := player_fleet_body.move_and_collide(motion, false, FLEET_COLLISION_MARGIN, true)
		if hit == null:
			break
		var normal := hit.get_normal()
		var inward := velocity.dot(normal)
		if inward < 0.0:
			velocity -= normal * inward
			if hyperjump_time >= 0.0:
				hyperjump_time = -1.0
				boost_button.disabled = false
				boost_decelerating = true
		motion = hit.get_remainder()
		motion -= normal * minf(0.0, motion.dot(normal))
		if motion.is_zero_approx():
			break
	ship_position = player_fleet_body.position.clamp(Vector2.ZERO, WORLD_SIZE)

func _resolve_ship_collisions() -> void:
	var size := _ship_size()
	var player_radius := minf(size.x * 0.43, size.y * 0.34)
	var uses_stretched_hull := not cached_hull_shapes.is_empty()
	var discs: Array[Vector2] = []
	if not uses_stretched_hull:
		discs = _player_collision_discs()
	var broad_radius := size.length() * 0.5 if uses_stretched_hull else size.y * 0.5
	# A few relaxation passes resolve contacts without doing detailed off-screen drawing.
	for pass_index in range(3):
		for asteroid in asteroids:
			if asteroid.iron <= 0:
				continue
			var rock_radius: float = asteroid.radius * 0.90
			if ship_position.distance_squared_to(asteroid.position) < pow(broad_radius + rock_radius, 2):
				if uses_stretched_hull:
					_push_player(_stretched_hull_push(asteroid.position, rock_radius))
				for offset in discs:
					var difference: Vector2 = ship_position + offset - asteroid.position
					var limit := player_radius + rock_radius
					if difference.length_squared() >= limit * limit:
						continue
					var distance := difference.length()
					var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
					_push_player(normal * (limit - distance))
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
			if uses_stretched_hull and ship_position.distance_squared_to(enemy.position) < pow(broad_radius + float(enemy.radius), 2):
				var radius := _enemy_hull_radius(enemy, ship_position - (enemy.position as Vector2))
				var push := _stretched_hull_push(enemy.position, radius)
				_push_player(push * 0.10)
				enemy.position -= push * 0.90
				var normal := push.normalized()
				var inward := (enemy.velocity as Vector2).dot(normal)
				if inward > 0.0:
					enemy.velocity -= inward * normal
			for offset in discs:
				var difference: Vector2 = ship_position + offset - enemy.position
				var limit := player_radius + _enemy_hull_radius(enemy, difference)
				if difference.length_squared() >= limit * limit:
					continue
				var distance := difference.length()
				var normal := difference / distance if distance > 0.001 else Vector2.RIGHT
				var overlap := limit - distance
				var player_share := 0.10
				_push_player(normal * overlap * player_share)
				enemy.position -= normal * overlap * (1.0 - player_share)
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

func _turn_acceleration(max_turn_rate: float) -> float:
	return max_turn_rate * 1.85

func _steered_rotation(angle: float, rate: float, direction: Vector2, max_turn_rate: float, delta: float) -> Vector2:
	var turning := direction.length_squared() > 0.0001
	var error := angle_difference(angle, direction.angle()) if turning else 0.0
	var torque := _turn_acceleration(max_turn_rate)
	# Match the remaining angle to the distance needed to brake the turn.
	var desired_rate := signf(error) * minf(max_turn_rate, sqrt(2.0 * torque * absf(error)))
	var next_rate := move_toward(rate, desired_rate, torque * delta)
	var step := next_rate * delta
	if turning and signf(step) == signf(error) and absf(step) >= absf(error):
		return Vector2(direction.angle(), 0.0)
	return Vector2(wrapf(angle + step, -PI, PI), next_rate)

func _steer_heading(direction: Vector2, max_turn_rate: float, delta: float) -> void:
	var rotation := _steered_rotation(heading, angular_velocity, direction, max_turn_rate, delta)
	heading = rotation.x
	angular_velocity = rotation.y

func _steer_other_ship(ship: Dictionary, direction: Vector2, delta: float) -> void:
	var rotation := _steered_rotation(ship.heading, ship.angular_velocity, direction, ship.turn_speed, delta)
	ship.heading = rotation.x
	ship.angular_velocity = rotation.y

func _update_manual_flight(turn_input: float, accelerating: bool, braking: bool, speed_limit: float, ship_acceleration: float, ship_turn_speed: float, boosting: bool, delta: float) -> void:
	var max_turn_rate := ship_turn_speed * (0.55 if boosting else 1.0)
	angular_velocity = move_toward(angular_velocity, turn_input * max_turn_rate, _turn_acceleration(max_turn_rate) * delta)
	heading = wrapf(heading + angular_velocity * delta, -PI, PI)
	thrust = move_toward(thrust, 1.0 if accelerating and not braking else 0.0, delta * THROTTLE_RAMP)
	if braking:
		velocity = velocity.move_toward(Vector2.ZERO, ship_acceleration * 1.25 * delta)
		return
	engine_throttle_target = float(accelerating and ship_acceleration > 0.0)
	if boosting:
		var envelope := _boost_burst_envelope()
		engine_boost_target = envelope * lerpf(0.35, 1.0, boost_power)
		var boost_force := ship_acceleration * lerpf(1.35, 3.6, boost_power) * envelope
		var burst_limit := speed_limit * lerpf(1.75, 3.0, boost_power)
		velocity = (velocity + Vector2.from_angle(heading) * boost_force * delta).limit_length(maxf(burst_limit, velocity.length()))
		return
	if thrust > 0.0:
		var forward := Vector2.from_angle(heading)
		var forward_speed := velocity.dot(forward)
		var engine_room := maxf(speed_limit - forward_speed, 0.0)
		var forward_gain := minf(engine_room, ship_acceleration * thrust * delta)
		# Turning changes the thrust direction and leaves the existing drift in world space.
		velocity = (velocity + forward * forward_gain).limit_length(maxf(speed_limit, velocity.length()))
	else:
		velocity *= exp(-drag * delta)
		if velocity.length_squared() < 0.25:
			velocity = Vector2.ZERO
	if velocity.length() > speed_limit and ship_acceleration > 0.0:
		velocity = velocity.normalized() * move_toward(velocity.length(), speed_limit, ship_acceleration * 0.7 * delta)

func _update_rts_flight(speed_limit: float, ship_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	var to_destination := rts_destination - ship_position
	var distance := to_destination.length()
	if _at_flight_destination(distance, 3.0, 4.0):
		rts_move_active = false
		velocity = Vector2.ZERO
		_steer_heading(Vector2.ZERO, ship_turn_speed, delta)
		thrust = move_toward(thrust, 0.0, delta * THROTTLE_RAMP)
		return
	_steer_heading(to_destination if distance > RTS_DOCKING_DISTANCE else Vector2.ZERO, ship_turn_speed, delta)
	var forward := Vector2.from_angle(heading)
	var course := to_destination.normalized()
	var alignment := smoothstep(0.1, 0.94, forward.dot(course))
	# Use low-speed correction thrusters for the final approach without spinning the hull.
	var braking_acceleration := ship_acceleration * 0.55
	var arrival_speed := minf(distance * RTS_APPROACH_RATE, sqrt(2.0 * braking_acceleration * distance) * 0.8)
	var cruise_fraction := lerpf(1.0, alignment, smoothstep(RTS_DOCKING_DISTANCE, RTS_DOCKING_DISTANCE * 3.0, distance))
	var desired_velocity := course * minf(speed_limit, arrival_speed) * cruise_fraction
	var engine_demand := clampf((desired_velocity - velocity).dot(forward) / maxf(ship_acceleration * 0.5, 1.0), 0.0, 1.0) * alignment
	var cruise_power := 0.58 * _navigation_exhaust(course, desired_velocity.length(), alignment, delta)
	engine_throttle_target = maxf(engine_demand, cruise_power)
	thrust = move_toward(thrust, engine_demand, delta * THROTTLE_RAMP)
	var correction := braking_acceleration + (ship_acceleration - braking_acceleration) * thrust
	velocity = velocity.move_toward(desired_velocity, correction * delta)

func _physics_process(delta: float) -> void:
	elapsed += delta
	engine_throttle_target = 0.0
	engine_boost_target = 0.0
	if control_mode == 1:
		var camera_input := Vector2(
			float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
			float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
		if camera_input != Vector2.ZERO:
			_pan_camera(camera_input.normalized() * RTS_CAMERA_SPEED * delta)
		var valid_enemy: bool = selected_enemy >= 0 and selected_enemy < enemies.size() and enemies[selected_enemy].alive
		var valid_asteroid: bool = selected_asteroid >= 0 and selected_asteroid < asteroids.size() and asteroids[selected_asteroid].iron > 0
		if rts_attack_active and not valid_enemy and not valid_asteroid:
			rts_attack_active = false
		firing = rts_attack_active
	_update_turrets(delta)
	var ship := _current_ship()
	if not has_flight_controls:
		angular_velocity = 0.0
		thrust = 0.0
		boost_time = 0.0
		boost_charging = false
		boost_charge = 0.0
	var turn_input := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
	var accelerating := Input.is_key_pressed(KEY_W)
	var braking := Input.is_key_pressed(KEY_S)
	var manual_control := control_mode == 0 and has_flight_controls and (turn_input != 0.0 or accelerating or braking)
	if boost_charging:
		boost_charge = minf(1.0, boost_charge + delta / BOOST_CHARGE_SECONDS)
		if is_equal_approx(boost_charge, 1.0) and float(ship.speed) > 0.0:
			var boost_direction := Vector2.from_angle(heading)
			_set_sustained_boost(true, boost_direction)
			if not cached_engines.is_empty():
				engine_audio.play_boost(1.0)
	var boosting := boost_time > 0.0
	if boosting:
		boost_time = maxf(0.0, boost_time - delta)
	var acceleration_factor: float = ship.acceleration
	var speed_factor: float = ship.speed
	var ship_acceleration := acceleration * acceleration_factor
	var ship_turn_speed := turn_speed * float(ship.turn)
	var speed_limit := top_speed * speed_factor
	if boost_decelerating and velocity.length() <= speed_limit + 0.01:
		boost_decelerating = false
	# The mining beam follows the pointer and operates while the fire button is held.
	mining = false
	laser_active = firing and selected_weapon == 2
	mining_asteroid = -1
	if laser_active:
		var aim_position := _aim_world_position()
		for i in range(asteroids.size() - 1, -1, -1):
			if asteroids[i].iron > 0 and aim_position.distance_to(asteroids[i].position) <= asteroids[i].radius:
				mining_asteroid = i
				break
	if mining_asteroid >= 0:
		var asteroid: Dictionary = asteroids[mining_asteroid]
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
				if selected_asteroid == mining_asteroid:
					selected_asteroid = -1
				mining_asteroid = -1
				laser_active = false
				machine_gun_active = false
				mining = false
				mining_progress = 0.0
	if hyperjump_time >= 0.0:
		_update_hyperjump(HYPERJUMP_TRAVEL_SPEED * speed_factor, HYPERJUMP_TRAVEL_ACCELERATION * acceleration_factor, ship_turn_speed, delta)
	elif sustained_boost_enabled and boost_destination_active:
		_update_boost_destination(BOOST_TRAVEL_SPEED * speed_factor, BOOST_TRAVEL_ACCELERATION * acceleration_factor, ship_turn_speed, delta)
	elif sustained_boost_enabled and sustained_boost_direction != Vector2.ZERO:
		var boost_speed := BOOST_TRAVEL_SPEED * speed_factor
		var boost_acceleration := BOOST_TRAVEL_ACCELERATION * acceleration_factor
		var boost_velocity := sustained_boost_direction * boost_speed
		var movement_acceleration := _boost_acceleration(boost_speed, boost_acceleration) if boost_speed > velocity.length() else boost_acceleration
		velocity = velocity.move_toward(boost_velocity, movement_acceleration * delta)
		_steer_heading(sustained_boost_direction, ship_turn_speed, delta)
		thrust = move_toward(thrust, 1.0, delta * 5.0)
		engine_boost_target = 1.0
	elif boost_decelerating and not manual_control and not rts_move_active:
		velocity = velocity.move_toward(velocity.normalized() * speed_limit, ship_acceleration * 2.0 * delta)
		_steer_heading(Vector2.ZERO, ship_turn_speed, delta)
		thrust = move_toward(thrust, 0.0, delta * 5.0)
	elif control_mode == 1 and has_flight_controls and rts_move_active:
		_update_rts_flight(speed_limit, ship_acceleration, ship_turn_speed, delta)
	else:
		_update_manual_flight(turn_input if manual_control else 0.0, manual_control and accelerating, manual_control and braking, speed_limit, ship_acceleration, ship_turn_speed, boosting, delta)
	# Keep the ship inside the large play area.
	_advance_player(delta)
	if ship_position.x <= 0.0 or ship_position.x >= WORLD_SIZE.x:
		velocity.x = 0.0
	if ship_position.y <= 0.0 or ship_position.y >= WORLD_SIZE.y:
		velocity.y = 0.0
	if sustained_boost_enabled and not boost_destination_active and sustained_boost_direction != Vector2.ZERO:
		var at_edge := (ship_position.x <= 0.0 and sustained_boost_direction.x < 0.0) or (ship_position.x >= WORLD_SIZE.x and sustained_boost_direction.x > 0.0) or (ship_position.y <= 0.0 and sustained_boost_direction.y < 0.0) or (ship_position.y >= WORLD_SIZE.y and sustained_boost_direction.y > 0.0)
		if at_edge:
			_set_sustained_boost(false)
			engine_boost_target = 0.0
	_update_combat(delta)
	var position_before_contact := ship_position
	_resolve_ship_collisions()
	if ship_position != position_before_contact:
		ship_motion_remainder = Vector2.ZERO
		if fleet.size() > 1:
			var corrected_position := ship_position
			ship_position = position_before_contact
			_move_player_against_fleet(corrected_position)
	_collect_tritium(delta)
	_update_debris(delta)
	_update_player_exhaust(delta)
	_update_exhaust_particles(delta)
	if has_flight_controls and not cached_engines.is_empty():
		engine_audio.update_mix(engine_flame, engine_overdrive, _sustained_boost_active(), delta)
	_queue_flight_redraw()

func _draw_background(canvas: CanvasItem) -> void:
	var size := get_viewport_rect().size
	canvas.draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var star_count := mini(stars.size(), 55 if graphics_quality == 0 else (110 if graphics_quality == 1 else 190))
	for star_index in range(star_count):
		var star: Dictionary = stars[star_index]
		var depth: float = star.depth
		var drift := (star.position as Vector2) * size - starfield_offset * (1.0 + depth * 4.0)
		var point := Vector2(fposmod(drift.x, size.x), fposmod(drift.y, size.y))
		var phase: float = elapsed * star.twinkle_speed + star.phase
		var shimmer := 0.65 * sin(phase) + 0.35 * sin(phase * 2.17 + float(star.phase))
		var alpha: float = (0.25 + depth * 0.5) * (0.9 + star.twinkle_strength * shimmer)
		var tint: Color = star.tint
		var radius := 0.5 + depth * 1.1
		if graphics_quality > 0 and depth > 0.88:
			var glow := 0.04 + 0.09 * smoothstep(0.15, 0.95, shimmer)
			canvas.draw_circle(point, radius + 1.3, Color(tint, glow), true, -1.0, true)
		canvas.draw_circle(point, radius, Color(tint, alpha), true, -1.0, true)

func _draw_asteroid_effects(canvas: CanvasItem) -> void:
	_draw_hull_impacts(ASTEROID_IMPACT_INDEX, canvas)
	var marked_asteroid := selected_asteroid
	if marked_asteroid == -1:
		marked_asteroid = mining_asteroid
	if marked_asteroid >= 0:
		var asteroid: Dictionary = asteroids[marked_asteroid]
		canvas.draw_arc(asteroid.position, asteroid.radius + 10.0, 0.0, TAU, 48, Color(0.45, 0.9, 1.0, 0.75), 2.0, true)
	if mining:
		var asteroid: Dictionary = asteroids[mining_asteroid]
		var bar_size := Vector2(maxf(asteroid.radius * 1.5, 65.0), 7.0)
		var bar_position: Vector2 = asteroid.position + Vector2(-bar_size.x / 2.0, -asteroid.radius - 24.0)
		canvas.draw_rect(Rect2(bar_position, bar_size), Color(0.03, 0.06, 0.09, 0.9))
		canvas.draw_rect(Rect2(bar_position, Vector2(bar_size.x * float(asteroid.iron) / float(asteroid.max_iron), bar_size.y)), Color("e3ad79"))
		canvas.draw_rect(Rect2(bar_position, bar_size), Color(0.8, 0.88, 0.9, 0.8), false, 1.0)

func _draw_debris(canvas: CanvasItem) -> void:
	var camera := _world_transform()
	var visible_world := _visible_world(camera)
	for piece in debris:
		if not visible_world.has_point(piece.position):
			continue
		canvas.draw_set_transform(camera * piece.position, piece.rotation, Vector2.ONE * camera_zoom)
		var alpha: float = minf(1.0, piece.life / 1.5)
		MODULES.draw_part(canvas, piece.part, Vector2.ZERO, ENEMY_PART_SCALE, alpha)
		if piece.part.has("turret"):
			MODULES.draw_mounted_turret(canvas, piece.part.turret, Vector2.ZERO, ENEMY_PART_SCALE, alpha)

func _draw() -> void:
	var size := get_viewport_rect().size
	var camera := _world_transform()
	var visible_world := _visible_world(camera)
	draw_set_transform_matrix(camera)
	_draw_rocket_effects(visible_world)
	for shot in projectiles:
		if not visible_world.has_point(shot.position):
			continue
		var direction: Vector2 = shot.velocity.normalized()
		if shot.get("kind", "") == "rocket":
			_draw_rocket(shot)
		elif shot.get("kind", "") == "railgun":
			var tip: Vector2 = shot.position
			var length := minf(tip.distance_to(shot.muzzle), 165.0)
			draw_line(tip - direction * length, tip, Color(0.65, 0.42, 1.0, 0.3), 9.0, true)
			draw_line(tip - direction * length * 0.87, tip, Color("b196ff"), 3.5, true)
			draw_line(tip - direction * length * 0.33, tip, Color("f4ebff"), 2.0, true)
		elif shot.get("kind", "") == "bullet":
			draw_line(shot.position - direction * 12.0, shot.position, Color("ffd078"), 2.5, true)
		elif shot.get("kind", "") == MODULES.CRUISER_MACHINE_LASER:
			var tip: Vector2 = shot.position
			var tail := tip - direction * minf(tip.distance_to(shot.muzzle), 32.0)
			draw_line(tail, tip, Color(CRUISER_LASER_COLOR, 0.28), 8.0, true)
			draw_line(tail, tip, CRUISER_LASER_COLOR, 3.5, true)
			draw_line(tail.lerp(tip, 0.43), tip, Color("e7fff6"), 1.5, true)
		else:
			var color := Color("8af4ff") if shot.friendly else Color("ff7562")
			draw_line(shot.position - direction * 16.0, shot.position, color, 4.0, true)
			draw_circle(shot.position, 3.0, Color.WHITE)
	_draw_mining_beams()
	# Draw collectibles above the hull so their final movement is visible.
	draw_set_transform_matrix(camera)
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
	if camera_zoom < MAP_LABEL_ZOOM:
		_draw_sector_labels(camera)
	var ship_screen := camera * ship_position
	_draw_hud(size)
	_draw_aim_indicators(size)
	var marker_alpha := 1.0 - smoothstep(7.0, 16.0, _ship_size().y * camera_zoom)
	if marker_alpha > 0.0 and visible_world.has_point(ship_position):
		var forward := Vector2.from_angle(heading)
		var side := forward.orthogonal()
		draw_colored_polygon(PackedVector2Array([ship_screen + forward * 7.0, ship_screen - forward * 5.0 + side * 4.0, ship_screen - forward * 5.0 - side * 4.0]), Color(Color("e0f9ff"), marker_alpha))
	if control_mode == 1 and hyperjump_time < 0.0:
		if rts_selected:
			draw_arc(ship_screen, maxf(_ship_size().length() * 0.5 * camera_zoom, 12.0) + 5.0, 0.0, TAU, 48, Color(0.65, 0.82, 0.76, 0.42), 1.25, true)
		if rts_move_active:
			var marker := camera * rts_destination
			draw_arc(marker, 10.0, 0.0, TAU, 32, Color("79efbb"), 2.0, true)
		if rts_dragging:
			var selection := Rect2(rts_drag_start, rts_drag_end - rts_drag_start).abs()
			draw_rect(selection, Color(0.35, 0.95, 0.7, 0.12))
			draw_rect(selection, Color("79efbb"), false, 1.5)
	if radial_menu_open:
		_draw_radial_menu()

func _draw_radial_menu() -> void:
	var mouse_offset := get_viewport().get_mouse_position() - radial_menu_position
	var highlighted := mouse_offset.length() >= 18.0 and mouse_offset.length() <= RADIAL_MENU_RADIUS
	draw_circle(radial_menu_position, RADIAL_MENU_RADIUS, Color(0.025, 0.055, 0.09, 0.96), true, -1.0, true)
	draw_arc(radial_menu_position, RADIAL_MENU_RADIUS, 0.0, TAU, 64, Color("7196a7"), 1.5, true)
	if highlighted:
		var start_angle := PI if mouse_offset.y < 0.0 else 0.0
		draw_arc(radial_menu_position, 45.0, start_angle, start_angle + PI, 32, Color(0.36, 0.73, 0.86, 0.28), 52.0, true)
	draw_line(radial_menu_position + Vector2(-RADIAL_MENU_RADIUS, 0), radial_menu_position + Vector2(RADIAL_MENU_RADIUS, 0), Color("507383"), 1.0, true)
	draw_circle(radial_menu_position, 18.0, Color("102434"), true, -1.0, true)
	draw_arc(radial_menu_position, 18.0, 0.0, TAU, 32, Color("507383"), 1.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, radial_menu_position + Vector2(-8, 5), "×", HORIZONTAL_ALIGNMENT_CENTER, 16.0, 16, Color("9ab3bf"))
	var label := "EXIT BOOST" if sustained_boost_enabled else "BOOST"
	draw_string(font, radial_menu_position + Vector2(-60, -35), label, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 12, Color("dcf4ff"))
	draw_string(font, radial_menu_position + Vector2(-65, 47), "RIGHT-CLICK A SYSTEM", HORIZONTAL_ALIGNMENT_CENTER, 130.0, 10, Color("91aebe"))

func _draw_rocket(shot: Dictionary) -> void:
	var center: Vector2 = shot.position
	var forward := Vector2.from_angle(shot.rocket_heading)
	var side := forward.orthogonal()
	var tail := center - forward * ROCKET_TAIL_OFFSET
	var burn := smoothstep(ROCKET_IGNITION_DELAY, ROCKET_IGNITION_DELAY + 0.08, shot.age)
	if burn > 0.0:
		var plume_length := (23.0 + 5.0 * sin(shot.age * 110.0)) * burn
		var trail_end := tail - forward * plume_length
		draw_colored_polygon(PackedVector2Array([tail + side * 4.5, tail - side * 4.5, trail_end]), Color("ff8041"))
		draw_colored_polygon(PackedVector2Array([tail + side * 2.1, tail - side * 2.1, tail.lerp(trail_end, 0.7)]), Color("fff4c8"))
		draw_circle(tail, 7.5, Color(1.0, 0.44, 0.14, 0.22 * burn), true, -1.0, true)
	var nose := center + forward * 10.0
	draw_colored_polygon(PackedVector2Array([
		center - forward * 2.0, tail + side * 6.0, tail - side * 6.0,
	]), Color("677891"))
	draw_colored_polygon(PackedVector2Array([
		nose, center + forward * 3.0 + side * 3.6, tail + side * 2.5,
		tail - side * 2.5, center + forward * 3.0 - side * 3.6,
	]), Color("bec9d5"))
	draw_line(center + side * 1.4 - forward * 4.0, center + side * 1.4 + forward * 4.0, Color("eff4ff"), 1.4, true)
	draw_line(center - side * 3.2, center + side * 3.2, Color("e48251"), 1.8, true)

func _draw_rocket_effects(visible_world: Rect2) -> void:
	for puff in rocket_smoke:
		var position: Vector2 = puff.position
		if not visible_world.has_point(position):
			continue
		var age := clampf((elapsed - puff.born) / ROCKET_SMOKE_LIFETIME, 0.0, 1.0)
		var color := Color("d0a083").lerp(Color("8a95a8"), smoothstep(0.0, 0.6, age))
		color.a = 0.36 * (1.0 - age) * (1.0 - age)
		draw_circle(position, lerpf(3.5, 17.0, age), color, true, -1.0, true)
	for blast in rocket_blasts:
		var position: Vector2 = blast.position
		if not visible_world.has_point(position):
			continue
		var age := clampf((elapsed - blast.born) / ROCKET_BLAST_DURATION, 0.0, 1.0)
		var fade := 1.0 - age
		draw_circle(position, 8.0 + age * 29.0, Color(1.0, 0.35, 0.13, 0.30 * fade), true, -1.0, true)
		draw_arc(position, 9.0 + age * 29.0, 0.0, TAU, 28, Color(1.0, 0.59, 0.26, 0.72 * fade), 2.0, true)
		draw_circle(position, 8.0 * fade, Color(1.0, 0.88, 0.63, fade), true, -1.0, true)

func _draw_aim_indicators(size: Vector2) -> void:
	if camera_zoom < MAP_LABEL_ZOOM or hyperjump_time >= 0.0 or (control_mode == 1 and not rts_attack_active):
		return
	if is_instance_valid(settings_layer) or is_instance_valid(hangar_layer) or get_viewport().gui_get_hovered_control() != null:
		return
	var pointer := get_viewport().get_mouse_position()
	if not Rect2(Vector2.ZERO, size).has_point(pointer):
		return
	var aim_position := _aim_world_position()
	var weapon: Dictionary = WEAPON_SLOTS[selected_weapon - 1]
	for part in cached_turret_mounts:
		var turret: String = part.turret
		if turret not in weapon.turrets:
			continue
		var color: Color = CRUISER_LASER_COLOR if turret == MODULES.CRUISER_MACHINE_LASER else weapon.color
		var origin := _turret_world_position(part)
		var direction := Vector2.from_angle(_turret_angle(part))
		var distance := origin.distance_to(aim_position)
		var start := _world_transform() * (origin + direction * 20.0)
		var tip := _world_transform() * (origin + direction * distance)
		var line_color := color
		line_color.a = 0.28
		draw_line(start, tip, line_color, 1.0, true)
		draw_arc(tip, 5.0, 0.0, TAU, 20, color, 1.5, true)

func _draw_mining_beams() -> void:
	if not mining:
		return
	var asteroid: Dictionary = asteroids[mining_asteroid]
	for part in custom_parts:
		if part.get("turret", "") != "miner" or not _turret_is_aimed(part, asteroid.position):
			continue
		var origin := _turret_world_position(part)
		var beam_start := origin + Vector2.from_angle(_turret_angle(part)) * MODULES.MINING_TURRET_MUZZLE_OFFSET
		var beam_direction: Vector2 = (asteroid.position - beam_start).normalized()
		var beam_end: Vector2 = asteroid.position - beam_direction * asteroid.radius * 0.75
		draw_line(beam_start, beam_end, Color(0.2, 0.8, 1.0, 0.25), 11.0, true)
		draw_line(beam_start, beam_end, Color(0.65, 0.96, 1.0, 0.95), 3.0, true)
		draw_circle(beam_end, 5.0 + sin(elapsed * 18.0) * 2.0, Color(0.8, 0.98, 1.0, 0.85))

func _turret_world_position(part: Dictionary) -> Vector2:
	_ensure_ship_cache()
	return ship_position + _turret_local_position(part).rotated(heading + PI / 2.0)

func _turret_local_position(part: Dictionary) -> Vector2:
	if part.has("local_position"):
		return part.local_position
	return Vector2(part.x, part.y) * MODULES.CELL - cached_ship_bounds.get_center()

func _boost_burst_envelope() -> float:
	if boost_time <= 0.0 or boost_duration <= 0.0:
		return 0.0
	var progress := 1.0 - boost_time / boost_duration
	return smoothstep(0.0, 0.24, progress) * (1.0 - smoothstep(0.68, 1.0, progress))

func _navigation_exhaust(course: Vector2, target_speed: float, alignment: float, delta: float) -> float:
	# Maintain a cruise flame at constant speed. Braking and lateral corrections
	# belong to the maneuvering thrusters and do not drive the aft bell.
	var braking_demand := (velocity.dot(course) - target_speed) / delta
	return alignment * smoothstep(8.0, 65.0, target_speed) * (1.0 - smoothstep(8.0, 80.0, braking_demand))

func _reset_player_exhaust() -> void:
	engine_throttle_target = 0.0
	engine_boost_target = 0.0
	engine_flame = 0.0
	engine_overdrive = 0.0

func _update_player_exhaust(delta: float) -> void:
	var flame_target := maxf(engine_throttle_target, engine_boost_target)
	var flame_rate := ENGINE_IGNITION_RATE if flame_target > engine_flame else ENGINE_FADE_RATE
	var boost_rate := ENGINE_IGNITION_RATE if engine_boost_target > engine_overdrive else ENGINE_FADE_RATE
	engine_flame = move_toward(engine_flame, flame_target, flame_rate * delta)
	engine_overdrive = move_toward(engine_overdrive, engine_boost_target, boost_rate * delta)

func _sustained_boost_active() -> bool:
	return (sustained_boost_enabled and sustained_boost_direction != Vector2.ZERO) or (hyperjump_time >= 0.0 and thrust > 0.1)

func _enemy_engine_power(enemy: Dictionary) -> float:
	return clampf((enemy.velocity as Vector2).length() / maxf(float(enemy.speed), 1.0), 0.2, 1.0)

func _update_exhaust_particles(delta: float) -> void:
	var remaining := 0
	for particle in exhaust_particles:
		if elapsed - particle.born < particle.lifetime:
			exhaust_particles[remaining] = particle
			remaining += 1
	exhaust_particles.resize(remaining)
	var player_pose := Transform2D(heading + PI / 2.0, ship_position)
	_update_engine_trails(cached_engines, player_pose, velocity, engine_flame, _sustained_boost_active())
	for enemy in enemies:
		_update_engine_trails(enemy.engines, Transform2D(float(enemy.heading) + PI / 2.0, enemy.position),
			enemy.velocity, _enemy_engine_power(enemy) if enemy.alive else 0.0)
	if camera_zoom < EXHAUST_PARTICLE_MIN_ZOOM:
		return
	var visible_world := _visible_world(_world_transform())
	_emit_exhaust_particles(cached_engines, player_pose, velocity, engine_flame, engine_overdrive, delta, visible_world)
	for enemy in enemies:
		if enemy.alive:
			_emit_exhaust_particles(enemy.engines, Transform2D(float(enemy.heading) + PI / 2.0, enemy.position),
				enemy.velocity, _enemy_engine_power(enemy), 0.0, delta, visible_world)

func _update_engine_trails(engines: Array[Dictionary], pose: Transform2D, ship_velocity: Vector2, power: float, sustained_boost: bool = false) -> void:
	for engine in engines:
		var trail: Array = engine.get("trail", [])
		while not trail.is_empty() and elapsed - float(trail[0].time) >= float(trail[0].get("lifetime", ENGINE_TRAIL_LIFETIME)):
			trail.pop_front()
		var active := power > 0.05 and ship_velocity.length_squared() > 400.0
		if active:
			var position: Vector2 = (pose * engine.nozzle) * Vector2(0.0, 8.0)
			engine.trail_head = position
			engine.trail_power = power
			var fresh_segment := not bool(engine.get("trail_active", false)) or (not trail.is_empty() and position.distance_to(trail[-1].position) > maxf(500.0, ship_velocity.length() * 0.3))
			if fresh_segment or trail.is_empty() or elapsed - float(trail[-1].time) >= ENGINE_TRAIL_INTERVAL - 0.00001:
				trail.append({
					"position": position, "time": elapsed, "power": power, "break_before": fresh_segment,
					"lifetime": BOOST_TRAIL_LIFETIME if sustained_boost else ENGINE_TRAIL_LIFETIME,
				})
		engine.trail = trail
		engine.trail_active = active

func _draw_engine_trails(canvas: CanvasItem, engines: Array[Dictionary]) -> void:
	for engine in engines:
		var trail: Array = engine.get("trail", [])
		var half_width: float = maxf(clampf(float(engine.size.x), 0.7, 2.0), minf(0.5 / camera_zoom, 4.0))
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for sample in trail:
			if sample.break_before:
				if points.size() >= 2:
					canvas.draw_polyline_colors(points, colors, half_width * 2.0, true)
				points.clear()
				colors.clear()
			var point: Vector2 = sample.position
			if not points.is_empty() and points[-1].distance_squared_to(point) < 0.01:
				continue
			var fade := pow(clampf(1.0 - (elapsed - float(sample.time)) / float(sample.get("lifetime", ENGINE_TRAIL_LIFETIME)), 0.0, 1.0), 1.5) * float(sample.power)
			points.append(point)
			colors.append(Color(1.0, 0.55, 0.22, 0.42 * fade))
		if bool(engine.get("trail_active", false)) and not points.is_empty():
			var head: Vector2 = engine.trail_head
			if points[-1].distance_squared_to(head) >= 0.01:
				points.append(head)
				colors.append(Color(1.0, 0.55, 0.22, 0.42 * float(engine.trail_power)))
		if points.size() >= 2:
			canvas.draw_polyline_colors(points, colors, half_width * 2.0, true)

func _emit_exhaust_particles(engines: Array[Dictionary], pose: Transform2D, ship_velocity: Vector2, power: float, boost: float, delta: float, visible_world: Rect2) -> void:
	if power <= 0.01:
		return
	var density := (24.0 + 22.0 * graphics_quality) * power * (1.0 + boost)
	for engine in engines:
		var nozzle: Transform2D = pose * engine.nozzle
		if not visible_world.has_point(nozzle.origin):
			continue
		var size: Vector2 = engine.size
		var width_scale := sqrt(size.x)
		var rate := density * width_scale * size.y
		var emission := float(engine.get("emission", 0.0)) + rate * delta
		var count := int(emission)
		engine.emission = emission - count
		for index in range(count):
			if exhaust_particles.size() >= EXHAUST_PARTICLE_LIMIT:
				return
			var age := (emission - index - 1.0) / rate
			var spread := exhaust_rng.randf_range(-1.0, 1.0)
			var spark := exhaust_rng.randf() < 0.45
			var speed := exhaust_rng.randf_range(305.0, 460.0) if spark else exhaust_rng.randf_range(130.0, 235.0)
			speed *= size.y * lerpf(0.70, 1.0, power) * (1.0 + boost * 0.85)
			var jet := nozzle.basis_xform(Vector2(spread * speed * (0.20 if spark else 0.28), speed))
			var particle := ExhaustParticle.new()
			# Each particle inherits the ship's motion and keeps its launch direction.
			particle.origin = nozzle * Vector2(spread * size.x * 4.0, 3.0) - ship_velocity * age
			particle.velocity = ship_velocity + jet
			particle.born = elapsed - age
			particle.lifetime = exhaust_rng.randf_range(0.18, 0.31) if spark else exhaust_rng.randf_range(0.25, 0.41)
			particle.radius = exhaust_rng.randf_range(1.3, 2.4) if spark else exhaust_rng.randf_range(3.0, 6.0)
			particle.radius *= lerpf(0.6, 1.0, size.y) * width_scale
			particle.opacity = lerpf(0.4, 1.0, power)
			if spark:
				particle.streak = jet * exhaust_rng.randf_range(0.020, 0.035)
			exhaust_particles.append(particle)

func _draw_exhaust_particles(canvas: CanvasItem) -> void:
	_draw_engine_trails(canvas, cached_engines)
	for enemy in enemies:
		_draw_engine_trails(canvas, enemy.engines)
	if camera_zoom < EXHAUST_PARTICLE_MIN_ZOOM:
		return
	var visible_world := _visible_world(_world_transform())
	for particle in exhaust_particles:
		var age := elapsed - particle.born
		var position := particle.origin + particle.velocity * age
		if not visible_world.has_point(position):
			continue
		var progress := clampf(age / particle.lifetime, 0.0, 1.0)
		var fade := (1.0 - progress) * particle.opacity
		if particle.streak != Vector2.ZERO:
			var color := EXHAUST_SPARK_HOT.lerp(EXHAUST_SPARK_COOL, progress)
			color.a = fade
			canvas.draw_line(position, position - particle.streak * (1.0 - progress), color, particle.radius, true)
		else:
			var color := EXHAUST_PLUME_HOT.lerp(EXHAUST_PLUME_COOL, progress)
			color.a = fade * lerpf(0.40, 0.10, progress)
			var radius := Vector2.ONE * particle.radius * lerpf(1.0, 3.6, progress)
			canvas.draw_texture_rect(engine_light_texture, Rect2(position - radius, radius * 2.0), false, color)

func _draw_engine_flare(canvas: CanvasItem, engine: Dictionary, power: float, phase: float, boost: float = 0.0) -> void:
	if power <= 0.01:
		return
	var size: Vector2 = engine.size
	var intensity := minf(power * 2.0, 1.0)
	var flicker := 0.94 + 0.08 * sin(elapsed * 27.0 + phase) + 0.04 * sin(elapsed * 49.0 + phase * 1.7)
	var width := (7.0 + 3.0 * power) * size.x * (1.0 + boost * 0.25)
	var length := (32.0 + 26.0 * power) * size.y * (1.0 + boost * 1.5) * flicker
	var center := Vector2(0.0, width * 0.45)
	canvas.draw_set_transform_matrix(engine.nozzle)
	# A broad, soft halo and fine rays frame the white-hot engine core.
	var halo := Vector2(width * 4.5, width * 4.5)
	canvas.draw_texture_rect(engine_light_texture, Rect2(center - halo, halo * 2.0), false, Color(1.0, 0.66, 0.31, 0.42 * intensity))
	var ray_length := width * 5.5 * flicker
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-ray_length, 0), center + Vector2(0, -width * 0.22),
		center + Vector2(ray_length, 0), center + Vector2(0, width * 0.22),
	]), Color(1.0, 0.82, 0.55, 0.20 * intensity))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.8, 0), Vector2(-width * 0.45, length * 0.26),
		Vector2(0, length), Vector2(width * 0.45, length * 0.26), Vector2(width * 0.8, 0),
	]), Color(1.0, 0.49, 0.15, 0.32 * intensity))
	var core_glow := Vector2(width * 1.7, width * 1.7)
	canvas.draw_texture_rect(engine_light_texture, Rect2(center - core_glow, core_glow * 2.0), false, Color(1.0, 0.91, 0.68, 0.9 * intensity))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(-width * 0.55, 0), Vector2(-width * 0.4, width * 1.1),
		Vector2(0, length * 0.38), Vector2(width * 0.4, width * 1.1), Vector2(width * 0.55, 0),
	]), Color(1.0, 0.98, 0.87, intensity))

func _draw_engine_exhaust(canvas: CanvasItem) -> void:
	for index in range(cached_engines.size()):
		var engine: Dictionary = cached_engines[index]
		if boost_charging:
			canvas.draw_set_transform_matrix(engine.nozzle)
			canvas.draw_circle(Vector2.ZERO, 5.0 + boost_charge * 8.0, Color(1.0, 0.59, 0.27, 0.12 + 0.18 * boost_charge))
		_draw_engine_flare(canvas, engine, engine_flame, float(index) * 2.7, engine_overdrive)

func _draw_machine_gun_flash(canvas: CanvasItem, center: Vector2, turret_angle: float, scale_factor: float, shot: Dictionary, is_long: bool, is_retro: bool = false) -> void:
	if shot.is_empty():
		return
	var strength := 1.0 - (elapsed - float(shot.fired_at)) / MACHINE_GUN_FLASH_DURATION
	if strength <= 0.0:
		return
	var muzzle := center + MODULES.machine_gun_muzzle_offset(shot.barrel, turret_angle, scale_factor, is_long, is_retro)
	var forward := Vector2.UP.rotated(turret_angle) * scale_factor
	var side := forward.orthogonal()
	var tip := muzzle + forward * (6.0 + 7.0 * strength)
	var shoulders := muzzle + forward * 3.0
	canvas.draw_colored_polygon(PackedVector2Array([muzzle, shoulders + side * 3.0, tip, shoulders - side * 3.0]), Color(1.0, 0.57, 0.23, strength))
	canvas.draw_colored_polygon(PackedVector2Array([muzzle, shoulders + side * 1.3, muzzle.lerp(tip, 0.65), shoulders - side * 1.3]), Color(1.0, 0.96, 0.75, strength))

func _cruiser_barrel_recoil(shot: Dictionary) -> float:
	var age := elapsed - float(shot.get("fired_at", -INF))
	return CRUISER_BARREL_RECOIL_DISTANCE * (1.0 - smoothstep(0.0, CRUISER_BARREL_RECOIL_DURATION, age))

func _draw_cruiser_laser_flash(canvas: CanvasItem, mount: Dictionary, turret_angle: float, shot: Dictionary) -> void:
	var age := elapsed - float(shot.fired_at)
	var strength := 1.0 - smoothstep(0.0, MACHINE_GUN_FLASH_DURATION, age)
	if strength <= 0.0:
		return
	var muzzle := _turret_local_position(mount) + MODULES.cruiser_laser_muzzle_offset(mount, shot.barrel, turret_angle, _cruiser_barrel_recoil(shot))
	var forward := Vector2.UP.rotated(turret_angle)
	canvas.draw_circle(muzzle, 10.0 * strength, Color(CRUISER_LASER_COLOR, strength * 0.35), true, -1.0, true)
	canvas.draw_line(muzzle, muzzle + forward * (7.0 + 12.0 * strength), Color(CRUISER_LASER_COLOR, strength), 4.0, true)
	canvas.draw_circle(muzzle, 3.0 * strength, Color(0.89, 1.0, 0.96, strength))

func _rocket_recoil(age: float) -> float:
	var kick := 1.0 - smoothstep(0.0, ROCKET_RECOIL_DURATION, age)
	return 6.0 * kick

func _draw_rocket_launch(canvas: CanvasItem, center: Vector2, turret_angle: float, scale_factor: float, age: float) -> void:
	if age >= ROCKET_FLASH_DURATION:
		return
	var fade := 1.0 - age / ROCKET_FLASH_DURATION
	var forward := Vector2.UP.rotated(turret_angle) * scale_factor
	var side := forward.orthogonal()
	var muzzle := center + forward * (MODULES.ROCKET_MUZZLE_OFFSET - _rocket_recoil(age))
	var base := muzzle + forward * 2.0
	canvas.draw_circle(muzzle, (7.0 + 7.0 * (1.0 - fade)) * scale_factor, Color(1.0, 0.51, 0.21, 0.32 * fade), true, -1.0, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		base - side * 5.0, base + forward * (10.0 + 8.0 * fade), base + side * 5.0,
	]), Color(1.0, 0.67, 0.35, fade))
	canvas.draw_circle(base, 3.5 * fade * scale_factor, Color(1.0, 0.94, 0.76, fade), true, -1.0, true)

func _draw_enemy_exhaust(canvas: CanvasItem, enemy: Dictionary) -> void:
	for engine in enemy.engines:
		_draw_engine_flare(canvas, engine, _enemy_engine_power(enemy), float(engine.phase))

func _draw_enemy_hull(canvas: CanvasItem, enemy: Dictionary, index: int) -> void:
	for module in enemy.exterior:
		MODULES.draw_part(canvas, module.part, module.offset, ENEMY_PART_SCALE)
		_draw_part_shield_glow(canvas, module.part, module.offset, enemy.dimensions, ENEMY_PART_SCALE, index)

func _draw_enemy_turrets(canvas: CanvasItem, enemy: Dictionary, index: int) -> void:
	var turret_angle := angle_difference(enemy.heading, enemy.aim_angle)
	for mount in enemy.turrets:
		var recoil := _rocket_recoil(elapsed - float(mount.get("rocket_launched_at", -INF)))
		MODULES.draw_mounted_turret(canvas, mount.part.turret, mount.offset, ENEMY_PART_SCALE, 1.0, Color.WHITE, turret_angle, recoil)
		_draw_part_shield_glow(canvas, mount.part, mount.offset, enemy.dimensions, ENEMY_PART_SCALE, index, true, turret_angle, recoil)

func _draw_enemy_effects(canvas: CanvasItem, enemy: Dictionary, index: int) -> void:
	var turret_angle := angle_difference(enemy.heading, enemy.aim_angle)
	for mount in enemy.turrets:
		if mount.has("machine_gun_shot"):
			_draw_machine_gun_flash(canvas, mount.offset, turret_angle, ENEMY_PART_SCALE, mount.machine_gun_shot, mount.part.turret == "long_machine_gun", mount.part.turret == "retro_machine_gun")
		if mount.has("rocket_launched_at"):
			_draw_rocket_launch(canvas, mount.offset, turret_angle, ENEMY_PART_SCALE, elapsed - float(mount.rocket_launched_at))
	_draw_shield_impacts(index, enemy.dimensions, canvas)
	_draw_hull_impacts(index, canvas)
	if selected_enemy == index:
		# Target bars stay upright while the ship rotates.
		canvas.draw_set_transform(Vector2.ZERO, -float(enemy.heading) - PI / 2.0)
		var marker_radius := float(enemy.radius) + 16.0
		var marker_color := HOSTILE_SHIP_COLOR if enemy.hostile else NEUTRAL_SHIP_COLOR
		canvas.draw_arc(Vector2.ZERO, marker_radius, 0, TAU, 48, marker_color, 2.0, true)
		var bar_position := Vector2(-35, -marker_radius - 26.0)
		if enemy.max_shield > 0.0:
			canvas.draw_rect(Rect2(bar_position, Vector2(70, 5)), Color(0.03, 0.07, 0.12, 0.9))
			canvas.draw_rect(Rect2(bar_position, Vector2(70.0 * enemy.shield / enemy.max_shield, 5)), Color("58b6ff"))
		bar_position.y += 9.0
		canvas.draw_rect(Rect2(bar_position, Vector2(70, 5)), Color(0.12, 0.03, 0.03, 0.9))
		canvas.draw_rect(Rect2(bar_position, Vector2(70.0 * enemy.health / enemy.max_health, 5)), Color("f27065"))

func _draw_custom_ship(canvas: CanvasItem) -> void:
	var center := cached_ship_bounds.get_center()
	for index in range(custom_parts.size()):
		var part: Dictionary = custom_parts[index]
		if not MODULES.is_exterior_structure(part):
			continue
		var position := Vector2(part.x, part.y) * MODULES.CELL - center
		MODULES.draw_part(canvas, part, position, 1.0, 1.0, Color.WHITE, 1.0, true)
		if cached_armour_borders.has(index):
			MODULES.draw_armour_border(canvas, cached_armour_borders[index], -center)
		_draw_part_shield_glow(canvas, part, position, cached_ship_bounds.size, 1.0, -1)
	for index in cached_armour_borders:
		var panel: Dictionary = custom_parts[index]
		if not MODULES.is_armour_overlay(panel):
			continue
		var position := Vector2(panel.x, panel.y) * MODULES.CELL - center
		MODULES.draw_part(canvas, panel, position)
		MODULES.draw_armour_border(canvas, cached_armour_borders[index], -center)
		_draw_part_shield_glow(canvas, panel, position, cached_ship_bounds.size, 1.0, -1)

func _draw_player_details(canvas: CanvasItem) -> void:
	var center := cached_ship_bounds.get_center()
	for detail in custom_parts:
		if detail.type == "preset_light_gunship":
			MODULES.draw_light_gunship_beacon(canvas, detail, Vector2(detail.x, detail.y) * MODULES.CELL - center, MODULES.navigation_light_brightness(elapsed))
		if MODULES.is_decoration(detail):
			var brightness := MODULES.navigation_light_brightness(elapsed) if detail.type == "navigation_lights" else 1.0
			MODULES.draw_part(canvas, detail, Vector2(detail.x, detail.y) * MODULES.CELL - center, 1.0, 1.0, Color.WHITE, brightness)
	for part in cached_turret_mounts:
		var key := _turret_key(part)
		var position := _turret_local_position(part)
		var turret_angle := _turret_angle(part) - heading
		if part.turret == MODULES.CRUISER_MACHINE_LASER:
			var shot: Dictionary = player_machine_gun_shots.get(key, {})
			MODULES.draw_cruiser_turret(canvas, part, turret_angle, int(shot.get("barrel", -1)), _cruiser_barrel_recoil(shot))
			continue
		var recoil := _rocket_recoil(elapsed - float(player_rocket_launches.get(key, -INF)))
		MODULES.draw_mounted_turret(canvas, part.turret, position, 1.0, 1.0, Color.WHITE, turret_angle, recoil)
		_draw_part_shield_glow(canvas, part, position, cached_ship_bounds.size, 1.0, -1, true, turret_angle, recoil)

func _draw_part_shield_glow(canvas: CanvasItem, part: Dictionary, position: Vector2, dimensions: Vector2, part_scale: float, enemy_index: int, mounted_turret: bool = false, turret_angle: float = 0.0, recoil: float = 0.0) -> void:
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
			var tint := Color(0.32, 0.75, 1.0)
			if mounted_turret:
				MODULES.draw_mounted_turret(canvas, part.turret, position, part_scale, strength, tint, turret_angle, recoil)
			else:
				MODULES.draw_part(canvas, part, position, part_scale, strength, tint, 1.0, enemy_index == -1)

func _draw_hyperjump_bow(canvas: CanvasItem) -> void:
	var jump_speed := HYPERJUMP_TRAVEL_SPEED * float(_current_ship().speed)
	var intensity := smoothstep(0.03, 0.55, velocity.length() / maxf(jump_speed, 1.0))
	if intensity <= 0.001:
		return
	var half_width := maxf(12.0, cached_ship_bounds.size.x * 0.5)
	var nose_y := -cached_ship_bounds.size.y * 0.5
	var flicker := 0.85 + 0.15 * sin(elapsed * 17.0)
	var tip := Vector2(0.0, nose_y - 3.0)
	for layer in range(4, 0, -1):
		var radius := half_width * (0.25 + float(layer) * 0.17)
		canvas.draw_circle(tip, radius, Color(1.0, 0.29 + 0.08 * (4 - layer), 0.08, 0.045 * intensity * flicker), true, -1.0, true)
	for wave in range(3):
		var phase := fposmod(elapsed * 0.85 + float(wave) / 3.0, 1.0)
		var width := half_width * (0.55 + 0.45 * phase)
		var reach := half_width * (0.24 + 0.65 * phase)
		var points := PackedVector2Array()
		for segment in range(25):
			var x := float(segment) / 12.0 - 1.0
			points.append(Vector2(x * width, nose_y + half_width * 0.12 - reach * (1.0 - x * x)))
		var opacity := intensity * (1.0 - phase) * flicker
		canvas.draw_polyline(points, Color(1.0, 0.28, 0.07, opacity * 0.25), 6.0, true)
		canvas.draw_polyline(points, Color(1.0, 0.75, 0.38, opacity * 0.8), 1.5, true)

func _draw_player_effects(canvas: CanvasItem) -> void:
	if hyperjump_time >= 0.0:
		_draw_hyperjump_bow(canvas)
	if not player_machine_gun_shots.is_empty() or not player_rocket_launches.is_empty():
		for part in cached_turret_mounts:
			var key := _turret_key(part)
			var position := _turret_local_position(part)
			var turret_angle := _turret_angle(part) - heading
			if player_machine_gun_shots.has(key):
				var shot: Dictionary = player_machine_gun_shots[key]
				if part.turret == MODULES.CRUISER_MACHINE_LASER:
					_draw_cruiser_laser_flash(canvas, part, turret_angle, shot)
				else:
					_draw_machine_gun_flash(canvas, position, turret_angle, 1.0, shot, part.turret == "long_machine_gun", part.turret == "retro_machine_gun")
			if player_rocket_launches.has(key):
				_draw_rocket_launch(canvas, position, turret_angle, 1.0, elapsed - float(player_rocket_launches[key]))
	_draw_shield_impacts(-1, cached_ship_bounds.size, canvas)
	_draw_hull_impacts(-1, canvas)

func _draw_sector_labels(camera: Transform2D) -> void:
	var font := ThemeDB.fallback_font
	var viewport := get_viewport_rect()
	var opacity := 1.0 - smoothstep(MAP_LABEL_ZOOM * 0.5, MAP_LABEL_ZOOM, camera_zoom)
	for system: Dictionary in SOLAR_SYSTEM.SYSTEMS:
		var center := camera * (system.center as Vector2)
		var radius := maxf(6.0, system.radius * camera_zoom)
		if not viewport.grow(radius + 40.0).has_point(center):
			continue
		var label := str(system.name).to_upper()
		if system.kind == SOLAR_SYSTEM.BodyKind.BLUE_DWARF:
			label += "  /  BLUE DWARF"
		var label_color := Color(system.color, opacity)
		if system.radius * camera_zoom < 6.0:
			draw_circle(center, 3.0, label_color, true, -1.0, true)
		draw_line(center + Vector2(0, radius + 5.0), center + Vector2(0, radius + 20.0), label_color.darkened(0.35), 1.0, true)
		draw_string(font, center + Vector2(-90.0, radius + 36.0), label, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 14, label_color)

func _draw_hud(size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(30, 17), "FPS  %d" % Engine.get_frames_per_second(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d9f0fb"))
	draw_rect(Rect2(Vector2(size.x / 2.0 - 120.0, 24.0), Vector2(240.0, 54.0)), Color(0.025, 0.06, 0.1, 0.88))
	draw_string(font, Vector2(size.x / 2.0 - 110.0, 47.0), "WAVE %d" % wave_number, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 16, Color("e4f5ff"))
	var map_rect := Rect2(Vector2(30, 30), Vector2(240, 168))
	draw_rect(map_rect.grow(8), Color(0.025, 0.06, 0.1, 0.88))
	draw_rect(map_rect, Color(0.05, 0.11, 0.16, 0.95))
	for i in range(1, 4):
		var x := map_rect.position.x + map_rect.size.x * i / 4.0
		var y := map_rect.position.y + map_rect.size.y * i / 4.0
		draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.3, 0.55, 0.65, 0.2))
		draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.3, 0.55, 0.65, 0.2))
	draw_rect(map_rect, Color(0.35, 0.65, 0.75, 0.6), false, 1.0)
	var nearby_system := solar_system.nearest_system(ship_position)
	var chart_bounds := SOLAR_SYSTEM.WORLD_BOUNDS
	var chart_scale := _fit_chart(map_rect.size, chart_bounds) * 0.87
	var chart := Transform2D(0.0, Vector2.ONE * chart_scale, 0.0, map_rect.get_center() - chart_bounds.get_center() * chart_scale)
	solar_system.draw_minimap(self, chart)
	for i in range(fleet.size()):
		if i != active_fleet_index and chart_bounds.has_point(fleet[i].position):
			draw_circle(chart * fleet[i].position, 3.0, Color("87e5bf"))
	var view_size := size / camera_zoom
	var camera_view := Rect2(_camera_center() - view_size * 0.5, view_size).intersection(chart_bounds)
	if camera_view.has_area():
		var view_marker_size := (camera_view.size * chart_scale).max(Vector2.ONE * 4.0)
		draw_rect(Rect2(chart * camera_view.get_center() - view_marker_size * 0.5, view_marker_size), Color(0.48, 0.78, 0.91, 0.7), false, 1.0)
	var map_hint := "SCROLL ZOOM  ·  SHIFT-DRAG PAN  ·  F CENTER SHIP"
	if hyperjump_time < 0.0:
		draw_string(font, Vector2(30, 221), map_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6cbdc"))
	draw_string(font, Vector2(30, 241), "ZOOM OUT AND RIGHT-CLICK A SYSTEM TO JUMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6cbdc"))
	var neutral_count := 0
	var hostile_count := 0
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		if not enemy.alive:
			continue
		if enemy.hostile:
			hostile_count += 1
		else:
			neutral_count += 1
		if chart_bounds.has_point(enemy.position):
			var marker_color := HOSTILE_SHIP_COLOR if enemy.hostile else NEUTRAL_SHIP_COLOR
			draw_circle(chart * enemy.position, 3.5 if i == selected_enemy else 2.5, marker_color)
	var wave_status := "%d NEUTRAL  ·  %d HOSTILE" % [neutral_count, hostile_count]
	if enemy_wave_timer >= 0.0:
		wave_status = "NEXT WAVE IN %d" % int(ceil(enemy_wave_timer))
	draw_string(font, Vector2(size.x / 2.0 - 110.0, 67.0), wave_status, HORIZONTAL_ALIGNMENT_CENTER, 220.0, 11, Color("91aebe"))
	if hyperjump_time >= 0.0 or elapsed < hyperjump_arrival_until:
		var navigation_text := "Arrived in %s" % SOLAR_SYSTEM.SYSTEMS[nearby_system].name
		if hyperjump_time >= 0.0:
			navigation_text = "Hyperjump to %s" % SOLAR_SYSTEM.SYSTEMS[hyperjump_destination].name
		var navigation_position := Vector2(size.x * 0.5 - 170.0, 92.0)
		draw_rect(Rect2(navigation_position, Vector2(340.0, 38.0)), Color("102434"))
		draw_string(font, navigation_position + Vector2(0.0, 25.0), navigation_text, HORIZONTAL_ALIGNMENT_CENTER, 340.0, 16, HYPERJUMP_COLOR)
	if chart_bounds.has_point(ship_position):
		var player_on_map := chart * ship_position
		if hyperjump_time >= 0.0:
			draw_dashed_line(player_on_map, chart * hyperjump_arrival, Color(HYPERJUMP_COLOR, 0.55), 1.0, 4.0)
		var forward := Vector2.from_angle(heading)
		var side := forward.orthogonal()
		draw_colored_polygon(PackedVector2Array([player_on_map + forward * 7.0, player_on_map - forward * 5.0 + side * 4.0, player_on_map - forward * 5.0 - side * 4.0]), Color("e0f9ff"))
	var controls_text := "WASD FLY  ·  1 LASER  3 GUN  4 ROCKET  5 RAILGUN  ·  LEFT CLICK FIRE  ·  RIGHT CLICK / TAB TARGET  ·  SPACE BOOST  ·  MIDDLE CLICK COMMANDS"
	if control_mode == 1:
		controls_text = "WASD PAN CAMERA  ·  SPACE RECENTER  ·  SELECT SHIP, CLICK TO MOVE OR ATTACK  ·  1 LASER  3 GUN  4 ROCKET  5 RAILGUN  ·  MIDDLE CLICK COMMANDS"
	if sustained_boost_enabled:
		controls_text = "BOOST  ·  CLICK A DESTINATION  ·  MIDDLE CLICK FOR COMMANDS"
		controls_text += "  ·  SPACE TO EXIT" if control_mode == 0 else "  ·  EXIT BOOST TO RETURN TO NORMAL FLIGHT"
	if hyperjump_time >= 0.0:
		controls_text = "HYPER JUMP IN PROGRESS  ·  SCROLL TO ZOOM  ·  SHIFT-DRAG TO PAN"
	draw_string(font, Vector2(30, size.y - 35), controls_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("91aebe"))
	if hyperjump_time < 0.0:
		var charge_position := Vector2(30, size.y - 205)
		var boost_label := "HOLD SPACE FOR BOOST  ·  RELEASE EARLY FOR A BURST" if has_flight_controls else "FLIGHT OFFLINE  ·  CHOOSE A SHIP IN THE HANGAR"
		if control_mode == 1 and has_flight_controls:
			boost_label = "RTS COMMAND MODE"
		if sustained_boost_enabled:
			boost_label = "BOOST  ·  CLICK TO CHANGE DESTINATION" if boost_destination_active else "BOOST  ·  CLICK A DESTINATION"
		draw_string(font, charge_position + Vector2(0, -6), boost_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("a6bce8") if has_flight_controls else Color("ffb58c"))
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
	var weapon_name: String = WEAPON_SLOTS[selected_weapon - 1].name
	var weapon_color := Color("ffd078")
	if selected_weapon == 3 and cached_turret_mounts.any(func(mount: Dictionary) -> bool: return mount.turret == MODULES.CRUISER_MACHINE_LASER):
		weapon_name = "MACHINE LASER"
		weapon_color = CRUISER_LASER_COLOR
	draw_string(font, Vector2(size.x - 235, 170), "WEAPON %d: %s" % [selected_weapon, weapon_name], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, weapon_color)
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

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

const COMBAT_CONTROLLER := preload("res://scripts/combat_controller.gd")
const MINING_CONTROLLER := preload("res://scripts/mining_controller.gd")
const GAME_INPUT := preload("res://scripts/game_input.gd")
const GAME_HUD := preload("res://scripts/game_hud.gd")
const FLIGHT_NAVIGATION := preload("res://scripts/flight_navigation.gd")
const FLEET_AVOIDANCE := preload("res://scripts/ships/fleet_avoidance.gd")
const PROJECTILE_GEOMETRY := preload("res://scripts/projectile_geometry.gd")
const ASTEROID_FACTORY := preload("res://scripts/asteroid_factory.gd")
const ROCKET_PROJECTILE := preload("res://scripts/rocket_projectile.gd")
const SOLAR_SYSTEM := preload("res://scripts/solar_system.gd")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const SAVES := preload("res://scripts/galaxy_saves.gd")
const HOME_MENU := preload("res://scripts/home_menu.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const LOADOUT := preload("res://scripts/ship_loadout.gd")
const HANGAR := preload("res://scripts/hangar.gd")
const SHIP_LIBRARY := preload("res://scripts/ship_design_library.gd")
const SETTINGS_MENU := preload("res://scripts/settings_menu.gd")
const KEY_BINDINGS := preload("res://scripts/key_bindings.gd")
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
const ENEMY_SHIPS_ENABLED := false
const ENEMY_SPEED := 270.0
const ENEMY_ACCELERATION := 390.0
const ENEMY_PART_SCALE := 0.75
const ENEMY_MIN_COMBAT_RANGE := 320.0
const ENEMY_PREFERRED_RANGE := 460.0
const ENEMY_FIRE_RANGE := 650.0
const NEUTRAL_SHIP_COLOR := Color("9bbfd0")
const HOSTILE_SHIP_COLOR := Color("ff7668")
const DISPLAY_SPEED_SCALE := 100.0
const DISPLAY_KM_SPEED_UNIT := MODULES.WORLD_UNITS_PER_METER * 1000.0 / DISPLAY_SPEED_SCALE
const BOOST_TRAVEL_SPEED := 6141.25
const BOOST_TRAVEL_ACCELERATION := 6200.0
const HYPERJUMP_COLOR := Color("9ee9ff")
const HYPERJUMP_TRAVEL_SPEED := 25500.0
const HYPERJUMP_ACCELERATION_SECONDS := 8.0
const FLEET_JUMP_INTERVAL := 0.5
const JUMP_FINAL_APPROACH_RANGE := 600.0
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
const CAMERA_ZOOM_STEP := 1.28
const CAMERA_PAN_SPEED := 700.0
const CAMERA_MAX_SHIP_SCREEN_FRACTION := 0.25
const MAP_LABEL_ZOOM := 0.004
# Keep every star name visible until systems are packed closer than this on screen.
const ALL_STAR_NAMES_SEPARATION := 70.0
const DISTANT_MAP_ZOOM_FACTOR := 0.4
# Gameplay positions are kept local to a floating origin so close-up flight stays
# smooth even when the galaxy spans hundreds of millions of world units.
const REBASE_RADIUS := 750000.0
const STAR_PARALLAX_FULL_ZOOM := 0.12
const RTS_DOCKING_DISTANCE := 24.0
const RTS_APPROACH_RATE := 0.9
const TRAVEL_APPROACH_RATE := 1.6
const BOOST_FINAL_APPROACH_DISTANCE := 300.0
const BOOST_ARRIVAL_RADIUS := 4.0
const BOOST_ARRIVAL_SPEED := 5.0
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
const ROCKET_IGNITION_DELAY := ROCKET_PROJECTILE.IGNITION_DELAY
const ROCKET_TAIL_OFFSET := ROCKET_PROJECTILE.TAIL_OFFSET
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
var combat_controller = COMBAT_CONTROLLER.new(self)
var game_input = GAME_INPUT.new(self)
var game_hud = GAME_HUD.new(self)

const SHIP_STATE := preload("res://scripts/ships/ship_state.gd")
const SHIP_VERSIONS := preload("res://scripts/ships/ship_version_catalog.gd")
const SHIP_REGISTRY := preload("res://scripts/ships/ship_registry.gd")
const SHIP_SIMULATION := preload("res://scripts/ships/ship_simulation.gd")
const SHIP_CAPABILITIES := preload("res://scripts/ships/ship_capabilities.gd")
const SHIP_ORDER := preload("res://scripts/ships/ship_order.gd")
const SHIP_ORDER_QUEUE := preload("res://scripts/ships/ship_order_queue.gd")
const SHIP_ORDER_CONTROLLER := preload("res://scripts/ships/ship_order_controller.gd")
const FLEET_ORDER_PANEL := preload("res://scripts/fleet_order_panel.gd")
var order_controller := SHIP_ORDER_CONTROLLER.new()
var active_order_hold := false
var autonomous_mining_target := false
var order_status_label: Label
var order_notice_until_usec := 0
var fleet_order_list_dirty := false
var fleet_detail_refresh_usec := 0
var order_target_request := {}
const FLEET_COLLIDER_RANGE := 32000.0
const FLEET_COLLIDER_EXIT_RANGE := 40000.0
const FLEET_HULL_MIN_PIXELS := 7.0
const FLEET_HULL_FULL_PIXELS := 16.0
const FLEET_VISUAL_MARGIN := 32.0
var ship_registry := SHIP_REGISTRY.new()
var fleet: Array[Dictionary]:
	get: return ship_registry.ships
var fleet_views: Dictionary = {}
var fleet_colliders: Dictionary = {}
var active_fleet_index := 0
var fleet_visuals: Node2D
var fleet_dialog: AcceptDialog
var fleet_list: ItemList
var fleet_orders: FLEET_ORDER_PANEL
var fleet_designs: OptionButton
var fleet_status: Label
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
var rts_selected := false
var selected_fleet: Array[int] = []
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
var hyperjump_context_button: Button
var hyperjump_context_destination := -1
var hyperjump_arrival_until := 0.0
var hyperjump_time := -1.0
var hyperjump_destination := -1
var hyperjump_arrival := Vector2.ZERO
var hyperjump_galaxy_target := PackedFloat64Array()
var hyperjump_distance := 0.0
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
var galaxy_cloud: ColorRect
var solar_system: SOLAR_SYSTEM
var home_layer: CanvasLayer
var home_menu: HOME_MENU
var game_started := false
var world_size := Vector2.ZERO
# Temporary steering waypoints; order destinations remain unchanged.
var fleet_detours := {}
var galaxy_origin := PackedFloat64Array([0.0, 0.0])
var world_origin: Vector2:
	get: return Vector2(galaxy_origin[0], galaxy_origin[1])
var galaxy_name := ""
var save_slot := ""
var ship_version_catalog: Dictionary = {}
var galaxy_seed := 0
var asteroid_system := -1
var depleted_ore := {}
var live_rocks := {}
var order_rocks := {}
var asteroid_visuals: Node2D
var asteroid_effects: Node2D
var enemy_visuals: Node2D
var debris_visual: Node2D
var exhaust_particles_visual: Node2D
var exhaust_particles: Array[ExhaustParticle] = []
var exhaust_rng := RandomNumberGenerator.new()
var player_visual: ShipVisual
var player_fleet_body: CharacterBody2D
var custom_parts: Array = []
var ship_cache_ready := false
var cached_ship_stats: Dictionary = {}
var cached_ship_bounds := Rect2()
var cached_ship_scale := 1.0
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
var boost_time := 0.0
var boost_duration := 0.0
var boost_power := 0.0
var stars: Array[Dictionary] = []
var starfield_camera_center := Vector2.ZERO
var starfield_offset := Vector2.ZERO
var rng := RandomNumberGenerator.new()
const SIMULATION_CLOCK := preload("res://scripts/simulation/simulation_clock.gd")
const SIMULATION_SCHEDULER := preload("res://scripts/simulation/simulation_scheduler.gd")
var simulation_clock := SIMULATION_CLOCK.new()
var simulation_scheduler := SIMULATION_SCHEDULER.new()
var elapsed: float:
	get: return simulation_clock.elapsed
var play_time := 0.0
var simulation_rate_control: OptionButton
var simulation_calendar: Label
var calendar_dirty := true
var flight_redraw_pending := false
var last_render_usec := 0
var rate_sample_usec := 0
var rate_sample_seconds := 0.0
var achieved_rate := 0.0
var changed_physics_cadence := false
var asteroids: Array[Dictionary] = []
var selected_asteroid := -1
var mining_asteroid := -1
var mining := false
var iron := 0
var mining_progress := 0.0
var camera_zoom := 0.25
var camera_zoom_target := camera_zoom
var camera_zoom_focus := Vector2.ZERO
# Panned camera positions stay precise even outside the local physics region.
var camera_galaxy_position := PackedFloat64Array([0.0, 0.0])
var camera_following := true
var camera_ship_index := 0
var camera_dragging := false
var graphics_quality := 2
var frame_cap := 0
var vsync_enabled := false
var graphics_settings_path := "user://graphics_settings.cfg"
var engine_light_texture: GradientTexture2D
var engine_audio := ROCKET_ENGINE_AUDIO.new()
@onready var heritage_gun_audio: AudioStreamPlayer = $HeritageGunAudio

func _ready() -> void:
	set_physics_process(false)
	set_process_unhandled_input(false)
	_load_graphics_settings()
	engine_audio.name = "RocketEngineAudio"
	add_child(engine_audio)
	home_layer = CanvasLayer.new()
	home_layer.layer = 10
	add_child(home_layer)
	home_menu = HOME_MENU.new()
	home_menu.settings_requested.connect(_open_settings)
	home_menu.new_game_requested.connect(_start_new_game)
	home_menu.load_game_requested.connect(_load_game)
	home_layer.add_child(home_menu)

func _start_new_game(title: String, galaxy: Dictionary, contents: Dictionary) -> void:
	if is_instance_valid(hangar_layer):
		return
	home_menu.set_process_unhandled_input(false)
	_create_ship_editor([], "Back to galaxy setup", func(parts: Array):
		_close_hangar(false)
		galaxy_name = title
		save_slot = SAVES.new_id()
		_start_flight(galaxy, contents, {}, parts)
		if not _save_galaxy():
			call_deferred("_show_save_error")
	)

func _load_game(slot_id: String) -> void:
	var state := SAVES.read(slot_id)
	if state.is_empty() or not _valid_flight_save(state):
		home_menu.set_error("This save could not be loaded. Select another galaxy or start a new game.")
		return
	galaxy_name = state.name
	save_slot = slot_id
	var arms := int(state.get("arms", GALAXY.DEFAULT_ARMS))
	var galaxy := GALAXY.create_map(state.seed, state.count, state.generator_version, arms)
	_start_flight(galaxy, {}, state)
	SAVES.mark_recent(save_slot)

func _valid_flight_save(state: Dictionary) -> bool:
	var ships: Variant = state.get("fleet")
	var format := int(state.get("format_version", 1))
	var current := format >= 3
	if not ships is Array or ships.is_empty() or not SHIP_VERSIONS.valid(state.get("ship_versions", {})):
		return false
	if current:
		if not SHIP_STATE.valid_point(state.get("galaxy_origin")) or not state.get("active_ship_id") is String \
			or not state.get("next_ship_id") is int or state.next_ship_id < 1:
			return false
	else:
		var index: Variant = state.get("active_ship")
		var origin: Variant = state.get("world_origin")
		if not index is int or index < 0 or index >= ships.size() or (origin != null and not SHIP_STATE.finite_vector(origin)):
			return false
	var ids := {}
	for ship in ships:
		if not ship is Dictionary or not ship.get("name") is String or not ship.get("parts") is Array:
			return false
		if MODULES.validate(ship.parts, false, false) != "":
			return false
		if not ship.get("admin", {}) is Dictionary or (current and not ship.has("admin")):
			return false
		var legacy_versions: Variant = ship.get("admin_versions", {})
		if not legacy_versions is Dictionary:
			return false
		for design_id in legacy_versions:
			if not design_id is String or not SHIP_VERSIONS.valid_versions(legacy_versions[design_id]):
				return false
		if current:
			if not SHIP_STATE.valid(ship, state.count) or ids.has(ship.id):
				return false
			if format >= 4 and not SHIP_ORDER_QUEUE.valid(ship, state.count):
				return false
			ids[ship.id] = true
		elif not SHIP_STATE.finite_vector(ship.get("position")):
			return false
		for property in ["heading", "hull", "shield", "shield_delay"]:
			if not SHIP_STATE.finite_number(ship.get(property)):
				return false
	return not current or ids.has(state.active_ship_id)

func _start_flight(galaxy: Dictionary, contents: Dictionary, state: Dictionary, launch_parts: Array = []) -> void:
	if state.is_empty() and MODULES.validate(launch_parts) != "":
		return
	home_menu.hide()
	home_layer.queue_free()
	game_started = true
	galaxy_seed = galaxy.seed
	world_size = galaxy.world_size
	fleet_detours.clear()
	if SHIP_STATE.valid_point(state.get("galaxy_origin")):
		galaxy_origin = state.galaxy_origin
	elif SHIP_STATE.finite_vector(state.get("world_origin")):
		galaxy_origin = SHIP_STATE.absolute(galaxy_origin, state.world_origin)
	elif state.is_empty():
		# The origin moves in double precision; only scene projections are Vector2.
		galaxy_origin = SHIP_STATE.absolute(galaxy_origin, galaxy.systems[0].center)
		if GALAXY.is_wide_version(galaxy.generator_version):
			galaxy_origin = SHIP_STATE.absolute(galaxy_origin, GALAXY.starter_offset(GALAXY.VERSION))
	rng.randomize()
	player_fleet_body = CharacterBody2D.new()
	player_fleet_body.collision_layer = FLEET_COLLISION_LAYER
	player_fleet_body.collision_mask = FLEET_COLLISION_LAYER
	add_child(player_fleet_body)
	solar_system = SOLAR_SYSTEM.new()
	solar_system.configure(galaxy, contents)
	solar_system.set_origin(galaxy_origin[0], galaxy_origin[1])
	_create_flight_visuals()
	_create_top_controls()
	if state.is_empty():
		custom_parts = launch_parts.duplicate(true)
		ship_cache_ready = false
		ship_position = solar_system.starting_position()
		player_hull = _player_max_hull()
		player_shield = _player_max_shield()
		_register_ship({"name": "Ship 1", "parts": custom_parts, "position": ship_position, "heading": heading,
			"hull": player_hull, "shield": player_shield, "shield_delay": player_shield_delay})
	else:
		_restore_flight(state)
	_select_fleet_ship(active_fleet_index)
	camera_ship_index = active_fleet_index
	_ensure_ship_cache()
	_sync_fleet_colliders()
	_set_camera_zoom(_maximum_camera_zoom())
	_load_asteroids_near_ship()
	starfield_camera_center = _camera_center()
	if ENEMY_SHIPS_ENABLED:
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
	get_viewport().size_changed.connect(func():
		_set_camera_zoom(camera_zoom)
		_queue_flight_redraw()
	)
	simulation_scheduler.repeat(1.0, elapsed, _mark_calendar_dirty)
	last_render_usec = Time.get_ticks_usec()
	_sync_simulation_driver()
	_refresh_simulation_controls()
	set_process_unhandled_input(true)
	_queue_flight_redraw()

func _restore_flight(state: Dictionary) -> void:
	ship_version_catalog = SHIP_VERSIONS.restore(state)
	if state.has("active_ship_id"):
		for record: Dictionary in state.fleet:
			ship_registry.add(SHIP_STATE.snapshot(record))
			if record.id == state.active_ship_id:
				active_fleet_index = fleet.size() - 1
		ship_registry.next_id = state.next_ship_id
	else:
		for record: Dictionary in state.fleet:
			_register_ship(record)
		active_fleet_index = state.active_ship
		var legacy: Dictionary = fleet[active_fleet_index]
		legacy.cargo = {"iron": maxi(0, int(state.get("iron", 0))), "tritium": maxi(0, int(state.get("tritium", 0)))}
		if SHIP_STATE.finite_vector(state.get("velocity")):
			legacy.velocity = state.velocity
			legacy.navigation.mode = "drift" if legacy.velocity != Vector2.ZERO else "idle"
		var jump: Variant = state.get("jump")
		if jump is Dictionary and SHIP_STATE.finite_vector(jump.get("arrival")):
			var destination := int(jump.get("destination", -1))
			if destination >= 0 and destination < solar_system.systems.size():
				var distance: Variant = jump.get("distance", 0.0)
				legacy.navigation = {"mode": "jump", "target": SHIP_STATE.absolute(galaxy_origin, jump.arrival.clamp(_world_min(), _world_max())),
					"system": destination, "distance": maxf(0.0, float(distance)) if SHIP_STATE.finite_number(distance) else 0.0, "time": 0.0}
	for ship in fleet:
		_prepare_fleet_stats(ship)
		if state.has("format_version") and int(state.format_version) < 4:
			_migrate_navigation_order(ship)
	_load_active_ship_state(fleet[active_fleet_index])
	if SIMULATION_CLOCK.valid_snapshot(state.get("clock")):
		simulation_clock.restore(state.clock)
	play_time = SAVES.play_seconds(state)
	if state.get("ore_remaining") is Dictionary:
		depleted_ore = state.ore_remaining

func _migrate_navigation_order(ship: Dictionary) -> void:
	var nav: Dictionary = ship.navigation
	var systems := solar_system.systems.size()
	if nav.mode == "move":
		SHIP_ORDER_QUEUE.submit(ship, "move", nav.target, 0.0, false, true, systems)
	elif nav.mode == "jump" and SHIP_ORDER_QUEUE.submit(ship, "hyperjump", nav.system, 0.0, false, true, systems):
		var order: Dictionary = ship.orders[0]
		order.state = "running"
		order.stage = "jump"
		order.progress = {"travel_target": nav.target, "jump_distance": nav.distance}

func _save_galaxy() -> bool:
	_save_active_fleet_ship()
	var saved_ships: Array[Dictionary] = []
	for ship in fleet:
		saved_ships.append(SHIP_STATE.snapshot(ship))
	var state := {"name": galaxy_name, "seed": galaxy_seed, "count": solar_system.systems.size(), "fleet": saved_ships,
		"generator_version": solar_system.galaxy.generator_version, "active_ship_id": fleet[active_fleet_index].id,
		"next_ship_id": ship_registry.next_id, "clock": simulation_clock.snapshot(), "play_time": play_time,
		"ore_remaining": depleted_ore, "galaxy_origin": galaxy_origin, "ship_versions": ship_version_catalog}
	if GALAXY.is_wide_version(solar_system.galaxy.generator_version):
		state.arms = int(solar_system.galaxy.spiral.get("arms", GALAXY.DEFAULT_ARMS))
	var saved := SAVES.write(save_slot, state)
	if saved:
		SAVES.mark_recent(save_slot)
	return saved

func _show_save_error() -> void:
	_open_settings()
	settings_layer.get_child(0).set_save_status("Could not save this galaxy. Try Save game again.")

func _save_from_settings(return_home: bool) -> void:
	if not _save_galaxy():
		settings_layer.get_child(0).set_save_status("Could not save this galaxy. Try again before leaving.")
	elif return_home:
		var error := get_tree().reload_current_scene()
		if error != OK:
			settings_layer.get_child(0).set_save_status("Game saved. Could not open the home screen.")
	else:
		settings_layer.get_child(0).set_save_status("Game saved.")

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
	galaxy_cloud = preload("res://scripts/galaxy_cloud.gd").new()
	galaxy_cloud.configure(solar_system.galaxy)
	world_background.add_child(galaxy_cloud)
	world_background.add_child(solar_system)
	asteroid_visuals = Node2D.new()
	world_background.add_child(asteroid_visuals)
	asteroid_effects = _add_draw_layer(asteroid_visuals, _draw_asteroid_effects)
	asteroid_effects.top_level = true
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

func _add_engine_light(visual: ShipVisual, nozzle: Transform2D, effect_scale: float = 1.0) -> void:
	var light := PointLight2D.new()
	light.texture = engine_light_texture
	light.color = Color(1.0, 0.56, 0.24)
	light.texture_scale = 1.35 * effect_scale
	light.position = nozzle * Vector2(0.0, 6.0 * effect_scale)
	light.energy = 0.0
	visual.add_child(light)
	visual.engine_lights.append(light)

func _set_engine_lighting(visual: ShipVisual, strength: float) -> void:
	for index in range(visual.engine_lights.size()):
		var light := visual.engine_lights[index]
		light.visible = strength > 0.01
		light.energy = strength * (0.65 + 0.08 * sin(elapsed * 19.0 + float(index) * 2.3))

func _queue_flight_redraw() -> void:
	flight_redraw_pending = true

func _redraw_flight() -> void:
	var viewport := get_viewport_rect()
	var viewport_size := viewport.size
	var zoom := Vector2.ONE * camera_zoom
	var camera := _world_transform()
	var camera_center := _camera_center()
	var view := Rect2(camera_center - viewport_size * 0.5 / camera_zoom, viewport_size / camera_zoom)
	var visible_world := view.grow(220.0)
	var cloud_zoom := camera_zoom * GALAXY.separation_for(solar_system.galaxy.generator_version)
	galaxy_cloud.show_cloud(camera, 1.0 - smoothstep(70.0, 600.0, cloud_zoom), 1.16, galaxy_origin[0], galaxy_origin[1])
	solar_system.update_view(elapsed, camera, _camera_center(), viewport_size * 0.5, view)
	asteroid_visuals.transform = Transform2D(0.0, zoom, 0.0, viewport_size * 0.5)
	asteroid_effects.transform = camera
	exhaust_particles_visual.transform = Transform2D(0.0, zoom, 0.0, viewport_size * 0.5)
	exhaust_particles_visual.queue_redraw()
	for asteroid in asteroids:
		var rock: Node2D = asteroid.visual
		rock.visible = asteroid.iron > 0 and visible_world.has_point(asteroid.position)
		if rock.visible:
			rock.position = (asteroid.position as Vector2) - camera_center
			if rock.material == null:
				var material := ShaderMaterial.new()
				material.shader = preload("res://scripts/asteroid_surface.gdshader")
				material.set_shader_parameter("rock_color", asteroid.base)
				material.set_shader_parameter("rock_seed", float(absi(("%d/%s" % [galaxy_seed, asteroid.id]).hash()) % 10000))
				rock.material = material
	var glowing_ships := {}
	if graphics_quality > 0:
		for impact in shield_impacts:
			glowing_ships[impact.enemy] = true
	for i in range(enemies.size()):
		var enemy: Dictionary = enemies[i]
		var visual: ShipVisual = enemy_visuals.get_child(i)
		visual.visible = enemy.alive and visible_world.has_point(enemy.position)
		if visual.visible:
			var position_on_screen := _world_to_screen(enemy.position)
			var pose := Transform2D(enemy.heading + PI / 2.0, zoom, 0.0, position_on_screen)
			_redraw_ship_visual(visual, pose, enemy.position, glowing_ships.has(i))
			_set_engine_lighting(visual, _enemy_engine_power(enemy))
	var camera_anchor := _camera_anchor()
	for index in fleet.size():
		if index == active_fleet_index:
			continue
		var parked: Dictionary = fleet[index]
		var screen_position := _fleet_screen_position(index, camera_anchor)
		var size: Vector2 = parked.bounds_size
		var margin := float(parked.radius) * camera_zoom + FLEET_VISUAL_MARGIN
		if size.y * camera_zoom <= FLEET_HULL_MIN_PIXELS or not viewport.grow(margin).has_point(screen_position):
			_remove_fleet_view(parked.id)
			continue
		if not fleet_views.has(parked.id):
			_create_fleet_view(parked)
		var view_ship: Dictionary = fleet_views[parked.id]
		var visual: ShipVisual = view_ship.visual
		var pose := Transform2D(float(parked.heading) + PI / 2.0, zoom, 0.0, screen_position)
		_redraw_ship_visual(visual, pose, _ship_local(parked), false)
		_set_engine_lighting(visual, float(view_ship.engine_flame))
	var player_screen := _fleet_screen_position(active_fleet_index, camera_anchor)
	_redraw_ship_visual(player_visual, Transform2D(heading + PI / 2.0, zoom, 0.0, player_screen), ship_position, glowing_ships.has(-1))
	_set_engine_lighting(player_visual, engine_flame * (1.0 + 0.5 * engine_overdrive))
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

func _camera_anchor() -> PackedFloat64Array:
	if not camera_following:
		return camera_galaxy_position
	return SHIP_STATE.absolute(galaxy_origin, ship_position) if camera_ship_index == active_fleet_index else fleet[camera_ship_index].galaxy_position

func _camera_center() -> Vector2:
	return SHIP_STATE.relative(_camera_anchor(), galaxy_origin)

func _fleet_screen_position(index: int, anchor: PackedFloat64Array) -> Vector2:
	var position: PackedFloat64Array = SHIP_STATE.absolute(galaxy_origin, ship_position) if index == active_fleet_index else fleet[index].galaxy_position
	return get_viewport_rect().size * 0.5 + SHIP_STATE.relative(position, anchor) * camera_zoom

func _center_camera_on_selection() -> void:
	camera_ship_index = active_fleet_index if selected_fleet.is_empty() else selected_fleet[0]
	camera_following = true
	_queue_flight_redraw()

func _world_to_screen(point: Vector2) -> Vector2:
	return get_viewport_rect().size * 0.5 + (point - _camera_center()) * camera_zoom

func _world_min() -> Vector2:
	return -world_origin

func _world_max() -> Vector2:
	return Vector2(world_size.x - galaxy_origin[0], world_size.y - galaxy_origin[1])

func _world_bounds() -> Rect2:
	return Rect2(_world_min(), world_size)

# Keep the physics bubble near zero even if the camera is panning a remote map.
func _maybe_rebase_world() -> void:
	var anchor := ship_position
	if anchor.length_squared() <= REBASE_RADIUS * REBASE_RADIUS:
		return
	_rebase_world(anchor)

func _rebase_world(shift: Vector2) -> void:
	if not shift.is_finite() or shift.is_zero_approx():
		return
	galaxy_origin = SHIP_STATE.absolute(galaxy_origin, shift)
	ship_position -= shift
	starfield_camera_center -= shift
	hyperjump_arrival = SHIP_STATE.relative(hyperjump_galaxy_target, galaxy_origin) if SHIP_STATE.valid_point(hyperjump_galaxy_target) else hyperjump_arrival - shift
	boost_destination -= shift
	rts_destination -= shift
	player_fleet_body.position -= shift
	for ship_id: String in fleet_colliders:
		fleet_colliders[ship_id].body.position = _ship_local(ship_registry.find(ship_id))
	for enemy in enemies:
		enemy.position -= shift
		enemy.patrol_origin -= shift
		enemy.patrol_destination -= shift
	for asteroid in asteroids:
		asteroid.position -= shift
	for shot in projectiles:
		shot.position -= shift
		if shot.has("muzzle"):
			shot.muzzle -= shift
	for piece in debris:
		piece.position -= shift
	for drop in tritium_drops:
		drop.position -= shift
	for effect in tritium_pickup_effects:
		effect.position -= shift
	for puff in rocket_smoke:
		puff.position -= shift
	for blast in rocket_blasts:
		blast.position -= shift
	for impact in hull_impacts:
		impact.position -= shift
	# Short-lived visual trails are cheaper to restart than to move.
	exhaust_particles.clear()
	_clear_engine_trails(cached_engines)
	for view: Dictionary in fleet_views.values():
		_clear_engine_trails(view.engines)
	for enemy in enemies:
		_clear_engine_trails(enemy.get("engines", []))
	solar_system.set_origin(galaxy_origin[0], galaxy_origin[1])

func _clear_engine_trails(engines: Array) -> void:
	for engine in engines:
		engine.trail = []
		engine.trail_active = false

func _fit_chart(size: Vector2, bounds: Rect2) -> float:
	return minf(size.x / bounds.size.x, size.y / bounds.size.y)

func _minimum_camera_zoom() -> float:
	return _fit_chart(get_viewport_rect().size, solar_system.world_bounds) * 0.9 * DISTANT_MAP_ZOOM_FACTOR

func _distant_system_icon_opacity() -> float:
	var overview_zoom := _fit_chart(get_viewport_rect().size, solar_system.world_bounds) * 0.9
	return 1.0 - smoothstep(overview_zoom * 0.5, overview_zoom, camera_zoom)

func _maximum_camera_zoom() -> float:
	var viewport_size := get_viewport_rect().size
	var ship_size := _ship_size()
	return maxf(_minimum_camera_zoom(), minf(viewport_size.x, viewport_size.y) * CAMERA_MAX_SHIP_SCREEN_FRACTION / maxf(maxf(ship_size.x, ship_size.y), 1.0))

func _set_camera_zoom(value: float) -> void:
	camera_zoom = clampf(value, _minimum_camera_zoom(), _maximum_camera_zoom())
	camera_zoom_target = camera_zoom

func _offset_camera(anchor: PackedFloat64Array, offset: Vector2) -> void:
	camera_galaxy_position = SHIP_STATE.point(clampf(anchor[0] + offset.x, 0.0, world_size.x),
		clampf(anchor[1] + offset.y, 0.0, world_size.y))

func _pan_camera(offset: Vector2) -> void:
	_offset_camera(_camera_anchor(), offset / camera_zoom)
	camera_following = false

func _process(_delta: float) -> void:
	if not game_started:
		return
	var now := Time.get_ticks_usec()
	var real_delta := float(now - last_render_usec) / 1000000.0
	last_render_usec = now
	play_time += real_delta
	# Cap camera/audio catch-up independently of the play-time counter.
	var presentation_delta := minf(real_delta, 0.1)
	if not _simulation_menu_open():
		if not is_instance_valid(fleet_dialog) or not fleet_dialog.visible:
			var pan := Input.get_vector("camera_pan_left", "camera_pan_right", "camera_pan_up", "camera_pan_down")
			if pan != Vector2.ZERO:
				_pan_camera(pan * CAMERA_PAN_SPEED * presentation_delta)
				_queue_flight_redraw()
		if not simulation_clock.paused and has_flight_controls and not cached_engines.is_empty():
			engine_audio.update_mix(engine_flame, engine_overdrive, _sustained_boost_active(), presentation_delta)
		if not simulation_clock.paused and now - rate_sample_usec >= 1250000:
			achieved_rate = (elapsed - rate_sample_seconds) * 1000000.0 / float(now - rate_sample_usec)
			rate_sample_usec = now
			rate_sample_seconds = elapsed
			calendar_dirty = true
	if camera_zoom != camera_zoom_target:
		var previous_zoom := camera_zoom
		var zoom_blend := 1.0 - exp(-20.0 * presentation_delta)
		camera_zoom = previous_zoom * pow(camera_zoom_target / previous_zoom, zoom_blend)
		if absf(camera_zoom / camera_zoom_target - 1.0) < 0.001:
			camera_zoom = camera_zoom_target
		if not camera_following:
			var offset := camera_zoom_focus - get_viewport_rect().size * 0.5
			_offset_camera(camera_galaxy_position, offset * (1.0 / previous_zoom - 1.0 / camera_zoom))
		_queue_flight_redraw()
	if calendar_dirty:
		_refresh_simulation_controls()
	if is_instance_valid(fleet_dialog) and fleet_dialog.visible:
		if fleet_order_list_dirty:
			_refresh_fleet_list()
			fleet_order_list_dirty = false
		elif now >= fleet_detail_refresh_usec:
			_refresh_fleet_order_details()
	if order_status_label.visible and order_target_request.is_empty() and now >= order_notice_until_usec:
		order_status_label.hide()
	if flight_redraw_pending:
		if simulation_clock.paused and not _simulation_menu_open():
			_maybe_rebase_world()
		flight_redraw_pending = false
		_redraw_flight()

func _visible_world(_camera: Transform2D) -> Rect2:
	var view_size := get_viewport_rect().size / camera_zoom
	return Rect2(_camera_center() - view_size * 0.5, view_size).grow(220.0)

func _load_graphics_settings() -> void:
	var config := ConfigFile.new()
	if config.load(graphics_settings_path) == OK:
		graphics_quality = clampi(int(config.get_value("graphics", "quality", 2)), 0, 2)
		var saved_cap := int(config.get_value("graphics", "frame_cap", 0))
		frame_cap = saved_cap if saved_cap == 0 or (saved_cap >= 30 and saved_cap <= 240) else 0
		vsync_enabled = bool(config.get_value("graphics", "vsync", false))
		engine_audio.volume = clampf(float(config.get_value("audio", "engine_volume", 0.7)), 0.0, 1.0)
	KEY_BINDINGS.setup(config)
	_apply_graphics_settings()

func _apply_graphics_settings() -> void:
	Engine.max_fps = frame_cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)

func _save_graphics_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "quality", graphics_quality)
	config.set_value("graphics", "frame_cap", frame_cap)
	config.set_value("graphics", "vsync", vsync_enabled)
	for action in KEY_BINDINGS.ACTIONS:
		var events := InputMap.action_get_events(action)
		if not events.is_empty():
			config.set_value("key_bindings", action, events[0].keycode)
	config.set_value("audio", "engine_volume", engine_audio.volume)
	if config.save(graphics_settings_path) != OK:
		push_warning("Settings could not be saved; they will apply for this session.")

func _create_top_controls() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_add_top_button(layer, "fleet", -164, -122, "Fleet — manage your ships.", _open_fleet)
	hyperjump_context_button = Button.new()
	hyperjump_context_button.text = "Initiate Hyper Jump"
	hyperjump_context_button.visible = false
	hyperjump_context_button.focus_mode = Control.FOCUS_NONE
	hyperjump_context_button.custom_minimum_size = Vector2(190, 40)
	hyperjump_context_button.pressed.connect(_initiate_context_hyperjump)
	layer.add_child(hyperjump_context_button)
	_add_top_button(layer, "hangar", -114, -72, "Ship Builder — design and launch ships.", _open_hangar)
	_add_top_button(layer, "settings", -64, -22, "Settings — open the flight menu.", _open_settings)
	_create_simulation_controls(layer)
	order_status_label = Label.new()
	order_status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	order_status_label.offset_left = -550.0
	order_status_label.offset_right = -22.0
	order_status_label.offset_top = 68.0
	order_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	order_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	order_status_label.add_theme_constant_override("shadow_offset_y", 2)
	order_status_label.hide()
	layer.add_child(order_status_label)

func _create_simulation_controls(layer: CanvasLayer) -> void:
	simulation_rate_control = OptionButton.new()
	simulation_rate_control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	simulation_rate_control.offset_left = -255.0
	simulation_rate_control.offset_right = -176.0
	simulation_rate_control.offset_top = 22.0
	simulation_rate_control.offset_bottom = 64.0
	simulation_rate_control.focus_mode = Control.FOCUS_NONE
	simulation_rate_control.tooltip_text = "Simulation speed. Camera and menus remain available while paused."
	simulation_rate_control.add_item("Paused", 0)
	for rate: int in SIMULATION_CLOCK.RATES:
		simulation_rate_control.add_item("%d×" % rate, rate)
	simulation_rate_control.item_selected.connect(func(index: int):
		_set_simulation_rate(simulation_rate_control.get_item_id(index)))
	layer.add_child(simulation_rate_control)

	simulation_calendar = Label.new()
	simulation_calendar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	simulation_calendar.offset_left = -540.0
	simulation_calendar.offset_right = -267.0
	simulation_calendar.offset_top = 22.0
	simulation_calendar.offset_bottom = 64.0
	simulation_calendar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	simulation_calendar.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	simulation_calendar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	simulation_calendar.add_theme_color_override("font_shadow_color", Color.BLACK)
	simulation_calendar.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(simulation_calendar)

func _mark_calendar_dirty() -> void:
	calendar_dirty = true

func _refresh_simulation_controls() -> void:
	calendar_dirty = false
	var paused := simulation_clock.paused or _simulation_menu_open()
	var status := ""
	if paused:
		status = "  ·  Paused"
	elif achieved_rate < float(simulation_clock.rate) * 0.9:
		status = "  ·  %.1f× actual" % achieved_rate
	simulation_calendar.text = simulation_clock.calendar_text() + status
	simulation_rate_control.select(simulation_rate_control.get_item_index(0 if simulation_clock.paused else simulation_clock.rate))

func _set_simulation_rate(rate: int) -> void:
	if rate != 0 and rate not in SIMULATION_CLOCK.RATES:
		return
	simulation_clock.paused = rate == 0
	if simulation_clock.paused:
		firing = false
		engine_audio.silence()
		heritage_gun_audio.stop()
	else:
		simulation_clock.rate = rate
	_sync_simulation_driver()

func _simulation_menu_open() -> bool:
	return is_instance_valid(settings_layer) or is_instance_valid(hangar_layer)

func _sync_simulation_driver() -> void:
	var running := game_started and not simulation_clock.paused and not _simulation_menu_open()
	var rate := simulation_clock.rate if running else 1
	var target_ticks := SIMULATION_CLOCK.TICKS_PER_SECOND * rate
	var default_max := int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame"))
	var target_max := maxi(default_max, 2 * rate)
	# Real physics-server ticks keep CharacterBody2D contacts synchronized at every rate.
	if Engine.physics_ticks_per_second != target_ticks or Engine.max_physics_steps_per_frame != target_max:
		changed_physics_cadence = true
		Engine.physics_ticks_per_second = target_ticks
		Engine.max_physics_steps_per_frame = target_max
	set_physics_process(running)
	rate_sample_usec = Time.get_ticks_usec()
	rate_sample_seconds = elapsed
	achieved_rate = float(simulation_clock.rate)
	_mark_calendar_dirty()

func _exit_tree() -> void:
	if changed_physics_cadence:
		Engine.physics_ticks_per_second = int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"))
		Engine.max_physics_steps_per_frame = int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame"))

func _add_top_button(layer: CanvasLayer, label: String, left: float, right: float, tooltip: String, action: Callable) -> Button:
	var button := preload("res://scripts/hud_icon_button.gd").new()
	button.icon_kind = label
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = left
	button.offset_top = 22
	button.offset_right = right
	button.offset_bottom = 64
	button.pressed.connect(action)
	layer.add_child(button)
	return button

func _open_fleet() -> void:
	if is_instance_valid(hangar_layer) or is_instance_valid(settings_layer):
		return
	if not is_instance_valid(fleet_dialog):
		_create_fleet_dialog()
	if not order_target_request.is_empty():
		_cancel_order_target()
	_refresh_fleet_designs()
	_refresh_fleet_list()
	fleet_list.select(active_fleet_index)
	_refresh_fleet_order_details()
	fleet_status.text = "Select a ship to view its orders."
	fleet_status.tooltip_text = ""
	fleet_dialog.popup_centered(Vector2i(860, 560))

func _create_fleet_dialog() -> void:
	fleet_dialog = AcceptDialog.new()
	fleet_dialog.title = "Fleet command"
	fleet_dialog.theme = FLEET_ORDER_PANEL.make_theme()
	fleet_dialog.get_ok_button().text = "Close"
	add_child(fleet_dialog)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	fleet_dialog.add_child(column)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation", 20)
	panes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panes)
	var roster := VBoxContainer.new()
	roster.custom_minimum_size.x = 246.0
	roster.add_theme_constant_override("separation", 8)
	panes.add_child(roster)
	FLEET_ORDER_PANEL.label(roster, "YOUR SHIPS", 12, FLEET_ORDER_PANEL.ACCENT)
	fleet_list = ItemList.new()
	fleet_list.max_text_lines = 2
	fleet_list.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	fleet_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster.add_child(fleet_list)
	fleet_list.item_selected.connect(_switch_fleet_control)
	var add_ship := Button.new()
	add_ship.text = "+ Add ship"
	add_ship.toggle_mode = true
	roster.add_child(add_ship)
	var spawn_options := VBoxContainer.new()
	spawn_options.hide()
	roster.add_child(spawn_options)
	add_ship.toggled.connect(func(expanded: bool):
		spawn_options.visible = expanded
		add_ship.text = "− Add ship" if expanded else "+ Add ship"
	)
	fleet_designs = OptionButton.new()
	fleet_designs.clip_text = true
	spawn_options.add_child(fleet_designs)
	var spawn_button := Button.new()
	spawn_button.text = "Spawn nearby"
	spawn_button.pressed.connect(_spawn_fleet_ship)
	spawn_options.add_child(spawn_button)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(440, 435)
	panes.add_child(scroll)
	fleet_orders = FLEET_ORDER_PANEL.new()
	fleet_orders.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fleet_orders.systems = solar_system.systems
	fleet_orders.submitted.connect(_fleet_panel_order)
	fleet_orders.cancel_requested.connect(func(): _cancel_fleet_orders(_fleet_panel_selection()))
	scroll.add_child(fleet_orders)
	fleet_status = FLEET_ORDER_PANEL.label(column, "", 13, FLEET_ORDER_PANEL.MUTED)
	fleet_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _refresh_fleet_designs() -> void:
	fleet_designs.clear()
	fleet_design_entries.clear()
	if HANGAR.is_editable_design(custom_parts) and MODULES.validate(custom_parts) == "":
		fleet_design_entries.append({"name": "Current ship design", "parts": custom_parts.duplicate(true),
			"admin": fleet[active_fleet_index].admin.duplicate(true)})
	var library: Variant = SHIP_LIBRARY.read()
	if library is Dictionary:
		var names: Array = library.keys()
		names.sort()
		for ship_name in names:
			var parts := SHIP_LIBRARY.restore_design(library[ship_name])
			if HANGAR.is_editable_design(parts) and MODULES.validate(parts) == "":
				fleet_design_entries.append({"name": str(ship_name), "parts": parts})
	for design in fleet_design_entries:
		fleet_designs.add_item(design.name)
	if fleet_design_entries.is_empty():
		fleet_designs.add_item("Build or save a ship design first")
	fleet_designs.disabled = fleet_design_entries.is_empty()

func _select_fleet_ship(index: int) -> void:
	selected_fleet.assign([index])
	rts_selected = index == active_fleet_index
	_queue_flight_redraw()

func _selected_ship_cargo() -> Dictionary:
	if selected_fleet.is_empty():
		return {}
	var index := selected_fleet[0]
	var ship: Dictionary = fleet[index]
	var active := index == active_fleet_index
	var cargo: Dictionary = {"iron": iron, "tritium": tritium} if active else ship.cargo
	var profile: Dictionary = _custom_stats() if active else ship.fleet_stats
	return {"name": ship.name, "iron": cargo.iron, "tritium": cargo.tritium, "capacity": profile.cargo_capacity}

func _fleet_panel_selection() -> int:
	var selected := fleet_list.get_selected_items()
	return active_fleet_index if selected.is_empty() else selected[0]

func _refresh_fleet_list() -> void:
	var selected := _fleet_panel_selection()
	fleet_list.clear()
	for i in range(fleet.size()):
		var ship: Dictionary = fleet[i]
		var order := SHIP_ORDER_QUEUE.current(ship)
		var status := SHIP_ORDER.caption(order)
		if ship.orders.size() > 1:
			status += "  ·  %d queued" % (ship.orders.size() - 1)
		fleet_list.add_item("%s\n%s" % [ship.name, status])
		fleet_list.set_item_tooltip(i, "%s\n%s · %s" % [ship.name, status, SHIP_ORDER.activity(order)])
	fleet_list.select(clampi(selected, 0, fleet.size() - 1))
	_refresh_fleet_order_details()

func _refresh_fleet_order_details() -> void:
	var index := _fleet_panel_selection()
	var ship: Dictionary = fleet[index]
	var cargo: Dictionary = {"iron": iron, "tritium": tritium} if index == active_fleet_index else ship.cargo
	fleet_orders.show_ship(ship, cargo, int(ship.fleet_stats.cargo_capacity))
	fleet_detail_refresh_usec = Time.get_ticks_usec() + 200000

func _fleet_panel_order(type: String, parameter: float, repeat: bool, append: bool) -> void:
	var index := _fleet_panel_selection()
	var ship: Dictionary = fleet[index]
	if type == "move":
		order_target_request = {"ship_id": ship.id, "append": append}
		rts_dragging = false
		firing = false
		fleet_dialog.hide()
		_show_order_notice("Right-click a destination for %s · Esc to cancel." % ship.name)
		return
	var target: Variant = int(parameter) if type == "hyperjump" else null
	if type == "mine":
		var reason := _mining_block_reason(index)
		if not reason.is_empty():
			_show_order_notice("%s: %s" % [ship.name, reason])
			return
		# A queued mining order may start after a hyperjump in a different system.
		target = ""
	if not _submit_fleet_order(index, type, target, parameter, repeat, append):
		_show_order_notice("Order could not be queued. Check its parameters or clear the queue.")
	_refresh_fleet_order_details()

func _pick_order_target(screen_position: Vector2) -> void:
	var request := order_target_request
	var index := fleet.find(ship_registry.find(request.ship_id))
	if index < 0:
		_cancel_order_target()
		return
	var target := SHIP_STATE.absolute(galaxy_origin, _screen_to_world(screen_position))
	order_target_request = {}
	if not _submit_fleet_order(index, "move", target, 0.0, false, request.append):
		_show_order_notice("Order could not be queued. Check its parameters or clear the queue.")

func _cancel_order_target() -> void:
	order_target_request = {}
	_show_order_notice("Target selection cancelled.")

func _show_order_notice(text: String, ship_id := "") -> void:
	order_status_label.text = text
	order_status_label.show()
	order_notice_until_usec = Time.get_ticks_usec() + 6000000
	if is_instance_valid(fleet_dialog) and fleet_dialog.visible and (ship_id == "" or ship_id == fleet[_fleet_panel_selection()].id):
		fleet_status.text = text
		fleet_status.tooltip_text = text

func _register_ship(legacy: Dictionary) -> Dictionary:
	var ship := ship_registry.new_ship(legacy, galaxy_origin)
	_prepare_fleet_stats(ship)
	return ship

func _ship_local(ship: Dictionary) -> Vector2:
	return SHIP_STATE.relative(ship.galaxy_position, galaxy_origin)

func _submit_fleet_order(index: int, type: String, target: Variant = null, quantity: float = 0.0, repeat := false, append := false) -> bool:
	if index < 0 or index >= fleet.size():
		return false
	var ship: Dictionary = fleet[index]
	if ship.owner_id != SHIP_STATE.OWNER_PLAYER:
		return false
	var replace_navigation: bool = not append or ship.orders.is_empty()
	if index == active_fleet_index:
		_commit_active_ship_state()
	if not SHIP_ORDER_QUEUE.submit(ship, type, target, quantity, repeat, append, solar_system.systems.size()):
		return false
	if replace_navigation:
		fleet_detours.erase(ship.id)
		ship.navigation = {"mode": "hold"}
		if index == active_fleet_index:
			_apply_active_order_navigation(ship)
	fleet_order_list_dirty = true
	_show_order_notice("%s: %s order %s." % [ship.name, type.capitalize(), "queued" if append else "assigned"])
	return true

func _cancel_fleet_orders(index: int) -> void:
	if index < 0 or index >= fleet.size():
		return
	var ship: Dictionary = fleet[index]
	if ship.owner_id != SHIP_STATE.OWNER_PLAYER or not SHIP_ORDER_QUEUE.cancel(ship):
		return
	fleet_detours.erase(ship.id)
	if index == active_fleet_index:
		_apply_active_order_navigation(ship)
	fleet_order_list_dirty = true
	_show_order_notice("%s: orders cancelled." % ship.name)

func _run_fleet_order(ship: Dictionary, delta: float) -> void:
	var order: Dictionary = ship.orders[0]
	var previous_stage: String = order.stage
	var previous_state: String = order.state
	order_controller.tick(ship, delta, _resolve_order_jump, _resolve_order_rock, _extract_order_ore, _nearest_mineable_asteroid)
	if ship.last_order.get("id") == order.id:
		fleet_order_list_dirty = true
		var report: Dictionary = ship.last_order
		_show_order_notice("%s · %s %s: %s" % [ship.name, report.type.capitalize(), report.state, report.reason], ship.id)
	elif order.stage != previous_stage or order.state != previous_state:
		fleet_order_list_dirty = true

func _drive_active_order(delta: float) -> bool:
	autonomous_mining_target = false
	var ship: Dictionary = fleet[active_fleet_index]
	if hyperjump_time < 0.0 and (sustained_boost_enabled or boost_time > 0.0):
		if not ship.orders.is_empty() and ship.orders[0].state != "suspended":
			order_controller.suspend(ship)
			fleet_order_list_dirty = true
		active_order_hold = false
		return false
	if ship.orders.is_empty():
		return false
	_run_fleet_order(ship, delta)
	_apply_active_order_navigation(ship)
	iron = ship.cargo.iron
	tritium = ship.cargo.tritium
	if not ship.orders.is_empty():
		var order: Dictionary = ship.orders[0]
		if order.type == "mine" and order.stage in ["aiming", "mining"] and live_rocks.has(order.target_entity_id):
			var index: int = live_rocks[order.target_entity_id].index
			if index < asteroids.size() and asteroids[index].id == order.target_entity_id:
				mining_asteroid = index
				autonomous_mining_target = true
				mining = order.stage == "mining" and asteroids[index].iron > 0
	return true

func _apply_active_order_navigation(ship: Dictionary) -> void:
	var nav: Dictionary = ship.navigation
	var was_jumping := hyperjump_time >= 0.0
	rts_attack_active = false
	firing = false
	mining = false
	mining_asteroid = -1
	sustained_boost_enabled = false
	boost_destination_active = false
	boost_decelerating = false
	boost_time = 0.0
	rts_move_active = nav.mode == "move"
	active_order_hold = nav.mode == "hold"
	if rts_move_active:
		rts_destination = SHIP_STATE.relative(nav.target, galaxy_origin)
	if nav.mode == "jump":
		hyperjump_galaxy_target = nav.target
		hyperjump_arrival = SHIP_STATE.relative(nav.target, galaxy_origin)
		hyperjump_destination = nav.system
		hyperjump_distance = nav.distance
		hyperjump_time = nav.time
	else:
		hyperjump_time = -1.0
		if was_jumping and ship.last_order.get("state") == "completed":
			hyperjump_arrival_until = elapsed + 3.0

func _resolve_order_jump(ship: Dictionary, destination: int) -> PackedFloat64Array:
	var source := solar_system.nearest_system(_ship_local(ship))
	return solar_system.hyperjump_arrival_coordinates(source, destination) if source != destination else PackedFloat64Array()

func _asteroid_site_id(system: int, index: int, site: Dictionary) -> String:
	return "%d/field/%s" % [system, site.field_id] if site.has("field_id") else "%d/%d" % [system, index]

func _nearest_mineable_asteroid(ship: Dictionary) -> String:
	var system := solar_system.nearest_system(_ship_local(ship))
	var nearest := ""
	var distance := INF
	if system == asteroid_system:
		for rock in asteroids:
			if rock.iron <= 0:
				continue
			var offset := SHIP_STATE.relative(rock.galaxy_position, ship.galaxy_position)
			if offset.length_squared() < distance:
				distance = offset.length_squared()
				nearest = rock.id
		return nearest
	var sites := GALAXY.asteroid_sites(galaxy_seed, solar_system.systems[system], solar_system.system_contents(system))
	for index in sites.size():
		var site := sites[index]
		var id := _asteroid_site_id(system, index, site)
		if int(depleted_ore.get(id, ASTEROID_FACTORY.ore_capacity(site.radius, site.ore))) <= 0:
			continue
		var offset := SHIP_STATE.relative(SHIP_STATE.point(site.position.x, site.position.y), ship.galaxy_position)
		if offset.length_squared() < distance:
			distance = offset.length_squared()
			nearest = id
	return nearest

func _resolve_order_rock(id: String) -> Dictionary:
	if live_rocks.has(id):
		return live_rocks[id]
	if not order_rocks.has(id):
		var prefix := id.get_slice("/", 0)
		if not prefix.is_valid_int():
			return {}
		var system := int(prefix)
		if system < 0 or system >= solar_system.systems.size():
			return {}
		var sites := GALAXY.asteroid_sites(galaxy_seed, solar_system.systems[system], solar_system.system_contents(system))
		for index in sites.size():
			var site := sites[index]
			var candidate := _asteroid_site_id(system, index, site)
			if candidate == id:
				order_rocks[id] = {"galaxy_position": SHIP_STATE.point(site.position.x, site.position.y),
					"radius": site.radius, "max_iron": ASTEROID_FACTORY.ore_capacity(site.radius, site.ore)}
				break
	if not order_rocks.has(id):
		return {}
	var rock: Dictionary = order_rocks[id]
	rock.iron = clampi(int(depleted_ore.get(id, rock.max_iron)), 0, rock.max_iron)
	return rock

func _extract_ore(id: String, requested: int) -> int:
	var rock := _resolve_order_rock(id)
	if rock.is_empty():
		return 0
	var extracted := clampi(requested, 0, rock.iron)
	rock.iron -= extracted
	depleted_ore[id] = rock.iron
	return extracted

func _extract_order_ore(ship: Dictionary, id: String, requested: int) -> int:
	var amount := _extract_ore(id, mini(requested, SHIP_CAPABILITIES.available_space(ship.fleet_stats, ship.cargo)))
	ship.cargo.iron += amount
	return amount

func _prepare_fleet_stats(ship: Dictionary) -> void:
	var bounds := MODULES.bounds(ship.parts)
	ship.ship_scale = MODULES.length_scale(bounds.size.y / MODULES.WORLD_UNITS_PER_METER, ship.admin)
	ship.bounds_size = bounds.size * float(ship.ship_scale)
	ship.radius = ship.bounds_size.length() * 0.5
	ship.fleet_stats = _stats_with_admin(ship.parts, ship.admin)
	ship.can_fly = SHIP_CAPABILITIES.can_perform(ship.fleet_stats, "move")

func _save_active_fleet_ship() -> void:
	var ship: Dictionary = fleet[active_fleet_index]
	if ship.parts != custom_parts:
		ship.parts = custom_parts.duplicate(true)
		ship.design_id = SHIP_STATE.design_id(ship.parts)
		_prepare_fleet_stats(ship)
	_commit_active_ship_state()

func _commit_active_ship_state() -> void:
	var ship: Dictionary = fleet[active_fleet_index]
	ship.galaxy_position = SHIP_STATE.absolute(galaxy_origin, ship_position)
	ship.heading = heading
	ship.angular_velocity = angular_velocity
	ship.velocity = velocity
	ship.hull = player_hull
	ship.shield = player_shield
	ship.shield_delay = player_shield_delay
	ship.cargo.iron = iron
	ship.cargo.tritium = tritium
	if hyperjump_time >= 0.0:
		ship.navigation = {"mode": "jump", "target": hyperjump_galaxy_target, "system": hyperjump_destination,
			"distance": hyperjump_distance, "time": hyperjump_time}
	elif sustained_boost_enabled:
		ship.navigation = {"mode": "boost", "direction": sustained_boost_direction}
		if boost_destination_active:
			ship.navigation.target = SHIP_STATE.absolute(galaxy_origin, boost_destination)
	elif boost_time > 0.0:
		ship.navigation = {"mode": "burst", "time": boost_time, "duration": boost_duration, "power": boost_power}
	elif boost_decelerating:
		ship.navigation = {"mode": "decelerate"}
	elif rts_move_active:
		ship.navigation = {"mode": "move", "target": SHIP_STATE.absolute(galaxy_origin, rts_destination)}
	elif active_order_hold and not velocity.is_zero_approx():
		ship.navigation = {"mode": "hold"}
	else:
		ship.navigation = {"mode": "drift" if not velocity.is_zero_approx() else "idle"}

func _load_active_ship_state(ship: Dictionary) -> void:
	custom_parts = ship.parts.duplicate(true)
	ship_position = _ship_local(ship).clamp(_world_min(), _world_max())
	ship_motion_remainder = Vector2.ZERO
	heading = ship.heading
	angular_velocity = ship.angular_velocity
	velocity = ship.velocity
	player_hull = ship.hull
	player_shield = ship.shield
	player_shield_delay = ship.shield_delay
	iron = ship.cargo.iron
	tritium = ship.cargo.tritium
	ship_cache_ready = false
	boost_time = 0.0
	boost_decelerating = false
	sustained_boost_enabled = false
	sustained_boost_direction = Vector2.ZERO
	boost_destination_active = false
	rts_move_active = false
	hyperjump_time = -1.0
	hyperjump_arrival_until = 0.0
	var nav: Dictionary = ship.navigation
	active_order_hold = nav.mode == "hold"
	match nav.mode:
		"move":
			rts_move_active = true
			rts_destination = SHIP_STATE.relative(nav.target, galaxy_origin)
		"jump":
			hyperjump_destination = nav.system
			hyperjump_galaxy_target = nav.target
			hyperjump_arrival = SHIP_STATE.relative(nav.target, galaxy_origin)
			hyperjump_distance = nav.distance
			hyperjump_time = nav.time
		"boost":
			sustained_boost_enabled = true
			sustained_boost_direction = nav.direction
			boost_destination_active = nav.has("target")
			if boost_destination_active:
				boost_destination = SHIP_STATE.relative(nav.target, galaxy_origin)
				rts_destination = boost_destination
				rts_move_active = true
		"burst":
			boost_time = nav.time
			boost_duration = nav.duration
			boost_power = nav.power
		"decelerate":
			boost_decelerating = true

func _draw_parked_ship(canvas: CanvasItem, ship: Dictionary) -> void:
	var parts: Array = ship.parts
	var center: Vector2 = MODULES.bounds(parts).get_center()
	var ship_scale: float = ship.get("ship_scale", 1.0)
	var borders: Dictionary = MODULES.armour_borders(parts)
	var cell_size := MODULES.cell_size_for(parts[0]) if not parts.is_empty() else MODULES.CELL
	var origin := Vector2.ONE * (cell_size - MODULES.CELL) * 0.5
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		if MODULES.is_exterior_structure(part):
			MODULES.draw_part(canvas, part, (MODULES.part_position(part) - center) * ship_scale, ship_scale)
			if borders.has(index):
				MODULES.draw_armour_border(canvas, borders[index], (origin - center) * ship_scale, cell_size * ship_scale)
	for index in borders:
		var part: Dictionary = parts[index]
		if MODULES.is_armour_overlay(part):
			MODULES.draw_part(canvas, part, (MODULES.part_position(part) - center) * ship_scale, ship_scale)
			MODULES.draw_armour_border(canvas, borders[index], (origin - center) * ship_scale, cell_size * ship_scale)
	for part in parts:
		if MODULES.is_decoration(part):
			MODULES.draw_part(canvas, part, (MODULES.part_position(part) - center) * ship_scale, ship_scale)
		if part.has("turret"):
			MODULES.draw_mounted_turret(canvas, part.turret, (MODULES.mount_position(part) - center) * ship_scale, ship_scale)

func _draw_fleet_exhaust(canvas: CanvasItem, view: Dictionary) -> void:
	for index in range(view.engines.size()):
		_draw_engine_flare(canvas, view.engines[index], float(view.engine_flame), float(index) * 2.7)

func _draw_empty_fleet_layer(_canvas: CanvasItem) -> void:
	pass

# Camera changes must not create or remove physics colliders.
func _sync_fleet_colliders() -> void:
	for index in fleet.size():
		var ship: Dictionary = fleet[index]
		var has_body := fleet_colliders.has(ship.id)
		var limit := FLEET_COLLIDER_EXIT_RANGE if has_body else FLEET_COLLIDER_RANGE
		var needed := index != active_fleet_index and ship_position.distance_squared_to(_ship_local(ship)) <= limit * limit
		if needed and not has_body:
			_create_fleet_collider(ship)
		elif has_body and not needed:
			_remove_fleet_collider(ship.id)

func _remove_fleet_collider(ship_id: String) -> void:
	if not fleet_colliders.has(ship_id):
		return
	var body: CharacterBody2D = fleet_colliders[ship_id].body
	remove_child(body)
	body.queue_free()
	fleet_colliders.erase(ship_id)

func _remove_fleet_view(ship_id: String) -> void:
	if not fleet_views.has(ship_id):
		return
	var visual: ShipVisual = fleet_views[ship_id].visual
	visual.hide()
	visual.queue_free()
	fleet_views.erase(ship_id)

func _create_fleet_view(ship: Dictionary) -> void:
	var bounds := MODULES.bounds(ship.parts)
	var ship_scale: float = ship.ship_scale
	var fleet_engines: Array[Dictionary] = []
	for part in ship.parts:
		_collect_engine_nozzles(part, bounds.get_center(), fleet_engines, ship_scale)
	var view := {"engines": fleet_engines, "engine_flame": 0.0}
	var visual := _add_ship_visual(fleet_visuals, _draw_fleet_exhaust.bind(view), _draw_parked_ship.bind(ship), _draw_empty_fleet_layer, _draw_empty_fleet_layer)
	SHIP_RELIEF.bake(visual.material, ship.parts, bounds, ship_scale)
	for engine in fleet_engines:
		_add_engine_light(visual, engine.nozzle, engine.effect_scale)
	view.visual = visual
	fleet_views[ship.id] = view
	visual.queue_redraw()

func _create_fleet_collider(ship: Dictionary) -> void:
	var body := CharacterBody2D.new()
	body.collision_layer = FLEET_COLLISION_LAYER
	body.collision_mask = FLEET_COLLISION_LAYER
	body.position = _ship_local(ship)
	body.rotation = float(ship.heading) + PI / 2.0
	var shapes := _add_fleet_collision_shapes(body, ship.parts, MODULES.bounds(ship.parts), ship.ship_scale)
	add_child(body)
	fleet_colliders[ship.id] = {"body": body, "hull_shapes": shapes}

func _add_fleet_collision_shapes(body: PhysicsBody2D, parts: Array, bounds: Rect2, ship_scale: float) -> Array[PackedVector2Array]:
	var shapes := _fleet_hull_shapes(parts, bounds, ship_scale)
	for shape in shapes:
		var collider := CollisionPolygon2D.new()
		collider.polygon = shape
		body.add_child(collider)
	return shapes

func _fleet_hull_shapes(parts: Array, bounds: Rect2, ship_scale: float) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	var center := bounds.get_center()
	var scale_transform := Transform2D(0.0, Vector2.ONE * ship_scale, 0.0, Vector2.ZERO)
	for part in parts:
		if not MODULES.is_exterior_structure(part):
			continue
		var offset := MODULES.part_position(part) - center
		var polygons: Array[PackedVector2Array] = []
		if MODULES.PRESET_TEXTURES.has(part.type):
			polygons = MODULES.preset_alpha_polygons(part, offset)
		else:
			polygons = MODULES.structural_polygons(part, offset)
		for polygon in polygons:
			if polygon.size() >= 3:
				shapes.append(scale_transform * polygon)
	return shapes

func _spawn_fleet_ship() -> void:
	if hyperjump_time >= 0.0:
		fleet_status.text = "Wait until the hyperjump finishes before spawning a ship."
		return
	var selected := fleet_designs.selected
	if selected < 0 or selected >= fleet_design_entries.size():
		fleet_status.text = "Build or save a ship design in the Ship Builder first."
		return
	var design: Dictionary = fleet_design_entries[selected]
	var parts: Array = design.parts.duplicate(true)
	var error: String = MODULES.validate(parts)
	if error != "":
		fleet_status.text = "This design cannot fly: " + error
		return
	_save_active_fleet_ship()
	var admin := _admin_for_new_ship(parts, design.get("admin", {}))
	var bounds := MODULES.bounds(parts)
	var radius := bounds.size.length() * 0.5 * MODULES.length_scale(bounds.size.y / MODULES.WORLD_UNITS_PER_METER, admin)
	var distance := _ship_size().length() * 0.5 + radius + 100.0
	var position := ship_position
	var clear := false
	# Search outward in all directions, including near the edge of the world.
	for attempt in range((fleet.size() + 1) * 16):
		var ring := int(attempt / 16)
		var angle := heading + PI / 2.0 + TAU * float(attempt % 16) / 16.0
		position = ship_position + Vector2.RIGHT.rotated(angle) * (distance + float(ring) * (radius * 2.0 + 100.0))
		if not _world_bounds().has_point(position):
			continue
		clear = true
		for index in range(fleet.size()):
			var other: Dictionary = fleet[index]
			var other_radius: float = _ship_size().length() * 0.5 if index == active_fleet_index else other.radius
			if position.distance_to(_ship_local(other)) < radius + other_radius + 50.0:
				clear = false
				break
		if clear:
			break
	if not clear:
		fleet_status.text = "No room to spawn here. Move away from the world edge and try again."
		return
	var stats := _stats_with_admin(parts, admin)
	var name := "%s · %d" % [design.name, fleet.size() + 1]
	_register_ship({"name": name, "parts": parts, "admin": admin, "position": position, "heading": heading,
		"hull": float(stats.health), "shield": float(stats.shield), "shield_delay": 0.0})
	_sync_fleet_colliders()
	_refresh_fleet_list()
	fleet_status.text = "Spawned %s. Select it to give it orders." % name
	_queue_flight_redraw()

func _switch_fleet_control(index: int) -> void:
	if index < 0 or index >= fleet.size():
		return
	if index == active_fleet_index:
		_select_fleet_ship(index)
		return
	_save_active_fleet_ship()
	active_fleet_index = index
	_select_fleet_ship(index)
	var ship: Dictionary = fleet[active_fleet_index]
	_remove_fleet_view(ship.id)
	_remove_fleet_collider(ship.id)
	var new_position := _ship_local(ship)
	if new_position.length_squared() > REBASE_RADIUS * REBASE_RADIUS:
		_rebase_world(new_position)
	_load_active_ship_state(ship)
	thrust = 0.0
	_reset_player_exhaust()
	rts_attack_active = false
	auto_approach = false
	firing = false
	laser_active = false
	machine_gun_active = false
	mining = false
	selected_enemy = -1
	selected_asteroid = -1
	mining_asteroid = -1
	mining_progress = 0.0
	for i in range(shield_impacts.size() - 1, -1, -1):
		if shield_impacts[i].enemy == -1:
			shield_impacts.remove_at(i)
	for i in range(hull_impacts.size() - 1, -1, -1):
		if hull_impacts[i].enemy == -1:
			hull_impacts.remove_at(i)
	turret_angles.clear()
	player_machine_gun_shots.clear()
	player_rocket_launches.clear()
	_ensure_ship_cache()
	player_fleet_body.position = ship_position
	player_fleet_body.rotation = heading + PI / 2.0
	_sync_fleet_colliders()
	_load_asteroids_near_ship()
	if is_instance_valid(fleet_dialog):
		_refresh_fleet_designs()
		_refresh_fleet_list()
		fleet_list.select(index)
		fleet_status.text = "Focused on %s." % ship.name
	_queue_flight_redraw()

func _combat_locked() -> bool:
	return sustained_boost_enabled or boost_time > 0.0 or hyperjump_time >= 0.0

func _clear_combat_control() -> void:
	selected_enemy = -1
	selected_asteroid = -1
	auto_approach = false
	rts_attack_active = false
	firing = false
	laser_active = false
	machine_gun_active = false
	mining = false
	mining_asteroid = -1
	mining_progress = 0.0

func _set_sustained_boost(enabled: bool, direction := Vector2.ZERO) -> void:
	_ensure_ship_cache()
	if enabled and (not has_flight_controls or float(_current_ship().speed) <= 0.0):
		return
	boost_decelerating = not enabled and sustained_boost_enabled
	sustained_boost_enabled = enabled
	if enabled:
		active_order_hold = false
		_clear_combat_control()
	sustained_boost_direction = direction
	boost_destination_active = false
	boost_time = 0.0
	rts_dragging = false
	rts_move_active = false
	rts_attack_active = false
	firing = false
	_queue_flight_redraw()

func _fleet_command_selection() -> Array[int]:
	return selected_fleet.duplicate() if not selected_fleet.is_empty() else [active_fleet_index]

func _can_fleet_boost(index: int) -> bool:
	var ship: Dictionary = fleet[index]
	var jumping: bool = hyperjump_time >= 0.0 if index == active_fleet_index else ship.navigation.mode == "jump"
	return not jumping and ship.can_fly and float(ship.fleet_stats.boost) > 0.0

func _toggle_sustained_boost() -> void:
	if hyperjump_time >= 0.0:
		return
	var enable := not sustained_boost_enabled
	if enable and not _can_fleet_boost(active_fleet_index):
		# Keep the group selected even if its current focus can't boost.
		var group := _fleet_command_selection()
		for index in group:
			if _can_fleet_boost(index):
				_switch_fleet_control(index)
				selected_fleet.assign(group)
				break
		if not _can_fleet_boost(active_fleet_index):
			_show_order_notice("No selected ships can boost.")
			return
	_set_sustained_boost(enable)
	if not enable:
		for index in _fleet_command_selection():
			var ship: Dictionary = fleet[index]
			if index != active_fleet_index and ship.navigation.mode == "boost":
				ship.navigation = {"mode": "decelerate"}
				fleet_detours.erase(ship.id)

func _steer_sustained_boost(screen_position: Vector2) -> void:
	var indices: Array[int] = []
	var positions: Array[Vector2] = []
	for index in _fleet_command_selection():
		if not _can_fleet_boost(index):
			continue
		indices.append(index)
		positions.append(ship_position if index == active_fleet_index else _ship_local(fleet[index]))
	if indices.is_empty():
		return
	var translation := FLEET_AVOIDANCE.formation_translation(positions, _screen_to_world(screen_position), _world_min(), _world_max())
	for slot in indices.size():
		var index := indices[slot]
		var ship: Dictionary = fleet[index]
		var target := positions[slot] + translation
		fleet_detours.erase(ship.id)
		if index == active_fleet_index:
			boost_destination = target
			boost_destination_active = true
			rts_destination = target
			rts_move_active = true
			sustained_boost_direction = translation.normalized()
		else:
			if not ship.orders.is_empty():
				order_controller.suspend(ship)
				fleet_order_list_dirty = true
			ship.navigation = {"mode": "boost", "direction": translation.normalized(), "target": SHIP_STATE.absolute(galaxy_origin, target)}
	_queue_flight_redraw()

func _boost_acceleration(boost_speed: float, boost_acceleration: float) -> float:
	return SHIP_SIMULATION.boost_acceleration(boost_speed, boost_acceleration, velocity)

func _at_flight_destination(distance: float, radius: float, max_speed: float) -> bool:
	return distance < radius and velocity.length_squared() < max_speed * max_speed

func _navigation_velocity(current: Vector2, forward: Vector2, course: Vector2, target_speed: float, acceleration: float, delta: float) -> Vector2:
	return FLIGHT_NAVIGATION.navigation_velocity(current, forward, course, target_speed, acceleration, delta)

func _boost_approach_speed(distance: float, acceleration_limit: float) -> float:
	if distance >= BOOST_FINAL_APPROACH_DISTANCE:
		return SHIP_SIMULATION.approach_speed(distance, acceleration_limit, TRAVEL_APPROACH_RATE)
	# Finish with an approximately constant deceleration instead of an exponential crawl.
	# Aim slightly inside the arrival radius so the ship can settle before it is snapped into place.
	var remaining := maxf(0.0, distance - BOOST_ARRIVAL_RADIUS * 0.5)
	var transition_distance := BOOST_FINAL_APPROACH_DISTANCE - BOOST_ARRIVAL_RADIUS * 0.5
	var transition_speed := SHIP_SIMULATION.approach_speed(BOOST_FINAL_APPROACH_DISTANCE, acceleration_limit, TRAVEL_APPROACH_RATE)
	return transition_speed * sqrt(remaining / transition_distance)

func _update_boost_destination(boost_speed: float, boost_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	var to_destination := boost_destination - ship_position
	var distance := to_destination.length()
	if _at_flight_destination(distance, BOOST_ARRIVAL_RADIUS, BOOST_ARRIVAL_SPEED):
		ship_position = boost_destination
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		_set_sustained_boost(false)
		boost_decelerating = false
		thrust = move_toward(thrust, 0.0, delta * 5.0)
		return
	var route := _fleet_move_route(fleet[active_fleet_index], SHIP_STATE.absolute(galaxy_origin, ship_position),
		to_destination, velocity, boost_speed, boost_acceleration, ship_turn_speed)
	sustained_boost_direction = route.normalized()
	_steer_heading(route, ship_turn_speed, delta)
	var alignment := smoothstep(0.98, 0.995, Vector2.from_angle(heading).dot(sustained_boost_direction))
	var speed := minf(boost_speed, _boost_approach_speed(route.length(), boost_acceleration))
	var desired_velocity := sustained_boost_direction * speed * lerpf(1.0, alignment, smoothstep(RTS_DOCKING_DISTANCE, 160.0, distance))
	engine_boost_target = _navigation_exhaust(sustained_boost_direction, desired_velocity.length(), alignment, delta)
	var movement_acceleration := _boost_acceleration(boost_speed, boost_acceleration) if desired_velocity.length() > velocity.length() else boost_acceleration
	velocity = _navigation_velocity(velocity, Vector2.from_angle(heading), sustained_boost_direction, speed, movement_acceleration, delta)
	thrust = move_toward(thrust, alignment if speed > 5.0 else 0.0, delta * THROTTLE_RAMP)

func _can_hyperjump() -> bool:
	return SHIP_CAPABILITIES.can_perform(_custom_stats(), "hyperjump")

func _close_hyperjump_chart() -> void:
	hyperjump_context_button.hide()
	hyperjump_context_destination = -1

func _hyperjump_pick_radius(system: Dictionary) -> float:
	return maxf(24.0, float(system.radius) * camera_zoom + 12.0)

func _system_at_screen(point: Vector2) -> int:
	if camera_zoom >= MAP_LABEL_ZOOM or solar_system.systems.size() < 2:
		return -1
	var camera := _world_transform()
	var selected := -1
	var nearest := INF
	var distant_icons := _distant_system_icon_opacity() > 0.5
	for index in solar_system.systems.size():
		var system: Dictionary = solar_system.systems[index]
		var center := camera * solar_system.system_centers[index]
		var radius := maxf(6.0, float(system.radius) * camera_zoom)
		var label_bounds := Rect2(center + Vector2(-55.0, 8.0), Vector2(110.0, 24.0)) if distant_icons else Rect2(center + Vector2(-90.0, radius + 5.0), Vector2(180.0, 36.0))
		var distance := point.distance_squared_to(center)
		if (distance <= pow(_hyperjump_pick_radius(system), 2.0) or label_bounds.has_point(point)) and distance < nearest:
			selected = index
			nearest = distance
	return selected

func _show_hyperjump_context(destination: int, screen_position: Vector2) -> void:
	hyperjump_context_destination = destination
	var count := _fleet_jump_candidates(destination).size()
	hyperjump_context_button.text = "Hyperjump %d Ships" % count if count > 1 else "Initiate Hyper Jump"
	hyperjump_context_button.disabled = count == 0
	hyperjump_context_button.tooltip_text = "Travel to %s" % solar_system.systems[destination].name if count > 0 else "Choose another system with a flight-capable ship."
	var button_size := Vector2(190, 40)
	hyperjump_context_button.position = screen_position.clamp(Vector2.ZERO, (get_viewport_rect().size - button_size).max(Vector2.ZERO))
	hyperjump_context_button.size = button_size
	hyperjump_context_button.show()

func _initiate_context_hyperjump() -> void:
	var destination := hyperjump_context_destination
	_close_hyperjump_chart()
	if destination < 0:
		return
	var candidates := _fleet_jump_candidates(destination)
	if candidates.size() == 1 and candidates[0].index == active_fleet_index:
		_execute_hyperjump(candidates[0].source, destination)
	elif not candidates.is_empty():
		_execute_fleet_hyperjump(candidates, destination)

func _fleet_jump_candidates(destination: int) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for index in _fleet_command_selection():
		var ship: Dictionary = fleet[index]
		var piloted := index == active_fleet_index
		if (hyperjump_time >= 0.0 if piloted else ship.navigation.mode == "jump") or not SHIP_CAPABILITIES.can_perform(ship.fleet_stats, "hyperjump"):
			continue
		var local := ship_position if piloted else _ship_local(ship)
		var source := solar_system.nearest_system(local)
		if source != destination:
			candidates.append({"index": index, "source": source, "position": local, "radius": ship.radius})
	return candidates

func _execute_fleet_hyperjump(candidates: Array[Dictionary], destination: int) -> void:
	var anchor := solar_system.hyperjump_arrival_coordinates(candidates[0].source, destination)
	var route := SHIP_STATE.relative(anchor, SHIP_STATE.absolute(galaxy_origin, candidates[0].position)).normalized()
	var lateral := route.orthogonal() if not route.is_zero_approx() else Vector2.UP
	# Give each hull a distinct arrival lane, without exchanging left/right positions.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var difference: Vector2 = a.position - b.position
		var side := difference.dot(lateral)
		return side < 0.0 if not is_zero_approx(side) else a.index < b.index)
	var width := 0.0
	for slot in candidates.size():
		if slot > 0:
			width += FLEET_AVOIDANCE.clearance(candidates[slot - 1].radius, candidates[slot].radius) + 16.0
		candidates[slot].lane = width
	# Ships already further along the flight direction leave first.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var difference: Vector2 = a.position - b.position
		var lead := difference.dot(route)
		return lead > 0.0 if not is_zero_approx(lead) else a.index < b.index)
	var sent := 0
	for candidate in candidates:
		var index: int = candidate.index
		if not _submit_fleet_order(index, "hyperjump", destination):
			continue
		var order: Dictionary = fleet[index].orders[0]
		order.parameters.departure_delay = sent * FLEET_JUMP_INTERVAL
		var target := SHIP_STATE.absolute(anchor, lateral * (float(candidate.lane) - width * 0.5))
		order.progress.travel_target = SHIP_STATE.point(clampf(target[0], 0.0, world_size.x), clampf(target[1], 0.0, world_size.y))
		order.progress.jump_distance = SHIP_STATE.relative(order.progress.travel_target, SHIP_STATE.absolute(galaxy_origin, candidate.position)).length()
		sent += 1
	if sent > 1:
		_show_order_notice("%d ships jumping to %s in sequence." % [sent, solar_system.systems[destination].name])

func _execute_hyperjump(source: int, destination: int) -> void:
	if source == destination or not _can_hyperjump() or hyperjump_time >= 0.0:
		return
	_cancel_fleet_orders(active_fleet_index)
	active_order_hold = false
	hyperjump_destination = destination
	hyperjump_galaxy_target = solar_system.hyperjump_arrival_coordinates(source, destination)
	hyperjump_arrival = SHIP_STATE.relative(hyperjump_galaxy_target, galaxy_origin)
	hyperjump_distance = ship_position.distance_to(hyperjump_arrival)
	_set_sustained_boost(false)
	boost_decelerating = false
	rts_move_active = false
	rts_attack_active = false
	firing = false
	hyperjump_arrival_until = 0.0
	hyperjump_time = 0.0
	_clear_combat_control()
	_queue_flight_redraw()

func _hyperjump_cruise_speed() -> float:
	return float(_current_ship().hyperdrive)

func _update_hyperjump(jump_speed: float, jump_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	hyperjump_time += delta
	var to_destination := hyperjump_arrival - ship_position
	var distance := to_destination.length()
	# World positions are single-precision vectors. Allow for their rounding at galaxy scale.
	var arrival_tolerance := maxf(SHIP_SIMULATION.JUMP_ARRIVAL_RADIUS, maxf(absf(hyperjump_arrival.x), absf(hyperjump_arrival.y)) * 0.00000012)
	if distance <= arrival_tolerance and velocity.length() <= SHIP_SIMULATION.JUMP_ARRIVAL_SPEED:
		ship_position = hyperjump_arrival
		ship_motion_remainder = Vector2.ZERO
		velocity = Vector2.ZERO
		angular_velocity = 0.0
		hyperjump_time = -1.0
		hyperjump_arrival_until = elapsed + 3.0
		thrust = 0.0
		return
	var route := _fleet_move_route(fleet[active_fleet_index], SHIP_STATE.absolute(galaxy_origin, ship_position),
		to_destination, velocity, jump_speed, jump_acceleration, ship_turn_speed, true)
	_steer_heading(route, ship_turn_speed, delta)
	var course := route.normalized()
	var alignment := smoothstep(0.94, 0.995, Vector2.from_angle(heading).dot(course))
	var arrival_speed := SHIP_SIMULATION.approach_speed(minf(distance, route.length()), jump_acceleration, TRAVEL_APPROACH_RATE)
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
	if game_started:
		_close_hyperjump_chart()
	else:
		home_menu.set_process_unhandled_input(false)
	engine_audio.silence()
	heritage_gun_audio.stop()
	set_process_unhandled_input(false)
	settings_layer = CanvasLayer.new()
	settings_layer.layer = 20
	add_child(settings_layer)
	_sync_simulation_driver()
	var menu := SETTINGS_MENU.new()
	menu.in_flight = game_started
	if game_started:
		_set_camera_zoom(camera_zoom)
		menu.initial_zoom = camera_zoom
		menu.minimum_zoom = _minimum_camera_zoom()
		menu.maximum_zoom = _maximum_camera_zoom()
		menu.save_requested.connect(_save_from_settings)
	menu.initial_graphics_quality = graphics_quality
	menu.initial_frame_cap = frame_cap
	menu.initial_vsync = vsync_enabled
	menu.initial_engine_volume = engine_audio.volume
	settings_layer.add_child(menu)
	menu.key_binding_changed.connect(func(): _save_graphics_settings())
	menu.engine_volume_changed.connect(func(value: float):
		engine_audio.volume = value
		_save_graphics_settings()
	)
	menu.graphics_quality_changed.connect(func(value: int):
		graphics_quality = clampi(value, 0, 2)
		_save_graphics_settings()
		if game_started:
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
		if game_started:
			_queue_flight_redraw()
	)
	menu.closed.connect(_close_settings)

func _close_settings() -> void:
	if not is_instance_valid(settings_layer):
		return
	settings_layer.queue_free()
	settings_layer = null
	if game_started:
		_sync_simulation_driver()
		set_process_unhandled_input(true)
	else:
		home_menu.set_process_unhandled_input(true)
		home_menu.focus_settings()

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
	engine_audio.silence()
	heritage_gun_audio.stop()
	set_process_unhandled_input(false)
	_save_active_fleet_ship()
	_create_ship_editor(custom_parts, "Return to flight", func(parts: Array):
		# A fresh editor design uses the performance shown in the editor, not old admin overrides.
		fleet[active_fleet_index].admin = {}
		_deploy_custom_ship(parts, false)
		if not save_slot.is_empty() and not _save_galaxy():
			_show_save_error()
	)

func _create_ship_editor(parts: Array, close_caption: String, launch: Callable) -> void:
	hangar_layer = CanvasLayer.new()
	hangar_layer.layer = 20
	add_child(hangar_layer)
	_sync_simulation_driver()
	var hangar := HANGAR.new()
	hangar.current_parts = parts.duplicate(true)
	hangar.close_caption = close_caption
	hangar.speed_unit = DISPLAY_KM_SPEED_UNIT
	hangar.performance_profile = func(design: Array): return _stats_with_admin(design, {})
	hangar.closed.connect(_close_hangar)
	hangar.launch_requested.connect(launch)
	hangar_layer.add_child(hangar)

func _close_hangar(restore_home := true) -> void:
	if not is_instance_valid(hangar_layer):
		return
	hangar_layer.queue_free()
	hangar_layer = null
	_sync_simulation_driver()
	set_process_unhandled_input(game_started)
	if restore_home and not game_started and is_instance_valid(home_menu):
		home_menu.set_process_unhandled_input(true)
		home_menu._show_setup()

func _deploy_custom_ship(parts: Array, use_type_default := true) -> void:
	if MODULES.validate(parts) != "":
		return
	if use_type_default and not fleet.is_empty():
		fleet[active_fleet_index].admin = _admin_for_new_ship(parts, {})
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
	_set_camera_zoom(camera_zoom)
	player_shield_delay = 0.0
	velocity = Vector2.ZERO
	boost_decelerating = false
	angular_velocity = 0.0
	thrust = 0.0
	_reset_player_exhaust()
	boost_time = 0.0
	rts_move_active = false
	rts_attack_active = false
	firing = false
	laser_active = false
	machine_gun_active = false
	hyperjump_time = -1.0
	hyperjump_arrival_until = 0.0
	_save_active_fleet_ship()
	_prepare_fleet_stats(fleet[active_fleet_index])
	_close_hangar()
	_queue_flight_redraw()

func _ensure_ship_cache() -> void:
	if ship_cache_ready:
		return
	var overrides: Dictionary = fleet[active_fleet_index].get("admin", {}) if not fleet.is_empty() else {}
	cached_ship_stats = _stats_with_admin(custom_parts, overrides)
	cached_ship_bounds = MODULES.bounds(custom_parts)
	cached_ship_scale = MODULES.length_scale(cached_ship_bounds.size.y / MODULES.WORLD_UNITS_PER_METER, overrides)
	has_flight_controls = cached_ship_stats.has_command_deck
	cached_engines.clear()
	cached_turret_mounts.clear()
	for light in player_visual.engine_lights:
		light.hide()
		light.queue_free()
	player_visual.engine_lights.clear()
	var center := cached_ship_bounds.get_center()
	SHIP_RELIEF.bake(player_visual.material, custom_parts, cached_ship_bounds, cached_ship_scale)
	player_visual.queue_redraw()
	for collider in player_fleet_body.get_children():
		player_fleet_body.remove_child(collider)
		collider.queue_free()
	_add_fleet_collision_shapes(player_fleet_body, custom_parts, cached_ship_bounds, cached_ship_scale)
	cached_hull_shapes.clear()
	cached_armour_borders = MODULES.armour_borders(custom_parts)
	var uses_shaped_hull := custom_parts.any(func(part: Dictionary) -> bool:
		return MODULES.is_exterior_structure(part) and (part.get("fine_grid", false) or part.type in ["wedge_half", "armor_wedge"] or MODULES.footprint(part).size != Vector2i.ONE)
	)
	for part in custom_parts:
		_collect_engine_nozzles(part, center, cached_engines, cached_ship_scale)
		if uses_shaped_hull and MODULES.is_exterior_structure(part):
			cached_hull_shapes.append_array(MODULES.material_polygons(part, (MODULES.part_position(part) - center) * cached_ship_scale, MODULES.cell_size_for(part) * cached_ship_scale))
	var slots: Array = cached_ship_stats.slots
	for index in slots.size():
		var slot: Dictionary = slots[index]
		if slot.type not in SHIP_CAPABILITIES.SLOT_WEAPONS:
			continue
		cached_turret_mounts.append({"x": 0, "y": 0, "slot_index": index, "turret": slot.type,
			"local_position": LOADOUT.local_position(slot, cached_ship_bounds, cached_ship_scale)})
	for engine in cached_engines:
		_add_engine_light(player_visual, engine.nozzle, engine.effect_scale)
	ship_cache_ready = true

func _collect_engine_nozzles(part: Dictionary, center: Vector2, engines: Array, ship_scale: float = 1.0) -> void:
	var first_engine := engines.size()
	if MODULES.PRESET_TEXTURES.has(part.type):
		var texture := MODULES.preset_texture(part)
		var sprite_rect := MODULES.preset_draw_rect(part, Vector2(part.x, part.y) * MODULES.CELL - center)
		var fit := sprite_rect.size.x / texture.get_size().x
		for mount in MODULES.PRESET_ENGINE_LAYOUTS.get(part.type, []):
			engines.append({"nozzle": Transform2D(0.0, sprite_rect.position + mount.pixel * fit), "size": mount.plume * fit})
		var outlets: Array = []
		var sizes: Array[Vector2] = []
		var flare_size := Vector2.ONE
		match part.type:
			"pixel_custom":
				_add_pixel_engine_nozzles(texture.get_image(), sprite_rect.position, fit, engines)
			"preset_scout":
				outlets = [Vector2(77, 496), Vector2(190, 496)]
				flare_size = Vector2(2.2, 1.15)
			MODULES.HD_LIGHT_CRUISER:
				outlets = [Vector2(56, 835), Vector2(111, 848), Vector2(226.5, 848), Vector2(281.5, 835)]
				sizes = [Vector2(4.0, 2.1), Vector2(4.8, 2.6), Vector2(4.8, 2.6), Vector2(4.0, 2.1)]
			"preset_armoured_starter":
				outlets = [Vector2(169, 1464), Vector2(591, 1464)]
				flare_size = Vector2(9.5, 6.0)
		for index in range(outlets.size()):
			var size := flare_size if sizes.is_empty() else sizes[index]
			engines.append({"nozzle": Transform2D(0.0, sprite_rect.position + outlets[index] * fit), "size": size * fit})
	if MODULES.ENGINE_NOZZLE_OFFSETS.has(part.type):
		var angle := float(int(part.rotation)) * PI / 2.0
		var position := MODULES.part_position(part) - center
		if part.type in MODULES.MAIN_ENGINE_TYPES:
			for outlet in MODULES.engine_nozzles(part, position):
				engines.append({"nozzle": Transform2D(angle, outlet.position), "size": Vector2(outlet.width, 1.0)})
		else:
			position = MODULES.mount_position(part) - center + Vector2.DOWN.rotated(angle) * MODULES.CELL * MODULES.ENGINE_NOZZLE_OFFSETS[part.type]
			engines.append({"nozzle": Transform2D(angle, position), "size": Vector2.ONE * 0.65})
	for index in range(first_engine, engines.size()):
		var engine: Dictionary = engines[index]
		var nozzle: Transform2D = engine.nozzle
		nozzle.origin *= ship_scale
		engine.nozzle = nozzle
		engine.size *= ship_scale
		engine.effect_scale = ship_scale

func _add_pixel_engine_nozzles(image: Image, origin: Vector2, fit: float, engines: Array) -> void:
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
		engines.append({"nozzle": Transform2D(0.0, origin + center * fit), "size": Vector2(width, length) * fit})

func _custom_stats() -> Dictionary:
	_ensure_ship_cache()
	return cached_ship_stats

func _stats_with_admin(parts: Array, admin: Dictionary) -> Dictionary:
	return SHIP_CAPABILITIES.build(parts, admin, {"speed": top_speed, "acceleration": acceleration, "turn": turn_speed,
		"boost": BOOST_TRAVEL_SPEED, "hyperdrive": HYPERJUMP_TRAVEL_SPEED, "speed_unit": DISPLAY_KM_SPEED_UNIT})

func _ship_capabilities(index: int) -> Dictionary:
	var ship: Dictionary = fleet[index]
	var profile := (_custom_stats() if index == active_fleet_index else ship.fleet_stats as Dictionary).duplicate()
	var cargo := {"iron": iron, "tritium": tritium} if index == active_fleet_index else ship.cargo as Dictionary
	profile.available_cargo_space = SHIP_CAPABILITIES.available_space(profile, cargo)
	return profile

func _ship_admin_versions(ship: Dictionary) -> Dictionary:
	return ship_version_catalog.get(ship.design_id, {}).get("versions", {})

func _admin_for_new_ship(parts: Array, fallback: Dictionary) -> Dictionary:
	var entry: Dictionary = ship_version_catalog.get(SHIP_STATE.design_id(parts), {})
	var default_name: String = entry.get("default", "")
	return fallback.duplicate(true) if default_name.is_empty() else entry.versions[default_name].duplicate(true)

func _set_default_ship_version(index: int, version_name: String) -> bool:
	if index < 0 or index >= fleet.size():
		return false
	var design_id: String = fleet[index].design_id
	var entry: Dictionary = ship_version_catalog.get(design_id, {})
	if not version_name.is_empty() and not entry.get("versions", {}).has(version_name):
		return false
	if entry.get("default", "") == version_name:
		return true
	var previous := ship_version_catalog
	ship_version_catalog = previous.duplicate()
	ship_version_catalog[design_id] = {"versions": entry.versions, "default": version_name}
	if _save_galaxy():
		return true
	ship_version_catalog = previous
	return false

func _apply_ship_admin(index: int, values: Dictionary, new_version := "") -> bool:
	if index < 0 or index >= fleet.size():
		return false
	if values.is_empty() and new_version.is_empty():
		return true
	var ship: Dictionary = fleet[index]
	if not new_version.is_empty() and (new_version != new_version.strip_edges() or not SHIP_VERSIONS.matching_name(_ship_admin_versions(ship), new_version).is_empty()):
		return false
	var updated: Dictionary = ship.admin.duplicate(true)
	updated.merge(values, true)
	var base_length := MODULES.dimensions_meters(ship.parts).y
	if values.has("length_meters") and (values.length_meters == snappedf(base_length, 0.001) or MODULES.length_scale(base_length, values) == 1.0):
		updated.erase("length_meters")
	return _commit_ship_admin(index, updated, new_version)

func _apply_ship_admin_version(index: int, version_name: String) -> bool:
	if index < 0 or index >= fleet.size():
		return false
	var versions := _ship_admin_versions(fleet[index])
	if not versions.has(version_name):
		return false
	# Replace overrides, so fields absent from this version go back to hull defaults.
	return _commit_ship_admin(index, versions[version_name].duplicate(true))

func _commit_ship_admin(index: int, updated: Dictionary, new_version := "") -> bool:
	_save_active_fleet_ship()
	var ship: Dictionary = fleet[index]
	var previous: Dictionary = ship.admin
	var previous_catalog := ship_version_catalog
	var previous_hull: float = ship.hull
	var previous_shield: float = ship.shield
	var base_length := MODULES.dimensions_meters(ship.parts).y
	var previous_scale := MODULES.length_scale(base_length, previous)
	ship.admin = updated
	if not new_version.is_empty():
		var versions := _ship_admin_versions(ship).duplicate()
		versions[new_version] = updated.duplicate(true)
		var entry: Dictionary = previous_catalog.get(ship.design_id, {})
		ship_version_catalog = previous_catalog.duplicate()
		ship_version_catalog[ship.design_id] = {"versions": versions, "default": entry.get("default", "")}
	var resized := not is_equal_approx(MODULES.length_scale(base_length, ship.admin), previous_scale)
	var updated_stats := _stats_with_admin(ship.parts, ship.admin)
	ship.hull = minf(previous_hull, float(updated_stats.health))
	ship.shield = minf(previous_shield, float(updated_stats.shield))
	if index == active_fleet_index:
		player_hull = ship.hull
		player_shield = ship.shield
	if not _save_galaxy():
		ship.admin = previous
		ship_version_catalog = previous_catalog
		ship.hull = previous_hull
		ship.shield = previous_shield
		if index == active_fleet_index:
			player_hull = previous_hull
			player_shield = previous_shield
		return false
	_prepare_fleet_stats(ship)
	if index == active_fleet_index:
		ship_cache_ready = false
		_ensure_ship_cache()
		if resized:
			_set_camera_zoom(camera_zoom)
	elif resized:
		_remove_fleet_view(ship.id)
		_remove_fleet_collider(ship.id)
		_sync_fleet_colliders()
	_queue_flight_redraw()
	return true

func _current_ship() -> Dictionary:
	var totals := _custom_stats()
	return {"speed": totals.speed, "acceleration": totals.acceleration, "turn": totals.maneuver, "boost": totals.boost, "hyperdrive": totals.hyperdrive}

func _player_max_hull() -> float:
	return _custom_stats().health

func _player_max_shield() -> float:
	return _custom_stats().shield

func _cargo_available() -> bool:
	return SHIP_CAPABILITIES.available_space(_custom_stats(), {"iron": iron, "tritium": tritium}) > 0

func _ship_size() -> Vector2:
	_ensure_ship_cache()
	return cached_ship_bounds.size * cached_ship_scale

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
			if not Rect2(_world_min() + Vector2.ONE * margin, world_size - Vector2.ONE * margin * 2.0).has_point(position):
				continue
			var separated := true
			for existing in enemies:
				if position.distance_to(existing.position) < radius + float(existing.radius) + 40.0:
					separated = false
					break
			if separated:
				break
		position = position.clamp(_world_min() + Vector2.ONE * margin, _world_max() - Vector2.ONE * margin)
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
	if _combat_locked():
		return
	auto_approach = false
	var candidates: Array[Dictionary] = []
	for i in range(enemies.size()):
		if enemies[i].alive:
			var distance: float = ship_position.distance_to(enemies[i].position)
			if distance <= TARGET_RANGE:
				candidates.append({"type": "enemy", "index": i, "distance": distance})
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
	if _combat_locked():
		return
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
	selected_asteroid = _pick_asteroid(world_position)

func _pick_asteroid(world_position: Vector2) -> int:
	# Keep clicks forgiving at flight zoom without grabbing distant rocks on the galaxy map.
	return MINING_CONTROLLER.pick_target(asteroids, world_position, minf(6.0 / camera_zoom, 600.0))

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
	return PROJECTILE_GEOMETRY.segment_ellipse_hit(start, end, center, ship_heading, radii)

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
	return PROJECTILE_GEOMETRY.segment_polygon_hit(start, end, shape)

func _asteroid_shot_contact(start: Vector2, end: Vector2) -> Variant:
	return PROJECTILE_GEOMETRY.asteroid_hit(start, end, asteroids)

func _player_shot_contact(start: Vector2, end: Vector2) -> Variant:
	var half_size := _ship_size() * 0.5
	if player_shield > 0.0:
		return _segment_ellipse_hit(start, end, ship_position, heading, half_size + Vector2.ONE * SHIELD_MARGIN * cached_ship_scale)
	if cached_hull_shapes.is_empty():
		return _segment_ellipse_hit(start, end, ship_position, heading, half_size * 0.7)
	return PROJECTILE_GEOMETRY.ship_hull_hit(start, end, ship_position, heading, cached_hull_shapes)

func _enemy_hull_contact(start: Vector2, end: Vector2, enemy: Dictionary) -> Variant:
	return PROJECTILE_GEOMETRY.ship_cells_hit(start, end, enemy.position, enemy.heading, enemy.exterior, MODULES.CELL * ENEMY_PART_SCALE)

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

func _draw_shield_impacts(enemy_index: int, dimensions: Vector2, canvas: CanvasItem, effect_scale: float = 1.0) -> void:
	var half_size := dimensions * 0.5 + Vector2.ONE * SHIELD_MARGIN * effect_scale
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
			var radius := half_size + Vector2.ONE * float(ring) * 5.0 * effect_scale
			var points := PackedVector2Array()
			var segments := 24 if graphics_quality == 2 else 12
			for i in range(segments + 1):
				var t := angle - width + float(i) / float(segments) * width * 2.0
				points.append(Vector2(cos(t) * radius.x, sin(t) * radius.y))
			var opacity := fade * (1.0 - wave * 0.35)
			canvas.draw_polyline(points, Color(0.15, 0.55, 1.0, 0.18 * opacity), 7.0 * effect_scale, true)
			canvas.draw_polyline(points, Color(0.52, 0.89, 1.0, 0.9 * opacity), (2.5 - float(ring) * 0.7) * effect_scale, true)
		var spark_fade := 1.0 - smoothstep(0.0, 0.4, progress)
		var hit_point := Vector2(cos(angle) * half_size.x, sin(angle) * half_size.y)
		for ray_data in impact.rays:
			var ray := Vector2.from_angle(ray_data.angle)
			var inner: float = 2.0 + progress * ray_data.speed * 0.65
			var tip: float = inner + ray_data.length * spark_fade
			canvas.draw_line(hit_point + ray * inner * effect_scale, hit_point + ray * tip * effect_scale, Color(0.78, 0.96, 1.0, spark_fade), ray_data.width * effect_scale, true)

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
		destination = destination.clamp(_world_min() + margin, _world_max() - margin)
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
	var inward := (position.clamp(_world_min() + edge_margin, _world_max() - edge_margin) - position) / edge_margin.x
	var intended := away * clampf(radial_speed, -speed, speed) + tangent * orbit_speed + inward * speed
	var steered := _enemy_steering(enemy, intended) * minf(intended.length(), speed)
	# Obstacle steering can turn inward. Limit closing speed as the fighter nears the player.
	var minimum_range := ENEMY_MIN_COMBAT_RANGE + extra_range
	var min_outward_speed := clampf(player_outward_speed + (minimum_range - distance) * 2.0, -speed, speed * 0.8)
	var outward_speed := maxf(steered.dot(away), min_outward_speed)
	var sideways_limit := sqrt(maxf(0.0, speed * speed - outward_speed * outward_speed))
	return away * outward_speed + tangent * clampf(steered.dot(tangent), -sideways_limit, sideways_limit)

func _turret_key(part: Dictionary) -> Vector3i:
	return Vector3i(int(part.x), int(part.y), int(part.get("slot_index", part.get("cruiser_index", -1))))

func _turret_angle(part: Dictionary) -> float:
	var rest_angle := heading + float(int(part.get("rotation", 0))) * PI / 2.0
	return float(turret_angles.get(_turret_key(part), rest_angle))

func _update_turrets(delta: float) -> void:
	_ensure_ship_cache()
	var target_position: Vector2 = asteroids[mining_asteroid].position if autonomous_mining_target else _aim_world_position()
	var tracked_turrets: Array = ["miner"] if autonomous_mining_target else WEAPON_SLOTS[selected_weapon - 1].turrets
	for part in cached_turret_mounts:
		var kind: String = part.turret
		var current := _turret_angle(part)
		var desired := heading + float(int(part.get("rotation", 0))) * PI / 2.0
		if not _combat_locked() and kind in tracked_turrets:
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
	for part in cached_turret_mounts:
		if part.get("turret", "") == kind and _turret_is_aimed(part, target_position):
			return true
	return false

func _aimed_mining_rate(target_position: Vector2) -> float:
	var rate := 0.0
	for part in cached_turret_mounts:
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
	combat_controller._update_combat(delta)

func _load_asteroids_near_ship() -> void:
	var index := solar_system.nearest_system(ship_position)
	if index == asteroid_system:
		return
	asteroid_system = index
	for asteroid in asteroids:
		var visual: Node2D = asteroid.visual
		visual.free()
	asteroids.clear()
	live_rocks.clear()
	autonomous_mining_target = false
	selected_asteroid = -1
	mining_asteroid = -1
	mining_progress = 0.0
	mining = false
	asteroid_effects.queue_redraw()
	var sites := GALAXY.asteroid_sites(galaxy_seed, solar_system.systems[index], solar_system.system_contents(index))
	for i in sites.size():
		var site := sites[i]
		var id := _asteroid_site_id(index, i, site)
		_add_asteroid(solar_system.local_point(site.position.x, site.position.y), site.radius, site.ore, id,
			SHIP_STATE.point(site.position.x, site.position.y))

func _add_asteroid(position: Vector2, radius: float, ore: float, id: String, absolute := PackedFloat64Array()) -> void:
	var asteroid := ASTEROID_FACTORY.create(position, radius, ore, id, galaxy_seed, depleted_ore)
	asteroid.galaxy_position = absolute if not absolute.is_empty() else SHIP_STATE.absolute(galaxy_origin, position)
	asteroid.index = asteroids.size()
	live_rocks[id] = asteroid
	var visual := _add_draw_layer(asteroid_visuals, func(canvas: CanvasItem): _draw_asteroid(asteroid, canvas))
	visual.position = position
	asteroid_visuals.move_child(visual, asteroid_effects.get_index())
	asteroid.visual = visual
	asteroids.append(asteroid)

func _draw_asteroid(asteroid: Dictionary, canvas: CanvasItem) -> void:
	var radius: float = asteroid.radius
	var shape: PackedVector2Array = asteroid.shape
	# UVs cover the whole silhouette and stay fixed in rock-local coordinates.
	var uv := PackedVector2Array()
	for point in shape:
		uv.append(point / (radius * 2.0) + Vector2(0.5, 0.5))
	canvas.draw_polygon(shape, PackedColorArray([Color.WHITE]), uv)

func _screen_to_world(point: Vector2, clamp_to_world: bool = true) -> Vector2:
	var world_position := _camera_center() + (point - get_viewport_rect().size * 0.5) / camera_zoom
	return world_position.clamp(_world_min(), _world_max()) if clamp_to_world else world_position

func _aim_world_position() -> Vector2:
	if rts_attack_active:
		if selected_enemy >= 0 and selected_enemy < enemies.size() and enemies[selected_enemy].alive:
			return enemies[selected_enemy].position
		if selected_asteroid >= 0 and selected_asteroid < asteroids.size() and asteroids[selected_asteroid].iron > 0:
			return asteroids[selected_asteroid].position
	return _screen_to_world(get_viewport().get_mouse_position())

func _fleet_ship_at_screen(screen_position: Vector2) -> int:
	var anchor := _camera_anchor()
	for i in range(fleet.size() - 1, -1, -1):
		var ship: Dictionary = fleet[i]
		var active := i == active_fleet_index
		var ship_heading: float = heading if active else float(ship.heading)
		var dimensions: Vector2 = _ship_size() if active else ship.bounds_size
		var offset := screen_position - _fleet_screen_position(i, anchor)
		if dimensions.y * camera_zoom < FLEET_HULL_FULL_PIXELS and offset.length_squared() <= 64.0:
			return i
		var local := (offset / camera_zoom).rotated(-ship_heading - PI / 2.0)
		if not Rect2(-dimensions * 0.5, dimensions).has_point(local):
			continue
		if active:
			for collider in player_fleet_body.get_children():
				if Geometry2D.is_point_in_polygon(local, collider.polygon):
					return i
		else:
			# Remote hulls are selectable without adding them to the physics bubble.
			var shapes: Array[PackedVector2Array] = fleet_colliders[ship.id].hull_shapes if fleet_colliders.has(ship.id) else _fleet_hull_shapes(ship.parts, MODULES.bounds(ship.parts), ship.ship_scale)
			for shape in shapes:
				if Geometry2D.is_point_in_polygon(local, shape):
					return i
	return -1

func _mining_block_reason(index: int) -> String:
	var profile := _ship_capabilities(index)
	if profile.mining_rate <= 0.0:
		return "No mining laser equipped."
	if profile.cargo_capacity <= 0:
		return "Ship has no cargo capacity."
	var cargo: Dictionary = {"iron": iron, "tritium": tritium} if index == active_fleet_index else fleet[index].cargo
	return "Cargo hold is full." if SHIP_CAPABILITIES.available_space(profile, cargo) <= 0 else ""

func _issue_mining_order(rock: int, append: bool) -> void:
	var accepted := 0
	var first_problem := ""
	for index in selected_fleet:
		var reason := _mining_block_reason(index)
		if reason == "":
			if _submit_fleet_order(index, "mine", asteroids[rock].id, 1.0, true, append):
				accepted += 1
				continue
			reason = "Mining order could not be queued."
		if first_problem == "":
			first_problem = "%s: %s" % [fleet[index].name, reason]
	if accepted == 0:
		_show_order_notice(first_problem)
	elif accepted < selected_fleet.size():
		_show_order_notice("Mining ordered for %d of %d selected ships. %s" % [accepted, selected_fleet.size(), first_problem])

func _rts_issue_order(screen_position: Vector2, append := false) -> void:
	if selected_fleet.is_empty():
		return
	var destination := _screen_to_world(screen_position)
	var target_at := _screen_to_world(screen_position, false)
	var rock := _pick_asteroid(target_at)
	if rock >= 0:
		_issue_mining_order(rock, append)
		return
	var positions: Array[Vector2] = []
	for index in selected_fleet:
		positions.append(ship_position if index == active_fleet_index else _ship_local(fleet[index]))
	var translation := FLEET_AVOIDANCE.formation_translation(positions, destination, _world_min(), _world_max())
	for slot in selected_fleet.size():
		var index := selected_fleet[slot]
		if index == active_fleet_index and not append and not _combat_locked():
			var previous_enemy := selected_enemy
			var previous_asteroid := selected_asteroid
			_select_target_at(target_at)
			if selected_enemy >= 0:
				_cancel_fleet_orders(index)
				rts_attack_active = true
				rts_move_active = false
				mining_progress = 0.0
				continue
			selected_enemy = previous_enemy
			selected_asteroid = previous_asteroid
		var local_target := positions[slot] + translation
		_submit_fleet_order(index, "move", SHIP_STATE.absolute(galaxy_origin, local_target), 0.0, false, append)

func _finish_rts_selection(screen_position: Vector2) -> void:
	rts_dragging = false
	rts_drag_end = screen_position
	var selection := Rect2(rts_drag_start, rts_drag_end - rts_drag_start).abs()
	if selection.size.length() > 8.0:
		selected_fleet.clear()
		var anchor := _camera_anchor()
		for index in range(fleet.size()):
			var dimensions: Vector2 = _ship_size() if index == active_fleet_index else fleet[index].bounds_size
			var ship_screen := _fleet_screen_position(index, anchor)
			var radius := maxf(dimensions.length() * 0.5 * camera_zoom, 12.0)
			if selection.intersects(Rect2(ship_screen - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)):
				selected_fleet.append(index)
		if not selected_fleet.is_empty() and not selected_fleet.has(active_fleet_index):
			var group := selected_fleet.duplicate()
			_switch_fleet_control(group[0])
			selected_fleet.assign(group)
	else:
		var clicked_ship := _fleet_ship_at_screen(screen_position)
		if clicked_ship >= 0:
			_switch_fleet_control(clicked_ship)
		else:
			var rock := _pick_asteroid(_screen_to_world(screen_position, false))
			if rock >= 0:
				if rts_attack_active:
					rts_attack_active = false
					firing = false
				selected_enemy = -1
				selected_asteroid = rock
				if selected_fleet.is_empty():
					_show_order_notice("Select a mining ship, then right-click the asteroid to mine it.")
				else:
					_show_order_notice("Right-click the asteroid to mine it with the selected ships.")
			else:
				selected_fleet.clear()
				selected_asteroid = -1
	rts_selected = selected_fleet.has(active_fleet_index)
	_queue_flight_redraw()

func _input(event: InputEvent) -> void:
	game_input._input(event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and game_started and not _save_galaxy():
		push_warning("The galaxy could not be saved when the window closed.")
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		firing = false
		rts_dragging = false
		radial_menu_open = false
		camera_dragging = false
		
func _make_rocket(origin: Vector2, angle: float, carrier_velocity: Vector2, friendly: bool, damage: float, scale_factor: float = 1.0) -> Dictionary:
	return ROCKET_PROJECTILE.create(origin, angle, carrier_velocity, friendly, damage, scale_factor)

func _update_rocket(shot: Dictionary, delta: float) -> void:
	ROCKET_PROJECTILE.update(shot, ship_position, delta)

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

func _update_mining(delta: float) -> void:
	mining = false
	laser_active = firing and selected_weapon == 2
	mining_asteroid = MINING_CONTROLLER.find_target(asteroids, _aim_world_position()) if laser_active else -1
	if mining_asteroid < 0:
		return
	var asteroid: Dictionary = asteroids[mining_asteroid]
	if ship_position.distance_to(asteroid.position) > MINING_CONTROLLER.mining_range(asteroid.radius, _ship_half_length()):
		return
	var rate := _aimed_mining_rate(asteroid.position)
	var capacity_left := SHIP_CAPABILITIES.available_space(_custom_stats(), {"iron": iron, "tritium": tritium})
	var result := MINING_CONTROLLER.tick(asteroid.iron, mining_progress, rate, capacity_left, delta)
	mining_progress = result.progress
	mining = result.active
	if result.extracted > 0:
		iron += _extract_ore(asteroid.id, result.extracted)
	if result.depleted:
		if selected_asteroid == mining_asteroid:
			selected_asteroid = -1
		mining_asteroid = -1
		laser_active = false
		machine_gun_active = false

func _unhandled_input(event: InputEvent) -> void:
	game_input._unhandled_input(event)

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
	return _hull_circle_push(center - ship_position, radius, heading + PI / 2.0, cached_hull_shapes)

func _hull_circle_push(offset: Vector2, radius: float, rotation: float, hull_shapes: Array[PackedVector2Array]) -> Vector2:
	var local := offset.rotated(-rotation)
	var push := Vector2.ZERO
	for shape in hull_shapes:
		var nearest_distance := INF
		var nearest := Vector2.ZERO
		var edge_normal := Vector2.ZERO
		var winding := -1.0 if Geometry2D.is_polygon_clockwise(shape) else 1.0
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
	target = target.clamp(_world_min(), _world_max())
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
			# Keep ordered jumps in their braking phase after a hull contact;
			# aborting here would make the order start the jump again next tick.
			if hyperjump_time >= 0.0 and SHIP_ORDER_QUEUE.current(fleet[active_fleet_index]).get("type") != "hyperjump":
				hyperjump_time = -1.0
				boost_decelerating = true
		motion = hit.get_remainder()
		motion -= normal * minf(0.0, motion.dot(normal))
		if motion.is_zero_approx():
			break
	ship_position = player_fleet_body.position.clamp(_world_min(), _world_max())

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
			enemy.position = (enemy.position as Vector2).clamp(_world_min(), _world_max())
		ship_position = ship_position.clamp(_world_min(), _world_max())

func _turn_acceleration(max_turn_rate: float) -> float:
	return FLIGHT_NAVIGATION.turn_acceleration(max_turn_rate)

func _steered_rotation(angle: float, rate: float, direction: Vector2, max_turn_rate: float, delta: float) -> Vector2:
	return FLIGHT_NAVIGATION.steered_rotation(angle, rate, direction, max_turn_rate, delta)

func _steer_heading(direction: Vector2, max_turn_rate: float, delta: float) -> void:
	var rotation := _steered_rotation(heading, angular_velocity, direction, max_turn_rate, delta)
	heading = rotation.x
	angular_velocity = rotation.y

func _steer_other_ship(ship: Dictionary, direction: Vector2, delta: float) -> void:
	var rotation := _steered_rotation(ship.heading, ship.angular_velocity, direction, ship.turn_speed, delta)
	ship.heading = rotation.x
	ship.angular_velocity = rotation.y

func _update_idle_flight(speed_limit: float, ship_acceleration: float, ship_turn_speed: float, boosting: bool, delta: float) -> void:
	var max_turn_rate := ship_turn_speed * (0.55 if boosting else 1.0)
	angular_velocity = move_toward(angular_velocity, 0.0, _turn_acceleration(max_turn_rate) * delta)
	heading = wrapf(heading + angular_velocity * delta, -PI, PI)
	thrust = move_toward(thrust, 0.0, delta * THROTTLE_RAMP)
	# Old saves can still contain a burst already in progress.
	if boosting:
		var envelope := _boost_burst_envelope()
		engine_boost_target = envelope * lerpf(0.35, 1.0, boost_power)
		var boost_force := ship_acceleration * lerpf(1.35, 3.6, boost_power) * envelope
		var burst_limit := speed_limit * lerpf(1.75, 3.0, boost_power)
		velocity = (velocity + Vector2.from_angle(heading) * boost_force * delta).limit_length(maxf(burst_limit, velocity.length()))
		return
	velocity *= exp(-drag * delta)
	if velocity.length_squared() < 0.25:
		velocity = Vector2.ZERO
	if velocity.length() > speed_limit and ship_acceleration > 0.0:
		velocity = velocity.normalized() * move_toward(velocity.length(), speed_limit, ship_acceleration * 0.7 * delta)

func _jump_peer_stop_time(other: Dictionary, piloted: bool, position: PackedFloat64Array, motion: Vector2) -> float:
	var target: PackedFloat64Array
	if piloted and hyperjump_time >= 0.0:
		target = hyperjump_galaxy_target
	elif not piloted and other.navigation.mode == "jump":
		target = other.navigation.target
	else:
		return INF
	var speed_squared := motion.length_squared()
	if speed_squared <= 0.001:
		return INF
	var remaining := SHIP_STATE.relative(target, position)
	var time := remaining.dot(motion) / speed_squared
	var braking := float(other.fleet_stats.hyperdrive) / HYPERJUMP_ACCELERATION_SECONDS
	# Only cap the projection if the ship is on course and can stop in time.
	if time <= 0.0 or speed_squared > 2.0 * braking * motion.length() * time:
		return INF
	return time if remaining.distance_squared_to(motion * time) <= SHIP_SIMULATION.JUMP_ARRIVAL_RADIUS ** 2 else INF

func _fleet_move_route(ship: Dictionary, position: PackedFloat64Array, destination: Vector2, current: Vector2, speed_limit: float, braking: float, turn: float, jumping := false) -> Vector2:
	if fleet.size() <= 1 or destination.length_squared() <= 16.0:
		return destination
	var route := destination
	var goal_distance := destination.length()
	var final_jump_approach := jumping and goal_distance <= maxf(JUMP_FINAL_APPROACH_RANGE, float(ship.radius) * 4.0)
	var waypoint := Vector2.ZERO
	var detour: Dictionary = fleet_detours.get(ship.id, {})
	if not detour.is_empty() and SHIP_STATE.relative(detour.destination, position).distance_squared_to(destination) <= 16.0:
		waypoint = SHIP_STATE.relative(detour.waypoint, position)
	if waypoint.length_squared() <= 100.0:
		waypoint = Vector2.ZERO
		fleet_detours.erase(ship.id)
	elif not final_jump_approach:
		route = waypoint
	var jump_distance := goal_distance if jumping else INF
	var encounter := _fleet_route_encounter(ship, position, route, current, speed_limit, braking, turn, jump_distance)
	if encounter.z == 0.0:
		if final_jump_approach:
			# Return to the assigned slot as soon as the direct approach is clear.
			fleet_detours.erase(ship.id)
		return route
	var threat := Vector2(encounter.x, encounter.y)
	if threat.distance_squared_to(destination) < encounter.z * encounter.z:
		# Do not finish the order or try to force our way into an occupied slot.
		return Vector2.ZERO
	if final_jump_approach and not waypoint.is_zero_approx():
		route = waypoint
		encounter = _fleet_route_encounter(ship, position, route, current, speed_limit, braking, turn, jump_distance)
		if encounter.z == 0.0:
			return route
		threat = Vector2(encounter.x, encounter.y)
	var local := SHIP_STATE.relative(position, galaxy_origin)
	waypoint = FLEET_AVOIDANCE.detour(route.normalized(), threat, encounter.z, _world_min() - local, _world_max() - local)
	if not waypoint.is_zero_approx():
		fleet_detours[ship.id] = {"destination": SHIP_STATE.absolute(position, destination), "waypoint": SHIP_STATE.absolute(position, waypoint)}
	return waypoint

# Return the first projected obstacle (xy offset, z clearance), or zero.
func _fleet_route_encounter(ship: Dictionary, position: PackedFloat64Array, route: Vector2, current: Vector2, speed_limit: float, braking: float, turn: float, jump_distance: float) -> Vector3:
	var jumping := jump_distance < INF
	var course := route.normalized()
	var approach_speed := minf(speed_limit, minf(route.length() * 3.0, maxf(current.dot(course), minf(braking * 0.65, 600.0))))
	if jumping:
		var commanded_speed := SHIP_SIMULATION.approach_speed(minf(jump_distance, route.length()), braking, TRAVEL_APPROACH_RATE)
		approach_speed = maxf(current.dot(course), minf(approach_speed, commanded_speed))
	if approach_speed <= 0.0:
		return Vector3.ZERO
	var horizon := clampf(0.6 + approach_speed / maxf(braking, 1.0) + 1.2 / maxf(turn, 0.2), 1.5, 8.0)
	var travel_time := minf(horizon, route.length() / approach_speed)
	var threat_time := INF
	var threat := Vector2.ZERO
	var clearance := 0.0
	for other: Dictionary in fleet:
		if other.id == ship.id:
			continue
		var piloted: bool = other.id == fleet[active_fleet_index].id
		var other_position: PackedFloat64Array = SHIP_STATE.absolute(galaxy_origin, ship_position) if piloted else other.galaxy_position
		var offset := SHIP_STATE.relative(other_position, position)
		var other_velocity: Vector2 = velocity if piloted else other.velocity
		var safe := FLEET_AVOIDANCE.clearance(ship.radius, other.radius)
		var stop_time := _jump_peer_stop_time(other, piloted, other_position, other_velocity) if jumping else INF
		var time := FLEET_AVOIDANCE.encounter_with_stop(offset, course * approach_speed, other_velocity, safe, travel_time, stop_time)
		if time >= threat_time:
			continue
		threat_time = time
		threat = offset + other_velocity * minf(time, stop_time)
		clearance = safe
	return Vector3(threat.x, threat.y, clearance)

func _update_rts_flight(speed_limit: float, ship_acceleration: float, ship_turn_speed: float, delta: float) -> void:
	var to_destination := rts_destination - ship_position
	var distance := to_destination.length()
	if _at_flight_destination(distance, 3.0, 4.0):
		rts_move_active = false
		velocity = Vector2.ZERO
		_steer_heading(Vector2.ZERO, ship_turn_speed, delta)
		thrust = move_toward(thrust, 0.0, delta * THROTTLE_RAMP)
		return
	var braking_acceleration := ship_acceleration * 0.55
	var route := _fleet_move_route(fleet[active_fleet_index], SHIP_STATE.absolute(galaxy_origin, ship_position),
		to_destination, velocity, speed_limit, braking_acceleration, ship_turn_speed)
	_steer_heading(route, ship_turn_speed, delta)
	var forward := Vector2.from_angle(heading)
	var course := route.normalized()
	var alignment := smoothstep(0.98, 0.995, forward.dot(course))
	var route_distance := route.length()
	var arrival_speed := minf(route_distance * RTS_APPROACH_RATE, sqrt(2.0 * braking_acceleration * route_distance) * 0.8)
	var cruise_fraction := lerpf(1.0, alignment, smoothstep(RTS_DOCKING_DISTANCE, RTS_DOCKING_DISTANCE * 3.0, distance))
	var desired_velocity := course * minf(speed_limit, arrival_speed) * cruise_fraction
	var engine_demand := clampf((desired_velocity - velocity).dot(forward) / maxf(ship_acceleration * 0.5, 1.0), 0.0, 1.0) * alignment
	var cruise_power := 0.58 * _navigation_exhaust(course, desired_velocity.length(), alignment, delta)
	engine_throttle_target = maxf(engine_demand, cruise_power)
	thrust = move_toward(thrust, engine_demand, delta * THROTTLE_RAMP)
	var correction := braking_acceleration + (ship_acceleration - braking_acceleration) * thrust
	velocity = _navigation_velocity(velocity, forward, course, minf(speed_limit, arrival_speed), correction, delta)

func _physics_process(_real_step: float) -> void:
	if simulation_clock.paused or _simulation_menu_open():
		return
	simulation_clock.advance()
	_step_flight(SIMULATION_CLOCK.STEP)
	simulation_scheduler.run_due(elapsed)
	_queue_flight_redraw()

func _step_flight(delta: float) -> void:
	_update_owned_fleet(delta)
	var autonomous := _drive_active_order(delta)
	engine_throttle_target = 0.0
	engine_boost_target = 0.0
	var valid_enemy: bool = selected_enemy >= 0 and selected_enemy < enemies.size() and enemies[selected_enemy].alive
	var valid_asteroid: bool = selected_asteroid >= 0 and selected_asteroid < asteroids.size() and asteroids[selected_asteroid].iron > 0
	if rts_attack_active and not valid_enemy and not valid_asteroid:
		rts_attack_active = false
	firing = rts_attack_active and not _combat_locked()
	if _combat_locked():
		_clear_combat_control()
	_update_turrets(delta)
	var ship := _current_ship()
	if not has_flight_controls:
		angular_velocity = 0.0
		thrust = 0.0
		boost_time = 0.0
	var boosting := boost_time > 0.0
	if boosting:
		boost_time = maxf(0.0, boost_time - delta)
	var acceleration_factor: float = ship.acceleration
	var speed_factor: float = ship.speed
	var ship_acceleration := acceleration * acceleration_factor
	var speed_limit := top_speed * speed_factor
	# At speed, a ship needs a wider arc and more time to change its heading.
	var speed_fraction := clampf(velocity.length() / maxf(speed_limit, 1.0), 0.0, 1.0)
	var ship_turn_speed := turn_speed * float(ship.turn) * lerpf(1.0, 0.45, speed_fraction)
	if not autonomous:
		_update_mining(delta)
	if hyperjump_time >= 0.0:
		var cruise_speed := _hyperjump_cruise_speed()
		var jump_acceleration := cruise_speed / HYPERJUMP_ACCELERATION_SECONDS
		_update_hyperjump(cruise_speed, jump_acceleration, ship_turn_speed, delta)
	elif sustained_boost_enabled and boost_destination_active:
		_update_boost_destination(float(ship.boost), BOOST_TRAVEL_ACCELERATION * acceleration_factor, ship_turn_speed, delta)
	elif sustained_boost_enabled and sustained_boost_direction != Vector2.ZERO:
		var boost_speed: float = ship.boost
		var boost_acceleration := BOOST_TRAVEL_ACCELERATION * acceleration_factor
		var movement_acceleration := _boost_acceleration(boost_speed, boost_acceleration) if boost_speed > velocity.length() else boost_acceleration
		_steer_heading(sustained_boost_direction, ship_turn_speed, delta)
		var forward := Vector2.from_angle(heading)
		var alignment := smoothstep(0.98, 0.995, forward.dot(sustained_boost_direction))
		velocity = _navigation_velocity(velocity, forward, sustained_boost_direction, boost_speed, movement_acceleration, delta)
		thrust = move_toward(thrust, alignment, delta * 5.0)
		engine_boost_target = alignment
	elif boost_decelerating and not rts_move_active:
		velocity = velocity.move_toward(Vector2.ZERO, maxf(1.0, ship_acceleration * 2.0) * delta)
		boost_decelerating = velocity != Vector2.ZERO
		_steer_heading(Vector2.ZERO, ship_turn_speed, delta)
		thrust = move_toward(thrust, 0.0, delta * 5.0)
	elif active_order_hold:
		velocity = velocity.move_toward(Vector2.ZERO, maxf(1.0, ship_acceleration) * 1.25 * delta)
		_steer_heading(Vector2.ZERO, ship_turn_speed, delta)
		thrust = move_toward(thrust, 0.0, delta * THROTTLE_RAMP)
	elif has_flight_controls and rts_move_active:
		_update_rts_flight(speed_limit, ship_acceleration, ship_turn_speed, delta)
	else:
		_update_idle_flight(speed_limit, ship_acceleration, ship_turn_speed, boosting, delta)
	if not rts_move_active and not boost_destination_active and hyperjump_time < 0.0:
		fleet_detours.erase(fleet[active_fleet_index].id)
	# Keep the ship inside the large play area.
	_advance_player(delta)
	var world_min := _world_min()
	var world_max := _world_max()
	if ship_position.x <= world_min.x or ship_position.x >= world_max.x:
		velocity.x = 0.0
	if ship_position.y <= world_min.y or ship_position.y >= world_max.y:
		velocity.y = 0.0
	if sustained_boost_enabled and not boost_destination_active and sustained_boost_direction != Vector2.ZERO:
		var at_edge := (ship_position.x <= world_min.x and sustained_boost_direction.x < 0.0) or (ship_position.x >= world_max.x and sustained_boost_direction.x > 0.0) or (ship_position.y <= world_min.y and sustained_boost_direction.y < 0.0) or (ship_position.y >= world_max.y and sustained_boost_direction.y > 0.0)
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
	_maybe_rebase_world()
	_load_asteroids_near_ship()
	_collect_tritium(delta)
	_update_debris(delta)
	_update_player_exhaust(delta)
	_update_exhaust_particles(delta)
	_commit_active_ship_state()

func _update_owned_fleet(delta: float) -> void:
	player_fleet_body.position = ship_position
	player_fleet_body.rotation = heading + PI / 2.0
	_sync_fleet_colliders()
	for index in fleet.size():
		if index == active_fleet_index:
			continue
		var ship: Dictionary = fleet[index]
		var nav: Dictionary = ship.navigation
		# A boost already under way takes precedence over orders even off-screen.
		var boosting: bool = nav.mode == "boost" and (nav.has("target") or nav.direction != Vector2.ZERO)
		if not ship.orders.is_empty() and not boosting:
			_run_fleet_order(ship, delta)
		var stats: Dictionary = ship.fleet_stats
		var recharge := maxf(0.0, delta - float(ship.shield_delay))
		ship.shield_delay = maxf(0.0, float(ship.shield_delay) - delta)
		if recharge > 0.0:
			ship.shield = minf(stats.shield, ship.shield + float(stats.shield_recharge) * recharge)
		var engine_target := _step_parked_navigation(ship, delta)
		var motion: Vector2 = ship.velocity * delta
		if fleet_colliders.has(ship.id):
			var collider: Dictionary = fleet_colliders[ship.id]
			var body: CharacterBody2D = collider.body
			var local := _ship_local(ship)
			body.position = local
			body.rotation = float(ship.heading) + PI / 2.0
			if not motion.is_zero_approx():
				var contact := body.move_and_collide(motion)
				if contact != null:
					ship.velocity = (ship.velocity as Vector2).slide(contact.get_normal())
					motion = body.position - local
			var destination := local + motion
			motion += _resolve_fleet_asteroid_contacts(ship, collider.hull_shapes, destination) - destination
		if fleet_views.has(ship.id):
			var view: Dictionary = fleet_views[ship.id]
			var flame_rate := ENGINE_IGNITION_RATE if engine_target > float(view.engine_flame) else ENGINE_FADE_RATE
			view.engine_flame = move_toward(float(view.engine_flame), engine_target, flame_rate * delta)
		if not motion.is_zero_approx():
			SHIP_SIMULATION.integrate(ship, motion, world_size)
		if fleet_colliders.has(ship.id):
			fleet_colliders[ship.id].body.position = _ship_local(ship)

func _resolve_fleet_asteroid_contacts(ship: Dictionary, hull_shapes: Array[PackedVector2Array], position: Vector2) -> Vector2:
	var rotation := float(ship.heading) + PI / 2.0
	for pass_index in range(3):
		var contact := false
		for rock in asteroids:
			if rock.iron <= 0:
				continue
			var offset: Vector2 = rock.position - position
			var radius: float = rock.radius * 0.90
			var limit: float = ship.radius + radius
			if offset.length_squared() >= limit * limit:
				continue
			var push := _hull_circle_push(offset, radius, rotation, hull_shapes)
			if push.is_zero_approx():
				continue
			contact = true
			position += push
			var normal := push.normalized()
			var inward: float = ship.velocity.dot(normal)
			ship.velocity -= normal * minf(inward, 0.0)
		if not contact:
			break
	return position

func _step_parked_navigation(ship: Dictionary, delta: float) -> float:
	var stats: Dictionary = ship.fleet_stats
	var nav: Dictionary = ship.navigation
	var current: Vector2 = ship.velocity
	var speed_limit: float = stats.normal_speed
	var accel: float = stats.travel_acceleration
	var turn: float = stats.turn_rate
	if not ship.can_fly or speed_limit <= 0.0:
		ship.navigation = {"mode": "idle"}
		ship.velocity = Vector2.ZERO
		return 0.0
	if nav.mode == "hold":
		fleet_detours.erase(ship.id)
		ship.velocity = current.move_toward(Vector2.ZERO, maxf(1.0, accel) * 1.25 * delta)
		if ship.velocity.is_zero_approx():
			ship.navigation = {"mode": "idle"}
		return 0.0
	if nav.mode == "move":
		var offset := SHIP_STATE.relative(nav.target, ship.galaxy_position)
		var route := _fleet_move_route(ship, ship.galaxy_position, offset, current, speed_limit, accel, turn)
		if route.is_zero_approx() and offset.length() > FLIGHT_NAVIGATION.MOVE_ARRIVAL_RADIUS:
			ship.velocity = current.move_toward(Vector2.ZERO, accel * delta)
			return 0.0
		var step := FLIGHT_NAVIGATION.move_order_step(Vector2.ZERO, ship.heading, current, route, speed_limit, accel, turn, RTS_APPROACH_RATE, delta)
		ship.heading = step.heading
		ship.velocity = step.velocity
		if step.arrived and offset.length() <= FLIGHT_NAVIGATION.MOVE_ARRIVAL_RADIUS:
			ship.navigation = {"mode": "idle"}
			fleet_detours.erase(ship.id)
		return step.engine_target
	if nav.mode in ["jump", "boost"]:
		var jump: bool = nav.mode == "jump"
		var offset := SHIP_STATE.relative(nav.target, ship.galaxy_position) if nav.has("target") else Vector2.ZERO
		var course := offset.normalized() if nav.has("target") else (nav.direction as Vector2)
		var distance := offset.length()
		var arrival_radius := SHIP_SIMULATION.JUMP_ARRIVAL_RADIUS if jump else BOOST_ARRIVAL_RADIUS
		var arrival_speed := SHIP_SIMULATION.JUMP_ARRIVAL_SPEED if jump else BOOST_ARRIVAL_SPEED
		if nav.has("target") and distance <= arrival_radius and current.length() <= arrival_speed:
			fleet_detours.erase(ship.id)
			ship.galaxy_position = nav.target
			ship.velocity = Vector2.ZERO
			ship.angular_velocity = 0.0
			ship.navigation = {"mode": "idle"}
			return 0.0
		var turn_rate := turn * lerpf(1.0, 0.45, clampf(current.length() / maxf(speed_limit, 1.0), 0.0, 1.0))
		var travel_speed: float = stats.hyperdrive if jump else stats.boost
		var travel_accel := travel_speed / HYPERJUMP_ACCELERATION_SECONDS if jump else BOOST_TRAVEL_ACCELERATION * float(stats.acceleration)
		if nav.has("target"):
			var route := _fleet_move_route(ship, ship.galaxy_position, offset, current, travel_speed, travel_accel, turn_rate, jump)
			course = route.normalized()
			distance = minf(distance, route.length()) if jump else route.length()
		_steer_parked(ship, course, turn_rate, delta)
		var forward := Vector2.from_angle(ship.heading)
		if jump:
			nav.time += delta
			var target_speed := minf(travel_speed, SHIP_SIMULATION.approach_speed(distance, travel_accel, TRAVEL_APPROACH_RATE))
			var alignment := smoothstep(0.94, 0.995, forward.dot(course))
			ship.velocity = current.move_toward(course * target_speed * alignment, travel_accel * delta)
			return alignment
		var target_speed := minf(travel_speed, _boost_approach_speed(distance, travel_accel)) if nav.has("target") else travel_speed
		var thrust_accel := SHIP_SIMULATION.boost_acceleration(travel_speed, travel_accel, current) if target_speed > current.length() else travel_accel
		ship.velocity = _navigation_velocity(current, forward, course, target_speed, thrust_accel, delta)
		return smoothstep(0.98, 0.995, forward.dot(course))
	fleet_detours.erase(ship.id)
	if nav.mode == "burst":
		nav.time = maxf(0.0, float(nav.time) - delta)
		var power: float = nav.power
		var progress := 1.0 - float(nav.time) / maxf(float(nav.duration), 0.001)
		var envelope := smoothstep(0.0, 0.24, progress) * (1.0 - smoothstep(0.68, 1.0, progress))
		var force := accel * lerpf(1.35, 3.6, power) * envelope
		ship.velocity = (current + Vector2.from_angle(ship.heading) * force * delta).limit_length(maxf(speed_limit * lerpf(1.75, 3.0, power), current.length()))
		if nav.time <= 0.0:
			ship.navigation = {"mode": "drift"}
		return envelope
	if nav.mode == "decelerate":
		ship.velocity = current.move_toward(Vector2.ZERO, maxf(1.0, accel * 2.0) * delta)
		if ship.velocity == Vector2.ZERO:
			ship.navigation.mode = "idle"
	else:
		var drift_velocity := current * exp(-drag * delta)
		ship.velocity = drift_velocity if drift_velocity.length_squared() >= 0.25 else Vector2.ZERO
		ship.navigation.mode = "drift" if ship.velocity != Vector2.ZERO else "idle"
	return 0.0

func _steer_parked(ship: Dictionary, direction: Vector2, turn_rate: float, delta: float) -> void:
	var rotation_step := _steered_rotation(ship.heading, ship.angular_velocity, direction, turn_rate, delta)
	ship.heading = rotation_step.x
	ship.angular_velocity = rotation_step.y

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
	if marked_asteroid < 0 or marked_asteroid >= asteroids.size() or asteroids[marked_asteroid].iron <= 0:
		marked_asteroid = mining_asteroid
	if marked_asteroid >= 0 and marked_asteroid < asteroids.size():
		var asteroid: Dictionary = asteroids[marked_asteroid]
		var marker_radius := maxf(asteroid.radius + 10.0, 9.0 / camera_zoom)
		canvas.draw_arc(asteroid.position, marker_radius, 0.0, TAU, 48, Color(0.45, 0.9, 1.0, 0.75), 1.5 / camera_zoom, true)
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
		canvas.draw_set_transform(_world_to_screen(piece.position), piece.rotation, Vector2.ONE * camera_zoom)
		var alpha: float = minf(1.0, piece.life / 1.5)
		MODULES.draw_part(canvas, piece.part, Vector2.ZERO, ENEMY_PART_SCALE, alpha)
		if piece.part.has("turret"):
			MODULES.draw_mounted_turret(canvas, piece.part.turret, Vector2.ZERO, ENEMY_PART_SCALE, alpha)

func _draw() -> void:
	if not game_started:
		return
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
	_draw_fleet_mining_beams()
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
	solar_system.draw_belt_markers(self, camera, get_viewport_rect())
	if solar_system.has_body_icons():
		solar_system.draw_body_icons(self, camera, get_viewport_rect())
	var anchor := _camera_anchor()
	var marker_view := get_viewport_rect().grow(8.0)
	var ship_screen := _fleet_screen_position(active_fleet_index, anchor)
	_draw_hud(size)
	_draw_aim_indicators(size)
	var marker_alpha := 1.0 - smoothstep(FLEET_HULL_MIN_PIXELS, FLEET_HULL_FULL_PIXELS, _ship_size().y * camera_zoom)
	if marker_alpha > 0.0 and marker_view.has_point(ship_screen):
		var forward := Vector2.from_angle(heading)
		var side := forward.orthogonal()
		draw_colored_polygon(PackedVector2Array([ship_screen + forward * 7.0, ship_screen - forward * 5.0 + side * 4.0, ship_screen - forward * 5.0 - side * 4.0]), Color(Color("e0f9ff"), marker_alpha))
	for index in range(fleet.size()):
		if index == active_fleet_index:
			continue
		var owned_ship: Dictionary = fleet[index]
		var dimensions: Vector2 = owned_ship.bounds_size
		var owned_alpha := 1.0 - smoothstep(FLEET_HULL_MIN_PIXELS, FLEET_HULL_FULL_PIXELS, dimensions.y * camera_zoom) if fleet_views.has(owned_ship.id) else 1.0
		var owned_screen := _fleet_screen_position(index, anchor)
		if owned_alpha > 0.0 and marker_view.has_point(owned_screen):
			var forward := Vector2.from_angle(float(owned_ship.heading))
			var side := forward.orthogonal()
			draw_colored_polygon(PackedVector2Array([owned_screen + forward * 7.0, owned_screen - forward * 5.0 + side * 4.0, owned_screen - forward * 5.0 - side * 4.0]), Color(Color("87e5bf"), owned_alpha))
	if hyperjump_time < 0.0:
		if rts_selected:
			draw_arc(ship_screen, maxf(_ship_size().length() * 0.5 * camera_zoom, 12.0) + 5.0, 0.0, TAU, 48, Color(0.65, 0.82, 0.76, 0.42), 1.25, true)
		for index in selected_fleet:
			if index != active_fleet_index:
				var owned_ship: Dictionary = fleet[index]
				var radius := maxf(float(owned_ship.radius) * camera_zoom, 12.0)
				draw_arc(_fleet_screen_position(index, anchor), radius + 5.0, 0.0, TAU, 48, Color(0.65, 0.82, 0.76, 0.42), 1.25, true)
		if rts_selected and rts_move_active:
			var marker := _world_to_screen(rts_destination)
			draw_line(ship_screen, marker, Color(0.47, 0.94, 0.73, 0.35), 1.25, true)
			draw_arc(marker, 10.0, 0.0, TAU, 32, Color("79efbb"), 2.0, true)
		for index in selected_fleet:
			if index == active_fleet_index:
				continue
			var owned_ship: Dictionary = fleet[index]
			if owned_ship.navigation.mode == "move":
				var marker := _world_to_screen(SHIP_STATE.relative(owned_ship.navigation.target, galaxy_origin))
				draw_line(_fleet_screen_position(index, anchor), marker, Color(0.47, 0.94, 0.73, 0.35), 1.25, true)
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
	if camera_zoom < MAP_LABEL_ZOOM or _combat_locked() or not rts_attack_active:
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
	if not mining or mining_asteroid < 0 or mining_asteroid >= asteroids.size():
		return
	var asteroid: Dictionary = asteroids[mining_asteroid]
	for part in cached_turret_mounts:
		if part.get("turret", "") != "miner" or not _turret_is_aimed(part, asteroid.position):
			continue
		_draw_mining_beam(_turret_world_position(part), asteroid)

func _fleet_mining_target(ship: Dictionary) -> Dictionary:
	if ship.orders.is_empty():
		return {}
	var order: Dictionary = ship.orders[0]
	if order.type != "mine" or order.state != "running" or order.stage != "mining":
		return {}
	var rock: Dictionary = live_rocks.get(order.target_entity_id, {})
	return rock if rock.get("iron", 0) > 0 else {}

func _draw_fleet_mining_beams() -> void:
	for ship_id in fleet_views:
		var ship := ship_registry.find(ship_id)
		var rock := _fleet_mining_target(ship)
		if rock.is_empty():
			continue
		var bounds := MODULES.bounds(ship.parts)
		var position := _ship_local(ship)
		var rotation := float(ship.heading) + PI / 2.0
		for slot in ship.fleet_stats.slots:
			if slot.type == "miner":
				var mount := LOADOUT.local_position(slot, bounds, ship.ship_scale)
				_draw_mining_beam(position + mount.rotated(rotation), rock)

func _draw_mining_beam(start: Vector2, asteroid: Dictionary) -> void:
	var direction: Vector2 = (asteroid.position - start).normalized()
	var tip: Vector2 = asteroid.position - direction * asteroid.radius * 0.75
	draw_line(start, tip, Color(0.2, 0.8, 1.0, 0.25), 11.0, true)
	draw_line(start, tip, Color(0.65, 0.96, 1.0, 0.95), 3.0, true)
	draw_circle(tip, 5.0 + sin(elapsed * 18.0) * 2.0, Color(0.8, 0.98, 1.0, 0.85))

func _turret_world_position(part: Dictionary) -> Vector2:
	_ensure_ship_cache()
	return ship_position + _turret_local_position(part).rotated(heading + PI / 2.0)

func _turret_local_position(part: Dictionary) -> Vector2:
	if part.has("local_position"):
		return part.local_position
	return (MODULES.mount_position(part) - cached_ship_bounds.get_center()) * cached_ship_scale

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
	for id: String in fleet_views:
		var ship := ship_registry.find(id)
		var view: Dictionary = fleet_views[id]
		_update_engine_trails(view.engines, Transform2D(float(ship.heading) + PI / 2.0, _ship_local(ship)), ship.velocity, float(view.engine_flame))
	if camera_zoom < EXHAUST_PARTICLE_MIN_ZOOM:
		return
	var visible_world := _visible_world(_world_transform())
	_emit_exhaust_particles(cached_engines, player_pose, velocity, engine_flame, engine_overdrive, delta, visible_world)
	for id: String in fleet_views:
		var ship := ship_registry.find(id)
		var view: Dictionary = fleet_views[id]
		_emit_exhaust_particles(view.engines, Transform2D(float(ship.heading) + PI / 2.0, _ship_local(ship)), ship.velocity, float(view.engine_flame), 0.0, delta, visible_world)
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
			var position: Vector2 = (pose * engine.nozzle) * Vector2(0.0, 8.0 * float(engine.get("effect_scale", 1.0)))
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
		var effect_scale := float(engine.get("effect_scale", 1.0))
		var half_width := maxf(clampf(float(engine.size.x), 0.7 * effect_scale, 2.0 * effect_scale), minf(0.5 / camera_zoom, 4.0 * effect_scale))
		var points := PackedVector2Array()
		var colors := PackedColorArray()
		for sample in trail:
			if sample.break_before:
				if points.size() >= 2:
					canvas.draw_polyline_colors(points, colors, half_width * 2.0, true)
				points.clear()
				colors.clear()
			var point: Vector2 = (sample.position as Vector2) - _camera_center()
			if not points.is_empty() and points[-1].distance_squared_to(point) < 0.01:
				continue
			var fade := pow(clampf(1.0 - (elapsed - float(sample.time)) / float(sample.get("lifetime", ENGINE_TRAIL_LIFETIME)), 0.0, 1.0), 1.5) * float(sample.power)
			points.append(point)
			colors.append(Color(1.0, 0.55, 0.22, 0.42 * fade))
		if bool(engine.get("trail_active", false)) and not points.is_empty():
			var head: Vector2 = (engine.trail_head as Vector2) - _camera_center()
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
		var effect_scale := float(engine.get("effect_scale", 1.0))
		var size: Vector2 = engine.size / effect_scale
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
			speed *= size.y * effect_scale * lerpf(0.70, 1.0, power) * (1.0 + boost * 0.85)
			var jet := nozzle.basis_xform(Vector2(spread * speed * (0.20 if spark else 0.28), speed))
			var particle := ExhaustParticle.new()
			# Each particle inherits the ship's motion and keeps its launch direction.
			particle.origin = nozzle * (Vector2(spread * size.x * 4.0, 3.0) * effect_scale) - ship_velocity * age
			particle.velocity = ship_velocity + jet
			particle.born = elapsed - age
			particle.lifetime = exhaust_rng.randf_range(0.18, 0.31) if spark else exhaust_rng.randf_range(0.25, 0.41)
			particle.radius = exhaust_rng.randf_range(1.3, 2.4) if spark else exhaust_rng.randf_range(3.0, 6.0)
			particle.radius *= lerpf(0.6, 1.0, size.y) * width_scale * effect_scale
			particle.opacity = lerpf(0.4, 1.0, power)
			if spark:
				particle.streak = jet * exhaust_rng.randf_range(0.020, 0.035)
			exhaust_particles.append(particle)

func _draw_exhaust_particles(canvas: CanvasItem) -> void:
	_draw_engine_trails(canvas, cached_engines)
	for view: Dictionary in fleet_views.values():
		_draw_engine_trails(canvas, view.engines)
	for enemy in enemies:
		_draw_engine_trails(canvas, enemy.engines)
	if camera_zoom < EXHAUST_PARTICLE_MIN_ZOOM:
		return
	var visible_world := _visible_world(_world_transform())
	for particle in exhaust_particles:
		var age := elapsed - particle.born
		var world_position := particle.origin + particle.velocity * age
		if not visible_world.has_point(world_position):
			continue
		var position := (particle.origin - _camera_center()) + particle.velocity * age
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
	return CRUISER_BARREL_RECOIL_DISTANCE * cached_ship_scale * (1.0 - smoothstep(0.0, CRUISER_BARREL_RECOIL_DURATION, age))

func _draw_cruiser_laser_flash(canvas: CanvasItem, mount: Dictionary, turret_angle: float, shot: Dictionary) -> void:
	var age := elapsed - float(shot.fired_at)
	var strength := 1.0 - smoothstep(0.0, MACHINE_GUN_FLASH_DURATION, age)
	if strength <= 0.0:
		return
	var muzzle := _turret_local_position(mount) + MODULES.cruiser_laser_muzzle_offset(mount, shot.barrel, turret_angle, _cruiser_barrel_recoil(shot))
	var forward := Vector2.UP.rotated(turret_angle) * cached_ship_scale
	canvas.draw_circle(muzzle, 10.0 * strength * cached_ship_scale, Color(CRUISER_LASER_COLOR, strength * 0.35), true, -1.0, true)
	canvas.draw_line(muzzle, muzzle + forward * (7.0 + 12.0 * strength), Color(CRUISER_LASER_COLOR, strength), 4.0 * cached_ship_scale, true)
	canvas.draw_circle(muzzle, 3.0 * strength * cached_ship_scale, Color(0.89, 1.0, 0.96, strength))

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
	var ship_scale := cached_ship_scale
	var dimensions := _ship_size()
	for index in range(custom_parts.size()):
		var part: Dictionary = custom_parts[index]
		if not MODULES.is_exterior_structure(part):
			continue
		var position := (MODULES.part_position(part) - center) * ship_scale
		MODULES.draw_part(canvas, part, position, ship_scale, 1.0, Color.WHITE, 1.0, true)
		if cached_armour_borders.has(index):
			_draw_player_armour_border(canvas, part, index, center, ship_scale)
		_draw_part_shield_glow(canvas, part, position, dimensions, ship_scale, -1)
	for index in cached_armour_borders:
		var panel: Dictionary = custom_parts[index]
		if not MODULES.is_armour_overlay(panel):
			continue
		var position := (MODULES.part_position(panel) - center) * ship_scale
		MODULES.draw_part(canvas, panel, position, ship_scale)
		_draw_player_armour_border(canvas, panel, index, center, ship_scale)
		_draw_part_shield_glow(canvas, panel, position, dimensions, ship_scale, -1)

func _draw_player_armour_border(canvas: CanvasItem, part: Dictionary, index: int, center: Vector2, ship_scale: float) -> void:
	var cell_size := MODULES.cell_size_for(part)
	var origin := Vector2.ONE * (cell_size - MODULES.CELL) * 0.5
	MODULES.draw_armour_border(canvas, cached_armour_borders[index], (origin - center) * ship_scale, cell_size * ship_scale)

func _draw_player_details(canvas: CanvasItem) -> void:
	var center := cached_ship_bounds.get_center()
	for detail in custom_parts:
		if MODULES.is_decoration(detail):
			var brightness := MODULES.navigation_light_brightness(elapsed) if detail.type == "navigation_lights" else 1.0
			MODULES.draw_part(canvas, detail, (MODULES.part_position(detail) - center) * cached_ship_scale, cached_ship_scale, 1.0, Color.WHITE, brightness)

func _draw_part_shield_glow(canvas: CanvasItem, part: Dictionary, position: Vector2, dimensions: Vector2, part_scale: float, enemy_index: int, mounted_turret: bool = false, turret_angle: float = 0.0, recoil: float = 0.0) -> void:
	if graphics_quality == 0:
		return
	for impact in shield_impacts:
		if impact.enemy != enemy_index:
			continue
		var effect_scale := part_scale if enemy_index == -1 else 1.0
		var radii := dimensions * 0.5 + Vector2.ONE * SHIELD_MARGIN * effect_scale
		var direction := Vector2.from_angle(impact.angle)
		var angle := atan2(direction.y / radii.y, direction.x / radii.x)
		var point := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var progress: float = 1.0 - impact.life / SHIELD_IMPACT_DURATION
		var strength := maxf(0.0, 1.0 - position.distance_to(point) / (100.0 * effect_scale)) * (1.0 - progress) * 0.8
		if strength > 0.01:
			var tint := Color(0.32, 0.75, 1.0)
			if mounted_turret:
				MODULES.draw_mounted_turret(canvas, part.turret, position, part_scale, strength, tint, turret_angle, recoil)
			else:
				MODULES.draw_part(canvas, part, position, part_scale, strength, tint, 1.0, enemy_index == -1)

func _draw_hyperjump_bow(canvas: CanvasItem) -> void:
	var jump_speed := _hyperjump_cruise_speed()
	var intensity := smoothstep(0.03, 0.55, velocity.length() / maxf(jump_speed, 1.0))
	if intensity <= 0.001:
		return
	var half_width := maxf(12.0, cached_ship_bounds.size.x * 0.5) * cached_ship_scale
	var nose_y := -_ship_half_length()
	var flicker := 0.85 + 0.15 * sin(elapsed * 17.0)
	var tip := Vector2(0.0, nose_y - 3.0 * cached_ship_scale)
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
		canvas.draw_polyline(points, Color(1.0, 0.28, 0.07, opacity * 0.25), 6.0 * cached_ship_scale, true)
		canvas.draw_polyline(points, Color(1.0, 0.75, 0.38, opacity * 0.8), 1.5 * cached_ship_scale, true)

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
					_draw_machine_gun_flash(canvas, position, turret_angle, cached_ship_scale, shot, part.turret == "long_machine_gun", part.turret == "retro_machine_gun")
			if player_rocket_launches.has(key):
				_draw_rocket_launch(canvas, position, turret_angle, cached_ship_scale, elapsed - float(player_rocket_launches[key]))
	_draw_shield_impacts(-1, _ship_size(), canvas, cached_ship_scale)
	_draw_hull_impacts(-1, canvas)

func _draw_sector_labels(camera: Transform2D) -> void:
	var font := ThemeDB.fallback_font
	var viewport := get_viewport_rect()
	var opacity := 1.0 - smoothstep(MAP_LABEL_ZOOM * 0.5, MAP_LABEL_ZOOM, camera_zoom)
	var icon_opacity := _distant_system_icon_opacity()
	var screen_separation := camera_zoom * GALAXY.separation_for(solar_system.galaxy.generator_version)
	if solar_system.systems.size() > 128 and screen_separation < 20.0:
		_draw_dense_galaxy_map(camera, viewport, font, screen_separation)
		return
	var show_all_names := screen_separation > ALL_STAR_NAMES_SEPARATION
	var pointed_system := _system_at_screen(get_viewport().get_mouse_position()) if not show_all_names else -1
	var current_system := solar_system.nearest_system(ship_position)
	for index in solar_system.systems.size():
		var system: Dictionary = solar_system.systems[index]
		var center := camera * solar_system.system_centers[index]
		var radius := maxf(6.0, system.radius * camera_zoom)
		if not viewport.grow(radius + 40.0).has_point(center):
			continue
		var label := str(system.name).to_upper()
		var show_name: bool = show_all_names or system.id == pointed_system or system.id == current_system
		var label_color := Color(system.color, opacity * (1.0 - icon_opacity))
		if system.radius * camera_zoom < 6.0 and icon_opacity < 1.0:
			draw_circle(center, 3.0, label_color, true, -1.0, true)
		if show_name:
			draw_line(center + Vector2(0, radius + 5.0), center + Vector2(0, radius + 20.0), label_color.darkened(0.35), 1.0, true)
			draw_string(font, center + Vector2(-90.0, radius + 36.0), label, HORIZONTAL_ALIGNMENT_CENTER, 180.0, 14, label_color)
		if icon_opacity > 0.0:
			var tint: Color = system.color
			draw_circle(center, 11.0, Color(tint, 0.045 * icon_opacity), true, -1.0, true)
			draw_circle(center, 7.0, Color(tint, 0.10 * icon_opacity), true, -1.0, true)
			draw_circle(center, 4.2, Color(tint, 0.27 * icon_opacity), true, -1.0, true)
			draw_line(center + Vector2(-8.0, 0.0), center + Vector2(8.0, 0.0), Color(tint, 0.35 * icon_opacity), 1.0, true)
			draw_line(center + Vector2(0.0, -8.0), center + Vector2(0.0, 8.0), Color(tint, 0.35 * icon_opacity), 1.0, true)
			draw_circle(center, 2.0, Color(tint.lerp(Color.WHITE, 0.7), icon_opacity), true, -1.0, true)
			if show_name:
				draw_string(font, center + Vector2(-55.0, 25.0), str(system.name).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 110.0, 12, Color(tint, icon_opacity))

func _draw_dense_galaxy_map(camera: Transform2D, viewport: Rect2, font: Font, separation: float) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var marker_radius := clampf(separation * 0.16, 0.75, 2.0)
	var chart_view := viewport.grow(6.0)
	for index in solar_system.systems.size():
		var system: Dictionary = solar_system.systems[index]
		var center := camera * solar_system.system_centers[index]
		if chart_view.has_point(center):
			points.append(center - Vector2(marker_radius, 0))
			points.append(center + Vector2(marker_radius, 0))
			colors.append(system.color)
	if not points.is_empty():
		draw_multiline_colors(points, colors, maxf(1.6, marker_radius * 1.45), true)

	var hovered := _system_at_screen(get_viewport().get_mouse_position())
	var current := solar_system.nearest_system(ship_position)
	for index in [current] if hovered == -1 or hovered == current else [current, hovered]:
		var system: Dictionary = solar_system.systems[index]
		var center := camera * solar_system.system_centers[index]
		if not chart_view.has_point(center):
			continue
		draw_arc(center, 6.5, 0.0, TAU, 18, system.color, 1.0, true)
		if index == hovered or hovered == -1:
			draw_string(font, center + Vector2(10.0, 3.0), system.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, system.color)

func _draw_hud(size: Vector2) -> void:
	game_hud._draw_hud(size)

func _format_speed(world_units_per_second: float) -> String:
	return game_hud._format_speed(world_units_per_second)

func _draw_resources(size: Vector2, font: Font) -> void:
	game_hud._draw_resources(size, font)

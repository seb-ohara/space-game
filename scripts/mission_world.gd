extends RefCounted
## Bridges the persistent contract ledger to flight, navigation and streamed NPCs.

const BOARD := preload("res://scripts/job_board.gd")
const STATE := preload("res://scripts/ships/ship_state.gd")
const GALAXY := preload("res://scripts/galaxy_generator.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const SHIP_RANDOMIZER := preload("res://scripts/ship_randomizer.gd")
const CAPS := preload("res://scripts/ships/ship_capabilities.gd")
const ASTEROIDS := preload("res://scripts/asteroid_factory.gd")
const EXCHANGE := 0
const DEPOT := 1
const BOUNTY := 2
const RAIDER := 3
const SURVEY := 4
const VISIT_RANGE := 1050.0
const STREAM_IN := 6500.0
const STREAM_OUT := 9500.0
const IRON_PRICE := 2

var game
var board := BOARD.new()
var tracked_id := 0
var site_cache := {}
var encounter_key := ""
var next_update := 0.0
var pending_payouts: Array[Dictionary] = []

func _init(owner) -> void:
	game = owner

func refresh() -> void:
	board.refresh(game.galaxy_seed, game.solar_system.systems, _system(), _available_ore)

func _system() -> int:
	return game.solar_system.nearest_system(game.ship_position)

func system_name(index: int) -> String:
	return game.solar_system.systems[index].name

func _available_ore(system: int) -> int:
	var solar = game.solar_system
	var sites := GALAXY.asteroid_sites(game.galaxy_seed, solar.systems[system], solar.system_contents(system))
	var total := 0
	for index in sites.size():
		var rock := sites[index]
		var id: String = game._asteroid_site_id(system, index, rock)
		total += int(game.depleted_ore.get(id, ASTEROIDS.ore_capacity(rock.radius, rock.ore)))
		if total >= 36:
			break
	return total

func site(system: int, region: int) -> PackedFloat64Array:
	var key := Vector2i(system, region)
	if site_cache.has(key):
		return site_cache[key]
	var solar = game.solar_system
	var center: Vector2 = solar.systems[system].center
	var version: int = solar.galaxy.generator_version
	var angle := TAU * float(hash("relay/%d/%d" % [game.galaxy_seed, system]) % 3600) / 3600.0
	var axis := Vector2.from_angle(angle)
	var base := axis * (float(solar.system_contents(system).edge) + 14000.0)
	if system == 0:
		# Keep the first exchange accessible from the starter mining pocket.
		base = GALAXY.starter_offset(version) + Vector2(-15500.0, 5000.0)
		axis = base.normalized()
	var offsets := [Vector2.ZERO, Vector2(12000, 21500), Vector2(25000, -21000), Vector2(18000, 41500),
		Vector2(24000, 4500), Vector2(36000, 18500), Vector2(48000, 3500)]
	var offset := base + (offsets[region] as Vector2).rotated(axis.angle())
	var size: Vector2 = game.world_size
	var absolute := STATE.point(clampf(center.x + offset.x, 1000.0, size.x - 1000.0), clampf(center.y + offset.y, 1000.0, size.y - 1000.0))
	site_cache[key] = absolute
	return absolute

func _local(point: PackedFloat64Array) -> Vector2:
	return STATE.relative(point, game.galaxy_origin)

func _near(system: int, region: int, radius: float) -> bool:
	return game.ship_position.distance_squared_to(_local(site(system, region))) <= radius * radius

func _at_contact(system: int, region: int) -> bool:
	return game.hyperjump_time < 0.0 and _near(system, region, VISIT_RANGE)

func _survey_point(job: Dictionary, region: int) -> PackedFloat64Array:
	var anchor := site(job.target, region)
	var bearing := TAU * float(hash("survey/%d/%d/%d" % [game.galaxy_seed, job.id, region]) % 3600) / 3600.0
	return STATE.absolute(anchor, Vector2.from_angle(bearing) * 4000.0)

func can_sell() -> bool:
	return game.iron > 0 and _at_contact(_system(), EXCHANGE)

func sell_iron() -> String:
	if not can_sell():
		return "The active ship must be carrying iron within range of an Exchange Relay."
	var units: int = game.iron
	game.iron = 0
	board.credits += units * IRON_PRICE
	game._commit_active_ship_state()
	game.fleet_order_list_dirty = true
	game._queue_flight_redraw()
	return "Sold %d iron for %d credits." % [units, units * IRON_PRICE]

func set_exchange_course() -> String:
	if game.hyperjump_time >= 0.0:
		return "Wait until the active ship exits hyperjump."
	var index: int = game.active_fleet_index
	if not CAPS.can_perform(game.fleet[index].fleet_stats, "move"):
		return "The active ship needs flight controls and thrust."
	if not game._submit_fleet_order(index, "move", site(_system(), EXCHANGE)):
		return "Could not queue a course to the exchange."
	return ""

func sync_cargo() -> void:
	for ship: Dictionary in game.fleet:
		ship.cargo.contracts = board.freight_units(ship.id)
	game.fleet_order_list_dirty = true

func _completed(job: Dictionary) -> void:
	if not job.is_empty():
		pending_payouts.append(job)

func _announce_payouts() -> void:
	if pending_payouts.is_empty():
		return
	if pending_payouts.size() == 1:
		var job := pending_payouts[0]
		game._show_order_notice("Contract complete: %s · +%d credits" % [BOARD.title(job), job.reward])
	else:
		var total := 0
		for job in pending_payouts:
			total += int(job.reward)
		game._show_order_notice("%d contracts complete · +%d credits" % [pending_payouts.size(), total])
	pending_payouts.clear()
	game._queue_flight_redraw()

func record_mining(deposit_id: String, amount: int) -> void:
	if game.debug_sandbox or amount <= 0 or board.active.is_empty():
		return
	for job in board.record_mining(int(deposit_id.get_slice("/", 0)), amount):
		_completed(job)

func record_enemy_defeat(enemy: Dictionary) -> void:
	if enemy.has("contract_id"):
		_completed(board.record_kill(enemy.contract_id, enemy.pirate_index))
	elif enemy.has("raider_system"):
		board.ambient_defeated[enemy.raider_system] = true

func update() -> void:
	if game.debug_sandbox:
		return
	if game.elapsed < next_update:
		_announce_payouts()
		return
	next_update = game.elapsed + 0.15
	if game.hyperjump_time >= 0.0:
		_stream("", 0, 0, {})
		_announce_payouts()
		return
	var system: int = game.asteroid_system
	if system < 0:
		return
	var ship: Dictionary = game.fleet[game.active_fleet_index]
	for job: Dictionary in board.active.duplicate():
		if job.kind == "survey" and job.target == system and game.ship_position.distance_squared_to(_local(_survey_point(job, SURVEY + int(job.progress)))) <= VISIT_RANGE * VISIT_RANGE:
			var waypoint: int = job.progress
			var done := board.record_scan(job.id, waypoint)
			if done.is_empty():
				game._show_order_notice("Survey scan %d/%d logged. Set course to the next signal in Jobs." % [job.progress, job.amount])
			else:
				_completed(done)
		elif job.kind == "freight":
			if job.carrier == "" and _at_contact(job.source, EXCHANGE) and board.load_freight(job.id, ship.id, CAPS.available_space(ship.fleet_stats, game._flight_cargo())):
				sync_cargo()
				game._show_order_notice("Freight loaded aboard %s · deliver to %s Depot." % [ship.name, system_name(job.target)])
			elif job.carrier == ship.id and _at_contact(job.target, DEPOT):
				var delivered := board.deliver_freight(job.id, ship.id)
				sync_cargo()
				_completed(delivered)
	_update_encounter(system)
	_announce_payouts()

func _bounty(system: int) -> Dictionary:
	for job in board.active:
		if job.kind == "bounty" and job.target == system:
			return job
	return {}

func _update_encounter(system: int) -> void:
	var bounty := _bounty(system)
	var entries := [{"region": EXCHANGE, "key": "%d/civil" % system},
		{"region": RAIDER, "key": "%d/raider" % system}, {"region": BOUNTY, "key": "%d/bounty" % system}]
	# Keep a finished pack in the scene until departure so debris and loot remain visible.
	for entry: Dictionary in entries:
		if encounter_key == entry.key and _near(system, entry.region, STREAM_OUT):
			if entry.region == BOUNTY and not bounty.is_empty() and not game.enemies.is_empty() and game.enemies[0].get("contract_id") != bounty.id:
				_stream("", system, 0, {})
			else:
				if entry.region == BOUNTY and not bounty.is_empty():
					_spawn_pack(system, bounty, _local(site(system, BOUNTY)))
				return
	for entry: Dictionary in entries:
		if (entry.region == BOUNTY and bounty.is_empty()) or (entry.region == RAIDER and board.ambient_defeated.has(system)):
			continue
		if _near(system, entry.region, STREAM_IN):
			_stream(entry.key, system, entry.region, bounty)
			return
	_stream("", system, 0, {})

func _stream(key: String, system: int, region: int, bounty: Dictionary) -> void:
	if key == encounter_key:
		return
	if not encounter_key.is_empty():
		game._clear_enemies()
		for index in range(game.projectiles.size() - 1, -1, -1):
			if game.projectiles[index].get("encounter", false):
				game.projectiles.remove_at(index)
	encounter_key = key
	if key.is_empty():
		return
	var center := _local(site(system, region))
	if region == BOUNTY:
		_spawn_pack(system, bounty, center)
	else:
		_spawn(system, region, bounty, 0, center)
	# Retry if all candidate points were blocked (e.g. around an oversized hull).
	if game.enemies.is_empty():
		encounter_key = ""

func _spawn_pack(system: int, bounty: Dictionary, center: Vector2) -> void:
	var occupied := int(bounty.defeated)
	for actor: Dictionary in game.enemies:
		occupied |= 1 << int(actor.pirate_index)
	for index in int(bounty.amount):
		if (occupied & (1 << index)) == 0:
			_spawn(system, BOUNTY, bounty, index, center)

func _spawn(system: int, region: int, bounty: Dictionary, index: int, center: Vector2) -> void:
	var civilian := region == EXCHANGE
	var tier := int(bounty.tier) if region == BOUNTY else 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("traffic/%d/%d/%d/%d/%d" % [game.galaxy_seed, system, region, bounty.get("id", 0) if region == BOUNTY else 0, index])
	# Bounty difficulty still governs combat stats and pack size, not just hull class.
	var class_id := 2 if tier == 2 and rng.randf() < 0.25 else 1 if tier >= 1 and rng.randf() < 0.50 else 0
	var roll := {} if civilian else SHIP_RANDOMIZER.generate(rng, class_id, true)
	var parts: Array = MODULES.preset_design(MODULES.CARGO_SHIP) if civilian else roll.parts
	var bounds := MODULES.bounds(parts)
	var dimensions := bounds.size
	var radius := dimensions.length() * 0.5
	var angle := rng.randf_range(0.0, TAU)
	var position := Vector2.INF
	for attempt in 24:
		var candidate := center + Vector2.from_angle(angle + TAU * float(attempt % 8) / 8.0) * (1350.0 + float(attempt / 8) * 1050.0)
		if candidate.distance_to(game.ship_position) > radius + game._ship_half_length() + 140.0 and game._npc_spawn_clear(candidate, radius):
			position = candidate
			break
	if not position.is_finite():
		return
	var hull: float = 160.0 if civilian else [42.0, 85.0, 130.0][tier]
	var shield: float = 0.0 if civilian else [0.0, 24.0, 55.0][tier]
	var heading := position.angle_to_point(game.ship_position)
	var caption: String = "Relay freighter" if civilian else "%s raider" % roll.class if region == RAIDER else "Wanted %s %d" % [roll.class, index + 1]
	var actor := {"name": caption,
		"position": position, "heading": heading, "aim_angle": heading, "velocity": Vector2.ZERO, "angular_velocity": 0.0,
		"turn_speed": 2.2, "hostile": not civilian, "civilian": civilian, "encounter": true, "alive": true,
		"patrol_origin": center, "patrol_destination": center, "health": hull, "max_health": hull, "shield": shield, "max_shield": shield,
		"shield_delay": 0.0, "fire_cooldown": 1.2, "fire_interval": [1.65, 1.30, 1.05][tier],
		"damage_factor": [0.65, 0.9, 1.15][tier], "speed": [178.0, 218.0, 256.0][tier], "avoid_side": 1.0 if index % 2 == 0 else -1.0,
		"dimensions": dimensions, "radius": radius, "ship_scale": 1.0, "next_turret": 0}
	actor.merge(game._generated_npc_layout(parts, bounds, 1.0, not civilian))
	if region == BOUNTY:
		actor.contract_id = bounty.id
		actor.pirate_index = index
	elif region == RAIDER:
		actor.raider_system = system
	game._add_enemy_visual(actor, parts, bounds, 1.0)

func abandon(id: int) -> void:
	var job := board.abandon(id)
	if job.is_empty():
		return
	if job.kind == "freight":
		sync_cargo()
	elif job.kind == "bounty" and encounter_key == "%d/bounty" % job.target:
		_stream("", 0, 0, {})
	game._queue_flight_redraw()

func goal(job: Dictionary) -> Dictionary:
	var region := EXCHANGE
	var system := int(job.target)
	var label := ""
	match job.kind:
		"mining": label = "Iron deposits"
		"survey":
			region = SURVEY + mini(job.amount - 1, job.progress)
			label = "Survey signal %d/%d" % [mini(job.amount, job.progress + 1), job.amount]
		"bounty":
			region = BOUNTY
			label = "Pirate hideout"
		"freight":
			region = EXCHANGE if job.carrier == "" else DEPOT
			system = job.source if region == EXCHANGE else job.target
			label = "Freight pickup" if region == EXCHANGE else "Freight delivery"
	return {"system": system, "region": region, "label": label}

func _goal_point(job: Dictionary, waypoint: Dictionary) -> PackedFloat64Array:
	return _survey_point(job, waypoint.region) if job.kind == "survey" else site(waypoint.system, waypoint.region)

func course_block(job: Dictionary) -> String:
	if game.hyperjump_time >= 0.0:
		return "Wait until the active ship exits hyperjump."
	var ship: Dictionary = game.fleet[game.active_fleet_index]
	if not CAPS.can_perform(ship.fleet_stats, "move"):
		return "The active ship needs flight controls and thrust."
	var waypoint := goal(job)
	if waypoint.system != _system() and not CAPS.can_perform(ship.fleet_stats, "hyperjump"):
		return "The active ship cannot hyperjump."
	if job.kind == "freight":
		if job.carrier != "" and ship.id != job.carrier:
			return "Select %s to deliver this freight." % carrier_name(job)
		if job.carrier == "" and CAPS.available_space(ship.fleet_stats, game._flight_cargo()) < job.amount:
			return "Free up at least %d units of cargo space to collect this shipment." % job.amount
	if job.kind == "mining":
		return game._mining_block_reason(game.active_fleet_index)
	if job.kind == "bounty" and not CAPS.can_perform(ship.fleet_stats, "combat"):
		return "The active ship needs a combat weapon."
	return ""

func set_course(job: Dictionary) -> String:
	var reason := course_block(job)
	if reason != "":
		return reason
	var index: int = game.active_fleet_index
	var waypoint := goal(job)
	var jump: bool = waypoint.system != _system()
	if jump and not game._submit_fleet_order(index, "hyperjump", waypoint.system):
		return "Could not queue the hyperjump."
	var queued: bool
	if job.kind == "mining":
		queued = game._submit_fleet_order(index, "mine", "", job.amount - job.progress, false, jump)
	else:
		queued = game._submit_fleet_order(index, "move", _goal_point(job, waypoint), 0.0, false, jump)
	if not queued:
		return "Could not queue the contract objective."
	tracked_id = job.id
	return ""

func carrier_name(job: Dictionary) -> String:
	return game.ship_registry.find(job.carrier).get("name", "the carrier ship")

func draw_markers(canvas: CanvasItem) -> void:
	if game.debug_sandbox:
		return
	var rect: Rect2 = game.get_viewport_rect()
	var font := ThemeDB.fallback_font
	var current: int = game.asteroid_system
	var chart: bool = game.camera_zoom < game.MAP_LABEL_ZOOM
	var tracked := BOARD.find(board.active, tracked_id)
	if tracked.is_empty() and not board.active.is_empty():
		tracked = board.active[0]
	var destination := Vector2.INF
	var caption := ""
	if not tracked.is_empty():
		var waypoint := goal(tracked)
		# Mining normally starts via the fleet's automatic deposit picker.
		# Use a cached representative deposit for the marker, never generate a belt per frame.
		var point := _goal_point(tracked, waypoint)
		if tracked.kind == "mining" and waypoint.system == current:
			var best := INF
			for rock: Dictionary in game.asteroids:
				if rock.iron <= 0:
					continue
				var distance: float = game.ship_position.distance_squared_to(rock.position)
				if distance < best:
					best = distance
					point = rock.galaxy_position
		destination = game._world_to_screen(_local(point))
		caption = "%s · %s" % [system_name(waypoint.system), waypoint.label]
	if current >= 0:
		for region in [EXCHANGE, DEPOT, RAIDER]:
			if region == RAIDER and board.ambient_defeated.has(current):
				continue
			var point: Vector2 = game._world_to_screen(_local(site(current, region)))
			if not rect.has_point(point) or point.distance_to(destination) < 26.0 or chart:
				continue
			var color := Color("ff7668") if region == RAIDER else Color("91cece")
			canvas.draw_arc(point, 7.0, 0.0, TAU, 20, color, 1.5, true)
			canvas.draw_string(font, point + Vector2(11.0, 4.0), ["Exchange Relay", "Freight Depot", "", "Raider Lane"][region], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if destination.is_finite():
		var edge := rect.grow(-34.0)
		var point := destination.clamp(edge.position, edge.end)
		var color := Color("ffd88e")
		canvas.draw_polyline(PackedVector2Array([point + Vector2(0, -9), point + Vector2(9, 0), point + Vector2(0, 9),
			point + Vector2(-9, 0), point + Vector2(0, -9)]), color, 1.6, true)
		var label_x := clampf(point.x + 13.0, 34.0, maxf(34.0, rect.size.x - 260.0))
		canvas.draw_string(font, Vector2(label_x, point.y + 16.0), caption, HORIZONTAL_ALIGNMENT_LEFT, 232.0, 12, color)

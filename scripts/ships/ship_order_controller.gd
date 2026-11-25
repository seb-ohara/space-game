extends RefCounted
## Shared order state machine. The game supplies target lookup and atomically commits ore transfers.

const STATE := preload("res://scripts/ships/ship_state.gd")
const CAPS := preload("res://scripts/ships/ship_capabilities.gd")
const QUEUE := preload("res://scripts/ships/ship_order_queue.gd")
const MINING := preload("res://scripts/mining_controller.gd")
const MODULES := preload("res://scripts/ship_modules.gd")
const NAV := preload("res://scripts/flight_navigation.gd")
const STALL_LIMIT := 60.0

func tick(ship: Dictionary, delta: float, resolve_jump: Callable, resolve_rock: Callable, extract: Callable) -> void:
	var order := QUEUE.current(ship)
	if order.is_empty():
		return
	var profile: Dictionary = ship.fleet_stats
	order.state = "running"
	match order.type:
		"move": _move(ship, order, profile, delta)
		"hyperjump": _jump(ship, order, profile, delta, resolve_jump)
		"mine": _mine(ship, order, profile, delta, resolve_rock, extract)
		_: _hold(ship, order, delta)

func suspend(ship: Dictionary) -> void:
	var order := QUEUE.current(ship)
	if not order.is_empty() and order.state != "suspended":
		order.state = "suspended"
		order.progress.erase("best_distance")
		order.progress.erase("stall")
		ship.navigation = {"mode": "drift"}

func _move(ship: Dictionary, order: Dictionary, profile: Dictionary, delta: float) -> void:
	if not CAPS.can_perform(profile, "move"):
		QUEUE.finish(ship, "failed", "Ship cannot fly.")
		return
	var distance := STATE.relative(order.target_position, ship.galaxy_position).length()
	if distance <= NAV.MOVE_ARRIVAL_RADIUS and (ship.velocity as Vector2).length() < 4.0:
		QUEUE.finish(ship, "completed", "Destination reached.")
	elif _track_progress(order, distance, delta):
		order.stage = "travel"
		ship.navigation = {"mode": "move", "target": order.target_position}
	else:
		QUEUE.finish(ship, "failed", "No progress toward destination.")

func _jump(ship: Dictionary, order: Dictionary, profile: Dictionary, delta: float, resolve: Callable) -> void:
	if not CAPS.can_perform(profile, "hyperjump"):
		QUEUE.finish(ship, "failed", "Ship cannot hyperjump.")
		return
	var progress: Dictionary = order.progress
	if not progress.has("travel_target"):
		var target: PackedFloat64Array = resolve.call(ship, order.parameters.system)
		if target.is_empty():
			QUEUE.finish(ship, "failed", "Ship is already in that system or the system is unavailable.")
			return
		progress.travel_target = target
		progress.jump_distance = STATE.relative(target, ship.galaxy_position).length()
	var distance := STATE.relative(progress.travel_target, ship.galaxy_position).length()
	if distance <= 4.0 and (ship.velocity as Vector2).length() <= 8.0:
		QUEUE.finish(ship, "completed", "Hyperjump arrival confirmed.")
	elif not _track_progress(order, distance, delta):
		QUEUE.finish(ship, "failed", "No progress toward jump arrival.")
	elif ship.navigation.mode != "jump" or ship.navigation.target != progress.travel_target:
		order.stage = "jump"
		ship.navigation = {"mode": "jump", "target": progress.travel_target, "system": order.parameters.system,
			"distance": progress.jump_distance, "time": 0.0}

func _mine(ship: Dictionary, order: Dictionary, profile: Dictionary, delta: float, resolve: Callable, extract: Callable) -> void:
	if profile.mining_rate <= 0.0:
		QUEUE.finish(ship, "failed", "No mining laser equipped.")
		return
	var free := CAPS.available_space(profile, ship.cargo)
	if free <= 0:
		QUEUE.finish(ship, "blocked", "Cargo hold is full.")
		return
	var rock: Dictionary = resolve.call(order.target_entity_id)
	if rock.is_empty():
		QUEUE.finish(ship, "failed", "Asteroid could not be found.")
		return
	if rock.iron <= 0:
		QUEUE.finish(ship, "blocked", "Asteroid deposit is exhausted.")
		return
	var offset := STATE.relative(rock.galaxy_position, ship.galaxy_position)
	var distance := offset.length()
	var reach := MINING.mining_range(rock.radius, float(ship.bounds_size.y) * 0.5)
	var progress: Dictionary = order.progress
	if distance > reach * 0.94:
		progress.aim = 0.0
		if not CAPS.can_perform(profile, "move"):
			QUEUE.finish(ship, "failed", "Ship cannot approach the asteroid.")
		elif _track_progress(order, distance, delta):
			order.stage = "approach"
			ship.navigation = {"mode": "move", "target": STATE.absolute(rock.galaxy_position, -offset.normalized() * reach * 0.80)}
		else:
			QUEUE.finish(ship, "failed", "No progress toward the asteroid.")
		return
	ship.navigation = {"mode": "hold"}
	if (ship.velocity as Vector2).length_squared() > 4.0:
		order.stage = "braking"
		return
	# Allow up to half a turret revolution to settle on a newly acquired target.
	var aim_time := PI / float(MODULES.TYPES.miner.turret_turn_speed)
	progress.aim = minf(aim_time, float(progress.get("aim", 0.0)) + delta)
	if progress.aim < aim_time:
		order.stage = "aiming"
		return
	order.stage = "mining"
	var mined := int(progress.get("mined", 0))
	var needed := free if order.repeat else mini(free, int(order.parameters.units) - mined)
	var result := MINING.tick(rock.iron, float(progress.get("fraction", 0.0)), profile.mining_rate, needed, delta)
	if result.extracted > 0:
		mined += int(extract.call(ship, order.target_entity_id, result.extracted))
	progress.mined = mined
	progress.fraction = result.progress
	if not order.repeat and mined >= order.parameters.units:
		QUEUE.finish(ship, "completed", "Mined %d iron." % mined)

func _hold(ship: Dictionary, order: Dictionary, delta: float) -> void:
	ship.navigation = {"mode": "hold"}
	if (ship.velocity as Vector2).length_squared() > 0.25:
		order.stage = "braking"
		return
	if order.type != "wait":
		QUEUE.finish(ship, "completed", "Ship is holding position.")
		return
	order.stage = "waiting"
	order.progress.waited = float(order.progress.get("waited", 0.0)) + delta
	if order.progress.waited + 1e-8 >= order.parameters.seconds:
		if order.repeat:
			order.progress.waited = 0.0
		else:
			QUEUE.finish(ship, "completed", "Wait finished.")

func _track_progress(order: Dictionary, distance: float, delta: float) -> bool:
	var progress: Dictionary = order.progress
	if not progress.has("best_distance") or distance < float(progress.best_distance) - 0.1:
		progress.best_distance = distance
		progress.stall = 0.0
	else:
		progress.stall = float(progress.get("stall", 0.0)) + delta
	return progress.stall < STALL_LIMIT

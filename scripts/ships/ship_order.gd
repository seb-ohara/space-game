extends RefCounted
## Serializable, explicit instructions. A repeat is permitted only for wait and mine.

const STATE := preload("res://scripts/ships/ship_state.gd")
const TYPES := ["idle", "move", "hyperjump", "mine", "stop", "wait"]
const MAX_QUEUE := 64
const STATES := ["queued", "running", "suspended"]
const STAGES := ["queued", "travel", "jump", "approach", "braking", "aiming", "mining", "waiting"]

static func create(ship_id: String, sequence: int, type: String, target: Variant, quantity: float, repeat: bool) -> Dictionary:
	var order := {"id": "%s/order-%d" % [ship_id, sequence], "ship_id": ship_id, "type": type,
		"state": "queued", "stage": "queued", "repeat": repeat, "parameters": {}, "progress": {}, "failure_reason": ""}
	match type:
		"move": order.target_position = target
		"hyperjump": order.parameters.system = target
		"mine":
			order.target_entity_id = target
			order.parameters.units = int(quantity)
		"wait": order.parameters.seconds = quantity
	return order

static func valid(order: Variant, ship_id: String, system_count: int) -> bool:
	if not order is Dictionary or not order.get("id") is String or not order.id.begins_with(ship_id + "/order-") \
		or order.get("ship_id") != ship_id or order.get("type") not in TYPES or order.get("state") not in STATES \
		or order.get("stage") not in STAGES or not order.get("repeat") is bool or not order.get("failure_reason") is String:
		return false
	if order.repeat and order.type not in ["mine", "wait"]:
		return false
	var params: Variant = order.get("parameters")
	var progress: Variant = order.get("progress")
	if not params is Dictionary or not progress is Dictionary:
		return false
	for key in ["mined", "fraction", "aim", "waited", "stall", "best_distance", "jump_distance"]:
		if progress.has(key) and (not STATE.finite_number(progress[key]) or progress[key] < 0.0):
			return false
	if progress.has("travel_target") and not STATE.valid_point(progress.travel_target):
		return false
	match order.type:
		"move": return STATE.valid_point(order.get("target_position"))
		"hyperjump":
			var delay: Variant = params.get("departure_delay", 0.0)
			return params.get("system") is int and params.system >= 0 and params.system < system_count \
				and STATE.finite_number(delay) and delay >= 0.0
		# An empty target means acquire the nearest deposit when the order starts.
		"mine": return order.get("target_entity_id") is String and params.get("units") is int and params.units > 0
		"wait": return STATE.finite_number(params.get("seconds")) and params.seconds > 0.0
	return true

static func caption(order: Dictionary) -> String:
	if order.is_empty():
		return "Idle"
	match order.type:
		"mine": return "Mine until full" if order.repeat else "Mine %d iron" % order.parameters.units
		"wait": return "Wait %s s%s" % [str(order.parameters.seconds), " (repeat)" if order.repeat else ""]
		"stop": return "Stop ship"
		_: return str(order.type).capitalize()

static func activity(order: Dictionary) -> String:
	if order.is_empty():
		return "No active orders"
	if order.state == "suspended":
		return "Paused by boost"
	if order.state == "queued":
		return "Ready to start"
	match order.stage:
		"travel": return "En route"
		"jump": return "In transit"
		"approach": return "Approaching asteroid"
		"braking": return "Slowing to a stop"
		"aiming": return "Aiming mining lasers"
		"mining": return "Extracting ore"
		"waiting": return "Waiting"
		_: return "Starting"
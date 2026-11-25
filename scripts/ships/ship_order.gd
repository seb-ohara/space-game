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
		"hyperjump": return params.get("system") is int and params.system >= 0 and params.system < system_count
		"mine": return order.get("target_entity_id") is String and not order.target_entity_id.is_empty() \
			and params.get("units") is int and params.units > 0
		"wait": return STATE.finite_number(params.get("seconds")) and params.seconds > 0.0
	return true

static func caption(order: Dictionary) -> String:
	if order.is_empty():
		return "Idle"
	var caption_text := str(order.type).capitalize()
	if order.repeat:
		caption_text += " (repeat)"
	if order.state == "suspended":
		caption_text += " · manual override"
	elif order.state == "running":
		caption_text += " · " + str(order.stage)
	return caption_text
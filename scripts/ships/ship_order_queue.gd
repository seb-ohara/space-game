extends RefCounted

const ORDER := preload("res://scripts/ships/ship_order.gd")
const TERMINAL := ["completed", "failed", "blocked", "cancelled"]

static func current(ship: Dictionary) -> Dictionary:
	return ship.orders[0] if not ship.orders.is_empty() else {}

static func submit(ship: Dictionary, type: String, target: Variant, quantity: float, repeat: bool, append: bool, system_count: int) -> bool:
	if not is_finite(quantity) or quantity < 0.0 or quantity > 1.0e9:
		return false
	var order := ORDER.create(ship.id, ship.next_order_id, type, target, quantity, repeat)
	if not ORDER.valid(order, ship.id, system_count) or (append and ship.orders.size() >= ORDER.MAX_QUEUE):
		return false
	if not append:
		cancel(ship, "Replaced by a new order.")
	ship.next_order_id += 1
	ship.orders.append(order)
	return true

static func finish(ship: Dictionary, state: String, reason: String = "") -> void:
	var order: Dictionary = ship.orders.pop_front()
	ship.last_order = {"id": order.id, "type": order.type, "state": state, "reason": reason}
	ship.navigation = {"mode": "hold"}

static func cancel(ship: Dictionary, reason: String = "Cancelled by pilot.") -> bool:
	if ship.orders.is_empty():
		return false
	finish(ship, "cancelled", reason)
	ship.orders.clear()
	return true

static func valid(ship: Dictionary, system_count: int) -> bool:
	var orders: Variant = ship.get("orders")
	var last: Variant = ship.get("last_order")
	if not orders is Array or orders.size() > ORDER.MAX_QUEUE or not ship.get("next_order_id") is int or ship.next_order_id < 1 or not last is Dictionary:
		return false
	var ids := {}
	for order in orders:
		if not ORDER.valid(order, ship.id, system_count) or ids.has(order.id):
			return false
		ids[order.id] = true
	return last.is_empty() or (last.get("id") is String and last.get("type") in ORDER.TYPES \
		and last.get("state") in TERMINAL and last.get("reason") is String)
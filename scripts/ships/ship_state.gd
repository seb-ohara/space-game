extends RefCounted
## Portable ship records. Position/targets are two double-precision galaxy coordinates.

const OWNER_PLAYER := "player"
const MODES := ["idle", "hold", "drift", "move", "jump", "boost", "burst", "decelerate"]
const FIELDS := ["id", "owner_id", "design_id", "name", "parts", "admin", "galaxy_position", "velocity",
	"heading", "angular_velocity", "hull", "shield", "shield_delay", "cargo", "navigation"]
const ORDER_DEFAULTS := {"orders": [], "next_order_id": 1, "last_order": {}}

static func point(x: float, y: float) -> PackedFloat64Array:
	return PackedFloat64Array([x, y])

static func valid_point(value: Variant) -> bool:
	return value is PackedFloat64Array and value.size() == 2 and is_finite(value[0]) and is_finite(value[1])

static func absolute(origin: PackedFloat64Array, local: Vector2) -> PackedFloat64Array:
	return point(origin[0] + local.x, origin[1] + local.y)

static func relative(value: PackedFloat64Array, origin: PackedFloat64Array) -> Vector2:
	return Vector2(value[0] - origin[0], value[1] - origin[1])

static func design_id(parts: Array) -> String:
	for part: Dictionary in parts:
		if str(part.type).begins_with("preset_"):
			return str(part.type)
	return "custom-%08x" % JSON.stringify(parts).hash()

static func from_legacy(source: Dictionary, id: String, origin: PackedFloat64Array) -> Dictionary:
	return {"id": id, "owner_id": OWNER_PLAYER, "design_id": design_id(source.parts), "name": source.name,
		"parts": source.parts.duplicate(true), "admin": source.get("admin", {}).duplicate(true),
		"galaxy_position": absolute(origin, source.position), "velocity": Vector2.ZERO,
		"heading": source.heading, "angular_velocity": 0.0, "hull": source.hull, "shield": source.shield,
		"shield_delay": source.shield_delay, "cargo": {"iron": 0, "tritium": 0}, "navigation": {"mode": "idle"},
		"orders": [], "next_order_id": 1, "last_order": {}}

static func snapshot(ship: Dictionary) -> Dictionary:
	var saved := {}
	for key: String in FIELDS:
		saved[key] = ship[key]
	for key: String in ORDER_DEFAULTS:
		saved[key] = ship.get(key, ORDER_DEFAULTS[key])
	return saved.duplicate(true)

static func valid(ship: Dictionary, system_count: int) -> bool:
	for key in ["id", "owner_id", "design_id"]:
		if not ship.get(key) is String or ship[key].is_empty():
			return false
	if not valid_point(ship.get("galaxy_position")) or not finite_vector(ship.get("velocity")) or not finite_number(ship.get("angular_velocity")):
		return false
	var cargo: Variant = ship.get("cargo")
	var nav: Variant = ship.get("navigation")
	if not cargo is Dictionary or not nav is Dictionary or nav.get("mode") not in MODES:
		return false
	for key in ["iron", "tritium"]:
		if not cargo.get(key) is int or cargo[key] < 0:
			return false
	match nav.mode:
		"move":
			return valid_point(nav.get("target"))
		"jump":
			return valid_point(nav.get("target")) and nav.get("system") is int and nav.system >= 0 and nav.system < system_count \
				and finite_number(nav.get("distance")) and nav.distance >= 0.0 and finite_number(nav.get("time")) and nav.time >= 0.0
		"boost":
			return finite_vector(nav.get("direction")) and (not nav.has("target") or valid_point(nav.target))
		"burst":
			for key in ["time", "duration", "power"]:
				if not finite_number(nav.get(key)) or nav[key] < 0.0:
					return false
	return true

static func finite_vector(value: Variant) -> bool:
	return value is Vector2 and value.is_finite()

static func finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(value)

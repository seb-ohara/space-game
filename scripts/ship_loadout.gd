extends RefCounted

# Coordinates are fractions of the hull bounding box, measured from its top left.
const TYPES := {
	"": "Empty",
	"laser": "Laser",
	"machine_gun": "Machine gun",
	"missile": "Rocket launcher",
	"railgun": "Railgun",
	"miner": "Mining laser",
	"shield": "Shield capacity (+100)",
	"shield_recharge": "Shield recharge (+2/s)",
}
const MAX_SLOTS := 32
const DEFAULT_SLOT_COUNT := 4

static func slots(admin: Dictionary) -> Array:
	var saved: Variant = admin.get("module_slots", resize_slots([], DEFAULT_SLOT_COUNT))
	if not saved is Array:
		return []
	var result: Array = []
	for value in saved.slice(0, MAX_SLOTS):
		if not value is Dictionary:
			continue
		var kind := str(value.get("type", ""))
		if not TYPES.has(kind):
			kind = ""
		var x := float(value.get("x", 0.5))
		var y := float(value.get("y", 0.5))
		if not is_finite(x) or not is_finite(y):
			x = 0.5
			y = 0.5
		result.append({"type": kind, "x": clampf(x, 0.0, 1.0), "y": clampf(y, 0.0, 1.0)})
	return result

static func local_position(slot: Dictionary, bounds: Rect2, scale_factor: float) -> Vector2:
	var fraction := Vector2(float(slot.x), float(slot.y))
	return (bounds.position + bounds.size * fraction - bounds.get_center()) * scale_factor

static func resize_slots(values: Array, count: int) -> Array:
	var result := values.duplicate(true)
	result.resize(clampi(count, 0, MAX_SLOTS))
	for i in result.size():
		if not result[i] is Dictionary:
			# Spread new hardpoints out so each one can be grabbed individually.
			result[i] = {"type": "", "x": 0.22 + 0.38 * (i % 2) + 0.025 * (i >> 2), "y": 0.25 + 0.5 * ((i >> 1) % 2)}
	return result

extends RefCounted
## Ship IDs and data outlive scene projections. Stable iteration order is also the fleet UI order.

const STATE := preload("res://scripts/ships/ship_state.gd")
var ships: Array[Dictionary] = []
var _by_id: Dictionary = {}
var next_id := 1

func new_ship(legacy: Dictionary, origin: PackedFloat64Array) -> Dictionary:
	var id := "ship-%08d" % next_id
	while _by_id.has(id):
		next_id += 1
		id = "ship-%08d" % next_id
	next_id += 1
	var ship := STATE.from_legacy(legacy, id, origin)
	add(ship)
	return ship

func add(ship: Dictionary) -> void:
	assert(not _by_id.has(ship.id))
	ships.append(ship)
	_by_id[ship.id] = ship

func find(ship_id: String) -> Dictionary:
	return _by_id.get(ship_id, {})

func nearby(origin: PackedFloat64Array, radius: float) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var radius_squared := radius * radius
	for ship in ships:
		var x: float = ship.galaxy_position[0] - origin[0]
		var y: float = ship.galaxy_position[1] - origin[1]
		if x * x + y * y <= radius_squared:
			results.append(ship)
	return results

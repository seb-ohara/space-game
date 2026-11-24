extends RefCounted
## Stateless mining rules. The caller owns cargo, asteroid data and persistence.
## find_target chooses the topmost non-depleted asteroid under an aim point.

static func find_target(asteroids: Array, aim_position: Vector2) -> int:
	for i in range(asteroids.size() - 1, -1, -1):
		var asteroid: Dictionary = asteroids[i]
		if asteroid.iron > 0 and aim_position.distance_to(asteroid.position) <= asteroid.radius:
			return i
	return -1

static func mining_range(asteroid_radius: float, ship_half_length: float) -> float:
	return asteroid_radius + maxf(650.0, ship_half_length + 35.0)

## Computes a mining tick without changing the asteroid or cargo. `capacity_left`
## is the remaining space for all cargo, not the ship's total cargo capacity.
## Returns the amount extracted, remaining progress, and beam/depletion state.
static func tick(ore: int, progress: float, rate: float, capacity_left: int, delta: float) -> Dictionary:
	progress += delta * rate
	var extracted := mini(mini(maxi(floori(progress), 0), maxi(ore, 0)), maxi(capacity_left, 0))
	progress -= extracted
	var remaining := ore - extracted
	var active := rate > 0.0
	if capacity_left - extracted <= 0:
		active = false
		progress = minf(progress, 1.0)
	if remaining <= 0:
		active = false
		progress = 0.0
	return {"extracted": extracted, "progress": progress, "active": active, "depleted": remaining <= 0}

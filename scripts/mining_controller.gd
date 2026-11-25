extends RefCounted
## Stateless mining rules. The caller owns cargo, asteroid data and persistence.
## find_target chooses the topmost non-depleted asteroid under an aim point.

const MINING_REACH := 1300.0

static func find_target(asteroids: Array, aim_position: Vector2) -> int:
	for i in range(asteroids.size() - 1, -1, -1):
		var asteroid: Dictionary = asteroids[i]
		if asteroid.iron > 0 and aim_position.distance_to(asteroid.position) <= asteroid.radius:
			return i
	return -1

## Mouse picking prefers a visible silhouette, then the closest edge within padding.
static func pick_target(asteroids: Array, position: Vector2, padding: float) -> int:
	var nearest := -1
	var best_distance := padding * padding
	for i in range(asteroids.size() - 1, -1, -1):
		var rock: Dictionary = asteroids[i]
		var reach := float(rock.radius) + padding
		if rock.iron <= 0 or position.distance_squared_to(rock.position) > reach * reach:
			continue
		var shape: PackedVector2Array = rock.shape
		var local: Vector2 = position - rock.position
		if Geometry2D.is_point_in_polygon(local, shape):
			return i
		for edge in shape.size():
			var closest := Geometry2D.get_closest_point_to_segment(local, shape[edge], shape[(edge + 1) % shape.size()])
			var distance := local.distance_squared_to(closest)
			if distance < best_distance:
				best_distance = distance
				nearest = i
	return nearest

static func mining_range(asteroid_radius: float, ship_half_length: float) -> float:
	return asteroid_radius + maxf(MINING_REACH, ship_half_length + 35.0)

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

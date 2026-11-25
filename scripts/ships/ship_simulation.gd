extends RefCounted
## Shared travel math; no rendering, scene nodes or input.

const STATE := preload("res://scripts/ships/ship_state.gd")
const JUMP_ARRIVAL_RADIUS := 4.0
const JUMP_ARRIVAL_SPEED := 8.0

static func integrate(ship: Dictionary, motion: Vector2, bounds: Vector2) -> void:
	var p: PackedFloat64Array = ship.galaxy_position
	var x := clampf(p[0] + motion.x, 0.0, bounds.x)
	var y := clampf(p[1] + motion.y, 0.0, bounds.y)
	var velocity: Vector2 = ship.velocity
	if (x == 0.0 and velocity.x < 0.0) or (x == bounds.x and velocity.x > 0.0):
		velocity.x = 0.0
	if (y == 0.0 and velocity.y < 0.0) or (y == bounds.y and velocity.y > 0.0):
		velocity.y = 0.0
	ship.galaxy_position = STATE.point(x, y)
	ship.velocity = velocity

static func approach_speed(distance: float, acceleration: float, rate: float) -> float:
	return minf(distance * rate, sqrt(2.0 * maxf(acceleration, 0.0) * distance) * 0.8)

static func boost_acceleration(speed: float, acceleration: float, velocity: Vector2) -> float:
	return acceleration * lerpf(0.12, 0.65, clampf(velocity.length() / maxf(speed, 0.01), 0.0, 1.0))

extends RefCounted
## Stateless flight calculations shared by player and fleet navigation.

static func navigation_velocity(current: Vector2, forward: Vector2, course: Vector2, target_speed: float, acceleration: float, delta: float) -> Vector2:
	# Navigation can brake drift, but main engines only accelerate forwards.
	var alignment := forward.dot(course)
	if alignment < 0.98:
		return current.move_toward(Vector2.ZERO, acceleration * delta)
	var forward_speed := current.dot(forward)
	var lateral := current - forward * forward_speed
	var braking := maxf(forward_speed - target_speed, 0.0)
	var correction := lateral + forward * braking
	var result := current - correction.limit_length(acceleration * delta)
	var gain := minf(maxf(target_speed - result.dot(forward), 0.0), acceleration * delta)
	return result + forward * gain

## Calculate one simple move-order step. This does not move a physics body or
## modify the order; the ship owner applies the result and handles collisions.
static func move_order_step(position: Vector2, heading: float, velocity: Vector2, destination: Vector2, speed_limit: float, acceleration: float, max_turn_rate: float, approach_rate: float, delta: float) -> Dictionary:
	var offset := destination - position
	if offset.length() <= 4.0:
		return {"arrived": true, "heading": heading, "velocity": Vector2.ZERO, "engine_target": 0.0}
	var next_heading := rotate_toward(heading, offset.angle(), max_turn_rate * delta)
	var course := offset.normalized()
	var forward := Vector2.from_angle(next_heading)
	var desired_speed := minf(speed_limit, offset.length() * approach_rate)
	return {
		"arrived": false,
		"heading": next_heading,
		"velocity": navigation_velocity(velocity, forward, course, desired_speed, acceleration, delta),
		"engine_target": smoothstep(0.98, 0.995, forward.dot(course)),
	}

static func turn_acceleration(max_turn_rate: float) -> float:
	return max_turn_rate * 1.85

static func steered_rotation(angle: float, rate: float, direction: Vector2, max_turn_rate: float, delta: float) -> Vector2:
	var turning := direction.length_squared() > 0.0001
	var error := angle_difference(angle, direction.angle()) if turning else 0.0
	var torque := turn_acceleration(max_turn_rate)
	# Match the remaining angle to the distance needed to brake the turn.
	var desired_rate := signf(error) * minf(max_turn_rate, sqrt(2.0 * torque * absf(error)))
	var next_rate := move_toward(rate, desired_rate, torque * delta)
	var step := next_rate * delta
	if turning and signf(step) == signf(error) and absf(step) >= absf(error):
		return Vector2(direction.angle(), 0.0)
	return Vector2(wrapf(angle + step, -PI, PI), next_rate)

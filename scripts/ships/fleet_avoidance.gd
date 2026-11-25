extends RefCounted
## Short-range navigation around other hulls. Vectors are relative to the moving ship.

static func formation_translation(positions: Array[Vector2], destination: Vector2, minimum: Vector2, maximum: Vector2) -> Vector2:
	var center := Vector2.ZERO
	var low := positions[0]
	var high := low
	for position in positions:
		center += position
		low = low.min(position)
		high = high.max(position)
	return (destination - center / float(positions.size())).clamp(minimum - low, maximum - high)

static func clearance(radius: float, other_radius: float) -> float:
	var combined := radius + other_radius
	return combined + maxf(10.0, combined * 0.12)

static func encounter_time(offset: Vector2, relative_velocity: Vector2, radius: float, horizon: float) -> float:
	# First time the projected relative motion enters the clearance circle.
	var speed_squared := relative_velocity.length_squared()
	var approach := offset.dot(relative_velocity)
	if approach <= 0.0 or speed_squared <= 0.001:
		return INF
	var outside := offset.length_squared() - radius * radius
	if outside <= 0.0:
		return 0.0
	var discriminant := approach * approach - speed_squared * outside
	if discriminant < 0.0:
		return INF
	var time := outside / (approach + sqrt(discriminant))
	return time if time <= horizon else INF

static func encounter_with_stop(offset: Vector2, own_velocity: Vector2, other_velocity: Vector2, radius: float, horizon: float, stop_time: float) -> float:
	var time := encounter_time(offset, own_velocity - other_velocity, radius, minf(horizon, stop_time))
	if time != INF or stop_time >= horizon:
		return time
	# After reaching its slot, the other hull remains an obstacle at that slot.
	return stop_time + encounter_time(offset + (other_velocity - own_velocity) * stop_time,
		own_velocity, radius, horizon - stop_time)

static func detour(course: Vector2, obstacle: Vector2, radius: float, minimum: Vector2, maximum: Vector2) -> Vector2:
	var flank := course.orthogonal()
	# Prefer the side we're already on; a centered encounter uses the same
	# relative passing side for both ships (opposite sides in world space).
	if obstacle.dot(flank) > radius * 0.25:
		flank = -flank
	for side in [flank, -flank]:
		var waypoint: Vector2 = obstacle + side * (radius * 1.65)
		var nearest := Geometry2D.get_closest_point_to_segment(obstacle, Vector2.ZERO, waypoint)
		if nearest.distance_to(obstacle) < radius:
			# If we're already close, turn out before trying to pass abeam.
			var radial := -obstacle.normalized()
			if radial.is_zero_approx():
				radial = -course
			waypoint = obstacle + (radial + side * 0.7).normalized() * (radius * 1.65)
		if waypoint == waypoint.clamp(minimum, maximum):
			return waypoint
	return Vector2.ZERO

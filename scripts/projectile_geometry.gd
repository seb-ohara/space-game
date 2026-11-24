extends RefCounted
## Swept projectile intersections. Returns the first contact point or null.

static func segment_ellipse_hit(start: Vector2, end: Vector2, center: Vector2, ship_heading: float, radii: Vector2) -> Variant:
	# Transform the swept shot into a unit circle so impacts match the rotated rim.
	var rotation := -(ship_heading + PI / 2.0)
	var local_start := (start - center).rotated(rotation) / radii
	var local_end := (end - center).rotated(rotation) / radii
	var movement := local_end - local_start
	var a := movement.length_squared()
	var c := local_start.length_squared() - 1.0
	if c <= 0.0:
		return start
	if a < 0.000001:
		return null
	var b := 2.0 * local_start.dot(movement)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return null
	var t := (-b - sqrt(discriminant)) / (2.0 * a)
	if t < 0.0 or t > 1.0:
		return null
	return start.lerp(end, t)

static func segment_polygon_hit(start: Vector2, end: Vector2, shape: PackedVector2Array) -> Variant:
	if Geometry2D.is_point_in_polygon(start, shape):
		return start
	var closest := INF
	var nearest: Variant = null
	for i in range(shape.size()):
		var contact: Variant = Geometry2D.segment_intersects_segment(start, end, shape[i], shape[(i + 1) % shape.size()])
		if contact != null and start.distance_squared_to(contact) < closest:
			closest = start.distance_squared_to(contact)
			nearest = contact
	return nearest

## Check local hull polygons transformed by the ship's position and heading.
static func ship_hull_hit(start: Vector2, end: Vector2, position: Vector2, heading: float, shapes: Array) -> Variant:
	var rotation := heading + PI / 2.0
	var local_start := (start - position).rotated(-rotation)
	var local_end := (end - position).rotated(-rotation)
	var best_distance := INF
	var nearest := Vector2.ZERO
	for shape in shapes:
		var contact: Variant = segment_polygon_hit(local_start, local_end, shape)
		if contact != null and local_start.distance_squared_to(contact) < best_distance:
			best_distance = local_start.distance_squared_to(contact)
			nearest = contact
	return nearest.rotated(rotation) + position if best_distance < INF else null

## Find the nearest hit among non-depleted asteroids. Shapes are rock-local.
static func asteroid_hit(start: Vector2, end: Vector2, asteroids: Array) -> Variant:
	var midpoint := (start + end) * 0.5
	var half_length := start.distance_to(end) * 0.5
	var closest := INF
	var nearest: Variant = null
	for asteroid in asteroids:
		if asteroid.iron <= 0:
			continue
		var center: Vector2 = asteroid.position
		var reach := half_length + float(asteroid.radius)
		if midpoint.distance_squared_to(center) > reach * reach:
			continue
		var local_start := start - center
		var contact: Variant = segment_polygon_hit(local_start, end - center, asteroid.shape)
		if contact != null and local_start.distance_squared_to(contact) < closest:
			closest = local_start.distance_squared_to(contact)
			nearest = center + contact
	return nearest

## Clip a projectile against occupied exterior cells in ship coordinates.
static func ship_cells_hit(start: Vector2, end: Vector2, position: Vector2, heading: float, exterior: Array, cell_size: float) -> Variant:
	var rotation := -heading - PI / 2.0
	var local_start := (start - position).rotated(rotation)
	var step := (end - start).rotated(rotation)
	var half_cell := Vector2.ONE * cell_size * 0.5
	var first_hit := INF
	for module in exterior:
		var low: Vector2 = module.offset - half_cell
		var high: Vector2 = module.offset + half_cell
		var entry := 0.0
		var exit := 1.0
		for axis in range(2):
			if is_zero_approx(step[axis]):
				if local_start[axis] < low[axis] or local_start[axis] > high[axis]:
					exit = -1.0
					break
				continue
			var near := (low[axis] - local_start[axis]) / step[axis]
			var far := (high[axis] - local_start[axis]) / step[axis]
			entry = maxf(entry, minf(near, far))
			exit = minf(exit, maxf(near, far))
		if entry <= exit:
			first_hit = minf(first_hit, entry)
	return start.lerp(end, first_hit) if first_hit < INF else null

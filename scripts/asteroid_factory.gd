extends RefCounted
## Deterministic asteroid data; rendering and scene ownership stay with the caller.

static func create(position: Vector2, radius: float, ore: float, id: String, galaxy_seed: int, depleted_ore: Dictionary) -> Dictionary:
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = ("%d/rock/%s" % [galaxy_seed, id]).hash()
	var shape := PackedVector2Array()
	var vertex_count := shape_rng.randi_range(19, 30)
	var base := Color.from_hsv(shape_rng.randf_range(0.045, 0.14), shape_rng.randf_range(0.04, 0.25), shape_rng.randf_range(0.25, 0.43))
	# Keep every vertex within radius for the broad-phase checks.
	var phase := shape_rng.randf_range(0.0, TAU)
	var phase2 := shape_rng.randf_range(0.0, TAU)
	var rotation := shape_rng.randf_range(0.0, TAU)
	var squash := shape_rng.randf_range(0.58, 1.0)
	var lobe_count := shape_rng.randi_range(2, 5)
	for i in range(vertex_count):
		var angle := TAU * float(i) / vertex_count
		var relief := 0.79 + 0.10 * sin(angle * lobe_count + phase) + 0.06 * sin(angle * 3.0 + phase2) + shape_rng.randf_range(-0.055, 0.055)
		var point := Vector2(cos(angle), sin(angle) * squash).rotated(rotation) * radius * clampf(relief, 0.55, 1.0)
		shape.append(point)
		# Preserve the original random stream and existing silhouettes.
		shape_rng.randf_range(0.40, 0.58)
		shape_rng.randf_range(-0.15, 0.15)
	var capacity := ore_capacity(radius, ore)
	return {"position": position, "radius": radius, "shape": shape, "base": base, "id": id, "iron": clampi(int(depleted_ore.get(id, capacity)), 0, capacity), "max_iron": capacity}

static func ore_capacity(radius: float, ore: float) -> int:
	return roundi(radius * radius / 42.25 * ore)

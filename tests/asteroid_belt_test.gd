extends SceneTree

const GALAXY = preload("res://scripts/galaxy_generator.gd")

func _initialize() -> void:
	var star := {"id": 17, "center": Vector2(30000.0, -20000.0)}
	var contents := {"belts": [
		{"orbit": 120000.0, "phase": 0.7, "rocks": 4, "ore": 0.8},
		{"orbit": 260000.0, "phase": 2.1, "rocks": 6, "ore": 1.4},
	]}
	var sites: Array[Dictionary] = GALAXY.asteroid_sites(12345, star, contents)
	assert(sites == GALAXY.asteroid_sites(12345, star, contents))
	# Existing pocket positions and ordering must remain compatible with mined-ore saves.
	var old_rng := RandomNumberGenerator.new()
	old_rng.seed = ("%d/%s" % [12345, "asteroids/17"]).hash()
	var old_index := 0
	for belt in contents.belts:
		var bearing := Vector2.from_angle(belt.phase)
		for i in int(belt.rocks):
			var expected: Vector2 = star.center + bearing * float(belt.orbit) + bearing.rotated(TAU * float(i) / int(belt.rocks)) * old_rng.randf_range(950.0, 2100.0)
			var expected_radius := old_rng.randf_range(125.0, 245.0)
			assert((sites[old_index].position as Vector2).is_equal_approx(expected))
			assert(is_equal_approx(sites[old_index].radius, expected_radius))
			old_index += 1
	var counts := [0, 0]
	for site in sites:
		var offset: Vector2 = site.position - star.center
		var index := 0 if offset.length() < 180000.0 else 1
		counts[index] += 1
		var angle_delta := absf(wrapf(offset.angle() - float(contents.belts[index].phase), -PI, PI))
		assert(angle_delta <= GALAXY.asteroid_field_half_angle(contents.belts[index]) + 0.03)
		assert(absf(offset.length() - float(contents.belts[index].orbit)) < 3250.0)
	for index in 2:
		assert(counts[index] >= 250 and counts[index] <= 1000)
	for i in range(old_index, sites.size()):
		assert(sites[i].has("field_id"))
		for j in i:
			assert((sites[i].position as Vector2).distance_to(sites[j].position) >= 499.9)
	var shifted: Array[Dictionary] = GALAXY.asteroid_sites(12345, star, contents, false, Vector2(1000, 2000))
	var relative: Array[Dictionary] = GALAXY.asteroid_sites(12345, star, contents, true)
	for i in sites.size():
		assert((shifted[i].position as Vector2).is_equal_approx(sites[i].position - Vector2(1000, 2000)))
		assert((relative[i].position as Vector2).is_equal_approx(sites[i].position - star.center))
	# Check a range of densities, including the exact requested seeded count.
	for seed_value in 30:
		var sample: Array[Dictionary] = GALAXY.asteroid_sites(seed_value, star, contents)
		var actual := [0, 0]
		for site in sample:
			var offset: Vector2 = site.position - star.center
			actual[0 if offset.length() < 180000.0 else 1] += 1
		for index in 2:
			var rng := RandomNumberGenerator.new()
			rng.seed = ("%d/asteroid-field/17/%d" % [seed_value, index]).hash()
			assert(actual[index] == rng.randi_range(250, 1000))
	print("Asteroid field generation checks passed: ", counts)
	quit()

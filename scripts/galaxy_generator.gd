extends RefCounted

enum BodyKind { SUN, TERRESTRIAL, MOON, BLUE_DWARF, GAS_GIANT, ICE_PLANET, ROCKY,
	RED_DWARF, RED_GIANT, BLUE_GIANT, BLUE_SUPERGIANT, RED_SUPERGIANT, WHITE_DWARF, NEUTRON_STAR,
	SUPER_EARTH, NEPTUNIAN, DWARF_PLANET, HOT_JUPITER, ULTRA_HOT_NEPTUNE, CHTHONIAN, LAVA, OCEAN, CARBON, PULSAR_PLANET }

const VERSION := 4
const CLOUD_VERSION := 3
const MIN_ARMS := 3
const MAX_ARMS := 6
const DEFAULT_ARMS := 4
const ORBIT_SCALE := 4.0
const SPIRAL_VERSION := 2
const GRID_VERSION := 1
const MIN_SYSTEMS := 1
const MAX_SYSTEMS := 1000
const GRID_MAX_SYSTEMS := 64
const DEFAULT_SYSTEMS := 5
const GRID_SECTOR_SIZE := 3400000.0
const SPIRAL_SEPARATION := 2100000.0
const SYSTEM_SEPARATION := SPIRAL_SEPARATION * 3.0
const WIDE_SYSTEM_SEPARATION := SYSTEM_SEPARATION * 12.0
const ARM_START := 0.19
const CORE_RADIUS := 0.26
const MAX_DISC_RADIUS := 920000.0
const AU := 150000.0
const ARRIVAL_MARGIN := 6500.0
const BAND_COUNT := 42
const SOLAR_RADIUS_AU := 0.00465047
const DISC_COMPRESSION := 2.6
const BELT_CLEARANCE := 3700.0
const STARTER_ORBIT := 436000.0
const STARTER_PHASE := -0.4
const STARTER_OFFSET := Vector2(-9045.0, 2700.0)
const STAR_NAMES := [
	"Azure", "Vesper", "Ember", "Meridian", "Aster", "Caelum", "Lyra", "Mira",
	"Rhea", "Orion", "Vega", "Pavo", "Cinder", "Sable", "Nacre", "Aquila",
]

static func create_map(seed_value: int, count: int, version: int = VERSION, arms: int = DEFAULT_ARMS) -> Dictionary:
	if version == GRID_VERSION:
		return _create_grid_map(seed_value, count)
	if version in [CLOUD_VERSION, VERSION]:
		return _create_cloud_map(seed_value, count, version, arms)
	return _create_spiral_map(seed_value, count)

static func _create_spiral_map(seed_value: int, count: int) -> Dictionary:
	count = clampi(count, MIN_SYSTEMS, MAX_SYSTEMS)
	var rng := _random_stream(seed_value, "spiral")
	var rotation := rng.randf_range(0.0, TAU)
	var winding := rng.randf_range(4.1, 5.15) * (-1.0 if rng.randf() < 0.5 else 1.0)
	var aspect := rng.randf_range(0.83, 0.98)
	var flatten := Vector2(1.0, aspect)
	var gap := 0.86 / sqrt(float(count))
	var home := spiral_point(0.66, 0, rotation, winding) * flatten if count > 1 else Vector2.ZERO
	var cells := {}
	_insert_spiral_point(cells, home, gap)
	var positions: Array[Vector2] = []
	var core_count := roundi(count * 0.13)
	for index in range(1, count):
		var point := Vector2.ZERO
		while true:
			var placed := false
			for attempt in 180:
				if index <= core_count:
					point = Vector2.from_angle(rng.randf_range(0.0, TAU)) * CORE_RADIUS * sqrt(rng.randf())
				else:
					var radius := lerpf(ARM_START, 1.0, sqrt(rng.randf()))
					var scatter := lerpf(0.36, 0.22, radius) * rng.randf_range(-1.0, 1.0)
					point = spiral_point(radius, index % 2, rotation + scatter, winding)
				point *= flatten
				if _fits_spiral_point(cells, point, gap):
					placed = true
					break
			if placed:
				break
			# Increase the physical radius of the galaxy if an arm runs out of room.
			gap *= 0.9
			cells.clear()
			_insert_spiral_point(cells, home, gap)
			for previous in positions:
				_insert_spiral_point(cells, previous, gap)
		positions.append(point)
		_insert_spiral_point(cells, point, gap)
	# Reveal the core first, then build the arms outward.
	positions.sort_custom(func(a: Vector2, b: Vector2): return a.length_squared() < b.length_squared())
	positions.push_front(home)

	var radius_scale := SPIRAL_SEPARATION / gap
	var margin := MAX_DISC_RADIUS + 400000.0
	var origin := flatten * radius_scale + Vector2.ONE * margin if count > 1 else Vector2.ONE * GRID_SECTOR_SIZE * 0.5
	var systems: Array[Dictionary] = []
	var name_offset := rng.randi_range(0, STAR_NAMES.size() - 1)
	for index in count:
		var star_name: String = STAR_NAMES[(name_offset + index - 1) % STAR_NAMES.size()]
		if index > STAR_NAMES.size():
			star_name += " %d" % (int((index - 1) / STAR_NAMES.size()) + 1)
		systems.append(_star(index, star_name, origin + positions[index] * radius_scale, rng))
	return {"seed": seed_value, "generator_version": SPIRAL_VERSION, "world_size": origin * 2.0, "systems": systems,
		"spiral": {"rotation": rotation, "winding": winding, "scale": flatten * radius_scale}}

static func spiral_point(radius: float, arm: int, rotation: float, winding: float) -> Vector2:
	return Vector2.from_angle(rotation + PI * arm + winding * pow(radius, 0.7)) * radius

static func _fits_spiral_point(cells: Dictionary, point: Vector2, gap: float) -> bool:
	var cell := Vector2i((point / gap).floor())
	for y in range(cell.y - 1, cell.y + 2):
		for x in range(cell.x - 1, cell.x + 2):
			for other: Vector2 in cells.get(Vector2i(x, y), []):
				if point.distance_squared_to(other) < gap * gap:
					return false
	return true

static func _insert_spiral_point(cells: Dictionary, point: Vector2, gap: float) -> void:
	var cell := Vector2i((point / gap).floor())
	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(point)

static func _create_grid_map(seed_value: int, count: int) -> Dictionary:
	count = clampi(count, MIN_SYSTEMS, GRID_MAX_SYSTEMS)
	var rng := _random_stream(seed_value, "map")
	var columns := ceili(sqrt(count * 1.2)) if count > 1 else 1
	var rows := ceili(float(count) / columns)
	var slots: Array[Vector2i] = []
	for y in rows:
		for x in columns:
			slots.append(Vector2i(x, y))

	var home := Vector2i((columns - 1) >> 1, (rows - 1) >> 1)
	slots.erase(home)
	for i in range(slots.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, i)
		var slot := slots[i]
		slots[i] = slots[swap_index]
		slots[swap_index] = slot
	slots.push_front(home)
	var systems: Array[Dictionary] = []
	var name_offset := rng.randi_range(0, STAR_NAMES.size() - 1)
	for index in count:
		var center := (Vector2(slots[index]) + Vector2(0.5, 0.5)) * GRID_SECTOR_SIZE
		if index > 0:
			center += Vector2(rng.randf_range(-0.19, 0.19), rng.randf_range(-0.19, 0.19)) * GRID_SECTOR_SIZE
		var star_name: String = STAR_NAMES[(name_offset + index - 1) % STAR_NAMES.size()]
		if index > STAR_NAMES.size():
			star_name += " " + ["II", "III", "IV"][int((index - 1) / STAR_NAMES.size()) - 1]
		systems.append(_star(index, star_name, center, rng))
	return {"seed": seed_value, "generator_version": GRID_VERSION,
		"world_size": Vector2(columns, rows) * GRID_SECTOR_SIZE, "systems": systems}

static func _star(index: int, star_name: String, center: Vector2, rng: RandomNumberGenerator) -> Dictionary:
	var star_mass := rng.randf_range(0.48, 1.65) if index > 0 else 1.0
	var blue := star_mass > 1.26
	return {
		"id": index, "name": "Sol" if index == 0 else star_name,
		"center": center, "mass": star_mass,
		"radius": 40000.0 if index == 0 else 32000.0 * sqrt(star_mass),
		"extent": 2.9 if blue else 2.65,
		"kind": BodyKind.BLUE_DWARF if blue else BodyKind.SUN,
		"color": Color("a2ddff") if blue else Color("ffd292"),
	}

static func starter_offset(version: int) -> Vector2:
	return Vector2.from_angle(STARTER_PHASE) * STARTER_ORBIT * orbit_scale_for(version) + STARTER_OFFSET

static func starting_position(galaxy: Dictionary) -> Vector2:
	if int(galaxy.generator_version) == VERSION:
		return galaxy.systems[0].center + starter_offset(VERSION)
	return galaxy.systems[0].center + Vector2.from_angle(STARTER_PHASE) * STARTER_ORBIT + STARTER_OFFSET

static func form_system(seed_value: int, star: Dictionary, version: int = -1) -> Dictionary:
	if version == VERSION or (version < 0 and star.get("wide_orbits", false)):
		var contents := _accrete_system(seed_value, star)
		var edge := float(star.radius) * float(star.extent)
		for planet: Dictionary in contents.planets:
			planet.orbit *= ORBIT_SCALE
			planet.formation_orbit *= ORBIT_SCALE
			for moon: Dictionary in planet.moons:
				moon.orbit *= ORBIT_SCALE
			planet.reach = _body_reach(planet)
			edge = maxf(edge, float(planet.orbit) * (1.0 + float(planet.eccentricity)) + float(planet.reach))
		for belt: Dictionary in contents.belts:
			belt.orbit *= ORBIT_SCALE
			edge = maxf(edge, float(belt.orbit) + 5500.0)
		contents.ice_line *= ORBIT_SCALE
		contents.edge = edge
		return contents
	if version == CLOUD_VERSION or (version < 0 and star.has("formation_luminosity")):
		return _accrete_system(seed_value, star)
	return _form_legacy_system(seed_value, star)

static func _form_legacy_system(seed_value: int, star: Dictionary) -> Dictionary:
	var rng := _random_stream(seed_value, "disc/%d" % int(star.id))
	var is_home := int(star.id) == 0
	var inner := float(star.radius) * float(star.extent) + 34000.0
	var outer := MAX_DISC_RADIUS if is_home else rng.randf_range(610000.0, MAX_DISC_RADIUS)
	var width := (outer - inner) / BAND_COUNT
	var ice_line := lerpf(inner, outer, clampf(0.43 * pow(float(star.mass), 1.25), 0.24, 0.75))
	var disc_mass := rng.randf_range(0.55, 2.0)
	var metal_fraction := rng.randf_range(0.14, 0.36)
	var gas_supply := rng.randf_range(0.8, 2.4)
	var planets: Array[Dictionary] = []
	if is_home:
		var starter := _planet(BodyKind.TERRESTRIAL, STARTER_ORBIT, STARTER_PHASE, 2400.0, 8250.0)
		# Reserve space for the authored starter moon before the disc forms its neighbours.
		starter.reach = 36000.0
		planets.append(starter)
		planets.append(_planet(BodyKind.GAS_GIANT, 828000.0, -1.22, 6100.0, 14400.0))

	var bands: Array[Dictionary] = []
	for i in BAND_COUNT:
		var orbit := inner + width * (i + 0.5)
		var frozen := orbit >= ice_line
		var density := disc_mass * rng.randf_range(0.45, 1.5) * lerpf(1.25, 0.48, float(i) / BAND_COUNT)
		var rock := density if _clears_planets(orbit, planets, 66000.0) else 0.0
		bands.append({"orbit": orbit, "rock": rock, "ice": rock * 1.15 if frozen else 0.0})

	var embryos: Array[Dictionary] = []
	for i in range(1, BAND_COUNT - 1):
		if float(bands[i].rock) > 0.0 and rng.randf() < 0.32:
			embryos.append({"band": i, "rock": 0.0, "ice": 0.0})
	# Large embryos reach into more bands. Every draw leaves less material for their neighbours.
	for pass_index in 7:
		for j in embryos.size():
			var embryo: Dictionary = embryos[(j + pass_index) % embryos.size()]
			var reach := clampi(int((float(embryo.rock) + float(embryo.ice)) / 1.55), 0, 3)
			for i in range(maxi(0, int(embryo.band) - reach), mini(BAND_COUNT, int(embryo.band) + reach + 1)):
				var share := 0.32 / (1.0 + absi(i - int(embryo.band)))
				for material in ["rock", "ice"]:
					var collected := float(bands[i][material]) * share
					bands[i][material] -= collected
					embryo[material] += collected

	var survivors: Array[Dictionary] = []
	for embryo in embryos:
		if not survivors.is_empty():
			var neighbour: Dictionary = survivors.back()
			if (int(embryo.band) - int(neighbour.band)) * width < 52000.0:
				# Keep the heavier body's orbit after a merger.
				if float(embryo.rock) + float(embryo.ice) > float(neighbour.rock) + float(neighbour.ice):
					neighbour.band = embryo.band
				neighbour.rock += embryo.rock
				neighbour.ice += embryo.ice
				continue
		survivors.append(embryo)

	for embryo in survivors:
		var orbit: float = bands[embryo.band].orbit
		var core := float(embryo.rock) + float(embryo.ice)
		if core < 0.70:
			# Subplanetary material stays available for belts.
			bands[embryo.band].rock += embryo.rock
			bands[embryo.band].ice += embryo.ice
			continue
		var kind := BodyKind.ROCKY
		var gas := 0.0
		if float(embryo.ice) > core * 0.35:
			kind = BodyKind.ICE_PLANET
			if core > 3.25 and gas_supply >= 0.7:
				kind = BodyKind.GAS_GIANT
				gas = minf(gas_supply, core * 0.32)
				gas_supply -= gas
		elif core > 1.4 and orbit > ice_line * 0.62:
			kind = BodyKind.TERRESTRIAL
		var radius := clampf(4250.0 * pow(core, 0.38), 2700.0, 8900.0) + 3900.0 * gas
		var period := 2300.0 * pow(orbit / 360000.0, 1.5) / sqrt(float(star.mass))
		planets.append(_planet(kind, orbit, rng.randf_range(0.0, TAU), period, radius))

	planets.sort_custom(func(a: Dictionary, b: Dictionary): return a.orbit < b.orbit)
	var edge := float(star.radius) * float(star.extent)
	for index in planets.size():
		var planet := planets[index]
		var orbit := float(planet.orbit)
		var before := float(planets[index - 1].orbit) if index > 0 else inner - 20000.0
		var after := float(planets[index + 1].orbit) if index + 1 < planets.size() else outer + 20000.0
		var clearance := minf(orbit - before, after - orbit) * 0.44
		var chance := 0.92 if planet.kind == BodyKind.GAS_GIANT else (0.52 if planet.kind == BodyKind.ICE_PLANET else 0.32)
		if is_home and orbit == STARTER_ORBIT:
			planet.moons.append(_moon(52000.0, 2.85, 1980.0, 0.26, 0.9))
		elif clearance > 27500.0 and rng.randf() < chance:
			var moon_orbit := maxf(float(planet.radius) + 9000.0, 19000.0)
			planet.moons.append(_moon(moon_orbit, rng.randf_range(0.0, TAU), rng.randf_range(950.0, 2150.0), 0.12, rng.randf_range(0.0, TAU)))
			if clearance > 51000.0 and planet.kind == BodyKind.GAS_GIANT:
				planet.moons.append(_moon(moon_orbit + 17000.0, rng.randf_range(0.0, TAU), 1475.0, 0.12, rng.randf_range(0.0, TAU)))
		var reach := float(planet.radius) * float(planet.extent)
		for moon in planet.moons:
			reach = maxf(reach, float(moon.orbit) * (1.0 + float(moon.eccentricity)) + float(moon.radius) * float(moon.extent))
		planet.reach = reach
		edge = maxf(edge, orbit + reach)

	var belt_candidates: Array[Dictionary] = []
	for band in bands:
		var residual := float(band.rock) + float(band.ice)
		if residual >= 0.24 and _clears_planets(band.orbit, planets, 14000.0):
			belt_candidates.append({"orbit": band.orbit, "mass": residual, "ore": clampf(float(band.rock) / residual * metal_fraction * 6.0, 0.35, 2.0)})
	belt_candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.mass > b.mass)
	var belts: Array[Dictionary] = []
	for belt in belt_candidates:
		if not belts.is_empty() and absf(float(belt.orbit) - float(belts[0].orbit)) < 95000.0:
			continue
		belt.phase = rng.randf_range(0.0, TAU)
		belt.rocks = clampi(3 + roundi(float(belt.mass)), 3, 7)
		belts.append(belt)
		edge = maxf(edge, float(belt.orbit) + 5500.0)
		if belts.size() >= (2 if disc_mass > 1.15 else 1):
			break
	return {"planets": planets, "belts": belts, "ice_line": ice_line, "edge": edge}

static func asteroid_sites(seed_value: int, star: Dictionary, contents: Dictionary, star_relative := false, origin := Vector2.ZERO) -> Array[Dictionary]:
	var rng := _random_stream(seed_value, "asteroids/%d" % int(star.id))
	var sites: Array[Dictionary] = []
	var center: Vector2 = Vector2.ZERO if star_relative else star.center
	if int(star.id) == 0:
		var starter := center + Vector2.from_angle(STARTER_PHASE) * STARTER_ORBIT + STARTER_OFFSET
		if star.get("wide_orbits", false):
			starter = center + starter_offset(VERSION)
		sites.append({"position": starter + Vector2(620.0, -120.0), "radius": 172.0, "ore": 1.0})
	for belt in contents.belts:
		var bearing := Vector2.from_angle(belt.phase)
		var cluster_center := center + bearing * float(belt.orbit)
		for i in int(belt.rocks):
			var offset := bearing.rotated(TAU * float(i) / int(belt.rocks)) * rng.randf_range(950.0, 2100.0)
			sites.append({"position": cluster_center + offset, "radius": rng.randf_range(125.0, 245.0), "ore": float(belt.ore)})
	if not star_relative and origin != Vector2.ZERO:
		for site in sites:
			site.position -= origin
	return sites

static func _random_stream(seed_value: int, stream: String) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = ("%d/%s" % [seed_value, stream]).hash()
	return result

static func _clears_planets(orbit: float, planets: Array[Dictionary], margin: float) -> bool:
	for planet in planets:
		if absf(orbit - float(planet.orbit)) < float(planet.get("reach", 0.0)) + margin:
			return false
	return true

static func _planet(kind: int, orbit: float, phase: float, period: float, radius: float) -> Dictionary:
	var colors := {
		BodyKind.TERRESTRIAL: Color("65d3d6"), BodyKind.GAS_GIANT: Color("eaaa76"),
		BodyKind.ICE_PLANET: Color("c7c7f1"), BodyKind.ROCKY: Color("c1a385"),
	}
	return {"orbit": orbit, "phase": phase, "radius": radius, "period": period,
		"extent": 1.055, "kind": kind, "color": colors[kind], "moons": []}

static func _moon(orbit: float, phase: float, radius: float, eccentricity: float, angle: float) -> Dictionary:
	return {"orbit": orbit, "phase": phase, "radius": radius, "extent": 1.015,
		"period": 320.0 * pow(orbit / 43200.0, 1.5), "eccentricity": eccentricity,
		"orbit_angle": angle, "kind": BodyKind.MOON, "color": Color("b9c5e1")}

# This spiral density field stands in for a fully simulated galactic disc. Gas
# collects in perturbed arms and a central bulge; stars sample the dense lanes.
static func cloud_arm_angle(radius: float, arm: int, shape: Dictionary) -> float:
	return float(shape.rotation) + TAU * arm / int(shape.arms) + float(shape.winding) * pow(radius, 0.7) \
		+ 0.085 * sin(radius * 13.0 + float(shape.phase) + arm * 2.1)

static func _create_cloud_map(seed_value: int, count: int, version: int, arms: int) -> Dictionary:
	count = clampi(count, MIN_SYSTEMS, MAX_SYSTEMS)
	var rng := _random_stream(seed_value, "cloud disc")
	var shape := {"rotation": rng.randf_range(0.0, TAU), "phase": rng.randf_range(0.0, TAU),
		"winding": rng.randf_range(3.9, 5.5) * (-1.0 if rng.randf() < 0.5 else 1.0),
		"arms": 2 if rng.randf() < 0.8 else 3}
	var wide := version == VERSION
	if wide:
		shape.arms = clampi(arms, MIN_ARMS, MAX_ARMS)
	var lane_scale := minf(1.0, 3.6 / int(shape.arms)) if wide else 1.0
	var flatten := Vector2(1.0, rng.randf_range(0.78, 0.95))
	var gap := 0.84 / sqrt(float(count))
	var positions: Array[Vector2] = []
	var cells := {}
	var home := Vector2.from_angle(cloud_arm_angle(0.66, 0, shape)) * 0.66 * flatten
	if count == 1:
		home = Vector2.ZERO
	_insert_spiral_point(cells, home, gap)
	var core_count := roundi(count * 0.12)
	for id in range(1, count):
		var point := Vector2.ZERO
		while true:
			var placed := false
			for attempt in 160:
				if id <= core_count:
					point = Vector2.from_angle(rng.randf_range(0.0, TAU)) * CORE_RADIUS * pow(rng.randf(), 0.72)
				else:
					var arm := (id - 1) % int(shape.arms)
					var r := lerpf(ARM_START, 0.97, pow(rng.randf(), 0.72))
					# Patchy star forming complexes along the arms, with a small diffuse population.
					var clump := sin(r * 37.0 + float(shape.phase) + arm * 1.9) * 0.5 + 0.5
					if rng.randf() > lerpf(0.42, 1.0, clump):
						continue
					var offset := clampf(rng.randfn(0.0, lerpf(0.19, 0.106, r)), -0.38, 0.38)
					point = Vector2.from_angle(cloud_arm_angle(r, arm, shape) + offset * lane_scale) * r
				point *= flatten
				if _fits_spiral_point(cells, point, gap):
					placed = true
					break
			if placed:
				break
			gap *= 0.9
			cells.clear()
			_insert_spiral_point(cells, home, gap)
			for previous in positions:
				_insert_spiral_point(cells, previous, gap)
		positions.append(point)
		_insert_spiral_point(cells, point, gap)
	positions.sort_custom(func(a: Vector2, b: Vector2): return a.length_squared() < b.length_squared())
	positions.push_front(home)

	# The small cushion keeps the actual stored Vector2 spacing above the minimum.
	var separation := separation_for(version)
	var radius_scale := (separation + (8192.0 if wide else 512.0)) / gap
	if count == 1:
		radius_scale = separation * 0.5 if wide else GRID_SECTOR_SIZE * 0.31
	var margin := MAX_DISC_RADIUS * orbit_scale_for(version) + 400000.0
	var origin := flatten * radius_scale + Vector2.ONE * margin
	shape.scale = flatten * radius_scale
	shape.separation = separation
	var systems: Array[Dictionary] = []
	var name_offset := rng.randi_range(0, STAR_NAMES.size() - 1)
	for id in count:
		var star_name: String = STAR_NAMES[(name_offset + id - 1) % STAR_NAMES.size()]
		if id > STAR_NAMES.size():
			star_name += " %d" % (int((id - 1) / STAR_NAMES.size()) + 1)
		systems.append(_evolved_star(seed_value, id, star_name, origin + positions[id] * radius_scale, (positions[id] / flatten).length()))
		if wide:
			systems.back().wide_orbits = true
	return {"seed": seed_value, "generator_version": version, "world_size": origin * 2.0,
		"systems": systems, "spiral": shape}

static func _evolved_star(seed_value: int, id: int, star_name: String, center: Vector2, galactic_radius: float) -> Dictionary:
	var rng := _random_stream(seed_value, "stellar/%d" % id)
	var roll := rng.randf()
	var kind := BodyKind.SUN
	var stage := "Main sequence"
	var mass := 1.0
	var temperature := 5772.0
	var physical_radius := 1.0
	var age := rng.randf_range(0.25, 9.0)
	var birth_mass := 1.0
	var radiation := 0.0
	if id > 0:
		if roll < 0.70:
			kind = BodyKind.RED_DWARF
			stage = "Red dwarf"
			mass = rng.randf_range(0.11, 0.58)
			temperature = lerpf(2550.0, 3900.0, inverse_lerp(0.11, 0.58, mass))
			physical_radius = pow(mass, 0.84)
		elif roll < 0.90:
			mass = rng.randf_range(0.62, 2.25)
			temperature = 5772.0 * pow(mass, 0.49)
			physical_radius = pow(mass, 0.82)
			age = minf(age, 9.7 / pow(mass, 2.5))
		elif roll < 0.935:
			kind = BodyKind.RED_GIANT
			stage = "Red giant"
			mass = rng.randf_range(1.1, 2.45)
			temperature = rng.randf_range(3450.0, 4900.0)
			physical_radius = rng.randf_range(9.0, 55.0)
			age = 10.2 / pow(mass, 2.5)
		elif roll < 0.952:
			kind = BodyKind.BLUE_GIANT
			stage = "Blue giant"
			mass = rng.randf_range(4.0, 10.0)
			temperature = rng.randf_range(11000.0, 24000.0)
			physical_radius = rng.randf_range(4.5, 12.0)
			age = rng.randf_range(0.02, 0.12)
		elif roll < 0.961:
			kind = BodyKind.BLUE_SUPERGIANT
			stage = "Blue supergiant"
			mass = rng.randf_range(12.0, 26.0)
			temperature = rng.randf_range(12500.0, 27500.0)
			physical_radius = rng.randf_range(19.0, 58.0)
			age = rng.randf_range(0.004, 0.018)
		elif roll < 0.971:
			kind = BodyKind.RED_SUPERGIANT
			stage = "Red supergiant"
			mass = rng.randf_range(10.0, 19.0)
			temperature = rng.randf_range(3000.0, 4050.0)
			physical_radius = rng.randf_range(220.0, 820.0)
			age = rng.randf_range(0.009, 0.027)
		elif roll < 0.992:
			kind = BodyKind.WHITE_DWARF
			stage = "White dwarf"
			mass = rng.randf_range(0.53, 1.25)
			birth_mass = rng.randf_range(1.35, 3.7)
			temperature = rng.randf_range(7800.0, 38000.0)
			physical_radius = rng.randf_range(0.008, 0.017)
			age = rng.randf_range(4.0, 11.0)
		else:
			kind = BodyKind.NEUTRON_STAR
			stage = "Neutron star · Pulsar"
			mass = rng.randf_range(1.22, 2.08)
			birth_mass = rng.randf_range(9.0, 20.0)
			temperature = rng.randf_range(250000.0, 680000.0)
			physical_radius = rng.randf_range(0.000014, 0.000020)
			age = rng.randf_range(0.04, 1.8)
			radiation = rng.randf_range(2.0, 6.0)
	var luminosity := physical_radius * physical_radius * pow(temperature / 5772.0, 4.0)
	# Evolved stars had a different frost line while their original discs existed.
	var birth_luminosity := luminosity
	if kind == BodyKind.RED_GIANT or kind == BodyKind.RED_SUPERGIANT or kind == BodyKind.BLUE_SUPERGIANT or kind == BodyKind.WHITE_DWARF:
		birth_luminosity = pow(birth_mass if kind == BodyKind.WHITE_DWARF else mass, 3.5)
	if kind == BodyKind.NEUTRON_STAR:
		birth_luminosity = luminosity # Use the second generation fallback disc.
	var radius := clampf(40000.0 * pow(physical_radius, 0.31), 5100.0, 132000.0)
	var tint := _stellar_color(temperature)
	return {"id": id, "name": "Sol" if id == 0 else star_name, "center": center, "mass": mass,
		"stage": stage, "age_gyr": age, "temperature": temperature, "stellar_radius": physical_radius,
		"luminosity": luminosity, "formation_luminosity": birth_luminosity,
		"radiation": radiation, "pulses": kind == BodyKind.NEUTRON_STAR,
		"metallicity": clampf(rng.randf_range(0.55, 1.65) * (1.18 - 0.43 * galactic_radius), 0.32, 1.7),
		"radius": radius, "extent": 3.65 if kind == BodyKind.NEUTRON_STAR else (2.36 if radius > 80000.0 else 2.75),
		"kind": kind, "color": tint, "surface_seed": rng.randf_range(1.0, 150.0),
		"surface_scale": rng.randf_range(0.75, 1.28) * (0.66 if radius > 80000.0 else 1.0)}

static func _stellar_color(temperature: float) -> Color:
	if temperature < 4500.0:
		return Color("ff6942").lerp(Color("ffba79"), smoothstep(2500.0, 4500.0, temperature))
	if temperature < 6500.0:
		return Color("ffba79").lerp(Color("fff7df"), smoothstep(4500.0, 6500.0, temperature))
	return Color("fff7df").lerp(Color("86b4ff"), smoothstep(6500.0, 28000.0, temperature))

static func separation_for(version: int) -> float:
	if version == VERSION:
		return WIDE_SYSTEM_SEPARATION
	return SYSTEM_SEPARATION if version == CLOUD_VERSION else SPIRAL_SEPARATION

static func orbit_scale_for(version: int) -> float:
	return ORBIT_SCALE if version == VERSION else 1.0

# Physical properties are in Earth/Solar units. Compress distances independently
# of body size so the whole disc remains usable at the game's system zoom.
static func _accrete_system(seed_value: int, star: Dictionary) -> Dictionary:
	var rng := _random_stream(seed_value, "accretion/%d" % int(star.id))
	var home: bool = star.id == 0
	var pulsar: bool = star.kind == BodyKind.NEUTRON_STAR
	var stellar_edge := float(star.radius) * float(star.extent)
	var inner := stellar_edge + 24000.0
	var outer := MAX_DISC_RADIUS if home else rng.randf_range(700000.0, MAX_DISC_RADIUS)
	var frost_au := 2.7 * sqrt(float(star.formation_luminosity))
	var inner_au := maxf(0.007, float(star.stellar_radius) * SOLAR_RADIUS_AU * 1.28)
	var outer_au := 6.1 if home else maxf(rng.randf_range(2.5, 8.0), frost_au * rng.randf_range(0.77, 2.55))
	var width := (outer - inner) / BAND_COUNT
	# Leave room for close-in migrants between the star and the first embryos.
	outer_au = maxf(outer_au, inner_au * 1.5)
	var frost_line := lerpf(inner, outer, pow(maxf(0.0, inverse_lerp(inner_au, outer_au, frost_au)), 1.0 / DISC_COMPRESSION))
	var density := rng.randf_range(0.45, 3.0) * float(star.metallicity) * (0.20 if pulsar else 1.0)
	var gas_left := pow(rng.randf(), 2.0) * 3600.0 * density if not pulsar else 0.0
	var carbon_ratio := rng.randf_range(0.34, 0.83) + (rng.randf_range(0.35, 0.54) if rng.randf() < 0.09 else 0.0)
	var planets: Array[Dictionary] = []
	var belts: Array[Dictionary] = []
	var history: Array[String] = []
	if home:
		var starter := _world(rng, star, BodyKind.TERRESTRIAL, STARTER_ORBIT, 1.0, 1.0, 0.20, 0.0)
		starter.merge({"phase": STARTER_PHASE, "period": 2400.0, "radius": 8250.0}, true)
		starter.moons.append(_formed_moon(rng, 52000.0, 2.85, 1980.0, 0.26, 0.9, "Cratered", false))
		_set_physical_orbit(starter, star, 1.0, 1.0)
		starter.reach = _body_reach(starter)
		planets.append(starter)
		var giant := _world(rng, star, BodyKind.GAS_GIANT, 828000.0, 318.0, 11.2, 0.36, 0.92)
		giant.merge({"phase": -1.22, "period": 6100.0}, true)
		_set_physical_orbit(giant, star, 5.2, 5.2)
		giant.reach = _body_reach(giant)
		planets.append(giant)
	# Most neutron stars lack planets; rare survivors here accrete out of fallback debris.
	var embryos: Array[Dictionary] = []
	var bands: Array[Dictionary] = []
	var can_form := not pulsar or rng.randf() < 0.32
	for i in BAND_COUNT:
		var orbit := inner + width * (i + 0.5)
		var rock := density * rng.randf_range(0.22, 1.8) * lerpf(1.32, 0.55, float(i) / BAND_COUNT)
		var ice := rock * rng.randf_range(1.15, 2.35) if orbit >= frost_line else 0.0
		if not _orbit_clear(orbit, 0.0, 18000.0, planets):
			rock = 0.0
			ice = 0.0
		bands.append({"orbit": orbit, "rock": rock, "ice": ice})
		if can_form and i >= 2 and rock > 0.0 and rng.randf() < 0.30:
			embryos.append({"band": i, "rock": 0.0, "ice": 0.0})
	# Growing embryos compete for the same material. A larger core feeds
	# from more annuli; inner cores never accrete frozen material.
	for step in 7:
		for j in embryos.size():
			var embryo: Dictionary = embryos[(j + step) % embryos.size()]
			var index := int(embryo.band)
			var reach := clampi(int((float(embryo.rock) + float(embryo.ice)) / 2.0), 1, 3)
			for i in range(maxi(0, index - reach), mini(BAND_COUNT, index + reach + 1)):
				var band := bands[i]
				if (band.orbit >= frost_line) != (bands[index].orbit >= frost_line):
					continue
				var share := 0.24 / (1.0 + absi(index - i))
				for material in ["rock", "ice"]:
					var amount := float(band[material]) * share
					band[material] -= amount
					embryo[material] += amount
	embryos.sort_custom(func(a: Dictionary, b: Dictionary): return a.rock + a.ice > b.rock + b.ice)
	var migrant: Dictionary = {}
	for embryo in embryos:
		var orbit := float(bands[int(embryo.band)].orbit)
		var orbit_au := _disc_au(orbit, inner, outer, inner_au, outer_au)
		var core := float(embryo.rock) + float(embryo.ice)
		if core < 0.08:
			continue
		var ice_fraction := float(embryo.ice) / maxf(core, 0.001)
		var gas := 0.0
		var kind := BodyKind.TERRESTRIAL if core < 2.0 else BodyKind.SUPER_EARTH
		var mass := clampf(core, 0.08, 10.0)
		var earth_radius := clampf(pow(mass, 0.29), 0.5, 2.0)
		if orbit >= frost_line and core >= 2.8 and gas_left >= 7.5 and not pulsar:
			if core >= 5.5 and gas_left >= 65.0 and rng.randf() < 0.66:
				gas = minf(minf(gas_left, 5000.0 - core), maxf(50.0 - core, pow(core, 2.05) * rng.randf_range(1.3, 7.5)))
				mass = core + gas
				earth_radius = clampf(6.0 + 3.5 * log(mass / 50.0 + 1.0), 6.0, 17.0)
				kind = BodyKind.GAS_GIANT
			else:
				gas = minf(gas_left, clampf(core * rng.randf_range(0.55, 2.7), maxf(0.0, 10.0 - core), 50.0 - core))
				mass = core + gas
				earth_radius = lerpf(2.0, 6.0, sqrt(inverse_lerp(10.0, 50.0, mass)))
				kind = BodyKind.NEPTUNIAN
		elif pulsar:
			kind = BodyKind.PULSAR_PLANET
		elif carbon_ratio > 1.0 and orbit < frost_line and rng.randf() < 0.59:
			kind = BodyKind.CARBON
		elif ice_fraction > 0.28 and orbit < frost_line + width * 6.0 and rng.randf() < 0.65:
			kind = BodyKind.OCEAN
		elif orbit < frost_line and _day_side_temperature(star, orbit_au) > 1500.0 and _period_days(star, orbit_au) < 10.0 and rng.randf() < 0.48:
			kind = BodyKind.LAVA
		elif ice_fraction > 0.30:
			kind = BodyKind.ICE_PLANET
		var birth_kind := kind
		var birth_mass := mass
		var gas_fraction := gas / mass
		var migrated := false
		var puffy := false
		var destination := orbit
		if not home and migrant.is_empty() and gas > 0.0 and orbit > inner + width * 11.0 and rng.randf() < 0.30:
			var close_orbit := inner + width * rng.randf_range(1.25, 3.5)
			var close_au := _disc_au(close_orbit, inner, outer, inner_au, outer_au)
			if _period_days(star, close_au) <= 10.0 and _equilibrium_temperature(star, close_au) >= 700.0:
				destination = close_orbit
				migrated = true
				puffy = rng.randf() < 0.64
				if kind == BodyKind.GAS_GIANT and _equilibrium_temperature(star, close_au) > 1050.0 and rng.randf() < 0.43:
					kind = BodyKind.CHTHONIAN
					mass = core
					earth_radius = clampf(0.82 * pow(mass, 0.27), 1.0, 3.2)
					gas_fraction = 0.0
					puffy = false
				else:
					kind = BodyKind.HOT_JUPITER if kind == BodyKind.GAS_GIANT else BodyKind.ULTRA_HOT_NEPTUNE
					if puffy:
						earth_radius *= rng.randf_range(1.22, 1.52)
		var planet := _world(rng, star, kind, destination, mass, earth_radius, ice_fraction, gas_fraction, puffy)
		planet.formation_orbit = orbit
		planet.formation_kind = birth_kind
		planet.formation_mass = birth_mass
		_set_physical_orbit(planet, star, _disc_au(destination, inner, outer, inner_au, outer_au), orbit_au)
		if not _orbit_clear(destination, 0.0, float(planet.reach) + 22000.0, planets) or destination + float(planet.reach) > outer or destination - float(planet.reach) < stellar_edge:
			continue
		gas_left -= gas
		planet.migrated = migrated
		if migrated:
			migrant = planet
			history.append("%s migrated inward" % planet.archetype)
		planets.append(planet)
	# Small spherical survivors share their orbit with uncleared debris.
	for i in range(BAND_COUNT - 2, 5, -1):
		if not can_form or pulsar or rng.randf() >= 0.10:
			continue
		var band := bands[i]
		if float(band.rock) + float(band.ice) < 0.16 or not _orbit_clear(band.orbit, 0.0, 22000.0, planets):
			continue
		var fraction := float(band.ice) / (float(band.rock) + float(band.ice))
		var dwarf := _world(rng, star, BodyKind.DWARF_PLANET, band.orbit, rng.randf_range(0.0008, 0.035), rng.randf_range(0.12, 0.36), fraction, 0.0)
		var debris_orbit := float(band.orbit) + float(dwarf.reach) + 2.0 * BELT_CLEARANCE
		if debris_orbit + BELT_CLEARANCE > outer or not _orbit_clear(debris_orbit, 0.0, BELT_CLEARANCE, planets):
			continue
		dwarf.orbit_cleared = false
		var dwarf_au := _disc_au(band.orbit, inner, outer, inner_au, outer_au)
		_set_physical_orbit(dwarf, star, dwarf_au, dwarf_au)
		planets.append(dwarf)
		belts.append(_debris_belt(rng, debris_orbit, float(band.rock) + float(band.ice), "Uncleared dwarf planet orbit", float(dwarf.phase) + PI))
		break
	if not migrant.is_empty():
		var scattered := false
		for planet in planets:
			if planet == migrant or planet.kind == BodyKind.DWARF_PLANET or float(planet.orbit) >= float(migrant.formation_orbit) or float(planet.gas_fraction) > 0.0:
				continue
			for e: float in [0.19, 0.12, 0.06]:
				if _orbit_clear(planet.orbit, e, float(planet.reach) + 4000.0, planets, planet) and _clears_debris(planet.orbit, e, planet.reach, belts) and float(planet.orbit) * (1.0 + e) + float(planet.reach) <= outer and float(planet.orbit) * (1.0 - e) - float(planet.reach) >= stellar_edge:
					planet.eccentricity = e
					planet.scattered = true
					history.append("A rocky world was scattered")
					scattered = true
					break
			if scattered:
				break
		var debris := (float(migrant.orbit) + float(migrant.formation_orbit)) * 0.5
		for band in bands:
			if absf(float(band.orbit) - debris) < width * 6.0 and _orbit_clear(band.orbit, 0.0, 8500.0, planets) and _belt_clear(band.orbit, belts):
				belts.append(_debris_belt(rng, band.orbit, 2.2, "Migration debris"))
				history.append("Migration left a debris belt")
				break
	planets.sort_custom(func(a: Dictionary, b: Dictionary): return a.orbit < b.orbit)
	for planet in planets:
		if planet.kind == BodyKind.DWARF_PLANET or not planet.moons.is_empty():
			continue
		var gas_world := float(planet.gas_fraction) > 0.0
		var capture: bool = planet == migrant and rng.randf() < 0.62
		var limit := rng.randi_range(1, 4) if gas_world else 1
		if not capture and rng.randf() >= (0.92 if gas_world else 0.45):
			continue
		var moon_orbit := maxf(16500.0, float(planet.reach) + 5900.0)
		for i in limit:
			var moon_radius := rng.randf_range(850.0, 3650.0) if gas_world else rng.randf_range(720.0, 2480.0)
			var e := rng.randf_range(0.14, 0.29) if capture and i == 0 else rng.randf_range(0.015, 0.12)
			var reach := moon_orbit * (1.0 + e) + moon_radius * 1.04
			if moon_orbit * (1.0 - e) - moon_radius * 1.04 <= float(planet.reach) or not _orbit_clear(planet.orbit, planet.eccentricity, reach + 3800.0, planets, planet):
				break
			if not _clears_debris(planet.orbit, planet.eccentricity, reach, belts) or float(planet.orbit) * (1.0 + float(planet.eccentricity)) + reach > outer or float(planet.orbit) * (1.0 - float(planet.eccentricity)) - reach < stellar_edge:
				break
			var moon_type := "Cratered"
			var variation := rng.randf()
			if gas_world and variation < 0.24:
				moon_type = "Volcanic"
			elif float(planet.ice_fraction) > 0.22 and variation < 0.69:
				moon_type = "Icy"
			elif variation > 0.70:
				moon_type = "Mineral"
			planet.moons.append(_formed_moon(rng, moon_orbit, rng.randf_range(0.0, TAU), moon_radius, e, rng.randf_range(0.0, TAU), moon_type, capture and i == 0))
			if capture and i == 0:
				history.append("The migrant captured a moon")
			planet.reach = reach
			moon_orbit = (reach + 5400.0) / 0.88
	var residual := bands.duplicate()
	residual.sort_custom(func(a: Dictionary, b: Dictionary): return a.rock + a.ice > b.rock + b.ice)
	for band: Dictionary in residual:
		if belts.size() >= 3:
			break
		var remaining := float(band.rock) + float(band.ice)
		if remaining > 0.06 and _orbit_clear(band.orbit, 0.0, 8500.0, planets) and _belt_clear(band.orbit, belts):
			var belt := _debris_belt(rng, band.orbit, remaining, "Residual disc")
			belt.ore = clampf(float(band.rock) / remaining * float(star.metallicity), 0.35, 2.0)
			belts.append(belt)
	var edge := stellar_edge
	for planet in planets:
		edge = maxf(edge, float(planet.orbit) * (1.0 + float(planet.eccentricity)) + float(planet.reach))
	for belt in belts:
		edge = maxf(edge, float(belt.orbit) + 5500.0)
	return {"planets": planets, "belts": belts, "ice_line": frost_line, "frost_line_au": frost_au,
		"carbon_oxygen_ratio": carbon_ratio, "history": history, "edge": edge}

static func _disc_au(orbit: float, inner: float, outer: float, inner_au: float, outer_au: float) -> float:
	return lerpf(inner_au, outer_au, pow(clampf(inverse_lerp(inner, outer, orbit), 0.0, 1.0), DISC_COMPRESSION))

static func _period_days(star: Dictionary, orbit_au: float) -> float:
	return 365.25 * pow(orbit_au, 1.5) / sqrt(float(star.mass))

static func _equilibrium_temperature(star: Dictionary, orbit_au: float) -> float:
	return 278.0 * pow(float(star.luminosity) / pow(orbit_au, 2.0), 0.25)

static func _day_side_temperature(star: Dictionary, orbit_au: float) -> float:
	return _equilibrium_temperature(star, orbit_au) * sqrt(2.0)

static func _set_physical_orbit(planet: Dictionary, star: Dictionary, orbit_au: float, formation_au: float) -> void:
	planet.orbit_au = orbit_au
	planet.formation_orbit_au = formation_au
	planet.equilibrium_temperature = _equilibrium_temperature(star, orbit_au)
	planet.period_days = _period_days(star, orbit_au)

static func _clears_debris(orbit: float, e: float, reach: float, belts: Array[Dictionary]) -> bool:
	for belt in belts:
		if orbit * (1.0 + e) + reach >= float(belt.orbit) - BELT_CLEARANCE and orbit * (1.0 - e) - reach <= float(belt.orbit) + BELT_CLEARANCE:
			return false
	return true

static func eccentric_anomaly(mean_anomaly: float, eccentricity: float) -> float:
	if eccentricity == 0.0:
		return mean_anomaly
	var anomaly := mean_anomaly
	for iteration in 3:
		anomaly -= (anomaly - eccentricity * sin(anomaly) - mean_anomaly) / (1.0 - eccentricity * cos(anomaly))
	return anomaly

static func _orbit_clear(orbit: float, e: float, reach: float, planets: Array[Dictionary], excluded: Dictionary = {}) -> bool:
	for other in planets:
		if not excluded.is_empty() and is_same(other, excluded):
			continue
		var other_orbit := float(other.orbit)
		var other_e := float(other.eccentricity)
		var other_reach := float(other.reach)
		if orbit * (1.0 + e) + reach >= other_orbit * (1.0 - other_e) - other_reach and orbit * (1.0 - e) - reach <= other_orbit * (1.0 + other_e) + other_reach:
			return false
	return true

static func _body_reach(body: Dictionary) -> float:
	var reach := float(body.radius) * float(body.extent)
	for moon: Dictionary in body.moons:
		reach = maxf(reach, float(moon.orbit) * (1.0 + float(moon.eccentricity)) + float(moon.radius) * float(moon.extent))
	return reach

static func _belt_clear(orbit: float, belts: Array[Dictionary]) -> bool:
	for belt in belts:
		if absf(float(belt.orbit) - orbit) < 65000.0:
			return false
	return true

static func _debris_belt(rng: RandomNumberGenerator, orbit: float, mass: float, origin: String, phase := -1.0) -> Dictionary:
	return {"orbit": orbit, "mass": mass, "origin": origin, "ore": rng.randf_range(0.38, 1.6),
		"rocks": clampi(3 + roundi(mass), 3, 8), "phase": rng.randf_range(0.0, TAU) if phase < 0.0 else phase}

# Appearance recipes are varied per body, including within each class.
static func _world(rng: RandomNumberGenerator, star: Dictionary, kind: int, orbit: float, mass: float, earth_radius: float, ice: float, gas: float, puffy := false) -> Dictionary:
	var recipe: Array = {
		BodyKind.TERRESTRIAL: ["Terrestrial", 0, "375e42", "a2ab64", "66a8dd", 0.30],
		BodyKind.SUPER_EARTH: ["Super-Earth", 0, "773c30", "e3b182", "e4b189", 0.46],
		BodyKind.NEPTUNIAN: ["Neptunian", 2, "17447f", "79dbe1", "59cfff", 0.69],
		BodyKind.GAS_GIANT: ["Jovian", 2, "84464a", "efd1a0", "f0bb85", 0.61],
		BodyKind.DWARF_PLANET: ["Dwarf planet", 3 if ice > 0.2 else 1, "564c65", "c3a49a", "000000", 0.0],
		BodyKind.HOT_JUPITER: ["Hot Jupiter", 2, "99183d", "ffc072", "ff8e50", 0.91],
		BodyKind.ULTRA_HOT_NEPTUNE: ["Ultra-hot Neptune", 2, "50345e", "f6a8cf", "bc7cee", 0.95],
		BodyKind.CHTHONIAN: ["Chthonian core", 1, "4c3036", "eba784", "000000", 0.0],
		BodyKind.LAVA: ["Lava world", 4, "1a2439", "ff8133", "ff7446", 0.20],
		BodyKind.OCEAN: ["Hycean world", 5, "032653", "36b9c3", "8ce5db", 0.81],
		BodyKind.CARBON: ["Carbon world", 1, "272439", "a7b2c1", "a287b3", 0.07],
		BodyKind.PULSAR_PLANET: ["Pulsar planet", 1, "433958", "a697bf", "a795ff", 0.10],
		BodyKind.ICE_PLANET: ["Ice world", 3, "556185", "e0ecf8", "83bded", 0.15],
	}[kind]
	var dark := _jitter_color(Color(recipe[2]), rng)
	var light := _jitter_color(Color(recipe[3]), rng)
	var radius := clampf(7200.0 * pow(earth_radius, 0.44), 2300.0, 25500.0)
	var atmosphere := clampf(float(recipe[5]) * rng.randf_range(0.66, 1.35) + (0.19 if puffy else 0.0), 0.0, 1.0)
	var ringed: bool = (kind == BodyKind.GAS_GIANT or kind == BodyKind.NEPTUNIAN) and rng.randf() < 0.43
	var extent := 1.82 if ringed else 1.025 + 0.155 * atmosphere
	return {"kind": kind, "archetype": recipe[0], "surface_style": recipe[1], "color": light.lerp(dark, 0.22),
		"surface_dark": dark, "surface_light": light, "atmosphere_color": _jitter_color(Color(recipe[4]), rng),
		"atmosphere": atmosphere, "surface_seed": rng.randf_range(1.0, 150.0), "surface_scale": rng.randf_range(0.69, 1.64),
		"axis_angle": rng.randf_range(-PI, PI), "rings": ringed, "ring_tilt": rng.randf_range(0.17, 0.58), "puffy": puffy,
		"orbit": orbit, "formation_orbit": orbit, "eccentricity": 0.0, "orbit_angle": rng.randf_range(0.0, TAU),
		"phase": rng.randf_range(0.0, TAU), "period": 2300.0 * pow(orbit / 360000.0, 1.5) / sqrt(float(star.mass)),
		"radius": radius, "extent": extent, "reach": radius * extent, "earth_radius": earth_radius, "earth_mass": mass,
		"ice_fraction": ice, "gas_fraction": gas, "moons": [], "orbit_cleared": true, "tidally_locked": kind == BodyKind.LAVA}

static func _formed_moon(rng: RandomNumberGenerator, orbit: float, phase: float, radius: float, e: float, angle: float, type: String, captured: bool) -> Dictionary:
	var moon := _moon(orbit, phase, radius, e, angle)
	var recipe: Array = {"Cratered": [1, "4d4859", "c9c2b7"], "Icy": [3, "526796", "e6f4f7"],
		"Volcanic": [6, "563338", "eac47a"], "Mineral": [1, "5f3d3b", "c38064"]}[type]
	var light := _jitter_color(Color(recipe[2]), rng)
	moon.merge({"archetype": type + " moon", "color": light, "surface_style": recipe[0], "surface_light": light,
		"surface_dark": _jitter_color(Color(recipe[1]), rng), "surface_seed": rng.randf_range(1.0, 150.0),
		"surface_scale": rng.randf_range(0.67, 1.65), "axis_angle": rng.randf_range(-PI, PI), "extent": 1.04, "captured": captured}, true)
	return moon

static func _jitter_color(base: Color, rng: RandomNumberGenerator) -> Color:
	return Color.from_hsv(fposmod(base.h + rng.randf_range(-0.069, 0.069), 1.0),
		clampf(base.s * rng.randf_range(0.65, 1.30), 0.0, 1.0), clampf(base.v * rng.randf_range(0.83, 1.14), 0.0, 1.0))

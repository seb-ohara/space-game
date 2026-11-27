extends RefCounted
## Editable, seeded hull families. Station pairs are (fore-to-aft fraction,
## half-width as a fraction of length); stretched wedges join the stations.

const MODULES := preload("res://scripts/ship_modules.gd")
const CLASS_NAMES := ["Fighter", "Gunship", "Corvette", "Frigate", "Destroyer", "Cruiser", "Battleship", "Capital Ship"]
# Inclusive ranges, in half-metre blueprint cells. 200 m belongs to Capital.
const RANGES := [Vector2i(20, 44), Vector2i(46, 70), Vector2i(72, 100), Vector2i(110, 140),
	Vector2i(142, 170), Vector2i(172, 200), Vector2i(220, 399), Vector2i(400, 600)]
const FAMILIES := [
	[["Delta", [0,.10, .22,.14, .57,.34, .74,.30, 1,.17], false],
	 ["Twin-tail", [0,.13, .31,.20, .47,.38, .72,.30, 1,.26], true]],
	[["Hammerhead", [0,.13, .20,.34, .37,.36, .61,.24, .81,.24, 1,.19], false],
	 ["Manta", [0,.16, .24,.21, .50,.41, .64,.40, .83,.27, 1,.24], true]],
	[["Lancer", [0,.055, .28,.12, .58,.15, .73,.24, .87,.24, 1,.16], true],
	 ["Longbow", [0,.08, .18,.19, .32,.19, .54,.13, .72,.19, 1,.17], false]],
	[["Peregrine", [0,.06, .25,.15, .48,.19, .63,.30, .83,.27, 1,.19], true],
	 ["Sentinel", [0,.11, .19,.18, .49,.19, .65,.25, .74,.25, 1,.21], false]],
	[["Bulwark", [0,.18, .16,.29, .34,.29, .52,.19, .76,.26, 1,.18], false],
	 ["Spearhead", [0,.055, .23,.18, .43,.29, .68,.28, .83,.22, 1,.21], true]],
	[["Crescent", [0,.10, .19,.22, .40,.35, .55,.35, .75,.25, 1,.23], true],
	 ["Citadel", [0,.16, .15,.24, .34,.24, .49,.30, .69,.30, .82,.22, 1,.21], false]],
	[["Dreadnought", [0,.14, .21,.27, .37,.27, .49,.21, .65,.30, .83,.30, 1,.21], true],
	 ["Rampart", [0,.20, .17,.32, .40,.32, .49,.25, .66,.28, .86,.28, 1,.25], true]],
	[["Ark", [0,.09, .12,.19, .26,.19, .40,.36, .58,.36, .68,.26, .88,.30, 1,.28], true],
	 ["Monolith", [0,.19, .15,.26, .33,.26, .47,.34, .62,.34, .76,.27, .89,.33, 1,.28], true]],
]
const PALETTES := [
	["8d9fa8", "506b79", "d4a861", "bacad0"], ["929e94", "445f58", "d79957", "c4c9b4"],
	["9ea8b8", "525e7b", "86c3ce", "c9d4dd"], ["9a9699", "615366", "ae7765", "c5b7ae"],
]
const RAIDER_PALETTES := [["956b67", "60434a", "ce9464", "b98a7c"], ["838997", "4e4b5e", "c87663", "a7a7aa"]]
const MID_X := 2 # The half-open coordinate of the builder's symmetry axis.
const SLOT := 4

static func class_for_length(length: float) -> String:
	for index in RANGES.size():
		var band: Vector2i = RANGES[index]
		if length >= band.x * MODULES.FINE_CELL_METERS and length <= band.y * MODULES.FINE_CELL_METERS:
			return CLASS_NAMES[index]
	return "Custom" if length > 0.0 else "—"

static func generate(rng: RandomNumberGenerator, class_id: int, raider := false) -> Dictionary:
	class_id = clampi(class_id, 0, RANGES.size() - 1)
	var band: Vector2i = RANGES[class_id]
	var family: Array = FAMILIES[class_id][rng.randi_range(0, int(FAMILIES[class_id].size()) - 1)]
	var colors: Array = RAIDER_PALETTES if raider else PALETTES
	var palette: Array = colors[rng.randi_range(0, colors.size() - 1)]
	var length := rng.randi_range(band.x, band.y)
	var profile: Array = family[1]
	var beam := rng.randf_range(0.87, 1.13)
	var rake := rng.randf_range(-0.16, 0.16)
	var stern_half := maxi(4, roundi(length * float(profile[-1]) * beam))
	var pair_count := 1 if class_id < 4 else 2 if class_id < 6 else 3
	# Allow real engine banks on large designs rather than overscaling a single nozzle.
	var engine_w := clampi(floori(float(stern_half) / (pair_count * 2.0)) / SLOT * SLOT, SLOT, 32)
	var engine_h := clampi(roundi(length * 0.065 / SLOT) * SLOT, SLOT, 24)
	var nose := 2 - length / 2
	var tail := nose + length - engine_h
	var notch := clampi(roundi(length * 0.035), 1, maxi(1, stern_half - pair_count * engine_w)) if family[2] else 0
	var core: Array[Rect2i] = []
	var parts: Array[Dictionary] = []
	var y := nose
	var half := maxi(2, roundi(length * float(profile[1]) * beam))
	for station in range(2, profile.size(), 2):
		var t := float(profile[station])
		var next_y := tail if t == 1.0 else clampi(nose + roundi((tail - nose) * (t + rake * t * (1.0 - t))), y + 1, tail - 1)
		var next_half := stern_half if t == 1.0 else maxi(2, roundi(length * float(profile[station + 1]) * beam))
		var inner := mini(half, next_half)
		core.append(Rect2i(MID_X - inner, y, inner * 2, next_y - y))
		var slope := absi(half - next_half)
		if slope > 0:
			var rotation := 0 if next_half > half else 2
			var rim: String = palette[2] if station == 4 else palette[1]
			parts.append(_panel("retro_wedge", Rect2i(MID_X + inner, y, slope, next_y - y), rim, rotation, rotation == 2))
			parts.append(_panel("retro_wedge", Rect2i(MID_X - inner - slope, y, slope, next_y - y), rim, rotation, rotation == 0))
		y = next_y
		half = next_half

	var inserts: Array[Rect2i] = []
	var cockpit := core[1]
	for candidate in core:
		if candidate.end.y > nose + length * 0.11 and candidate.size.y >= SLOT and candidate.size.x >= SLOT:
			cockpit = candidate
			break
	var glass_half := mini(cockpit.size.x / 2, clampi(roundi(length * (0.10 if class_id < 2 else 0.055)), 2, 32))
	var window_height := mini(cockpit.size.y, clampi(roundi(length * 0.11), SLOT, 22))
	var window_top := cockpit.position.y + (cockpit.size.y - window_height) / 2
	var window := Rect2i(MID_X - glass_half, window_top, glass_half * 2, window_height)
	inserts.append(window)
	parts.append(_panel("window", window))
	var canopy_wing := mini(glass_half / 2, cockpit.size.x / 2 - glass_half)
	if canopy_wing > 0:
		var right := Rect2i(window.end.x, window.position.y, canopy_wing, window.size.y)
		var left := _mirror(right)
		# The glass tapers toward the bow; matching hull halves close the corners.
		inserts.append_array([left, right])
		parts.append(_panel("window_wedge", right))
		parts.append(_panel("window_wedge", left, "", 0, true))
		parts.append(_panel("retro_wedge", right, palette[0], 2))
		parts.append(_panel("retro_wedge", left, palette[0], 2, true))

	var weapon_types := ["laser", "machine_gun", "missile"] if class_id < 2 else ["laser", "railgun", "missile"]
	var weapon: String = weapon_types[rng.randi_range(0, weapon_types.size() - 1)]
	var wanted_pairs := mini(6, 1 + class_id)
	for segment in range(1, core.size()):
		var deck := core[segment]
		if deck.size.x < SLOT * 3 or deck.size.y < SLOT or wanted_pairs == 0:
			continue
		for row in (2 if class_id >= 5 and deck.size.y >= 24 else 1):
			if wanted_pairs == 0:
				break
			var gun_y := deck.position.y + (deck.size.y - SLOT) / (3 if class_id >= 5 else 2) + row * (deck.size.y / 3)
			var gun_x := MID_X + clampi(roundi(deck.size.x * 0.32), SLOT / 2, deck.size.x / 2 - SLOT)
			var mount := Rect2i(gun_x, gun_y, SLOT, SLOT)
			var reflected := _mirror(mount)
			if not _clear(mount, inserts) or not _clear(reflected, inserts):
				continue
			var fitting := weapon if wanted_pairs % 3 != 0 else "laser"
			if not raider and wanted_pairs == 1 and class_id in [1, 2, 3] and rng.randf() < 0.45:
				fitting = "miner"
			for slot in [mount, reflected]:
				inserts.append(slot)
				var turret := _panel("turret_base", slot)
				turret.turret = fitting
				parts.append(turret)
			wanted_pairs -= 1
	# Use a central mount if the narrowest fighter's shoulders could not fit a pair.
	if not parts.any(func(part: Dictionary) -> bool: return part.has("turret")):
		for deck in core:
			var mount := Rect2i(MID_X - SLOT / 2, deck.position.y, SLOT, SLOT)
			if deck.encloses(mount) and _clear(mount, inserts):
				var turret := _panel("turret_base", mount)
				turret.turret = weapon
				parts.append(turret)
				inserts.append(mount)
				break

	# Carve a gap between the engine nacelles, keeping their upstream deck connected.
	var aft := core[-1]
	var recess := Rect2i(MID_X - notch, tail - mini(aft.size.y / 2, maxi(2, roundi(length * 0.08))), notch * 2, length)
	if notch > 0 and _clear(recess, inserts):
		inserts.append(recess)
	else:
		notch = 0
	var available := stern_half - notch - engine_w * pair_count
	for index in pair_count:
		var engine_x := MID_X + notch + index * engine_w + floori(float(available * (index + 1)) / (pair_count + 1))
		var mount := Rect2i(engine_x, tail, engine_w, engine_h)
		parts.append(_panel("engine", mount))
		parts.append(_panel("engine", _mirror(mount)))
	if notch == 0 and class_id != 0 and available / (pair_count + 1) >= SLOT / 2:
		parts.append(_panel("engine", Rect2i(MID_X - SLOT / 2, tail, SLOT, engine_h)))

	# Colour and partition the full decks into simple rectangles around equipment.
	var floors: Array[Rect2i] = []
	floors.append(window)
	for index in core.size():
		var deck := core[index]
		var strips: Array[Rect2i] = [deck]
		var stripe := clampi(roundi(deck.size.x * 0.14), 1, 12)
		if deck.size.x >= 14:
			strips = [Rect2i(deck.position, Vector2i(stripe, deck.size.y)),
				Rect2i(deck.position + Vector2i(stripe, 0), Vector2i(deck.size.x - stripe * 2, deck.size.y)),
				Rect2i(deck.end.x - stripe, deck.position.y, stripe, deck.size.y)]
		for strip_index in strips.size():
			var color: String = palette[3] if index % 3 == 0 else palette[0]
			if strips.size() == 3 and strip_index != 1:
				color = palette[2] if index in [1, 4] else palette[1]
			var pieces: Array[Rect2i] = [strips[strip_index]]
			for opening in inserts:
				var next: Array[Rect2i] = []
				for piece in pieces:
					_subtract(piece, opening, next)
				pieces = next
			for piece in pieces:
				parts.append(_panel("retro_plain", piece, color))
				floors.append(piece)

	var interior: Array[Rect2i] = []
	var command_width := 12 if glass_half >= 6 and class_id >= 2 else SLOT
	var command := Rect2i(MID_X - command_width / 2, window.position.y, command_width, SLOT)
	parts.append(_panel("command_deck" if command_width == 12 else "command_station", command, "", 0, false, "interior"))
	interior.append(command)
	var spare := float(MODULES.stats(parts).power)
	var shields := 1 + class_id / 3
	for index in maxi(1, ceili((-spare + 12.0 * shields) / 45.0)):
		if not _fit_interior(parts, "reactor", floors, interior):
			break
		spare += 45.0
	for index in mini(shields, maxi(0, floori(spare / 12.0))):
		_fit_interior(parts, "shield", floors, interior)
	if not raider:
		for index in 1 + class_id / 2:
			_fit_interior(parts, "retro_cargo", floors, interior)
	return {"parts": parts, "family": family[0], "class": CLASS_NAMES[class_id], "length": length * MODULES.FINE_CELL_METERS}

static func _panel(kind: String, area: Rect2i, paint := "", rotation := 0, flip := false, layer := "exterior") -> Dictionary:
	var part := {"type": kind, "fine_grid": true, "layer": layer, "x": area.position.x, "y": area.position.y,
		"width": area.size.x, "height": area.size.y, "rotation": rotation, "flip_x": flip}
	if paint != "":
		part.paint = paint
	return part

static func _mirror(rect: Rect2i) -> Rect2i:
	return Rect2i(2 * MID_X - rect.end.x, rect.position.y, rect.size.x, rect.size.y)

static func _clear(rect: Rect2i, occupied: Array[Rect2i]) -> bool:
	for area in occupied:
		if rect.intersects(area):
			return false
	return true

static func _subtract(rect: Rect2i, hole: Rect2i, into: Array[Rect2i]) -> void:
	var cut := rect.intersection(hole)
	if not cut.has_area():
		into.append(rect)
		return
	for piece in [Rect2i(rect.position.x, rect.position.y, rect.size.x, cut.position.y - rect.position.y),
		Rect2i(rect.position.x, cut.end.y, rect.size.x, rect.end.y - cut.end.y),
		Rect2i(rect.position.x, cut.position.y, cut.position.x - rect.position.x, cut.size.y),
		Rect2i(cut.end.x, cut.position.y, rect.end.x - cut.end.x, cut.size.y)]:
		if piece.has_area():
			into.append(piece)

static func _fit_interior(parts: Array[Dictionary], kind: String, floors: Array[Rect2i], occupied: Array[Rect2i]) -> bool:
	# Prefer space on the main decks; every installed system remains editable.
	for index in range(floors.size() - 1, -1, -1):
		var floor := floors[index]
		for y in range(floor.position.y, floor.end.y - SLOT + 1, SLOT):
			for x in range(floor.position.x, floor.end.x - SLOT + 1, SLOT):
				var slot := Rect2i(x, y, SLOT, SLOT)
				if _clear(slot, occupied):
					_install_interior(parts, kind, slot, occupied)
					return true
	# Tight fighters can fit a system across two paint panels or hull seams.
	for floor in floors:
		for y in range(floor.position.y, floor.end.y):
			for x in range(floor.position.x, floor.end.x):
				var slot := Rect2i(x, y, SLOT, SLOT)
				if not _clear(slot, occupied):
					continue
				var covered := 0
				for panel in floors:
					covered += panel.intersection(slot).get_area()
				if covered == SLOT * SLOT:
					_install_interior(parts, kind, slot, occupied)
					return true
	return false

static func _install_interior(parts: Array[Dictionary], kind: String, slot: Rect2i, occupied: Array[Rect2i]) -> void:
	occupied.append(slot)
	parts.append(_panel(kind, slot, "", 0, false, "interior"))

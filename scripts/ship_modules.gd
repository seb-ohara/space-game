extends RefCounted

const CARGO_TEXTURES := {
	"cargo": preload("res://component-art/cargo-bay-sprite.png"),
	"cargo_corner": preload("res://component-art/cargo-corner.png"),
	"cargo_inner": preload("res://component-art/cargo-inner.png"),
	"cargo_edge": preload("res://component-art/cargo-edge.png"),
}
const HULL_TEXTURES := {
	"hull": preload("res://hull-art/hull-square-tile.png"),
	"wedge": preload("res://hull-art/hull-wedge-tile.png"),
}
const SYSTEM_TEXTURES := {
	"reactor": preload("res://component-art/power-cell.png"),
	"shield": preload("res://component-art/shield-generator.png"),
}
const MINING_TURRET_TEXTURE := preload("res://component-art/mining-turret-sprite.png")
const MINING_TURRET_MUZZLE_OFFSET := CELL * 20.0 / 32.0

const ENGINE_SOURCE := preload("res://engine-art/engine-simple-ridges.png")
# The source has a large transparent canvas; this region contains the selected engine.
const ENGINE_SOURCE_RECT := Rect2i(312, 38, 1029, 569)
const ENGINE_PIXEL_SIZE := Vector2i(34, 19)
const ENGINE_NOZZLE_OFFSET := -0.47 + 0.94 * 19.0 / 34.0
static var engine_texture: ImageTexture = null

const CELL := 36.0
const BASE_TURN_SPEED := 8.0
const GRID_HALF_WIDTH := 21
const GRID_HALF_HEIGHT := 22
const MAX_COMPONENTS := 400
const ORDER := ["hull", "wedge", "connector", "turret_base", "engine", "laser", "machine_gun", "missile", "armor", "shield", "reactor", "cockpit", "cargo_corner", "cargo_inner", "cargo_edge", "miner"]
const TYPES := {
	"hull": {"name":"Square hull", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"triangle": {"name":"Triangular hull", "category":"HULL & STRUCTURE", "mass":5.0, "health":17.0},
	"wedge": {"name":"Right-angle hull", "category":"HULL & STRUCTURE", "mass":5.0, "health":17.0},
	"wing": {"name":"Wing", "category":"HULL & STRUCTURE", "mass":4.0, "health":12.0, "turn":12.0},
	"connector": {"name":"Connector", "category":"HULL & STRUCTURE", "mass":2.0, "health":8.0},
	"turret_base": {"name":"Turret base", "category":"HULL & STRUCTURE", "mass":4.0, "health":20.0},
	"engine": {"name":"Main engine", "category":"PROPULSION", "mass":10.0, "health":18.0, "power":-12.0, "thrust":75.0},
	"thruster": {"name":"Small thruster", "category":"PROPULSION", "mass":4.0, "health":10.0, "power":-5.0, "thrust":26.0, "turn":14.0},
	"laser": {"name":"Laser cannon", "category":"WEAPONS", "mass":5.0, "health":12.0, "power":-7.0, "weapon":18.0, "turret_turn_speed":2.2},
	"machine_gun": {"name":"Machine gun", "category":"WEAPONS", "mass":5.0, "health":12.0, "power":-5.0, "weapon":14.0, "turret_turn_speed":3.2},
	"missile": {"name":"Missile launcher", "category":"WEAPONS", "mass":9.0, "health":16.0, "power":-8.0, "weapon":28.0, "turret_turn_speed":1.5},
	"armor": {"name":"Armour plate", "category":"DEFENCE", "mass":12.0, "health":65.0},
	"shield": {"name":"Shield generator", "category":"DEFENCE", "mass":8.0, "health":18.0, "power":-12.0, "shield":60.0},
	"reactor": {"name":"Power cell", "category":"POWER & SYSTEMS", "mass":12.0, "health":20.0, "power":45.0},
	"cockpit": {"name":"Cockpit", "category":"POWER & SYSTEMS", "mass":10.0, "health":35.0, "power":10.0, "turn":12.0},
	"cargo": {"name":"Cargo pod", "category":"UTILITY & SPECIAL", "mass":8.0, "health":16.0, "cargo":200.0},
	"cargo_corner": {"name":"Cargo hold corner", "category":"UTILITY & SPECIAL", "mass":8.0, "health":16.0, "cargo":200.0},
	"cargo_inner": {"name":"Cargo hold inner", "category":"UTILITY & SPECIAL", "mass":8.0, "health":16.0, "cargo":200.0},
	"cargo_edge": {"name":"Cargo hold edge", "category":"UTILITY & SPECIAL", "mass":8.0, "health":16.0, "cargo":200.0},
	"miner": {"name":"Mining laser", "category":"UTILITY & SPECIAL", "mass":5.0, "health":12.0, "power":-6.0, "mining":4.0, "turret_turn_speed":1.8},
}

static func default_design() -> Array:
	return migrate_legacy([{"type":"cockpit", "x":0, "y":0, "rotation":0}, {"type":"hull", "x":0, "y":1, "rotation":0}, {"type":"reactor", "x":-1, "y":1, "rotation":0}, {"type":"engine", "x":0, "y":2, "rotation":0}, {"type":"turret_base", "turret":"laser", "x":1, "y":0, "rotation":0}, {"type":"shield", "x":1, "y":1, "rotation":0}, {"type":"turret_base", "turret":"miner", "x":-1, "y":0, "rotation":0}, {"type":"hull", "x":-1, "y":2, "rotation":0}, {"type":"cargo_inner", "x":-2, "y":2, "rotation":0}])

const TURRETS := ["laser", "machine_gun", "missile", "miner"]
const INTERIOR_ONLY_TYPES := ["reactor", "shield"]
const CARGO_HOLD_TYPES := ["cargo_corner", "cargo_inner", "cargo_edge"]
const INTERIOR_HULL_TYPES := ["hull", "armor"]
const PAINTABLE_HULL_TYPES := ["hull", "wedge", "triangle", "wing"]
const HULL_BASE_COLOR := Color("8b979c")

static func is_interior(part: Dictionary) -> bool:
	return part.get("layer", "exterior") == "interior"

static func can_place_on_layer(kind: String, interior: bool) -> bool:
	if interior:
		return kind in INTERIOR_ONLY_TYPES or kind in CARGO_HOLD_TYPES
	return kind not in INTERIOR_ONLY_TYPES

static func supports_interior(kind: String) -> bool:
	return kind in INTERIOR_HULL_TYPES

static func migrate_legacy(parts: Array) -> Array:
	var result := parts.duplicate(true)
	var exterior := {}
	for part in result:
		if part is Dictionary and part.get("type", "") in TURRETS:
			part.turret = part.type
			part.type = "turret_base"
		if part is Dictionary and not is_interior(part) and part.get("type", "") not in INTERIOR_ONLY_TYPES:
			exterior[Vector2i(int(part.get("x", 0)), int(part.get("y", 0)))] = true
	var hulls: Array = []
	for part in result:
		if part is Dictionary and part.get("type", "") in INTERIOR_ONLY_TYPES:
			part.layer = "interior"
			var cell := Vector2i(int(part.get("x", 0)), int(part.get("y", 0)))
			if not exterior.has(cell):
				hulls.append({"type":"hull", "x":cell.x, "y":cell.y, "rotation":0})
				exterior[cell] = true
	result.append_array(hulls)
	return result

static func _random_design_set(design: Array, cells: Dictionary, cell: Vector2i, kind: String, turret: String = "") -> void:
	if not cells.has(cell):
		return
	var part: Dictionary = design[cells[cell]]
	part.type = kind
	part.rotation = 0
	part.flip_x = cell.x > 0
	part.erase("turret")
	if turret != "":
		part.turret = turret

static func generate_random_design(rng: RandomNumberGenerator, combat: bool = false) -> Array:
	# Three coherent silhouettes: narrow interceptor, broad freighter and long cruiser.
	var profile := rng.randi_range(0, 2)
	var half_length := rng.randi_range(5, 7) if profile == 0 else (rng.randi_range(5, 6) if profile == 1 else rng.randi_range(8, 10))
	var max_width := rng.randi_range(3, 4) if profile == 0 else (rng.randi_range(4, 5) if profile == 1 else rng.randi_range(3, 4))
	if combat:
		half_length = 3 if profile == 2 else rng.randi_range(2, 3)
		max_width = 2 if profile == 1 else rng.randi_range(1, 2)
	var design: Array = []
	var cells := {}
	for y in range(-half_length, half_length + 1):
		var t := float(y + half_length) / float(half_length * 2)
		var width := 0
		if t > 0.0:
			if profile == 0:
				# A pointed nose, swept wings and a narrow engine section.
				width = maxi(1, roundi(float(max_width) * (1.0 - absf(t - 0.57) / 0.57)))
			elif profile == 1:
				# Broad parallel cargo hull with tapered ends.
				width = mini(max_width, 1 + mini(y + half_length, half_length - y))
				width = maxi(1, width)
			else:
				# Long central hull, with fins across its middle.
				width = 1 if t < 0.18 or t > 0.84 else (max_width if t > 0.38 and t < 0.64 else mini(2, max_width))
		for x in range(-width, width + 1):
			var cell := Vector2i(x, y)
			cells[cell] = design.size()
			var kind := "hull"
			if x == 0 and y == -half_length + 1:
				kind = "cockpit"
			design.append({"type":kind, "x":x, "y":y, "rotation":0, "flip_x":x > 0})
	# Engines sit at the aft edge, with unobstructed exhaust.
	_random_design_set(design, cells, Vector2i(0, half_length), "engine")
	if rng.randf() < 0.65:
		for side in [-1, 1]:
			_random_design_set(design, cells, Vector2i(side, half_length), "engine")
	# Equipment is placed in balanced pairs, leaving the centreline as the spine.
	var weapon_choices := ["laser", "machine_gun", "missile"]
	var weapon: String = weapon_choices[rng.randi_range(0, weapon_choices.size() - 1)]
	var weapon_y := -int(half_length / 2)
	for side in [-1, 1]:
		_random_design_set(design, cells, Vector2i(side, weapon_y), "turret_base", weapon)
		if not combat:
			_random_design_set(design, cells, Vector2i(side, half_length - 2), "cargo_inner")
	_random_design_set(design, cells, Vector2i(0, 0), "shield")
	if not combat and (profile == 1 or rng.randf() < 0.5):
		for side in [-1, 1]:
			_random_design_set(design, cells, Vector2i(side, 1), "turret_base", "miner")
	# Add paired reactors inside the hull until the complete design is powered.
	for y in range(-half_length + 2, half_length):
		if stats(design).power >= 0.0:
			break
		for side in [-1, 1]:
			var cell := Vector2i(side, y)
			if cells.has(cell) and design[cells[cell]].type == "hull":
				_random_design_set(design, cells, cell, "reactor")
	design = migrate_legacy(design)
	if combat:
		var hull_colours := ["884a49", "985847", "795060", "65546d"]
		var hull_colour: String = hull_colours[rng.randi_range(0, hull_colours.size() - 1)]
		for part in design:
			if part.type == "hull":
				part.paint = "bf7960" if absi(part.x) == max_width else hull_colour
	return design

static func stats(parts: Array) -> Dictionary:
	var result := {"mass":0.0, "health":0.0, "power":0.0, "thrust":0.0, "turn":0.0, "weapon":0.0, "shield":0.0, "cargo":0.0, "mining":0.0}
	for part in parts:
		if not TYPES.has(part.get("type", "")):
			continue
		var info: Dictionary = TYPES[part.type]
		for key in result:
			result[key] += float(info.get(key, 0.0))
			if part.type == "turret_base" and part.get("turret", "") in TURRETS:
				result[key] += float(TYPES[part.turret].get(key, 0.0))
	var thrust_to_mass := float(result.thrust) / maxf(result.mass, 1.0)
	result.speed = minf(0.40 + thrust_to_mass * 0.55, 1.25) if result.thrust > 0 else 0.0
	result.acceleration = clampf(thrust_to_mass * 0.75, 0.08, 1.2) if result.thrust > 0 else 0.0
	# Normalize against a three-cell ship of mass 100. Offsets soften the
	# advantage of tiny builds, and the base rate keeps large ships steerable.
	var length_in_cells := bounds(parts).size.y / CELL
	var mass_factor := (float(result.mass) + 35.0) / 135.0
	var length_factor := (length_in_cells + 2.0) / 5.0
	var steering_bonus := minf(float(result.turn) * 0.003, 0.15)
	result.maneuver = minf(0.12 + (0.45 + steering_bonus) / sqrt(mass_factor * length_factor), 1.1)
	return result

static func bounds(parts: Array) -> Rect2:
	if parts.is_empty():
		return Rect2(Vector2(-CELL / 2, -CELL / 2), Vector2.ONE * CELL)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for part in parts:
		var pos := Vector2(part.x, part.y) * CELL
		low = low.min(pos - Vector2.ONE * CELL / 2.0)
		high = high.max(pos + Vector2.ONE * CELL / 2.0)
	return Rect2(low, high - low)

static func clearance_issues(parts: Array) -> Array[Dictionary]:
	var cells := {}
	var issues: Array[Dictionary] = []
	for part in parts:
		if not is_interior(part):
			cells[Vector2i(int(part.x), int(part.y))] = part
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for part in parts:
		var is_weapon := false
		var is_engine: bool = part.type in ["engine", "thruster"]
		if not is_weapon and not is_engine:
			continue
		var direction: Vector2i = directions[int(part.rotation) % 4]
		if is_engine:
			direction = -direction
		var cursor := Vector2i(int(part.x), int(part.y)) + direction
		while absi(cursor.x) <= GRID_HALF_WIDTH and absi(cursor.y) <= GRID_HALF_HEIGHT:
			if cells.has(cursor):
				issues.append({"part": part, "blocked_at": cursor, "direction": direction, "side": "behind" if is_engine else "in front"})
				break
			cursor += direction
	return issues

static func validate(parts: Array, require_flight: bool = true, check_clearance: bool = true) -> String:
	if parts.size() == 0 or parts.size() > MAX_COMPONENTS:
		return "A ship needs 1–%d connected components." % MAX_COMPONENTS
	var cells := {}
	var cockpit_count := 0
	for part in parts:
		if not part is Dictionary or not TYPES.has(part.get("type", "")) or not part.has("x") or not part.has("y") or not part.has("rotation"):
			return "The design contains an invalid component."
		if typeof(part.x) not in [TYPE_INT, TYPE_FLOAT] or typeof(part.y) not in [TYPE_INT, TYPE_FLOAT] or typeof(part.rotation) not in [TYPE_INT, TYPE_FLOAT]:
			return "The design contains invalid coordinates."
		if part.has("flip_x") and typeof(part.flip_x) != TYPE_BOOL:
			return "A component has an invalid flip setting."
		if part.get("layer", "exterior") not in ["exterior", "interior"]:
			return "A component has an invalid layer."
		if part.has("paint") and (part.type not in PAINTABLE_HULL_TYPES or not part.paint is String or not Color.html_is_valid(part.paint)):
			return "A hull block has an invalid paint colour."
		if float(part.x) != int(part.x) or float(part.y) != int(part.y) or float(part.rotation) != int(part.rotation) or int(part.rotation) < 0 or int(part.rotation) > 3 or absf(float(part.x)) > GRID_HALF_WIDTH or absf(float(part.y)) > GRID_HALF_HEIGHT:
			return "A component is outside the build area."
		if part.type in TURRETS:
			return "Turrets must be mounted on a turret base."
		if part.has("turret") and (part.type != "turret_base" or part.turret not in TURRETS):
			return "The design contains an invalid turret mount."
		if not can_place_on_layer(part.type, is_interior(part)):
			return "The design has a component on the wrong layer."
		var key := Vector2i(int(part.x), int(part.y))
		if is_interior(part):
			key = Vector2i(key.x + GRID_HALF_WIDTH * 2 + 1, key.y)
		if cells.has(key):
			return "Components cannot overlap."
		cells[key] = true
		if part.type == "cockpit":
			cockpit_count += 1
	if cockpit_count != 1:
		return "A ship needs exactly one cockpit."
	var exterior := {}
	for part in parts:
		if not is_interior(part):
			exterior[Vector2i(int(part.x), int(part.y))] = part.type
	for part in parts:
		if is_interior(part) and not supports_interior(exterior.get(Vector2i(int(part.x), int(part.y)), "")):
			return "Interior equipment needs a hull cell beneath it."
	var visited := {}
	var todo: Array[Vector2i] = [exterior.keys()[0]]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + direction
			if exterior.has(neighbor) and not visited.has(neighbor):
				todo.append(neighbor)
	if visited.size() != exterior.size():
		return "Every component must connect to the ship."
	if check_clearance:
		var issues := clearance_issues(parts)
		if not issues.is_empty():
			var issue: Dictionary = issues[0]
			return "%s needs a clear path %s it." % [TYPES[issue.part.type].name, issue.side]
	var totals := stats(parts)
	if require_flight and totals.power < 0.0:
		return "Not enough power. Add a power cell inside the hull."
	if require_flight and totals.thrust <= 0.0:
		return "Add an engine to fly."
	return ""

static func get_engine_texture() -> Texture2D:
	if engine_texture == null:
		var image := ENGINE_SOURCE.get_image().get_region(ENGINE_SOURCE_RECT)
		image.resize(ENGINE_PIXEL_SIZE.x, ENGINE_PIXEL_SIZE.y, Image.INTERPOLATE_NEAREST)
		engine_texture = ImageTexture.create_from_image(image)
	return engine_texture

static func engine_vertices(part: Dictionary, center: Vector2, scale_factor: float = 1.0) -> PackedVector2Array:
	var half := CELL * 0.47 * scale_factor
	var height := half * 2.0 * ENGINE_PIXEL_SIZE.y / ENGINE_PIXEL_SIZE.x
	var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
	var corners := [Vector2(-half, -half), Vector2(half, -half), Vector2(half, -half + height), Vector2(-half, -half + height)]
	var vertices := PackedVector2Array()
	for point in corners:
		var local: Vector2 = point
		if part.get("flip_x", false):
			local.x = -local.x
		vertices.append(center + local.rotated(angle))
	return vertices

static func draw_part(canvas: CanvasItem, part: Dictionary, center: Vector2, scale_factor: float = 1.0, alpha: float = 1.0, tint: Color = Color.WHITE, turret_angle: float = 0.0) -> void:
	var kind: String = part.type
	if kind in PAINTABLE_HULL_TYPES and part.has("paint"):
		var paint := Color(str(part.paint))
		tint = Color(tint.r * paint.r / HULL_BASE_COLOR.r, tint.g * paint.g / HULL_BASE_COLOR.g, tint.b * paint.b / HULL_BASE_COLOR.b, tint.a)
	if kind == "engine":
		var corners := engine_vertices(part, center, scale_factor)
		var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var color := Color(tint.r, tint.g, tint.b, alpha * tint.a)
		canvas.draw_polygon(corners, PackedColorArray([color]), uv, get_engine_texture())
		return
	if CARGO_TEXTURES.has(kind) or HULL_TEXTURES.has(kind) or SYSTEM_TEXTURES.has(kind):
		var half := CELL * 0.5 * scale_factor
		var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
		var corners := PackedVector2Array()
		for point in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var local: Vector2 = point
			if part.get("flip_x", false):
				local.x = -local.x
			corners.append(center + (local * half).rotated(angle))
		var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var texture: Texture2D = CARGO_TEXTURES[kind] if CARGO_TEXTURES.has(kind) else (HULL_TEXTURES[kind] if HULL_TEXTURES.has(kind) else SYSTEM_TEXTURES[kind])
		canvas.draw_polygon(corners, PackedColorArray([Color(tint.r, tint.g, tint.b, alpha * tint.a)]), uv, texture)
		return
	var info: Dictionary = TYPES[kind]
	var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
	var half := CELL * 0.47 * scale_factor
	var pts := PackedVector2Array()
	var raw := [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]
	if kind == "triangle":
		raw = [Vector2(0,-1), Vector2(1,1), Vector2(-1,1)]
	elif kind == "wedge":
		raw = [Vector2(-1,-1), Vector2(1,1), Vector2(-1,1)]
	elif kind == "wing":
		raw = [Vector2(-0.8,-0.55), Vector2(0.9,-1), Vector2(0.35,1), Vector2(-0.8,0.75)]
	elif kind == "connector":
		raw = [Vector2(-0.5,-1), Vector2(0.5,-1), Vector2(0.5,1), Vector2(-0.5,1)]
	for point in raw:
		var local_point: Vector2 = point
		if part.get("flip_x", false):
			local_point.x = -local_point.x
		pts.append(center + (local_point * half).rotated(angle))
	var color := Color("a5adb1")
	match info.category:
		"PROPULSION": color = Color("697884")
		"WEAPONS": color = Color("b26d65")
		"DEFENCE": color = Color("6b9aaf")
		"POWER & SYSTEMS": color = Color("dfbf73") if kind == "reactor" else Color("c5d8dc")
		"UTILITY & SPECIAL": color = Color("cb945f")
	color = color * tint
	color.a = alpha * tint.a
	canvas.draw_colored_polygon(pts, color)
	var outline := Color(0.08, 0.12, 0.17, alpha * tint.a)
	canvas.draw_polyline(pts + PackedVector2Array([pts[0]]), outline, maxf(1.0, scale_factor * 2.0), true)
	var mark := Vector2.from_angle(angle - PI / 2.0)
	var detail := Color(0.18, 0.24, 0.29, alpha * tint.a)
	canvas.draw_line(center - mark * half * 0.45, center + mark * half * 0.45, detail, maxf(2.0, scale_factor * 3.0), true)
	if kind == "turret_base":
		canvas.draw_circle(center, half * 0.72, Color(0.17, 0.22, 0.26, alpha * tint.a))
		canvas.draw_arc(center, half * 0.72, 0.0, TAU, 24, Color(0.7, 0.78, 0.79, alpha * tint.a), 2.0 * scale_factor, true)
		if part.get("turret", "") == "miner":
			# The sprite faces up; its pivot is in the centre of the round housing.
			var pixel_scale := CELL * scale_factor / 32.0
			var corners := PackedVector2Array()
			for point in [Vector2(-16, -20), Vector2(16, -20), Vector2(16, 12), Vector2(-16, 12)]:
				corners.append(center + (point * pixel_scale).rotated(turret_angle))
			var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
			canvas.draw_polygon(corners, PackedColorArray([Color(tint.r, tint.g, tint.b, alpha * tint.a)]), uv, MINING_TURRET_TEXTURE)
		elif part.get("turret", "") in TURRETS:
			var direction := Vector2.UP.rotated(turret_angle)
			var side := direction.orthogonal()
			var turret_color := Color(0.35, 0.78, 0.88, alpha * tint.a) if part.turret == "miner" else Color(0.82, 0.43, 0.34, alpha * tint.a)
			canvas.draw_line(center, center + direction * half * 0.95, Color(0.1, 0.14, 0.17, alpha * tint.a), 7.0 * scale_factor, true)
			canvas.draw_line(center, center + direction * half * 0.95, turret_color, 3.5 * scale_factor, true)
			canvas.draw_circle(center, half * 0.38, turret_color)
			if part.turret == "machine_gun":
				canvas.draw_line(center + side * half * 0.22, center + side * half * 0.22 + direction * half * 0.8, turret_color, 2.0 * scale_factor, true)
			elif part.turret == "missile":
				canvas.draw_circle(center, half * 0.23, Color(0.22, 0.18, 0.18, alpha * tint.a))
		return
	if tint != Color.WHITE:
		return
	if kind == "cockpit":
		canvas.draw_circle(center, half * 0.35, Color(0.19, 0.48, 0.59, alpha))
	elif kind == "reactor":
		canvas.draw_circle(center, half * 0.30, Color(1.0, 0.83, 0.36, alpha))
	elif kind == "shield":
		canvas.draw_arc(center, half * 0.42, 0.0, TAU, 20, Color(0.6, 0.92, 1.0, alpha), 2.0 * scale_factor, true)
	elif kind in ["engine", "thruster"]:
		canvas.draw_circle(center - mark * half * 0.35, half * 0.23, Color(0.32, 0.82, 1.0, alpha))

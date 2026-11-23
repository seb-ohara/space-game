extends RefCounted

const HD_LIGHT_CRUISER := "preset_light_cruiser_hd"
const CRUISER_MACHINE_LASER := "cruiser_machine_laser"
const HD_CRUISER_HULL := preload("res://ship-sprites/starters/light-cruiser-hd-hull.png")
# Mount positions use source image pixels. Each atlas row holds that mount's
# barrels and housing, with its rotation pivot shared by all three layers.
const CRUISER_TURRET_LAYOUTS := {
	HD_LIGHT_CRUISER: {
		"mounts": [Vector2(89.5, 185), Vector2(246.5, 185), Vector2(70.5, 358), Vector2(265.5, 358), Vector2(167.5, 497)],
		"atlas": preload("res://ship-sprites/starters/light-cruiser-hd-turrets.png"),
		"stride": 96.0,
		"pivot": Vector2(38.5, 65),
		"barrels": [Rect2(23, 1, 15, 39), Rect2(39, 1, 16, 39)],
		"housing": Rect2(1, 40, 75, 55),
		"muzzles": [Vector2(-8.5, -57), Vector2(8, -57)],
		"filter": CanvasItem.TEXTURE_FILTER_LINEAR,
	},
}

const PRESET_TEXTURES := {
	"preset_scout": preload("res://ship-sprites/heritage/scout.png"),
	HD_LIGHT_CRUISER: preload("res://ship-sprites/starters/light-cruiser-hd.png"),
	"pixel_custom": preload("res://ship-sprites/starters/armoured-starter.png"),
	"preset_armoured_starter": preload("res://ship-sprites/starters/armoured-starter.png"),
}
const PRESET_NAMES := {
	"Built-in · Heritage Scout": "preset_scout",
	"Built-in · HD Light Cruiser": HD_LIGHT_CRUISER,
	"Built-in · Armoured Starter": "preset_armoured_starter",
}
const SHIP_PIXELS_PER_CELL := 8.0
const WORLD_UNITS_PER_METER := 11.25
const PRESET_LENGTHS_METERS := {
	"preset_scout": 25.0,
	"preset_armoured_starter": 13.0,
	HD_LIGHT_CRUISER: 70.0,
}

static func preset_design(kind: String) -> Array:
	if kind in [HD_LIGHT_CRUISER, "preset_scout", "preset_armoured_starter"]:
		var half_size := Vector2(_default_size({"type": kind})) * 0.5
		return [{"type":kind, "x":-floori(half_size.x), "y":-floori(half_size.y), "rotation":0}]
	return []

const CARGO_TEXTURES := {
	"retro_cargo": preload("res://component-art/retro-kit/retro_cargo.png"),

}
const HULL_TEXTURES := {
	"retro_plain": preload("res://component-art/retro-kit/retro_plain.png"),
	"retro_wedge": preload("res://component-art/retro-kit/retro_plain.png"),
	"retro_nose": preload("res://component-art/retro-kit/retro_nose.png"),
	"retro_spine": preload("res://component-art/retro-kit/retro_spine.png"),
	"retro_stern": preload("res://component-art/retro-kit/retro_stern.png"),
	"retro_wing_left": preload("res://component-art/retro-kit/retro_wing_left.png"),
	"retro_wing_right": preload("res://component-art/retro-kit/retro_wing_right.png"),
	"retro_pod_left": preload("res://component-art/retro-kit/retro_pod_left.png"),
	"retro_pod_right": preload("res://component-art/retro-kit/retro_pod_right.png"),

}
const SYSTEM_TEXTURES := {

	"reactor": preload("res://component-art/power-cell.png"),
	"shield": preload("res://component-art/shield-generator.png"),
	"command_deck": preload("res://component-art/command-deck.png"),
}
const DECORATION_TEXTURES := {
	"retro_bridge": preload("res://component-art/retro-kit/retro_bridge.png"),
	"retro_antenna": preload("res://component-art/retro-kit/retro_antenna.png"),

}
const RETRO_WEDGE_ICON := preload("res://component-art/retro-kit/retro_wedge_icon.png")
const EDGE_DECORATIONS := []
const ARMOUR_PANEL_SIZE := Vector2i(3, 4)
const MINING_TURRET_TEXTURE := preload("res://component-art/mining-turret-sprite.png")
const MINING_TURRET_MUZZLE_OFFSET := CELL * 20.0 / 32.0
const RETRO_TURRET_BASE_TEXTURE := preload("res://component-art/retro-kit/retro_turret_base.png")
const RETRO_MACHINE_GUN_TEXTURE := preload("res://component-art/retro-kit/retro_machine_gun.png")
const TURRET_BASE_TYPES := ["turret_base", "retro_turret_base"]
const MACHINE_GUN_TEXTURE := preload("res://component-art/laser-turret-32x32.png")
# Muzzle tips in pixels relative to the centre of the 32×32 sprite.
const LONG_MACHINE_GUN_TEXTURE := preload("res://component-art/long-machine-gun.png")
const MACHINE_GUN_MUZZLES := [Vector2(-4.5, -15.0), Vector2(4.5, -15.0)]
const ROCKET_MUZZLE_OFFSET := 20.0
const RAILGUN_MUZZLE_OFFSET := 28.0

const ENGINE_SOURCE := preload("res://engine-art/engine-simple-ridges.png")
# The source has a large transparent canvas; this region contains the selected engine.
const ENGINE_SOURCE_RECT := Rect2i(312, 38, 1029, 569)
const ENGINE_PIXEL_SIZE := Vector2i(34, 19)
const RETRO_ENGINE_TEXTURE := preload("res://component-art/retro-kit/retro_engine.png")
const MAIN_ENGINE_TYPES := ["retro_engine", "engine"]
const ENGINE_NOZZLE_OFFSETS := {
	"retro_engine": 0.45,
	"engine": -0.47 + 0.94 * 19.0 / 34.0,
	"thruster": 0.40,
}
static var pixel_starter_textures := {}
static var engine_texture: ImageTexture = null
static var navigation_lights_dim_texture: ImageTexture = null
static var cruiser_turret_textures := {}

const CELL := 36.0
const BASE_TURN_SPEED := 3.1
const GRID_HALF_WIDTH := 21
const GRID_HALF_HEIGHT := 22
const MAX_COMPONENTS := 400
const COMMAND_DECK_WIDTH := 3
const POWER_ADJACENCY_BONUS := {"reactor": 5.0, "shield": 2.0}
const SHIELD_STACK_FACTOR := 0.6
const ARMOUR_MASS := 12.0
const ARMOUR_HEALTH := 65.0
const ARMOUR_LAYER := "armour"
const ORDER := [
	"retro_nose", "retro_spine", "retro_plain", "retro_wedge", "retro_stern", "retro_wing_left", "retro_wing_right", "retro_pod_left", "retro_pod_right",
	"connector", "turret_base", "retro_turret_base", "retro_engine", "engine",
	"laser", "machine_gun", "retro_machine_gun", "long_machine_gun", "missile", "railgun", "miner",
	"reactor", "shield", "retro_cargo", "retro_bridge", "retro_antenna",
]
const TYPES := {
	"preset_scout": {"name":"Heritage Scout", "category":"PRESET SHIPS", "mass":90.0, "health":220.0, "power":20.0, "thrust":180.0},
	HD_LIGHT_CRUISER: {"name":"HD Light Cruiser", "category":"PRESET SHIPS", "mass":110.0, "health":240.0, "power":25.0, "thrust":220.0, "weapon":20.0},
	"pixel_custom": {"name":"Pixel ship", "category":"PRESET SHIPS", "mass":45.0, "health":110.0, "power":15.0, "thrust":90.0},
	"preset_armoured_starter": {"name":"Armoured Starter", "category":"PRESET SHIPS", "mass":45.0, "health":110.0, "power":15.0, "thrust":90.0},
	"retro_turret_base": {"name":"Heritage turret mount", "category":"HULL & STRUCTURE", "mass":4.0, "health":20.0},
	"retro_machine_gun": {"name":"Heritage machine gun", "category":"WEAPONS & MINING", "mass":5.0, "health":12.0, "power":-5.0, "weapon":14.0, "turret_turn_speed":3.2},
	"retro_nose": {"name":"Heritage nose", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_plain": {"name":"Heritage plain hull", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_wedge": {"name":"Heritage right-angle hull", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_spine": {"name":"Heritage central hull", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_stern": {"name":"Heritage stern", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_wing_left": {"name":"Heritage left wing", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_wing_right": {"name":"Heritage right wing", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_pod_left": {"name":"Heritage left pod", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_pod_right": {"name":"Heritage right pod", "category":"HULL & STRUCTURE", "mass":8.0, "health":28.0},
	"retro_bridge": {"name":"Heritage bridge", "category":"DETAILS", "mass":10.0, "health":25.0},
	"retro_cargo": {"name":"Heritage cargo module", "category":"SYSTEMS & CARGO", "mass":8.0, "health":16.0, "cargo":200.0},
	"retro_engine": {"name":"Heritage engine nozzle", "category":"PROPULSION", "mass":10.0, "health":18.0, "power":-12.0, "thrust":75.0},
	"retro_antenna": {"name":"Heritage antenna", "category":"DETAILS"},

	"connector": {"name":"Connector", "category":"HULL & STRUCTURE", "mass":2.0, "health":8.0},
	"turret_base": {"name":"Turret base", "category":"HULL & STRUCTURE", "mass":4.0, "health":20.0},
	"engine": {"name":"Main engine", "category":"PROPULSION", "mass":10.0, "health":18.0, "power":-12.0, "thrust":75.0},
	"thruster": {"name":"Small thruster", "category":"PROPULSION", "mass":4.0, "health":10.0, "power":-5.0, "thrust":26.0, "turn":14.0},
	"laser": {"name":"Laser cannon", "category":"WEAPONS & MINING", "mass":5.0, "health":12.0, "power":-7.0, "weapon":18.0, "turret_turn_speed":2.2},
	"long_machine_gun": {"name":"Long machine gun", "category":"WEAPONS & MINING", "mass":5.0, "health":12.0, "power":-5.0, "weapon":14.0, "turret_turn_speed":3.2},
	"machine_gun": {"name":"Machine gun", "category":"WEAPONS & MINING", "mass":5.0, "health":12.0, "power":-5.0, "weapon":14.0, "turret_turn_speed":3.2},
	"missile": {"name":"Rocket launcher", "category":"WEAPONS & MINING", "mass":9.0, "health":16.0, "power":-8.0, "weapon":28.0, "turret_turn_speed":1.5},
	"railgun": {"name":"Railgun", "category":"WEAPONS & MINING", "mass":11.0, "health":18.0, "power":-11.0, "weapon":52.0, "turret_turn_speed":1.7},
	"shield": {"name":"Shield generator", "category":"SYSTEMS & CARGO", "mass":8.0, "health":18.0, "power":-12.0, "shield":60.0},
	"reactor": {"name":"Power cell", "category":"SYSTEMS & CARGO", "mass":12.0, "health":20.0, "power":45.0},
	"command_deck": {"name":"Command deck", "category":"SYSTEMS & CARGO", "mass":10.0, "health":25.0},
	"miner": {"name":"Mining laser", "category":"WEAPONS & MINING", "mass":5.0, "health":12.0, "power":-6.0, "mining":4.0, "turret_turn_speed":1.8},
}

static func default_design() -> Array:
	return preset_design("preset_armoured_starter")

const TURRETS := ["laser", "machine_gun", "retro_machine_gun", "long_machine_gun", "missile", "railgun", "miner"]
const INTERIOR_ONLY_TYPES := ["reactor", "shield", "command_deck"]
const CARGO_HOLD_TYPES := ["retro_cargo"]
const HULL_BASE_COLOR := Color("8b979c")
const ARMOUR_FACE_COLOR := Color("9daab4")

static func is_interior(part: Dictionary) -> bool:
	return part.get("layer", "exterior") == "interior"

static func is_decoration(part: Dictionary) -> bool:
	return part.get("layer", "exterior") == "decoration"

static func is_exterior_structure(part: Dictionary) -> bool:
	return part.get("layer", "exterior") == "exterior"

static func is_armour_overlay(part: Dictionary) -> bool:
	return part.get("layer", "exterior") == ARMOUR_LAYER

static func decoration_mount(part: Dictionary) -> Vector2i:
	var cell := Vector2i(int(part.x), int(part.y))
	if part.type in EDGE_DECORATIONS:
		var inward: Vector2i = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT][int(part.rotation)]
		return cell + inward
	return cell

static func decoration_mount_error(part: Dictionary, support: Dictionary, slot_has_hull: bool) -> String:
	if part.type == "retro_antenna":
		return ""
	if part.type == "retro_bridge":
		return "" if slot_has_hull else "The bridge needs an exterior block beneath it."
	if part.type == "armour_panel":
		return "" if supports_interior(support.get("type", "")) else "The armour panel needs flat hull beneath every slot."
	if part.type not in EDGE_DECORATIONS:
		return "" if supports_interior(support.get("type", "")) else "Place this detail on a flat hull or armour block."
	if slot_has_hull:
		return "Side details need a free slot beside the hull."
	var kind: String = support.get("type", "")
	if supports_interior(kind) or is_full_wedge(kind) or kind == "wedge_half":
		var mount := decoration_mount(part)
		var direction := Vector2i(int(part.x), int(part.y)) - mount
		var edge := _edge_interval(support, mount, direction, true)
		if edge.x <= 0.5 and edge.y >= 0.5 and edge.y > edge.x:
			return ""
	return "Place this detail beside a solid hull edge."

static func can_place_on_layer(kind: String, interior: bool) -> bool:
	if interior:
		return kind in INTERIOR_ONLY_TYPES or kind in CARGO_HOLD_TYPES
	return kind not in INTERIOR_ONLY_TYPES

static func is_square_hull(kind: String) -> bool:
	return not is_full_wedge(kind) and HULL_TEXTURES.has(kind)

static func supports_interior(kind: String) -> bool:
	return kind == "armor" or is_square_hull(kind)

static func is_armour(kind: String) -> bool:
	return kind in ["armor", "armor_wedge"]

static func is_full_wedge(kind: String) -> bool:
	return kind in ["wedge", "armor_wedge", "retro_wedge"]

static func can_paint(kind: String) -> bool:
	return HULL_TEXTURES.has(kind) or is_armour(kind) or kind in ["wedge_half", "triangle", "wing"]

static func can_stretch(kind: String) -> bool:
	return kind == "engine" or HULL_TEXTURES.has(kind) or is_armour(kind) or CARGO_TEXTURES.has(kind) or (DECORATION_TEXTURES.has(kind) and kind not in ["armour_panel", "retro_bridge", "retro_antenna"])

static func _default_size(part: Dictionary) -> Vector2i:
	if PRESET_LENGTHS_METERS.has(part.type):
		var texture_size := preset_texture(part).get_size()
		var world_size: Vector2 = texture_size * (float(PRESET_LENGTHS_METERS[part.type]) * WORLD_UNITS_PER_METER / texture_size.y)
		return Vector2i((world_size / CELL).ceil())
	if part.type == "pixel_custom":
		var image_size := preset_texture(part).get_size()
		return Vector2i((image_size / SHIP_PIXELS_PER_CELL).ceil())
	if part.type == "armour_panel":
		return ARMOUR_PANEL_SIZE if int(part.get("rotation", 0)) % 2 == 0 else Vector2i(ARMOUR_PANEL_SIZE.y, ARMOUR_PANEL_SIZE.x)
	if part.type == "command_deck":
		return Vector2i(COMMAND_DECK_WIDTH, 1)
	return Vector2i.ONE

static func footprint(part: Dictionary) -> Rect2i:
	var default_size := _default_size(part)
	return Rect2i(int(part.get("x", 0)), int(part.get("y", 0)), int(part.get("width", default_size.x)), int(part.get("height", default_size.y)))

static func preset_draw_rect(part: Dictionary, center: Vector2, scale_factor: float = 1.0) -> Rect2:
	var span := Vector2(footprint(part).size) * CELL * scale_factor
	var texture_size: Vector2 = preset_texture(part).get_size()
	# Pixel ship artwork shares a fixed world scale.
	var fit := CELL * scale_factor / SHIP_PIXELS_PER_CELL if part.type == "pixel_custom" else minf(span.x / texture_size.x, span.y / texture_size.y)
	if PRESET_LENGTHS_METERS.has(part.type):
		fit = PRESET_LENGTHS_METERS[part.type] * WORLD_UNITS_PER_METER * scale_factor / texture_size.y
	var size := texture_size * fit
	return Rect2(center - Vector2.ONE * CELL * scale_factor * 0.5 + (span - size) * 0.5, size)

static func preset_texture(part: Dictionary) -> Texture2D:
	if part.type != "pixel_custom":
		return PRESET_TEXTURES[part.type]
	var data: String = str(part.get("pixels", ""))
	if not pixel_starter_textures.has(data):
		var image := Image.new()
		if image.load_png_from_buffer(Marshalls.base64_to_raw(data)) != OK or image.get_width() < 1 or image.get_height() < 1 or image.get_width() > 256 or image.get_height() > 256:
			return PRESET_TEXTURES.pixel_custom
		var texture := CanvasTexture.new()
		texture.diffuse_texture = ImageTexture.create_from_image(image)
		texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pixel_starter_textures[data] = texture
	return pixel_starter_textures[data]

static func _wedge_corner(part: Dictionary) -> Vector2i:
	var x := 1 if part.get("flip_x", false) else -1
	match int(part.get("rotation", 0)):
		1: return Vector2i(-1, x)
		2: return Vector2i(-x, -1)
		3: return Vector2i(1, -x)
	return Vector2i(x, 1)

static func _wedge_cell_distance(corner: Vector2i, area: Rect2i, cell: Vector2i) -> Vector2i:
	var near := cell - area.position
	if corner.x > 0:
		near.x = area.size.x - 1 - near.x
	if corner.y > 0:
		near.y = area.size.y - 1 - near.y
	return near

static func _wedge_has_material(part: Dictionary, area: Rect2i, cell: Vector2i) -> bool:
	var near := _wedge_cell_distance(_wedge_corner(part), area, cell)
	return near.x * area.size.y + near.y * area.size.x < area.get_area()

static func _block_key(offset: Vector2i) -> String:
	return "%d,%d" % [offset.x, offset.y]

static func _has_block(part: Dictionary, area: Rect2i, cell: Vector2i, cutouts: Dictionary) -> bool:
	return (cutouts.is_empty() or not cutouts.has(_block_key(cell - area.position))) and (not is_full_wedge(part.type) or _wedge_has_material(part, area, cell))

static func occupies(part: Dictionary, cell: Vector2i) -> bool:
	var area := footprint(part)
	return area.has_point(cell) and _has_block(part, area, cell, part.get("cutouts", {}))

static func occupied_cells(part: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var area := footprint(part)
	var cutouts: Dictionary = part.get("cutouts", {})
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if _has_block(part, area, cell, cutouts):
				cells.append(cell)
	return cells

static func remove_block(part: Dictionary, cell: Vector2i) -> void:
	if part.has("cell_paints"):
		part.cell_paints.erase(_block_key(cell - footprint(part).position))
	if not part.has("cutouts"):
		part.cutouts = {}
	part.cutouts[_block_key(cell - footprint(part).position)] = true

static func copy_cutouts(source: Dictionary, target: Dictionary, mirror: bool = false) -> void:
	target.erase("cutouts")
	target.erase("cell_paints")
	var origin := footprint(source).position
	for key in source.get("cell_paints", {}):
		var axes: PackedStringArray = key.split(",")
		var cell := origin + Vector2i(int(axes[0]), int(axes[1]))
		if mirror:
			cell.x = -cell.x
		if occupies(target, cell):
			if not target.has("cell_paints"):
				target.cell_paints = {}
			target.cell_paints[_block_key(cell - footprint(target).position)] = source.cell_paints[key]
	if not source.has("cutouts"):
		return
	for key in source.cutouts:
		var axes: PackedStringArray = key.split(",")
		var cell := origin + Vector2i(int(axes[0]), int(axes[1]))
		if mirror:
			cell.x = -cell.x
		if occupies(target, cell):
			remove_block(target, cell)

static func _valid_cutouts(part: Dictionary) -> bool:
	if not part.has("cutouts"):
		return true
	if not can_stretch(part.type) or not part.cutouts is Dictionary:
		return false
	var area := footprint(part)
	if part.cutouts.size() >= area.get_area():
		return false
	for key in part.cutouts:
		if not key is String or not part.cutouts[key] is bool or not part.cutouts[key]:
			return false
		var axes: PackedStringArray = key.split(",")
		if axes.size() != 2 or not axes[0].is_valid_int() or not axes[1].is_valid_int():
			return false
		var offset := Vector2i(int(axes[0]), int(axes[1]))
		var cell := area.position + offset
		if key != _block_key(offset) or not area.has_point(cell) or (is_full_wedge(part.type) and not _wedge_has_material(part, area, cell)):
			return false
	return true

static func _edge_interval(part: Dictionary, cell: Vector2i, direction: Vector2i, exact: bool = false) -> Vector2:
	var across := 0 if direction.x != 0 else 1
	var along := 1 - across
	if part.type == "wedge_half":
		var corner := _wedge_corner(part)
		if direction[across] != corner[across]:
			return Vector2.ZERO
		var length := 0.5 if along == int(part.rotation) % 2 else 1.0
		return Vector2(1.0 - length, 1.0) if corner[along] > 0 else Vector2(0.0, length)
	if not is_full_wedge(part.type):
		return Vector2(0.0, 1.0)
	var area := footprint(part)
	if part.type == "wedge" and area.size == Vector2i.ONE and not exact:
		return Vector2(0.0, 1.0)
	var corner := _wedge_corner(part)
	var near := _wedge_cell_distance(corner, area, cell)
	if direction[across] != corner[across]:
		near[across] += 1
	var remaining := area.get_area() - near.x * area.size.y - near.y * area.size.x
	var length := clampf(float(remaining) / area.size[across], 0.0, 1.0)
	return Vector2(1.0 - length, 1.0) if corner[along] > 0 else Vector2(0.0, length)

static func touches_edge(part: Dictionary, cell: Vector2i, direction: Vector2i) -> bool:
	var interval := _edge_interval(part, cell, direction)
	return interval.y > interval.x

static func shares_edge(part: Dictionary, neighbor: Dictionary, cell: Vector2i, direction: Vector2i) -> bool:
	if part.type not in ["wedge_half", "armor_wedge", "retro_wedge"] and neighbor.type not in ["wedge_half", "armor_wedge", "retro_wedge"]:
		return touches_edge(part, cell, direction) and touches_edge(neighbor, cell + direction, -direction)
	var first := _edge_interval(part, cell, direction, true)
	var second := _edge_interval(neighbor, cell + direction, -direction, true)
	return minf(first.y, second.y) > maxf(first.x, second.x)

static func on_grid(area: Rect2i) -> bool:
	return Rect2i(-GRID_HALF_WIDTH, -GRID_HALF_HEIGHT, GRID_HALF_WIDTH * 2 + 1, GRID_HALF_HEIGHT * 2 + 1).encloses(area)

static func has_command_deck(parts: Array) -> bool:
	return parts.any(func(part: Dictionary) -> bool: return part.type in ["command_deck", "retro_bridge"] or PRESET_TEXTURES.has(part.type))

static func migrate_legacy(parts: Array) -> Array:
	var result := parts.duplicate(true)
	var exterior := {}
	for part in result:
		if part is Dictionary and part.get("type", "") == "retro_bridge":
			if int(part.get("width", 3)) == 3:
				part.x = int(part.get("x", 0)) + 1
			part.width = 1
			if part.get("layer", "") == "interior":
				part.layer = "decoration"
		if part is Dictionary and part.get("type", "") in TURRETS:
			part.turret = part.type
			part.type = "turret_base"
		if part is Dictionary and TYPES.has(part.get("type", "")) and is_exterior_structure(part) and part.type not in INTERIOR_ONLY_TYPES:
			if _valid_dimensions(part) and on_grid(footprint(part)) and _valid_cutouts(part):
				for cell in occupied_cells(part):
					exterior[cell] = true
	var hulls: Array = []
	for part in result:
		if part is Dictionary and part.get("type", "") in ["reactor", "shield"]:
			part.layer = "interior"
			var cell := Vector2i(int(part.get("x", 0)), int(part.get("y", 0)))
			if not exterior.has(cell):
				hulls.append({"type":"retro_spine", "x":cell.x, "y":cell.y, "rotation":0})
				exterior[cell] = true
	result.append_array(hulls)
	var occupied_details := {}
	for item in result:
		if item is Dictionary and is_decoration(item):
			for cell in occupied_cells(item):
				occupied_details[cell] = true
	for item in result:
		if item is Dictionary and item.get("type", "") == "command_deck":
			var preferred := Vector2i(int(item.get("x", 0)) + int(item.get("width", 3)) / 2, int(item.get("y", 0)))
			var candidates: Array = [preferred]
			candidates.append_array(exterior.keys())
			for cell in candidates:
				if exterior.has(cell) and not occupied_details.has(cell):
					item.merge({"type":"retro_bridge", "layer":"decoration", "x":cell.x, "y":cell.y, "width":1, "height":1}, true)
					occupied_details[cell] = true
					break
	for i in range(result.size() - 1, -1, -1):
		var part: Variant = result[i]
		if part is Dictionary and part.get("type", "") == "command_deck" and part.get("width", 2) == 2:
			var preferred := Vector2i(int(part.get("x", 0)), int(part.get("y", 0)))
			result.remove_at(i)
			_install_command_deck(result, part, [preferred, preferred + Vector2i.LEFT])
	return result

static func add_legacy_command_deck(parts: Array) -> void:
	if parts.size() >= MAX_COMPONENTS or has_command_deck(parts) or not parts.any(func(part: Dictionary) -> bool: return part.type == "cockpit"):
		return
	_install_command_deck(parts, {"type":"command_deck", "layer":"interior", "rotation":0}, [])

static func _install_command_deck(parts: Array, deck: Dictionary, preferred: Array[Vector2i]) -> void:
	var floors := {}
	var occupied := {}
	for part in parts:
		if not part is Dictionary or not TYPES.has(part.get("type", "")) or not _valid_dimensions(part) or not on_grid(footprint(part)) or not _valid_cutouts(part):
			continue
		if is_interior(part) or supports_interior(part.type):
			var cells: Dictionary = occupied if is_interior(part) else floors
			for cell in occupied_cells(part):
				cells[cell] = true
	var anchors: Array[Vector2i] = preferred.duplicate()
	anchors.append_array(floors.keys())
	for cell in anchors:
		var fits := true
		for x in range(COMMAND_DECK_WIDTH):
			var slot := cell + Vector2i(x, 0)
			if not floors.has(slot) or occupied.has(slot):
				fits = false
				break
		if fits:
			deck.merge({"x":cell.x, "y":cell.y, "width":COMMAND_DECK_WIDTH}, true)
			parts.append(deck)
			return

static func _valid_dimensions(part: Dictionary) -> bool:
	var expected := _default_size(part)
	var width: Variant = part.get("width", expected.x)
	var height: Variant = part.get("height", expected.y)
	if typeof(width) not in [TYPE_INT, TYPE_FLOAT] or typeof(height) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	if not is_finite(width) or not is_finite(height) or width < 1 or height < 1 or width != floorf(width) or height != floorf(height):
		return false
	if width > GRID_HALF_WIDTH * 2 + 1 or height > GRID_HALF_HEIGHT * 2 + 1:
		return false
	return can_stretch(part.type) or (width == expected.x and height == expected.y)

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
			var kind := "retro_spine"
			if x == 0 and y == -half_length:
				kind = "retro_nose"
			design.append({"type":kind, "x":x, "y":y, "rotation":0, "flip_x":x > 0})
	# Engines sit at the aft edge, with unobstructed exhaust.
	_random_design_set(design, cells, Vector2i(0, half_length), "retro_engine")
	if rng.randf() < 0.65:
		for side in [-1, 1]:
			_random_design_set(design, cells, Vector2i(side, half_length), "retro_engine")
	# Equipment is placed in balanced pairs, leaving the centreline as the spine.
	var weapon_choices := ["laser", "machine_gun", "missile"]
	var weapon: String = weapon_choices[rng.randi_range(0, weapon_choices.size() - 1)]
	var weapon_y := -int(half_length / 2)
	for side in [-1, 1]:
		_random_design_set(design, cells, Vector2i(side, weapon_y), "turret_base", weapon)
		if not combat:
			_random_design_set(design, cells, Vector2i(side, half_length - 2), "retro_cargo")
	_random_design_set(design, cells, Vector2i(0, 0), "shield")
	if not combat and (profile == 1 or rng.randf() < 0.5):
		for side in [-1, 1]:
			_random_design_set(design, cells, Vector2i(side, 1), "turret_base", "miner")
	var command_y := 1 if combat else -half_length + 2
	design.append({"type":"retro_bridge", "layer":"decoration", "x":0, "y":command_y, "rotation":0, "width":1})
	# Add paired reactors inside the hull until the complete design is powered.
	for y in range(-half_length + 2, half_length):
		if stats(design).power >= 0.0:
			break
		if y == command_y:
			continue
		for side in [-1, 1]:
			var cell := Vector2i(side, y)
			if cells.has(cell) and design[cells[cell]].type == "retro_spine":
				_random_design_set(design, cells, cell, "reactor")
	design = migrate_legacy(design)
	if combat:
		var hull_colours := ["884a49", "985847", "795060", "65546d"]
		var hull_colour: String = hull_colours[rng.randi_range(0, hull_colours.size() - 1)]
		for part in design:
			if part.type == "retro_spine":
				part.paint = "bf7960" if absi(part.x) == max_width else hull_colour
	return design

static func stats(parts: Array) -> Dictionary:
	var result := {"mass":0.0, "health":0.0, "power":0.0, "thrust":0.0, "turn":0.0, "weapon":0.0, "cargo":0.0, "mining":0.0}
	var power_modules := {}
	var shield_count := 0
	for part in parts:
		if not TYPES.has(part.get("type", "")) or (is_decoration(part) and part.type != "retro_bridge"):
			continue
		var kind: String = part.type
		var info: Dictionary = TYPES[kind]
		var units := _material_units(part)
		for key in result:
			result[key] += float(info.get(key, 0.0)) * units
			if kind in TURRET_BASE_TYPES and part.get("turret", "") in TURRETS:
				result[key] += float(TYPES[part.turret].get(key, 0.0))
		if kind == "shield":
			shield_count += 1
		if POWER_ADJACENCY_BONUS.has(kind):
			power_modules[Vector2i(int(part.x), int(part.y))] = kind
	var power_bonus_by_cell := {}
	var sides := [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for cell: Vector2i in power_modules:
		var kind: String = power_modules[cell]
		for side: Vector2i in sides:
			if power_modules.get(cell + side, "") == kind:
				var bonus: float = POWER_ADJACENCY_BONUS[kind]
				power_bonus_by_cell[cell] = bonus
				result.power += bonus
				break
	result.power_bonus_by_cell = power_bonus_by_cell
	var first_shield: float = TYPES.shield.shield
	result.shield = roundf(first_shield * (1.0 - pow(SHIELD_STACK_FACTOR, shield_count)) / (1.0 - SHIELD_STACK_FACTOR))
	result.shield_recharge = minf(10.0, 3.0 + maxf(0.0, result.power) * 0.4) if shield_count > 0 else 0.0
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
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for part in parts:
		if is_decoration(part) or is_armour_overlay(part):
			continue
		var area := footprint(part)
		var solid := Rect2((Vector2(area.position) - Vector2.ONE * 0.5) * CELL, Vector2(area.size) * CELL)
		if PRESET_TEXTURES.has(part.type):
			solid = preset_draw_rect(part, Vector2(area.position) * CELL)
		if part.has("cutouts") or part.type == "wedge_half":
			var hull := material_polygons(part, Vector2(area.position) * CELL)
			if hull.is_empty():
				continue
			solid = Rect2(hull[0][0], Vector2.ZERO)
			for polygon in hull:
				for vertex in polygon:
					solid = solid.expand(vertex)
		low = low.min(solid.position)
		high = high.max(solid.end)
	if not low.is_finite():
		return Rect2(Vector2(-CELL / 2, -CELL / 2), Vector2.ONE * CELL)
	return Rect2(low, high - low)

static func dimensions_meters(parts: Array) -> Vector2:
	return bounds(parts).size / WORLD_UNITS_PER_METER

static func clearance_issues(parts: Array) -> Array[Dictionary]:
	var cells := {}
	var issues: Array[Dictionary] = []
	for part in parts:
		if is_exterior_structure(part):
			for cell in occupied_cells(part):
				cells[cell] = part
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for part in parts:
		var is_weapon := false
		var is_engine: bool = ENGINE_NOZZLE_OFFSETS.has(part.type)
		if not is_weapon and not is_engine:
			continue
		var direction: Vector2i = directions[int(part.rotation) % 4]
		if is_engine:
			direction = -direction
		for cell in occupied_cells(part):
			var cursor: Vector2i = cell + direction
			if occupies(part, cursor):
				continue
			while absi(cursor.x) <= GRID_HALF_WIDTH and absi(cursor.y) <= GRID_HALF_HEIGHT:
				if cells.has(cursor):
					issues.append({"part": part, "blocked_at": cursor, "direction": direction, "side": "behind" if is_engine else "in front"})
					break
				cursor += direction
	return issues

static func validate(parts: Array, require_flight: bool = true, check_clearance: bool = true) -> String:
	if parts.size() == 0 or parts.size() > MAX_COMPONENTS:
		return "A ship needs 1–%d connected components." % MAX_COMPONENTS
	var exterior := {}
	var interior := {}
	var decorations := {}
	var armour := {}
	var armour_panels: Array[Dictionary] = []
	var cockpit_count := 0
	var command_deck_count := 0
	for part in parts:
		if not part is Dictionary or not TYPES.has(part.get("type", "")) or not part.has("x") or not part.has("y") or not part.has("rotation"):
			return "The design contains an invalid component."
		if typeof(part.x) not in [TYPE_INT, TYPE_FLOAT] or typeof(part.y) not in [TYPE_INT, TYPE_FLOAT] or typeof(part.rotation) not in [TYPE_INT, TYPE_FLOAT]:
			return "The design contains invalid coordinates."
		if part.has("flip_x") and typeof(part.flip_x) != TYPE_BOOL:
			return "A component has an invalid flip setting."
		if part.get("layer", "exterior") not in ["exterior", "interior", "decoration", ARMOUR_LAYER]:
			return "A component has an invalid layer."
		if part.has("paint") and (not can_paint(part.type) or not part.paint is String or not Color.html_is_valid(part.paint)):
			return "A hull block has an invalid paint colour."
		if part.has("cell_paints"):
			if not can_paint(part.type) or not part.cell_paints is Dictionary:
				return "A hull block has an invalid paint colour."
			for key in part.cell_paints:
				if not key is String or not part.cell_paints[key] is String or not Color.html_is_valid(part.cell_paints[key]):
					return "A hull block has an invalid paint colour."
				var axes: PackedStringArray = key.split(",")
				if axes.size() != 2 or not axes[0].is_valid_int() or not axes[1].is_valid_int():
					return "A hull block has an invalid paint location."
				var offset := Vector2i(int(axes[0]), int(axes[1]))
				if key != _block_key(offset) or not occupies(part, footprint(part).position + offset):
					return "A hull block has an invalid paint location."
		if float(part.x) != int(part.x) or float(part.y) != int(part.y) or float(part.rotation) != int(part.rotation) or int(part.rotation) < 0 or int(part.rotation) > 3 or absf(float(part.x)) > GRID_HALF_WIDTH or absf(float(part.y)) > GRID_HALF_HEIGHT:
			return "A component is outside the build area."
		if part.type in TURRETS:
			return "Turrets must be mounted on a turret base."
		if part.has("turret") and (part.type not in TURRET_BASE_TYPES or part.turret not in TURRETS):
			return "The design contains an invalid turret mount."
		if is_decoration(part) != DECORATION_TEXTURES.has(part.type) or not can_place_on_layer(part.type, is_interior(part)) or (is_armour_overlay(part) and not is_armour(part.type)):
			return "The design has a component on the wrong layer."
		if not _valid_dimensions(part):
			return "A component has invalid dimensions."
		if not on_grid(footprint(part)):
			return "A component is outside the build area."
		if not _valid_cutouts(part):
			return "A component has invalid removed blocks."
		if PRESET_TEXTURES.has(part.type):
			if part.type == "pixel_custom":
				if not part.get("pixels", null) is String or str(part.pixels).length() > 600000:
					return "The pixel ship image is invalid."
				var image := Image.new()
				if image.load_png_from_buffer(Marshalls.base64_to_raw(part.pixels)) != OK or image.get_width() < 1 or image.get_height() < 1 or image.get_width() > 256 or image.get_height() > 256 or image.get_used_rect().size == Vector2i.ZERO:
					return "The pixel ship image is invalid or empty."
			if int(part.rotation) != 0:
				return "A preset ship must face forward."
			command_deck_count += 1
		if part.type in ["command_deck", "retro_bridge"]:
			if int(part.rotation) % 2 != 0:
				return "The command deck must span three horizontal cells."
			command_deck_count += 1
		var cells: Dictionary = decorations if is_decoration(part) else (interior if is_interior(part) else exterior)
		if is_armour_overlay(part):
			cells = armour
			armour_panels.append(part)
		var blocks := occupied_cells(part)
		if blocks.is_empty():
			return "A component needs at least one block."
		for cell in blocks:
			if cells.has(cell):
				return "Armour panels cannot overlap." if is_armour_overlay(part) else "Components cannot overlap."
			cells[cell] = part
		if part.type == "cockpit":
			cockpit_count += 1
	if cockpit_count > 1:
		return "A ship can have only one exterior cockpit."
	if command_deck_count > 1:
		return "A ship can have only one command deck."
	for panel in armour_panels:
		if not _armour_has_support(panel, exterior):
			return "Armour needs hull underneath its entire shape."
	for cell in interior:
		if not supports_interior(exterior.get(cell, {}).get("type", "")):
			return "The command deck needs three adjacent hull cells." if interior[cell].type in ["command_deck", "retro_bridge"] else "Interior equipment needs a hull cell beneath every slot."
	for cell in decorations:
		var detail: Dictionary = decorations[cell].duplicate()
		detail.x = cell.x
		detail.y = cell.y
		var error := decoration_mount_error(detail, exterior.get(decoration_mount(detail), {}), exterior.has(cell))
		if error != "":
			return error
	if exterior.is_empty():
		return "Place a hull block first."
	var visited := {}
	var todo: Array[Vector2i] = [exterior.keys()[0]]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		if visited.has(cell):
			continue
		visited[cell] = true
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor: Vector2i = cell + direction
			if exterior.has(neighbor) and not visited.has(neighbor) and shares_edge(exterior[cell], exterior[neighbor], cell, direction):
				todo.append(neighbor)
	if visited.size() != exterior.size():
		return "Every component must connect to the ship."
	if require_flight and command_deck_count == 0:
		return "Install a Heritage bridge on an exterior block to fly."
	if check_clearance:
		var issues := clearance_issues(parts)
		if not issues.is_empty():
			var issue: Dictionary = issues[0]
			return "%s needs a clear path %s it." % [TYPES[issue.part.type].name, issue.side]
	if not require_flight:
		return ""
	var totals := stats(parts)
	if totals.power < 0.0:
		return "Not enough power. Add a power cell inside the hull."
	if totals.thrust <= 0.0:
		return "Add an engine to fly."
	return ""

static func get_engine_texture() -> Texture2D:
	if engine_texture == null:
		var image := ENGINE_SOURCE.get_image().get_region(ENGINE_SOURCE_RECT)
		image.resize(ENGINE_PIXEL_SIZE.x, ENGINE_PIXEL_SIZE.y, Image.INTERPOLATE_NEAREST)
		engine_texture = ImageTexture.create_from_image(image)
	return engine_texture

static func engine_vertices(part: Dictionary, center: Vector2, scale_factor: float = 1.0) -> PackedVector2Array:
	var is_booster: bool = part.type in ["main_booster", "retro_engine"]
	var span := Vector2(footprint(part).size)
	var rotation := int(part.get("rotation", 0)) % 4
	var local_span := span if rotation % 2 == 0 else Vector2(span.y, span.x)
	var half_size := local_span * CELL * (0.5 if is_booster else 0.47) * scale_factor
	var height := half_size.y * 2.0 if is_booster else half_size.y * 2.0 * ENGINE_PIXEL_SIZE.y / ENGINE_PIXEL_SIZE.x
	var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
	var texture_center := center + (span - Vector2.ONE) * CELL * scale_factor * 0.5
	var corners := [Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y + height), Vector2(-half_size.x, -half_size.y + height)]
	var vertices := PackedVector2Array()
	for point in corners:
		var local: Vector2 = point
		if part.get("flip_x", false):
			local.x = -local.x
		vertices.append(texture_center + local.rotated(angle))
	return vertices

static func engine_nozzles(part: Dictionary, center: Vector2, scale_factor: float = 1.0) -> Array[Dictionary]:
	var vertices := engine_vertices(part, center, scale_factor)
	var edge_start := vertices[3]
	var edge_end := vertices[2]
	var area := footprint(part)
	var result: Array[Dictionary] = []
	for run in _solid_rects(part):
		var low := center + (Vector2(run.position - area.position) - Vector2.ONE * 0.5) * CELL * scale_factor
		var rect := Rect2(low, Vector2(run.size) * CELL * scale_factor)
		var direction := edge_end - edge_start
		var minimum := 0.0
		var maximum := 1.0
		for axis in range(2):
			if absf(direction[axis]) < 0.0001:
				if edge_start[axis] < rect.position[axis] - 0.001 or edge_start[axis] > rect.end[axis] + 0.001:
					maximum = -1.0
				continue
			var a := (rect.position[axis] - edge_start[axis]) / direction[axis]
			var b := (rect.end[axis] - edge_start[axis]) / direction[axis]
			minimum = maxf(minimum, minf(a, b))
			maximum = minf(maximum, maxf(a, b))
		if maximum - minimum > 0.0001:
			result.append({"position": edge_start.lerp(edge_end, (minimum + maximum) * 0.5),
				"width": edge_start.distance_to(edge_end) * (maximum - minimum) / (CELL * (1.0 if part.type == "main_booster" else 0.94) * scale_factor)})
	return result

static func hull_polygon(part: Dictionary, center: Vector2, cell_size: float = CELL) -> PackedVector2Array:
	var size := Vector2(footprint(part).size)
	var top_left := center - Vector2.ONE * cell_size * 0.5
	if is_full_wedge(part.type) or part.type == "wedge_half":
		var corner := (Vector2(_wedge_corner(part)) + Vector2.ONE) * 0.5
		var reach := Vector2.ONE
		if part.type == "wedge_half":
			reach[int(part.rotation) % 2] = 0.5
		var wide := corner.lerp(Vector2(1.0 - corner.x, corner.y), reach.x)
		var tall := corner.lerp(Vector2(corner.x, 1.0 - corner.y), reach.y)
		return PackedVector2Array([
			top_left + corner * size * cell_size,
			top_left + wide * size * cell_size,
			top_left + tall * size * cell_size,
		])
	return _rect_polygon(Rect2(top_left, size * cell_size))

static func _rect_polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])

static func _solid_rects(part: Dictionary) -> Array[Rect2i]:
	var area := footprint(part)
	var cutouts: Dictionary = part.get("cutouts", {})
	if cutouts.is_empty():
		return [area]
	var rects: Array[Rect2i] = []
	var previous := {}
	# Merge equal runs in consecutive rows so a single hole does not create a shape for every block.
	for y in range(area.size.y):
		var current := {}
		var start := 0
		for x in range(area.size.x + 1):
			if x < area.size.x and not cutouts.has(_block_key(Vector2i(x, y))):
				continue
			if x > start:
				var run := Vector2i(start, x - start)
				var index: int = previous.get(run, rects.size())
				if index == rects.size():
					rects.append(Rect2i(area.position + Vector2i(start, y), Vector2i(run.y, 1)))
				else:
					rects[index].size.y += 1
				current[run] = index
			start = x + 1
		previous = current
	return rects

static func preset_alpha_polygons(part: Dictionary, center: Vector2, scale_factor: float = 1.0) -> Array[PackedVector2Array]:
	var texture := preset_texture(part)
	var image: Image = texture.diffuse_texture.get_image() if texture is CanvasTexture else texture.get_image()
	var bitmap := BitMap.new()
	var alpha_threshold := 0.5 if part.type == HD_LIGHT_CRUISER else 0.1
	bitmap.create_from_image_alpha(image, alpha_threshold)
	var rect := preset_draw_rect(part, center, scale_factor)
	var pixel_scale := rect.size / Vector2(image.get_size())
	var epsilon := clampf(3.0 / pixel_scale.x, 0.5, 6.0)
	var polygons: Array[PackedVector2Array] = []
	for outline in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, image.get_size()), epsilon):
		var polygon := PackedVector2Array()
		for pixel in outline:
			polygon.append(rect.position + pixel * pixel_scale)
		polygons.append(polygon)
	return polygons

static func material_polygons(part: Dictionary, center: Vector2, cell_size: float = CELL) -> Array[PackedVector2Array]:
	if part.type == HD_LIGHT_CRUISER:
		return preset_alpha_polygons(part, center, cell_size / CELL)
	if PRESET_TEXTURES.has(part.type):
		var rect := preset_draw_rect(part, center, cell_size / CELL)
		var span := rect.size
		var top_left := rect.position
		var points := PackedVector2Array()
		var outline: Array = [Vector2(0.5, 0), Vector2(0.6, 0.05), Vector2(1, 0.8), Vector2(0.9, 0.96), Vector2(0.75, 1), Vector2(0.25, 1), Vector2(0.1, 0.96), Vector2(0, 0.8), Vector2(0.4, 0.05)]
		if part.type == "preset_armoured_starter":
			outline = [Vector2(0.35, 0), Vector2(0.65, 0), Vector2(1, 0.74), Vector2(1, 0.87), Vector2(0.86, 1), Vector2(0.14, 1), Vector2(0, 0.87), Vector2(0, 0.74)]
		for point: Vector2 in outline:
			points.append(top_left + point * span)
		return [points]
	var outline := hull_polygon(part, center, cell_size)
	if not part.has("cutouts"):
		return [outline]
	var origin := Vector2(footprint(part).position) + Vector2.ONE * 0.5
	var sections: Array[PackedVector2Array] = []
	for run in _solid_rects(part):
		var rect := Rect2(center + (Vector2(run.position) - origin) * cell_size, Vector2(run.size) * cell_size)
		var polygon := _rect_polygon(rect)
		if is_full_wedge(part.type):
			sections.append_array(Geometry2D.intersect_polygons(outline, polygon))
		else:
			sections.append(polygon)
	return sections

static func structural_polygons(part: Dictionary, center: Vector2) -> Array[PackedVector2Array]:
	if part.type in MAIN_ENGINE_TYPES:
		var engine := engine_vertices(part, center)
		if not part.has("cutouts"):
			return [engine]
		var sections: Array[PackedVector2Array] = []
		for run in _solid_rects(part):
			var low := center + (Vector2(run.position - footprint(part).position) - Vector2.ONE * 0.5) * CELL
			sections.append_array(Geometry2D.intersect_polygons(engine, _rect_polygon(Rect2(low, Vector2(run.size) * CELL))))
		return sections
	if part.type in ["triangle", "wing", "connector"]:
		return [_structural_outline(part, center, CELL * 0.47)]
	return material_polygons(part, center)

static func _armour_has_support(panel: Dictionary, exterior: Dictionary) -> bool:
	var panel_shape := hull_polygon(panel, Vector2(footprint(panel).position), 1.0)
	for cell in occupied_cells(panel):
		var support: Dictionary = exterior.get(cell, {})
		var kind: String = support.get("type", "")
		if supports_interior(kind):
			continue
		if not is_full_wedge(kind) and kind != "wedge_half":
			return false
		var hull := hull_polygon(support, Vector2(footprint(support).position), 1.0)
		var slope := (hull[2] - hull[1]).normalized()
		var facing := signf(slope.cross(hull[0] - hull[1]))
		var slot := Rect2(Vector2(cell) - Vector2.ONE * 0.5, Vector2.ONE)
		for section in Geometry2D.intersect_polygons(panel_shape, _rect_polygon(slot)):
			for vertex in section:
				if slope.cross(vertex - hull[1]) * facing < -0.0001:
					return false
	return true

static func armour_borders(parts: Array) -> Dictionary:
	var armour_indices: Array[int] = []
	for index in range(parts.size()):
		var part: Dictionary = parts[index]
		if is_armour(part.type):
			armour_indices.append(index)
	if armour_indices.is_empty():
		return {}
	var occupied := {}
	var plating := {}
	for part in parts:
		if is_armour_overlay(part):
			for cell in occupied_cells(part):
				plating[cell] = part
		elif is_exterior_structure(part):
			for cell in occupied_cells(part):
				occupied[cell] = part
	var borders := {}
	for index in armour_indices:
		var part: Dictionary = parts[index]
		var neighbours := plating if is_armour_overlay(part) else occupied
		var bevels: Array[Dictionary] = []
		for polygon in material_polygons(part, Vector2(footprint(part).position), 1.0):
			var middle := Vector2.ZERO
			for vertex in polygon:
				middle += vertex
			middle /= polygon.size()
			for vertex_index in range(polygon.size()):
				var start := polygon[vertex_index]
				var end := polygon[(vertex_index + 1) % polygon.size()]
				var delta := end - start
				if delta.length_squared() < 0.000001:
					continue
				var outward := delta.orthogonal().normalized()
				if outward.dot((start + end) * 0.5 - middle) < 0.0:
					outward = -outward
				if absf(delta.x) > 0.00001 and absf(delta.y) > 0.00001:
					_add_armour_bevel(bevels, polygon, start, end, outward)
					continue
				var axis := 0 if absf(delta.x) > 0.00001 else 1
				var direction := Vector2i(outward.round())
				if start[axis] > end[axis]:
					var swap := start
					start = end
					end = swap
				var exposed := start
				var neighbour := Vector2i((start + outward * 0.01 + Vector2.ONE * 0.5).floor())
				for slot in range(floori(start[axis] + 0.50001), ceili(end[axis] + 0.49999)):
					neighbour[axis] = slot
					if not neighbours.has(neighbour):
						continue
					var cover := _edge_interval(neighbours[neighbour], neighbour, -direction, true)
					var covered_from := maxf(start[axis], slot - 0.5 + cover.x)
					var covered_to := minf(end[axis], slot - 0.5 + cover.y)
					if covered_to - covered_from < 0.00001:
						continue
					var before := start
					before[axis] = covered_from
					_add_armour_bevel(bevels, polygon, exposed, before, outward)
					exposed[axis] = covered_to
				_add_armour_bevel(bevels, polygon, exposed, end, outward)
		borders[index] = bevels
	return borders

static func _add_armour_bevel(bevels: Array[Dictionary], face: PackedVector2Array, start: Vector2, end: Vector2, outward: Vector2) -> void:
	if start.distance_squared_to(end) < 0.000001:
		return
	var lighting := (outward.dot(Vector2(-0.6, -0.8)) + 1.0) * 0.5
	var inner := -outward * (4.0 / 32.0)
	var middle := inner * 0.5
	var rim := PackedVector2Array([start, end, end + middle, start + middle])
	var bevel := PackedVector2Array([start + middle, end + middle, end + inner, start + inner])
	for polygon in Geometry2D.intersect_polygons(face, rim):
		bevels.append({"shape":polygon, "color":Color("414d5b").lerp(Color("738390"), lighting)})
	for polygon in Geometry2D.intersect_polygons(face, bevel):
		bevels.append({"shape":polygon, "color":Color("738390").lerp(Color("c1ccd2"), lighting)})
	var fasteners := floori(start.distance_to(end) / 1.75)
	for index in range(fasteners):
		var position := start.lerp(end, (index + 0.5) / fasteners) - outward * (7.0 / 32.0)
		var socket := Rect2(position - Vector2.ONE * (1.5 / 32.0), Vector2.ONE * (3.0 / 32.0))
		var highlight := Rect2(socket.position, Vector2(2.0, 1.0) / 32.0)
		for polygon in Geometry2D.intersect_polygons(face, _rect_polygon(socket)):
			bevels.append({"shape":polygon, "color":Color("5d6b78")})
		for polygon in Geometry2D.intersect_polygons(face, _rect_polygon(highlight)):
			bevels.append({"shape":polygon, "color":Color("c1ccd2")})

static func draw_armour_border(canvas: CanvasItem, bevels: Array, origin: Vector2, cell_size: float = CELL, alpha: float = 1.0) -> void:
	for bevel in bevels:
		var points := PackedVector2Array()
		for vertex in bevel.shape:
			points.append(origin + vertex * cell_size)
		var color: Color = bevel.color
		color.a = alpha
		canvas.draw_colored_polygon(points, color)

static func _material_units(part: Dictionary) -> float:
	if not can_stretch(part.type):
		return 1.0
	var area := footprint(part).get_area()
	var cutouts: Dictionary = part.get("cutouts", {})
	if cutouts.is_empty() and part.type != "retro_wedge":
		return float(area)
	if not is_full_wedge(part.type):
		return float(area - cutouts.size())
	# One unit of wedge stats represents a half-cell of material.
	var twice_area := 0.0
	for polygon in material_polygons(part, Vector2.ZERO, 1.0):
		var cross_sum := 0.0
		for i in range(polygon.size()):
			cross_sum += polygon[i].cross(polygon[(i + 1) % polygon.size()])
		twice_area += absf(cross_sum)
	return twice_area

static func _texture_clips(part: Dictionary, pose: Transform2D) -> Array[Rect2]:
	if not part.has("cutouts"):
		return [Rect2(Vector2.ZERO, Vector2.ONE)]
	var area := footprint(part)
	var span := Vector2(area.size)
	var inverse := pose.affine_inverse()
	var clips: Array[Rect2] = []
	for run in _solid_rects(part):
		var low := Vector2(run.position - area.position) / span
		var high := Vector2(run.end - area.position) / span
		var a := (inverse * (low * 2.0 - Vector2.ONE) + Vector2.ONE) * 0.5
		var b := (inverse * (high * 2.0 - Vector2.ONE) + Vector2.ONE) * 0.5
		clips.append(Rect2(a.min(b), (b - a).abs()))
	return clips

static func _draw_textured_region(canvas: CanvasItem, texture: Texture2D, center: Vector2, half_size: Vector2, pose: Transform2D, region: Rect2, uv_region: Rect2, color: Color, clips: Array[Rect2]) -> void:
	for clip in clips:
		var visible := region.intersection(clip)
		if visible.size.x <= 0.000001 or visible.size.y <= 0.000001:
			continue
		var corners := PackedVector2Array()
		var uv := PackedVector2Array()
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			var point: Vector2 = visible.position + visible.size * corner
			corners.append(center + (pose * (point * 2.0 - Vector2.ONE)) * half_size)
			uv.append(uv_region.position + (point - region.position) / region.size * uv_region.size)
		canvas.draw_polygon(corners, PackedColorArray([color]), uv, texture)

static func _cell_paint_ratio(part: Dictionary, value: String) -> Color:
	var paint := Color(value)
	var base := Color(part.paint) if part.has("paint") else HULL_BASE_COLOR
	return Color(paint.r / maxf(base.r, 0.0001), paint.g / maxf(base.g, 0.0001), paint.b / maxf(base.b, 0.0001), 1.0)

static func _draw_hull_material(canvas: CanvasItem, part: Dictionary, center: Vector2, cell_size: float, color: Color, bevel_slope: bool) -> void:
	var face := HULL_BASE_COLOR if bevel_slope else ARMOUR_FACE_COLOR
	var outline := hull_polygon(part, center, cell_size) if bevel_slope else PackedVector2Array()
	var slope := (outline[2] - outline[1]).normalized() if bevel_slope else Vector2.ZERO
	for polygon in material_polygons(part, center, cell_size):
		canvas.draw_colored_polygon(polygon, face * color)
		for key in part.get("cell_paints", {}):
			var axes: PackedStringArray = key.split(",")
			var offset := Vector2(int(axes[0]), int(axes[1]))
			var rect := Rect2(center + (offset - Vector2.ONE * 0.5) * cell_size, Vector2.ONE * cell_size)
			for section in Geometry2D.intersect_polygons(polygon, _rect_polygon(rect)):
				canvas.draw_colored_polygon(section, face * color * _cell_paint_ratio(part, part.cell_paints[key]))
		if not bevel_slope:
			continue
		for i in range(polygon.size()):
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			if absf(slope.cross(a - outline[1])) < 0.01 and absf(slope.cross(b - outline[1])) < 0.01:
				canvas.draw_line(a, b, Color("6e7d83") * color, maxf(cell_size / 32.0, 1.0), true)

static func machine_gun_muzzle_offset(barrel: int, turret_angle: float, scale_factor: float = 1.0, is_long: bool = false, is_retro: bool = false) -> Vector2:
	var muzzle: Vector2 = MACHINE_GUN_MUZZLES[barrel]
	if is_long:
		muzzle = Vector2(-4.5 if barrel == 0 else 4.5, -47.0)
	elif is_retro:
		muzzle = Vector2(-4.8 if barrel == 0 else 4.8, -41.2)
	return muzzle.rotated(turret_angle) * (CELL * scale_factor / 32.0)

static func _draw_turret_sprite(canvas: CanvasItem, texture: Texture2D, center: Vector2, turret_angle: float, pixel_scale: float, pivot: Vector2, color: Color, source := Rect2()) -> void:
	var corners := PackedVector2Array()
	var texture_size := texture.get_size()
	if not source.has_area():
		source = Rect2(Vector2.ZERO, texture_size)
	var size := source.size
	var uv := PackedVector2Array()
	for point in [Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]:
		corners.append(center + ((point - pivot) * pixel_scale).rotated(turret_angle))
		uv.append((source.position + point) / texture_size)
	canvas.draw_polygon(corners, PackedColorArray([color]), uv, texture)

static func cruiser_laser_muzzle_offset(mount: Dictionary, barrel: int, turret_angle: float, recoil: float) -> Vector2:
	var muzzle: Vector2 = CRUISER_TURRET_LAYOUTS[mount.type].muzzles[barrel] * mount.pixel_scale
	muzzle.y += recoil
	return muzzle.rotated(turret_angle)

static func draw_cruiser_turret(canvas: CanvasItem, mount: Dictionary, angle: float, fired_barrel: int, recoil: float) -> void:
	var kind: String = mount.type
	var layout: Dictionary = CRUISER_TURRET_LAYOUTS[kind]
	if not cruiser_turret_textures.has(kind):
		var atlas := CanvasTexture.new()
		atlas.diffuse_texture = layout.atlas
		atlas.texture_filter = layout.filter
		cruiser_turret_textures[kind] = atlas
	var texture: CanvasTexture = cruiser_turret_textures[kind]
	var pixel_scale: float = mount.pixel_scale
	var center: Vector2 = mount.local_position
	var row_offset := Vector2(0, mount.cruiser_index * layout.stride)
	for barrel in range(2):
		var source: Rect2 = layout.barrels[barrel]
		var pivot: Vector2 = layout.pivot - source.position
		if barrel == fired_barrel:
			pivot.y -= recoil / pixel_scale
		source.position += row_offset
		_draw_turret_sprite(canvas, texture, center, angle, pixel_scale, pivot, Color.WHITE, source)
	var housing: Rect2 = layout.housing
	var housing_pivot: Vector2 = layout.pivot - housing.position
	housing.position += row_offset
	_draw_turret_sprite(canvas, texture, center, angle, pixel_scale, housing_pivot, Color.WHITE, housing)

static func navigation_light_brightness(time: float) -> float:
	var phase := fposmod(time, 2.4) / 2.4
	return smoothstep(0.0, 0.20, phase) * (1.0 - smoothstep(0.42, 0.65, phase))

static func draw_mounted_turret(canvas: CanvasItem, turret: String, center: Vector2, scale_factor: float = 1.0, alpha: float = 1.0, tint: Color = Color.WHITE, turret_angle: float = 0.0, recoil: float = 0.0) -> void:
	var sprite_color := Color(tint.r, tint.g, tint.b, alpha * tint.a)
	var pixel_scale := CELL * scale_factor / 32.0
	match turret:
		"miner":
			_draw_turret_sprite(canvas, MINING_TURRET_TEXTURE, center, turret_angle, pixel_scale, Vector2(16, 20), sprite_color)
		"retro_machine_gun":
			var size := RETRO_MACHINE_GUN_TEXTURE.get_size()
			_draw_turret_sprite(canvas, RETRO_MACHINE_GUN_TEXTURE, center, turret_angle, CELL * scale_factor / size.x, Vector2(size.x * 0.5, size.y * 0.755), sprite_color)
		"machine_gun":
			_draw_turret_sprite(canvas, MACHINE_GUN_TEXTURE, center, turret_angle, pixel_scale, Vector2(16, 16), sprite_color)
		"long_machine_gun":
			_draw_turret_sprite(canvas, LONG_MACHINE_GUN_TEXTURE, center, turret_angle, pixel_scale, Vector2(16, 48), sprite_color)
		"laser":
			var half := CELL * 0.47 * scale_factor
			var direction := Vector2.UP.rotated(turret_angle)
			var turret_color := Color(0.82, 0.43, 0.34, alpha * tint.a)
			canvas.draw_line(center, center + direction * half * 0.95, Color(0.1, 0.14, 0.17, alpha * tint.a), 7.0 * scale_factor, true)
			canvas.draw_line(center, center + direction * half * 0.95, turret_color, 3.5 * scale_factor, true)
			canvas.draw_circle(center, half * 0.38, turret_color)
		"missile", "railgun":
			var forward := Vector2.UP.rotated(turret_angle) * scale_factor
			var side := forward.orthogonal()
			var dark := Color("202b36") * sprite_color
			var steel := Color("8896a8") * sprite_color
			canvas.draw_circle(center, 9.0 * scale_factor, dark, true, -1.0, true)
			var receiver := center - forward * recoil
			if turret == "missile":
				var muzzle := receiver + forward * ROCKET_MUZZLE_OFFSET
				canvas.draw_line(receiver - forward * 7.0, muzzle, dark, 16.0 * scale_factor, true)
				canvas.draw_line(receiver - forward * 5.0, muzzle - forward * 2.0, steel, 12.0 * scale_factor, true)
				for tube: float in [-1.0, 1.0]:
					var offset := side * 3.0 * tube
					canvas.draw_line(receiver + offset, muzzle + offset, dark, 3.0 * scale_factor, true)
					canvas.draw_circle(muzzle - forward * 2.0 + offset, 1.2 * scale_factor, Color("f2a25d") * sprite_color)
			else:
				var muzzle := receiver + forward * RAILGUN_MUZZLE_OFFSET
				canvas.draw_line(receiver - forward * 7.0, receiver + forward * 9.0, steel, 13.0 * scale_factor, true)
				for rail: float in [-1.0, 1.0]:
					var offset := side * 3.2 * rail
					canvas.draw_line(receiver + offset, muzzle + offset, dark, 5.0 * scale_factor, true)
					canvas.draw_line(receiver + forward * 4.0 + offset, muzzle + offset, Color("ab98ed") * sprite_color, 2.0 * scale_factor, true)

static func _structural_outline(part: Dictionary, center: Vector2, half: float) -> PackedVector2Array:
	var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
	var raw := [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]
	match part.type:
		"triangle":
			raw = [Vector2(0,-1), Vector2(1,1), Vector2(-1,1)]
		"wedge":
			raw = [Vector2(-1,-1), Vector2(1,1), Vector2(-1,1)]
		"wing":
			raw = [Vector2(-0.8,-0.55), Vector2(0.9,-1), Vector2(0.35,1), Vector2(-0.8,0.75)]
		"connector":
			raw = [Vector2(-0.5,-1), Vector2(0.5,-1), Vector2(0.5,1), Vector2(-0.5,1)]
	var points := PackedVector2Array()
	for point: Vector2 in raw:
		var local_point := point
		if part.get("flip_x", false):
			local_point.x = -local_point.x
		points.append(center + (local_point * half).rotated(angle))
	return points

static func draw_part(canvas: CanvasItem, part: Dictionary, center: Vector2, scale_factor: float = 1.0, alpha: float = 1.0, tint: Color = Color.WHITE, navigation_light_level: float = 1.0, separate_turrets: bool = false) -> void:
	var kind: String = part.type
	if PRESET_TEXTURES.has(kind):
		var texture: Texture2D = preset_texture(part)
		if separate_turrets and kind == HD_LIGHT_CRUISER:
			texture = HD_CRUISER_HULL
		canvas.draw_texture_rect(texture, preset_draw_rect(part, center, scale_factor), false, Color(tint.r, tint.g, tint.b, alpha * tint.a))
		return
	if part.has("paint") and can_paint(kind):
		var paint := Color(str(part.paint))
		tint = Color(tint.r * paint.r / HULL_BASE_COLOR.r, tint.g * paint.g / HULL_BASE_COLOR.g, tint.b * paint.b / HULL_BASE_COLOR.b, tint.a)
	if kind == "retro_wedge":
		var cell_size := CELL * scale_factor
		var origin := footprint(part).position
		var texture: Texture2D = HULL_TEXTURES.retro_plain
		var color := Color(tint.r, tint.g, tint.b, alpha * tint.a)
		for polygon in material_polygons(part, center, cell_size):
			for cell in occupied_cells(part):
				var tile_origin := center + (Vector2(cell - origin) - Vector2.ONE * 0.5) * cell_size
				var tile := _rect_polygon(Rect2(tile_origin, Vector2.ONE * cell_size))
				for section in Geometry2D.intersect_polygons(polygon, tile):
					var uv := PackedVector2Array()
					for vertex in section:
						uv.append((vertex - tile_origin) / cell_size)
					var tile_color := color
					var key := _block_key(cell - origin)
					if part.get("cell_paints", {}).has(key):
						tile_color *= _cell_paint_ratio(part, part.cell_paints[key])
					canvas.draw_polygon(section, PackedColorArray([tile_color]), uv, texture)
		return
	var bevel_slope := kind == "wedge_half" or (kind == "wedge" and footprint(part).size != Vector2i.ONE)
	if bevel_slope or is_armour(kind):
		_draw_hull_material(canvas, part, center, CELL * scale_factor, Color(tint.r, tint.g, tint.b, alpha * tint.a), bevel_slope)
		return
	if kind in MAIN_ENGINE_TYPES:
		var corners := engine_vertices(part, center, scale_factor)
		var uv := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
		var color := Color(tint.r, tint.g, tint.b, alpha * tint.a)
		var texture := RETRO_ENGINE_TEXTURE if kind == "retro_engine" else get_engine_texture()
		if part.has("cutouts"):
			var span := Vector2(footprint(part).size)
			var size := span * CELL * scale_factor
			var texture_center := center + (span - Vector2.ONE) * CELL * scale_factor * 0.5
			var pose := Transform2D(int(part.get("rotation", 0)) * PI / 2.0, Vector2(-1 if part.get("flip_x", false) else 1, 1), 0.0, Vector2.ZERO)
			var height := 0.94 * ENGINE_PIXEL_SIZE.y / ENGINE_PIXEL_SIZE.x
			var region := Rect2(0.03, 0.03, 0.94, height)
			_draw_textured_region(canvas, texture, texture_center, size * 0.5, pose, region, Rect2(Vector2.ZERO, Vector2.ONE), color, _texture_clips(part, pose))
		else:
			canvas.draw_polygon(corners, PackedColorArray([color]), uv, texture)
		return
	if kind == "retro_turret_base" or CARGO_TEXTURES.has(kind) or HULL_TEXTURES.has(kind) or SYSTEM_TEXTURES.has(kind) or DECORATION_TEXTURES.has(kind):
		var span := Vector2(footprint(part).size)
		var cell_size := CELL * scale_factor
		var texture_center := center + (span - Vector2.ONE) * cell_size * 0.5
		var half_size := span * cell_size * 0.5
		if kind == "retro_antenna":
			var antenna_size := DECORATION_TEXTURES.retro_antenna.get_size()
			half_size = Vector2(antenna_size.x / antenna_size.y, 1.0) * cell_size * 0.5
		if kind == "retro_bridge":
			var texture_size := DECORATION_TEXTURES.retro_bridge.get_size()
			half_size = Vector2(1.4, 1.4 * texture_size.y / texture_size.x) * cell_size * 0.5
		var rotation := int(part.get("rotation", 0)) % 4
		var pose := Transform2D(rotation * PI / 2.0, Vector2(-1 if part.get("flip_x", false) else 1, 1), 0.0, Vector2.ZERO)
		var color := Color(tint.r, tint.g, tint.b, alpha * tint.a)
		var texture: Texture2D = RETRO_TURRET_BASE_TEXTURE if kind == "retro_turret_base" else CARGO_TEXTURES.get(kind, HULL_TEXTURES.get(kind, SYSTEM_TEXTURES.get(kind, DECORATION_TEXTURES.get(kind))))
		if span != Vector2.ONE and is_square_hull(kind) and kind != "hull":
			var origin := footprint(part).position
			var full := Rect2(Vector2.ZERO, Vector2.ONE)
			var tile_half_size := Vector2.ONE * cell_size * 0.5
			var tile_clips: Array[Rect2] = [full]
			for cell in occupied_cells(part):
				var tile_center := center + Vector2(cell - origin) * cell_size
				var tile_color := color
				var key := _block_key(cell - origin)
				if part.get("cell_paints", {}).has(key):
					tile_color *= _cell_paint_ratio(part, part.cell_paints[key])
				_draw_textured_region(canvas, texture, tile_center, tile_half_size, pose, full, full, tile_color, tile_clips)
			return
		if kind == "retro_antenna":
			var corners := PackedVector2Array()
			var uv := PackedVector2Array()
			for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
				corners.append(texture_center + pose * ((corner * 2.0 - Vector2.ONE) * half_size))
				uv.append(corner)
			canvas.draw_polygon(corners, PackedColorArray([color]), uv, texture)
			return
		var clips := _texture_clips(part, pose)
		if CARGO_TEXTURES.has(kind) and kind != "retro_cargo" and span != Vector2.ONE:
			# Keep the original corner and edge thickness as the center grows.
			var local_span := span if rotation % 2 == 0 else Vector2(span.y, span.x)
			var margin := Vector2.ONE * 0.3125 / local_span
			var columns := [0.0, margin.x, 1.0 - margin.x, 1.0]
			var rows := [0.0, margin.y, 1.0 - margin.y, 1.0]
			var cuts := [0.0, 0.3125, 0.6875, 1.0]
			for y in range(3):
				for x in range(3):
					var region := Rect2(columns[x], rows[y], columns[x + 1] - columns[x], rows[y + 1] - rows[y])
					var uv := Rect2(cuts[x], cuts[y], cuts[x + 1] - cuts[x], cuts[y + 1] - cuts[y])
					_draw_textured_region(canvas, texture, texture_center, half_size, pose, region, uv, color, clips)
		elif kind == "hull" and not part.get("cell_paints", {}).is_empty():
			var full := Rect2(Vector2.ZERO, Vector2.ONE)
			var inverse := pose.affine_inverse()
			var origin := footprint(part).position
			for cell in occupied_cells(part):
				var low := Vector2(cell - origin) / span
				var high := (Vector2(cell - origin) + Vector2.ONE) / span
				var a := (inverse * (low * 2.0 - Vector2.ONE) + Vector2.ONE) * 0.5
				var b := (inverse * (high * 2.0 - Vector2.ONE) + Vector2.ONE) * 0.5
				var cell_clips: Array[Rect2] = [Rect2(a.min(b), (b - a).abs())]
				var tile_color := color
				var key := _block_key(cell - origin)
				if part.cell_paints.has(key):
					tile_color *= _cell_paint_ratio(part, part.cell_paints[key])
				_draw_textured_region(canvas, texture, texture_center, half_size, pose, full, full, tile_color, cell_clips)
		else:
			var full := Rect2(Vector2.ZERO, Vector2.ONE)
			_draw_textured_region(canvas, texture, texture_center, half_size, pose, full, full, color, clips)
		return
	var info: Dictionary = TYPES[kind]
	var angle := float(int(part.get("rotation", 0)) % 4) * PI / 2.0
	var half := CELL * 0.47 * scale_factor
	var pts := _structural_outline(part, center, half)
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
		return
	if tint != Color.WHITE:
		return
	if kind == "reactor":
		canvas.draw_circle(center, half * 0.30, Color(1.0, 0.83, 0.36, alpha))
	elif kind == "shield":
		canvas.draw_arc(center, half * 0.42, 0.0, TAU, 20, Color(0.6, 0.92, 1.0, alpha), 2.0 * scale_factor, true)
	elif kind == "thruster":
		canvas.draw_circle(center - mark * half * 0.35, half * 0.23, Color(0.32, 0.82, 1.0, alpha))

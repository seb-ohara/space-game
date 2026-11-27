extends RefCounted

const GENERAL := "General"
const FLIGHT := "Flight"
const BUILDER := "Ship Builder"
const MODIFIERS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]
const ACTIONS := {
	"game_back": ["Menu / back / cancel", GENERAL, [{"key": KEY_ESCAPE}]],
	"camera_pan_up": ["Pan camera up", FLIGHT, [{"key": KEY_W}], true],
	"camera_pan_down": ["Pan camera down", FLIGHT, [{"key": KEY_S}], true],
	"camera_pan_left": ["Pan camera left", FLIGHT, [{"key": KEY_A}], true],
	"camera_pan_right": ["Pan camera right", FLIGHT, [{"key": KEY_D}], true],
	"boost_recenter": ["Recenter camera (alternate)", FLIGHT, [{"key": KEY_SPACE}]],
	"recenter": ["Recenter camera", FLIGHT, [{"key": KEY_F}]],
	"flight_zoom_in": ["Zoom in", FLIGHT, [{"mouse": MOUSE_BUTTON_WHEEL_UP}]],
	"flight_zoom_out": ["Zoom out", FLIGHT, [{"mouse": MOUSE_BUTTON_WHEEL_DOWN}]],
	"flight_pan_drag": ["Drag camera", FLIGHT, [{"mouse": MOUSE_BUTTON_LEFT, "mods": KEY_MASK_SHIFT}], true],
	"flight_select": ["Select / drag-select", FLIGHT, [{"mouse": MOUSE_BUTTON_LEFT}], true],
	"flight_order": ["Issue order / choose target", FLIGHT, [{"mouse": MOUSE_BUTTON_RIGHT}]],
	"flight_queue": ["Queue order", FLIGHT, [{"mouse": MOUSE_BUTTON_RIGHT, "mods": KEY_MASK_SHIFT}]],
	"flight_radial": ["Open command wheel", FLIGHT, [{"mouse": MOUSE_BUTTON_MIDDLE}]],
	"cycle_target": ["Cycle target", FLIGHT, [{"key": KEY_TAB}]],
	"weapon_1": ["Select laser", FLIGHT, [{"key": KEY_1}]],
	"weapon_2": ["Select mining laser", FLIGHT, [{"key": KEY_2}]],
	"weapon_3": ["Select machine gun", FLIGHT, [{"key": KEY_3}]],
	"weapon_4": ["Select rocket", FLIGHT, [{"key": KEY_4}]],
	"weapon_5": ["Select railgun", FLIGHT, [{"key": KEY_5}]],
	"flight_debug": ["Toggle debug test flight", FLIGHT, [{"key": KEY_F8}]],
	"builder_place": ["Place / paint / select", BUILDER, [{"mouse": MOUSE_BUTTON_LEFT}], true],
	"builder_resize": ["Resize / repeat placement", BUILDER, [{"mouse": MOUSE_BUTTON_LEFT, "mods": KEY_MASK_SHIFT}], true],
	"builder_erase": ["Erase", BUILDER, [{"mouse": MOUSE_BUTTON_RIGHT}], true],
	"builder_erase_area": ["Erase area", BUILDER, [{"mouse": MOUSE_BUTTON_RIGHT, "mods": KEY_MASK_SHIFT}], true],
	"builder_pan": ["Drag view", BUILDER, [{"mouse": MOUSE_BUTTON_MIDDLE}], true],
	"builder_zoom_in": ["Zoom in", BUILDER, [{"mouse": MOUSE_BUTTON_WHEEL_UP}]],
	"builder_zoom_out": ["Zoom out", BUILDER, [{"mouse": MOUSE_BUTTON_WHEEL_DOWN}]],
	"builder_rotate": ["Rotate component", BUILDER, [{"key": KEY_R}]],
	"builder_flip": ["Flip component", BUILDER, [{"key": KEY_F}]],
	"builder_undo": ["Undo edit", BUILDER, [{"key": KEY_Z, "mods": KEY_MASK_META}, {"key": KEY_Z, "mods": KEY_MASK_CTRL}]],
	"module_move_modifier": ["Hold to drag a fitted module", "Ship Administration", [{"key": KEY_SHIFT}], true],
}

static func describe(event: InputEvent) -> Dictionary:
	var data := {}
	if event is InputEventKey:
		if event.keycode == 0 and event.physical_keycode == 0:
			return data
		if event.keycode != 0:
			data.key = event.keycode
		else:
			data.physical_key = event.physical_keycode
	elif event is InputEventMouseButton:
		data.mouse = event.button_index
	else:
		return data
	var mods: int = event.get_modifiers_mask()
	# Godot reports a modifier key as both a keycode and a modifier on press.
	match data.get("key", data.get("physical_key", 0)):
		KEY_SHIFT: mods &= ~KEY_MASK_SHIFT
		KEY_CTRL: mods &= ~KEY_MASK_CTRL
		KEY_ALT: mods &= ~KEY_MASK_ALT
		KEY_META: mods &= ~KEY_MASK_META
	if mods != 0:
		data.mods = mods
	return data

static func _make_event(data: Dictionary) -> InputEventWithModifiers:
	var event: InputEventWithModifiers
	if data.get("mouse", 0) in range(MOUSE_BUTTON_LEFT, MOUSE_BUTTON_XBUTTON2 + 1):
		event = InputEventMouseButton.new()
		event.button_index = int(data.mouse)
	elif int(data.get("key", 0)) > 0 or int(data.get("physical_key", 0)) > 0:
		event = InputEventKey.new()
		event.keycode = int(data.get("key", 0))
		event.physical_keycode = int(data.get("physical_key", 0))
	else:
		return null
	var mods := int(data.get("mods", 0))
	event.shift_pressed = (mods & KEY_MASK_SHIFT) != 0
	event.ctrl_pressed = (mods & KEY_MASK_CTRL) != 0
	event.alt_pressed = (mods & KEY_MASK_ALT) != 0
	event.meta_pressed = (mods & KEY_MASK_META) != 0
	return event

static func is_wheel(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index in range(MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_RIGHT + 1)

static func accepts(action: String, event: InputEvent) -> bool:
	return not describe(event).is_empty() and not (ACTIONS[action].size() > 3 and is_wheel(event))

static func conflict(action: String, event: InputEvent) -> String:
	var data := describe(event)
	for other in ACTIONS:
		if other == action or not InputMap.has_action(other):
			continue
		var scope: String = ACTIONS[other][1]
		if scope != ACTIONS[action][1] and scope != GENERAL and ACTIONS[action][1] != GENERAL:
			continue
		for binding in InputMap.action_get_events(other):
			if describe(binding) == data:
				return other
	return ""

static func _replace(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	Input.action_release(action)
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)

static func set_binding(action: String, event: InputEvent) -> void:
	_replace(action, [_make_event(describe(event))])

static func setup(config: ConfigFile) -> void:
	for action in ACTIONS:
		_replace(action, [])
	# Preserve existing custom keys first, even if they overlap with a new default.
	for action in ACTIONS:
		if config.has_section_key("key_bindings", action):
			var saved: Variant = config.get_value("key_bindings", action)
			if saved is int:
				saved = [{"key": saved}]
			if saved is Array:
				_load_events(action, saved)
	for action in ACTIONS:
		if InputMap.action_get_events(action).is_empty():
			_load_events(action, ACTIONS[action][2])

static func _load_events(action: String, descriptions: Array) -> void:
	var events: Array[InputEvent] = []
	for data in descriptions:
		if data is Dictionary:
			var event := _make_event(data)
			if event != null and accepts(action, event) and conflict(action, event).is_empty():
				events.append(event)
	_replace(action, events)

static func ensure_setup() -> void:
	if not InputMap.has_action("game_back"):
		setup(ConfigFile.new())

static func save(config: ConfigFile) -> void:
	for action in ACTIONS:
		if InputMap.has_action(action):
			var events := InputMap.action_get_events(action)
			# Only save overrides, so future default changes don't become custom conflicts.
			var descriptions := events.map(describe)
			if not descriptions.is_empty() and descriptions != ACTIONS[action][2]:
				config.set_value("key_bindings", action, descriptions)

static func label(action: String) -> String:
	var names := PackedStringArray()
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton:
			var buttons := ["Left-click", "Right-click", "Middle-click", "Wheel up", "Wheel down", "Wheel left", "Wheel right", "Mouse 4", "Mouse 5"]
			var prefix := OS.get_keycode_string(event.get_modifiers_mask())
			names.append(prefix + "+" + buttons[event.button_index - 1] if not prefix.is_empty() else buttons[event.button_index - 1])
		else:
			names.append(event.as_text().trim_suffix(" (Physical)"))
	return " / ".join(names) if not names.is_empty() else "Unbound"

static func pressed(event: InputEvent, action: String) -> bool:
	if event is InputEventKey and (event.keycode in MODIFIERS or event.physical_keycode in MODIFIERS):
		if not event.pressed or event.echo:
			return false
		var data := describe(event)
		return InputMap.action_get_events(action).any(func(binding: InputEvent): return describe(binding) == data)
	return event.is_action_pressed(action, false, true)

static func strength(action: String) -> float:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event.keycode in MODIFIERS or event.physical_keycode in MODIFIERS):
			return Input.get_action_strength(action)
	return Input.get_action_strength(action, true)

static func shortcut_allowed(event: InputEvent, viewport: Viewport) -> bool:
	# A bound primary click must not prevent players from using on-screen buttons.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var control := viewport.gui_get_hovered_control()
		return control == null or not (control is BaseButton or control.focus_mode != Control.FOCUS_NONE)
	return true

static func released_trigger(event: InputEvent, trigger: InputEvent) -> bool:
	if trigger == null or not event.is_released():
		return false
	# End a drag even if the modifiers used to start it have already been released.
	if event is InputEventMouseButton and trigger is InputEventMouseButton:
		return event.button_index == trigger.button_index
	if event is InputEventKey and trigger is InputEventKey:
		return event.keycode == trigger.keycode if trigger.keycode != 0 else event.physical_keycode == trigger.physical_keycode
	return false

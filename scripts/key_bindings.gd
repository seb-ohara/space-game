extends RefCounted

const ACTIONS := {
	"flight_forward": ["Forward / pan up", KEY_W],
	"flight_back": ["Brake / pan down", KEY_S],
	"flight_left": ["Turn left / pan left", KEY_A],
	"flight_right": ["Turn right / pan right", KEY_D],
	"boost_recenter": ["Boost / recenter (RTS)", KEY_SPACE],
	"recenter": ["Recenter camera", KEY_F],
	"cycle_target": ["Cycle target", KEY_TAB],
	"fire": ["Fire (flight mode)", KEY_X],
	"weapon_1": ["Laser", KEY_1],
	"weapon_2": ["Mining laser", KEY_2],
	"weapon_3": ["Machine gun", KEY_3],
	"weapon_4": ["Rocket", KEY_4],
	"weapon_5": ["Railgun", KEY_5],
}

static func set_binding(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)

static func setup(config: ConfigFile) -> void:
	for action in ACTIONS:
		set_binding(action, int(config.get_value("key_bindings", action, ACTIONS[action][1])))

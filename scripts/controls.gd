extends RefCounted
## Runtime input map for SIGKILL.
##
## Actions are registered in code so every binding lives in one readable place.
## Physical keycodes are used, so WASD stays put on any keyboard layout.
## Rules: no Ctrl/Alt/Super chords anywhere (those belong to the desktop and to
## Fred's dictation tool). Esc frees the mouse and opens the menu (C16b). C slides and X
## crouches, so crouch-style keys never need a modifier. T opens the ask box to the
## player's AI and O turns the AI on or off (C11 guide HUD). B turns the roast announcer on or off (C12 rounds). M opens
## the multiplayer panel (C13), whose own keys count only while it is open. Weapons (C16):
## 1 to 9 pick a slot, the mouse wheel cycles, Q swaps back to the last weapon, and E
## reloads, because R already resets the arena. Settings (C16b): Esc opens the menu, X
## crouches, the right mouse button aims, a gamepad's right stick looks around, and the
## settings screen rebinds the actions in REBINDABLE to one key or mouse button each: never
## Esc, never a Ctrl, Alt or Super key or chord (Ctrl+Alt above all, the desktop's), and a
## bind that another action or a fixed key already uses is shown as a conflict. SIGSTOP
## bullet time (C18): F starts it and F again ends it (SIGCONT), rebindable like the rest.
## The fork bomb (C19): G throws one without drawing it, rebindable as "Fork bomb".
## Spectate as top (C23): Tab, held, shows the top table, rebindable as "top".
## ICEbreakers (I2): U runs the loaded breaker and Y loads the next kind, rebindable as "run breaker"
## and "next breaker". The brief's H was not free: it is the multiplayer panel's own (with J, K and L,
## kept from every action since C13), so the run is on U, the nearest free key beside Y. Y was free: the
## guide's yes to a question counts only while that question is up, and the question takes it first.
##
## TODO: once the project has been opened in the Godot editor, this can move to
## the Input Map in project settings.


## Keys 1 to 9 pick weapon slots 1 to 9.
const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]
## The actions the settings screen rebinds, in the order it lists them, with their shown
## names. A bind is "key:<physical keycode>" or "mouse:<button>"; the default is the first
## event ensure() gives the action. Every other binding is fixed (FIXED_KEYS, the wheel,
## the arrows beside the movement keys, the right stick).
const REBINDABLE := [
	["move_forward", "move forward"], ["move_back", "move back"], ["move_left", "move left"],
	["move_right", "move right"], ["jump", "jump"], ["slide", "slide"], ["crouch", "crouch"],
	["fire", "fire"], ["aim", "aim"], ["reload", "reload"], ["weapon_last", "last weapon"],
	["reset_arena", "respawn"], ["ask_ai", "ask your AI"], ["toggle_ai", "AI on/off"],
	["toggle_roast", "roast on/off"], ["net_menu", "multiplayer"], ["sigstop", "SIGSTOP"],
	["throw_bomb", "Fork bomb"], ["code_rain_vision", "code-rain vision"], ["sudo_overcharge", "sudo"],
	["show_top", "top"], ["run_breaker", "run breaker"], ["cycle_breaker", "next breaker"],
]
## Fixed keys a bind is shown in conflict with: what else uses them. The keys a panel or a
## question reads only while it is up are not listed: they count only there.
const FIXED_KEYS := {
	KEY_UP: "move forward (arrow)", KEY_DOWN: "move back (arrow)", KEY_LEFT: "move left (arrow)",
	KEY_RIGHT: "move right (arrow)",
}
const FIXED_BUTTONS := {MOUSE_BUTTON_WHEEL_UP: "previous weapon", MOUSE_BUTTON_WHEEL_DOWN: "next weapon"}
## Keys that are never a bind: Esc is the menu's, and modifiers make chords.
const NEVER_KEYS := [KEY_ESCAPE, KEY_CTRL, KEY_ALT, KEY_META, KEY_HYPER]
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "left mouse", MOUSE_BUTTON_RIGHT: "right mouse", MOUSE_BUTTON_MIDDLE: "middle mouse", MOUSE_BUTTON_WHEEL_UP: "wheel up", MOUSE_BUTTON_WHEEL_DOWN: "wheel down", MOUSE_BUTTON_XBUTTON1: "mouse 4", MOUSE_BUTTON_XBUTTON2: "mouse 5"}
const MOUSE_LAST := 9
const KEY_PREFIX := "key:"
const MOUSE_PREFIX := "mouse:"
## The right stick's dead zone: smaller than an action's default, so slow aiming works.
const STICK_DEADZONE := 0.15
const CTRL_ALT_REFUSED := "Ctrl+Alt belongs to the desktop: never bound in SIGKILL"
const CHORD_REFUSED := "no Ctrl, Alt or Super keys or chords in SIGKILL"
const ESC_REFUSED := "Esc is the menu's: pick another key"
const UNKNOWN_REFUSED := "that input can't be bound"

## Each rebindable action's default bind and its fixed extra events (the arrows), taken
## from the input map the first time ensure() builds it.
static var _defaults := {}
static var _extras := {}


static func ensure() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("slide", [KEY_C])
	_key("release_mouse", [KEY_ESCAPE])
	_key("reset_arena", [KEY_R])
	_key("ask_ai", [KEY_T])
	_key("toggle_ai", [KEY_O])
	_key("toggle_roast", [KEY_B])
	_key("net_menu", [KEY_M])
	_mouse("fire", MOUSE_BUTTON_LEFT)
	for i in SLOT_KEYS.size():
		_key("weapon_%d" % (i + 1), [SLOT_KEYS[i]])
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_key("weapon_last", [KEY_Q])
	_key("reload", [KEY_E])
	_key("crouch", [KEY_X])
	_key("sigstop", [KEY_F])
	_key("throw_bomb", [KEY_G])
	_key("code_rain_vision", [KEY_V])
	_key("sudo_overcharge", [KEY_Z])
	_key("show_top", [KEY_TAB])
	_key("run_breaker", [KEY_U])
	_key("cycle_breaker", [KEY_Y])
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	if _defaults.is_empty():
		for pair in REBINDABLE:
			var events := InputMap.action_get_events(pair[0])
			_defaults[pair[0]] = bind_of(events[0]) if not events.is_empty() else ""
			_extras[pair[0]] = events.slice(1)


## The default bind of a rebindable action, or "".
static func default_bind(action: String) -> String:
	ensure()
	return _defaults.get(action, "")


## True for an action the settings screen may rebind.
static func rebindable(action: String) -> bool:
	for pair in REBINDABLE:
		if pair[0] == action:
			return true
	return false


## Puts `binds` ({action: bind}, the settings' own) into the input map: each rebindable
## action gets its bind, or its default when it has none or one the game refuses, plus its
## fixed extras. Nothing else in the map changes.
static func apply_binds(binds: Dictionary) -> void:
	ensure()
	for pair in REBINDABLE:
		var action: String = pair[0]
		var bind: String = binds.get(action, "")
		var event := event_of(bind) if bind != "" else null
		if event == null:
			event = event_of(_defaults[action])
		InputMap.action_erase_events(action)
		if event != null:
			InputMap.action_add_event(action, event)
		for extra in _extras[action]:
			InputMap.action_add_event(action, extra)


## Why `event` can't become a bind, in a few words, or "" when it can: Ctrl+Alt is refused
## first by name, then any Ctrl, Alt or Super key or chord, Esc, and anything that is not a
## key or a mouse button press.
static func bind_problem(event: InputEvent) -> String:
	if event is InputEventWithModifiers:
		var mods := event as InputEventWithModifiers
		if mods.ctrl_pressed and mods.alt_pressed:
			return CTRL_ALT_REFUSED
		if mods.ctrl_pressed or mods.alt_pressed or mods.meta_pressed:
			return CHORD_REFUSED
	if event is InputEventKey:
		var code := _code_of(event as InputEventKey)
		if code == KEY_ESCAPE:
			return ESC_REFUSED
		if code == KEY_NONE or NEVER_KEYS.has(code):
			return CHORD_REFUSED if code != KEY_NONE else UNKNOWN_REFUSED
		return ""
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return "" if button >= MOUSE_BUTTON_LEFT and button <= MOUSE_LAST else UNKNOWN_REFUSED
	return UNKNOWN_REFUSED


## The bind text for a key or mouse button event the game accepts, or "".
static func bind_of(event: InputEvent) -> String:
	if bind_problem(event) != "":
		return ""
	if event is InputEventKey:
		return KEY_PREFIX + str(_code_of(event as InputEventKey))
	return MOUSE_PREFIX + str((event as InputEventMouseButton).button_index)


## The input event for a bind text, or null when the text is not one the game accepts.
static func event_of(bind: String) -> InputEvent:
	var number := ""
	var event: InputEvent = null
	if bind.begins_with(KEY_PREFIX):
		number = bind.substr(KEY_PREFIX.length())
		var key := InputEventKey.new()
		event = key
	elif bind.begins_with(MOUSE_PREFIX):
		number = bind.substr(MOUSE_PREFIX.length())
		event = InputEventMouseButton.new()
	if event == null or number.is_empty() or number.length() > 9 or not number.is_valid_int() or number.begins_with("-") or number.begins_with("+"):
		return null
	if event is InputEventKey:
		(event as InputEventKey).physical_keycode = int(number) as Key
	else:
		(event as InputEventMouseButton).button_index = int(number) as MouseButton
	return event if bind_problem(event) == "" else null


## A bind as the screen shows it: "W", "Space", "right mouse".
static func bind_label(bind: String) -> String:
	var event := event_of(bind)
	if event is InputEventKey:
		return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	if event is InputEventMouseButton:
		var button := (event as InputEventMouseButton).button_index
		return MOUSE_NAMES.get(button, "mouse %d" % button)
	return "none"


## What else uses each action's bind: {action: [shown names]} for every action with a
## conflict, against the other rebindable actions (as `binds` sets them) and the fixed keys.
static func conflicts(binds: Dictionary) -> Dictionary:
	ensure()
	var users := {}
	for pair in REBINDABLE:
		var bind: String = binds.get(pair[0], "")
		if event_of(bind) == null:
			bind = _defaults[pair[0]]
		if not users.has(bind):
			users[bind] = []
		users[bind].append(pair)
	var out := {}
	for bind in users:
		var fixed := _fixed_user(bind)
		for pair in users[bind]:
			var others := PackedStringArray()
			for other in users[bind]:
				if other != pair:
					others.append(other[1])
			if fixed != "":
				others.append(fixed)
			if not others.is_empty():
				out[pair[0]] = others
	return out


static func _fixed_user(bind: String) -> String:
	var event := event_of(bind)
	if event is InputEventKey:
		var code := (event as InputEventKey).physical_keycode
		if SLOT_KEYS.has(code):
			return "weapon slot %d" % (SLOT_KEYS.find(code) + 1)
		return FIXED_KEYS.get(code, "")
	if event is InputEventMouseButton:
		return FIXED_BUTTONS.get((event as InputEventMouseButton).button_index, "")
	return ""


static func _code_of(key: InputEventKey) -> Key:
	return key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode


static func _key(action: StringName, keycodes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


static func _axis(action: StringName, axis: JoyAxis, direction: float) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, STICK_DEADZONE)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)


static func _mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

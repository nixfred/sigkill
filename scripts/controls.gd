extends RefCounted
## Runtime input map for SIGKILL.
##
## Actions are registered in code so every binding lives in one readable place.
## Physical keycodes are used, so WASD stays put on any keyboard layout.
## Rules: no Ctrl/Alt/Super chords anywhere (those belong to the desktop and to
## Fred's dictation tool). Esc releases the mouse. C slides, so crouch-style keys
## never need a modifier. T opens the ask box to the player's AI and O turns the AI on
## or off (C11 guide HUD). B turns the roast announcer on or off (C12 rounds). M opens
## the multiplayer panel (C13), whose own keys count only while it is open. Weapons (C16):
## 1 to 9 pick a slot, the mouse wheel cycles, Q swaps back to the last weapon, and E
## reloads, because R already resets the arena.
##
## TODO: once the project has been opened in the Godot editor, this can move to
## the Input Map in project settings.


## Keys 1 to 9 pick weapon slots 1 to 9.
const SLOT_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9]


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


static func _key(action: StringName, keycodes: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for keycode in keycodes:
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_add_event(action, event)


static func _mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

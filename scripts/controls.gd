extends RefCounted
## Runtime input map for SIGKILL.
##
## Actions are registered in code so every binding lives in one readable place.
## Physical keycodes are used, so WASD stays put on any keyboard layout.
## Rules: no Ctrl/Alt/Super chords anywhere (those belong to the desktop and to
## Fred's dictation tool). Esc releases the mouse.
##
## TODO: once the project has been opened in the Godot editor, this can move to
## the Input Map in project settings.


static func ensure() -> void:
	_key("move_forward", [KEY_W, KEY_UP])
	_key("move_back", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("jump", [KEY_SPACE])
	_key("release_mouse", [KEY_ESCAPE])
	_key("reset_arena", [KEY_R])
	_mouse("fire", MOUSE_BUTTON_LEFT)


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

class_name CoopInput
extends RefCounted
## Split-screen co-op's input (W6, PRD 5.5): player 2's actions and both players' tile keys, made in the input map as the
## mode begins and taken out as it ends, so outside the mode the map is exactly the game's own.
##
## Player 1 plays as ever, keyboard and mouse, every key the game's own; only the right stick is off for it while the mode
## runs (player.gd stick_look), because the pad is player 2's. Player 2 has a gamepad (any pad; the tests drive it with
## simulated events and never need one) and a keyboard fallback on the numeric keypad, keys the game binds to nothing.
## Each player has three tile keys: grow their tile, shrink it, and flip the split (side by side, or stacked). Player 1's
## are `=`, `-` and `0` on the number row (the game binds none of them; Omarchy's own resize keys are SUPER with `=` and
## `-`, so they read as a resize). No Ctrl, Alt or Super anywhere, and no key or button belongs to two players.

## Player 2's own actions, by the game action they stand for. Every one is made with player 2's events below.
const P2 := {
	&"move_forward": &"p2_move_forward", &"move_back": &"p2_move_back", &"move_left": &"p2_move_left", &"move_right": &"p2_move_right",
	&"look_left": &"p2_look_left", &"look_right": &"p2_look_right", &"look_up": &"p2_look_up", &"look_down": &"p2_look_down",
	&"jump": &"p2_jump", &"slide": &"p2_slide", &"crouch": &"p2_crouch", &"fire": &"p2_fire", &"aim": &"p2_aim",
	&"reload": &"p2_reload", &"weapon_next": &"p2_weapon_next", &"weapon_prev": &"p2_weapon_prev", &"throw_bomb": &"p2_throw_bomb",
}
## Each player's tile keys: grow, shrink, flip.
const TILE := {
	1: {"grow": &"coop_grow_1", "shrink": &"coop_shrink_1", "flip": &"coop_flip_1"},
	2: {"grow": &"coop_grow_2", "shrink": &"coop_shrink_2", "flip": &"coop_flip_2"},
}
## The empty action a seat reads for a game action it has no key for (player.gd NO_ACTION).
const NONE := &"coop_none"
## A stick's and a trigger's dead zone.
const DEADZONE := 0.2

## Player 2's events per action: keypad keys ("key", keycode), pad buttons ("button", index) and pad axes ("axis", axis,
## direction). Pad events are for any pad (device -1).
const P2_EVENTS := {
	&"p2_move_forward": [["key", KEY_KP_8], ["axis", JOY_AXIS_LEFT_Y, -1.0]],
	&"p2_move_back": [["key", KEY_KP_5], ["axis", JOY_AXIS_LEFT_Y, 1.0]],
	&"p2_move_left": [["key", KEY_KP_4], ["axis", JOY_AXIS_LEFT_X, -1.0]],
	&"p2_move_right": [["key", KEY_KP_6], ["axis", JOY_AXIS_LEFT_X, 1.0]],
	&"p2_look_left": [["key", KEY_KP_7], ["axis", JOY_AXIS_RIGHT_X, -1.0]],
	&"p2_look_right": [["key", KEY_KP_9], ["axis", JOY_AXIS_RIGHT_X, 1.0]],
	&"p2_look_up": [["key", KEY_KP_DIVIDE], ["axis", JOY_AXIS_RIGHT_Y, -1.0]],
	&"p2_look_down": [["key", KEY_KP_MULTIPLY], ["axis", JOY_AXIS_RIGHT_Y, 1.0]],
	&"p2_jump": [["key", KEY_KP_ENTER], ["button", JOY_BUTTON_A]],
	&"p2_slide": [["button", JOY_BUTTON_B]],
	&"p2_crouch": [["button", JOY_BUTTON_LEFT_STICK]],
	&"p2_fire": [["key", KEY_KP_0], ["axis", JOY_AXIS_TRIGGER_RIGHT, 1.0]],
	&"p2_aim": [["key", KEY_KP_3], ["axis", JOY_AXIS_TRIGGER_LEFT, 1.0]],
	&"p2_reload": [["key", KEY_KP_2], ["button", JOY_BUTTON_X]],
	&"p2_weapon_next": [["key", KEY_KP_1], ["button", JOY_BUTTON_Y]],
	&"p2_weapon_prev": [["button", JOY_BUTTON_DPAD_LEFT]],
	&"p2_throw_bomb": [["button", JOY_BUTTON_DPAD_UP]],
	&"coop_grow_2": [["key", KEY_KP_ADD], ["button", JOY_BUTTON_RIGHT_SHOULDER]],
	&"coop_shrink_2": [["key", KEY_KP_SUBTRACT], ["button", JOY_BUTTON_LEFT_SHOULDER]],
	&"coop_flip_2": [["key", KEY_KP_PERIOD], ["button", JOY_BUTTON_BACK]],
}
## Player 1's tile keys, on the number row.
const P1_EVENTS := {
	&"coop_grow_1": [["key", KEY_EQUAL]],
	&"coop_shrink_1": [["key", KEY_MINUS]],
	&"coop_flip_1": [["key", KEY_0]],
}
## How each is shown on a tile's help line: the keyboard's and the pad's.
const P1_HELP := "=  grow   -  shrink   0  flip"
const P2_HELP := "RB/KP+  grow   LB/KP-  shrink   BACK/KP.  flip"


## Every action the mode adds, made with its events (once; again after remove()).
static func ensure() -> void:
	if not InputMap.has_action(NONE):
		InputMap.add_action(NONE)
	for table in [P2_EVENTS, P1_EVENTS]:
		for action in table:
			if InputMap.has_action(action):
				continue
			InputMap.add_action(action, DEADZONE)
			for spec in table[action]:
				InputMap.action_add_event(action, event_of(spec))


## Every action the mode added, out of the map again.
static func remove() -> void:
	for table in [P2_EVENTS, P1_EVENTS]:
		for action in table:
			if InputMap.has_action(action):
				InputMap.erase_action(action)
	if InputMap.has_action(NONE):
		InputMap.erase_action(NONE)


## What uses keyboard key `code` in the mode ("grow tile (co-op)", "player 2 (co-op)"), or "": the settings screen shows
## a bind on it in conflict (scripts/controls.gd).
static func key_user(code: Key) -> String:
	for table in [P1_EVENTS, P2_EVENTS]:
		for action in table:
			for spec in table[action]:
				if str(spec[0]) == "key" and spec[1] == code:
					if table == P1_EVENTS:
						return "%s tile (co-op)" % str(action).trim_prefix("coop_").trim_suffix("_1")
					return "player 2 (co-op)"
	return ""


## True while the mode's actions are in the map (between ensure() and remove()).
static func made() -> bool:
	return InputMap.has_action(NONE)


## Every action the mode adds (for the checks).
static func added() -> Array:
	var out: Array = [NONE]
	out.append_array(P2_EVENTS.keys())
	out.append_array(P1_EVENTS.keys())
	return out


## The input event for one of the tables' specs.
static func event_of(spec: Array) -> InputEvent:
	match str(spec[0]):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = spec[1]
			return key
		"button":
			var button := InputEventJoypadButton.new()
			button.button_index = spec[1]
			button.device = -1
			return button
		_:
			var motion := InputEventJoypadMotion.new()
			motion.axis = spec[1]
			motion.axis_value = spec[2]
			motion.device = -1
			return motion


## Player 2's events, every one (for the checks).
static func p2_events() -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for action in P2_EVENTS:
		for spec in P2_EVENTS[action]:
			out.append(event_of(spec))
	return out


## Player 1's tile keys' events (for the checks).
static func p1_events() -> Array[InputEvent]:
	var out: Array[InputEvent] = []
	for action in P1_EVENTS:
		for spec in P1_EVENTS[action]:
			out.append(event_of(spec))
	return out

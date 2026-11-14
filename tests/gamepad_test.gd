extends SceneTree
## Headless gamepad test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/gamepad_test.gd
##
## The pad's bindings (scripts/controls.gd PAD_BUTTONS and PAD_AXES) are in the input map once,
## for every pad, and a rebind keeps them. Then, through real pad events into the real player:
## the left stick moves, A jumps, RB draws the next weapon, a held trigger that wavers fires as
## many shots as a held click, and Start opens the menu and closes it again. In the menu the
## D-pad and the left stick move focus, A presses (Resume, Missions, Loadout), B backs out of the Missions
## screen, a key rebind's wait and the menu itself. In Loadout, A goes into a weapon's kit, the D-pad walks its
## skins and its mod, A wears or fits, and B comes back out. In split-screen co-op (W6) the pad is player 2's alone: off player 1's
## actions while the mode runs, back when it ends. Nothing outside this process is touched.

const Controls = preload("res://scripts/controls.gd")
const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
## A device id other than 0, so a binding that names one pad would miss it.
const DEVICE := 3

var _fails := 0
var _checks := 0


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # the daemons stay never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	_map_checks()
	_coop_checks()
	await _player_checks()
	print("GAMEPAD: %d checks" % _checks)
	print("GAMEPAD RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The input map. ---

func _map_checks() -> void:
	var missing := PackedStringArray()
	for action in Controls.PAD_BUTTONS:
		if _pad_events(action, InputEventJoypadButton).size() != 1:
			missing.append(action)
	for row in Controls.PAD_AXES:
		if _pad_events(row[0], InputEventJoypadMotion).size() != 1:
			missing.append(row[0])
	for action in ["look_left", "look_right", "look_up", "look_down"]:
		if _pad_events(action, InputEventJoypadMotion).size() != 1:
			missing.append(action)
	_check("every pad button and axis is in the input map once, matching any pad", missing.is_empty(), ", ".join(missing))
	Controls.ensure()
	var twice := 0
	for action in Controls.PAD_BUTTONS:
		twice += _pad_events(action, InputEventJoypadButton).size()
	_check("a second ensure() adds no pad event twice", twice == Controls.PAD_BUTTONS.size(), "%d" % twice)
	var first := InputMap.action_get_events("jump")[0] as InputEventKey
	_check("a pad event is never an action's bind: the key or mouse button stays first", first != null and first.physical_keycode == KEY_SPACE and Controls.default_bind("jump") == "key:%d" % KEY_SPACE)
	Controls.apply_binds({"jump": "key:%d" % KEY_K, "fire": "mouse:%d" % MOUSE_BUTTON_XBUTTON1})
	var kept := _pad_events("jump", InputEventJoypadButton).size() == 1 and _pad_events("fire", InputEventJoypadMotion).size() == 1
	Controls.apply_binds({})
	kept = kept and _pad_events("jump", InputEventJoypadButton).size() == 1 and (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_SPACE
	_check("a rebind and a reset keep A on jump and RT on fire", kept)
	var ui_ok := true
	for action in Controls.PAD_UI:
		ui_ok = ui_ok and _pad_events(action, InputEventJoypadButton).size() == 1
	_check("A is the menus' accept and B their cancel", ui_ok)
	_check("pads are ignored while the window is not focused", ProjectSettings.get_setting("input_devices/joypads/ignore_joypad_on_unfocused_application", false) == true)


func _pad_events(action: StringName, kind: Variant) -> Array:
	var out := []
	for event in InputMap.action_get_events(action):
		if is_instance_of(event, kind) and event.device == Controls.PAD:
			out.append(event)
	return out


# --- Split-screen co-op: the pad is player 2's alone. ---

## Co-op (W6) gives player 2 every pad (device -1), so while it runs the pad is off player 1's actions (one pad would
## otherwise drive both players, and D-pad up is SIGSTOP here and player 2's bomb there), a second player's _ready calling
## Controls.ensure() does not bring it back, player 2 keeps all of theirs and the menus keep A and B; when it ends the
## map is exactly the game's own again, event for event and in the same order.
func _coop_checks() -> void:
	var before := _pad_map()
	CoopInput.ensure()
	var leaked := _player_one_pad_events()
	_check("while co-op runs no pad button or axis is on player 1's actions", leaked.is_empty(), ", ".join(leaked))
	Controls.ensure()
	leaked = _player_one_pad_events()
	_check("a second player's ensure() in the mode does not bring the pad back to player 1", leaked.is_empty(), ", ".join(leaked))
	var p2_pad := 0
	for action in CoopInput.P2_EVENTS:
		p2_pad += _pad_events(action, InputEventJoypadButton).size() + _pad_events(action, InputEventJoypadMotion).size()
	var wanted := 0
	for action in CoopInput.P2_EVENTS:
		for spec in CoopInput.P2_EVENTS[action]:
			wanted += 0 if str(spec[0]) == "key" else 1
	_check("player 2 keeps every pad event of theirs", p2_pad == wanted and wanted > 0, "%d of %d" % [p2_pad, wanted])
	var menus := true
	for action in Controls.PAD_UI:
		menus = menus and _pad_events(action, InputEventJoypadButton).size() == 1
	_check("the menus keep A to accept and B to cancel during co-op", menus)
	var keys := InputMap.action_get_events("jump")[0] as InputEventKey
	_check("player 1's keyboard and mouse are untouched during co-op", keys != null and keys.physical_keycode == KEY_SPACE and InputMap.action_get_events("fire").size() >= 1)
	CoopInput.remove()
	var after := _pad_map()
	_check("when co-op ends the pad is back on player 1's actions and the map is as it was", after == before)
	_check("co-op's own actions are gone again", not CoopInput.made() and not InputMap.has_action("p2_fire"))


## The pad events left on player 1's actions, named, for the checks.
func _player_one_pad_events() -> PackedStringArray:
	var out := PackedStringArray()
	var actions: Array = Controls.PAD_BUTTONS.keys()
	for row in Controls.PAD_AXES:
		actions.append(row[0])
	for action in actions:
		for kind in [InputEventJoypadButton, InputEventJoypadMotion]:
			for event in _pad_events(action, kind):
				out.append("%s %s" % [action, (event as InputEvent).as_text()])
	return out


## Every event of the actions the pad is bound to, in order, as text: the map to compare before and after.
func _pad_map() -> Dictionary:
	var out := {}
	var actions: Array = Controls.PAD_BUTTONS.keys() + Controls.PAD_UI.keys()
	for row in Controls.PAD_AXES:
		actions.append(row[0])
	for action in actions:
		var events := []
		for event in InputMap.action_get_events(action):
			events.append("%s %s" % [event.get_class(), event.as_text()])
		out[action] = events
	return out


# --- The player, through real pad events. ---

func _player_checks() -> void:
	var link := Link.new()
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	hud.pause_menu().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(30)

	var start: Vector3 = player.global_position
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	await _frames(30)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(2)
	var moved: float = (player.global_position - start).length()
	_check("the left stick moves the player", moved > 1.0, "moved %.2f m" % moved)

	await _frames(40)
	var jumps := [0]
	player.jumped.connect(func(): jumps[0] += 1)
	await _button(JOY_BUTTON_A)
	await _frames(40)
	_check("A jumps", jumps[0] == 1, "%d jumps" % jumps[0])

	var drawn := []
	player.weapon_drawn.connect(func(w): drawn.append(w))
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(40)
	_check("RB draws the next weapon", drawn.size() == 1, str(drawn))
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	await _frames(40)

	var shots := [0]
	player.shot_fired.connect(func(_hit): shots[0] += 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await _frames(20)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(90)
	var by_click: int = shots[0]
	shots[0] = 0
	for i in 20:
		_axis(JOY_AXIS_TRIGGER_RIGHT, 0.7 + 0.2 * (i % 2))  # a hand on a trigger never holds still
		await _frames(1)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(90)
	var by_trigger: int = shots[0]
	_check("a held trigger that wavers fires as many shots as a held click, not one per wobble", by_click >= 1 and by_trigger == by_click, "click %d, trigger %d" % [by_click, by_trigger])

	var menu = hud.pause_menu()
	await _button(JOY_BUTTON_START)
	var opened: bool = menu.is_open()
	await _button(JOY_BUTTON_START)
	_check("Start opens the menu and Start closes it", opened and not menu.is_open(), "open %s then %s" % [opened, menu.is_open()])

	await _button(JOY_BUTTON_START)
	var first := _focus()
	await _button(JOY_BUTTON_DPAD_DOWN)
	var second := _focus()
	await _button(JOY_BUTTON_DPAD_UP)
	_check("in the menu the D-pad moves the focus down and back up", first != null and second != null and first != second and _focus() == first, "%s, %s" % [first, second])
	await _push_stick()
	var by_stick := _focus()
	await _push_stick(-1.0)
	_check("the left stick moves the focus as the D-pad does, one step for a held, wavering push", by_stick == second and _focus() == first, "%s" % by_stick)
	await _button(JOY_BUTTON_A)
	_check("A presses the focused button: Resume closes the menu", not menu.is_open())

	await _button(JOY_BUTTON_START)
	var missions = menu.missions_screen()
	while _focus() != null and _focus().get("text") != "Missions":  # down from Resume to Missions
		var was = _focus()
		await _button(JOY_BUTTON_DPAD_DOWN)
		if _focus() == was:
			break
	await _button(JOY_BUTTON_A)
	var shown: bool = missions.is_open()
	var at: int = missions.selected
	await _button(JOY_BUTTON_DPAD_DOWN)
	var moved_to: int = missions.selected
	await _push_stick()
	var stick_to: int = missions.selected
	await _push_stick(-1.0)
	_check("in Missions the left stick picks as the D-pad does, one mission a push", stick_to == moved_to + 1 and missions.selected == moved_to, "%d then %d" % [stick_to, missions.selected])
	await _button(JOY_BUTTON_B)
	_check("A opens Missions, the D-pad picks a mission there, and B backs out to the menu", shown and moved_to != at and not missions.is_open() and menu.is_open(), "shown %s, %d to %d" % [shown, at, moved_to])
	await _loadout_checks(menu, player)
	menu.begin_rebind("jump")
	var waiting: bool = menu.is_capturing()
	await _button(JOY_BUTTON_B)
	_check("B gives up a key rebind's wait, and binds nothing", waiting and not menu.is_capturing() and menu.is_open() and (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_SPACE)
	await _button(JOY_BUTTON_B)
	_check("B closes the menu", not menu.is_open())

	main.free()


## The Loadout screen on the pad: the D-pad picks a weapon, A goes into its kit, the D-pad walks its skins and
## then its mod, A wears or fits, B comes out of the kit and then out of the screen. Two of the cannon's kit are
## held here (a headless run's progress has no file: nothing is saved).
func _loadout_checks(menu, player) -> void:
	var progress := Progress.current()
	progress.clear()
	progress.count("kills_terminal_cannon", 30)
	player.select_slot(0)
	await _frames(20)
	var screen = menu.loadout_screen()
	while _focus() != null and _focus().get("text") != "Loadout":  # on from Missions to Loadout
		var was = _focus()
		await _button(JOY_BUTTON_DPAD_DOWN)
		if _focus() == was:
			break
	await _button(JOY_BUTTON_A)
	var shown: bool = screen.is_open()
	await _button(JOY_BUTTON_DPAD_DOWN)
	var next_weapon: int = screen.slot
	await _button(JOY_BUTTON_DPAD_UP)
	_check("A opens Loadout, and there the D-pad picks a weapon without going into its kit", shown and next_weapon == 1 and screen.slot == 0 and not screen.pad_in_kit(), "shown %s, slot %d" % [shown, next_weapon])
	await _button(JOY_BUTTON_A)
	var entered: bool = screen.pad_in_kit() and screen.pad_card() == 0
	await _button(JOY_BUTTON_DPAD_DOWN)
	var lit: bool = screen.pad_card() == 1 and screen.stage.skin == "tty1"
	await _button(JOY_BUTTON_A)
	_check("A goes into the weapon's kit at the skin worn; the D-pad lights the next skin and A wears it", entered and lit and progress.skin_of("terminal_cannon") == "tty1", "in %s, lit %s, wears %s" % [entered, lit, progress.skin_of("terminal_cannon")])
	var skins: int = WeaponKit.of("terminal_cannon").skins.size()
	await _push_stick(-1.0)
	await _push_stick(-1.0)
	var mod_card: bool = screen.pad_card() == skins
	var fitted_before: bool = progress.mod_on("terminal_cannon")
	await _button(JOY_BUTTON_A)
	_check("past the first skin the stick wraps round to the mod, and A fits it", mod_card and not fitted_before and progress.mod_on("terminal_cannon"), "card %d of %d" % [screen.pad_card(), skins])
	await _button(JOY_BUTTON_B)
	var out_of_kit: bool = not screen.pad_in_kit() and screen.is_open()
	await _button(JOY_BUTTON_B)
	_check("B comes out of the kit, then out of Loadout to the menu", out_of_kit and not screen.is_open() and menu.is_open())
	progress.clear()


func _focus() -> Control:
	return root.gui_get_focus_owner()


## The left stick pushed down (or up, for -1) and held a while with a wobble, then let go.
func _push_stick(direction: float = 1.0) -> void:
	for value in [0.3, 0.7, 0.95, 1.0, 0.85, 1.0, 0.9]:
		_axis(JOY_AXIS_LEFT_Y, value * direction)
		await _frames(1)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	await _frames(3)


func _axis(axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.device = DEVICE
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)


func _button(button: JoyButton) -> void:
	for down in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = button
		event.pressed = down
		Input.parse_input_event(event)
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame

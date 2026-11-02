extends SceneTree
## Headless test of split-screen co-op (W6, PRD 5.5). scripts/check.sh runs it as step 70, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/coop_test.gd
##
## Demo data only: the arena's own daemons; there is no real layer in the mode. Player 2 is driven by simulated input
## events (a pad's sticks, buttons and triggers, and the keypad), never a real gamepad.
##
## The code: nothing of the mode can run a program, call the compositor (no hyprctl, no IPC, no window calls), make a
## window, open a socket, touch a file or write anything. The keys: player 2's keys and buttons never collide with player
## 1's inside the mode (both ways), player 1's right stick is off while the pad is player 2's, the regular arena's keys are
## unchanged (the map exactly as before, outside the mode and after it), no Ctrl+Alt combo anywhere. The mode: off by
## default; queued, a second player beside the first, two tiles drawing the one world, the window's own 3D view off, one OS
## window; player 2 moves, looks and fires from simulated pad and keypad events while player 1 does not; the split moves
## (keys and buttons, a cooldown, the flip) and the trade applies both ways (the view, the look speed, the spread); a
## downed player revived by the partner standing close (and not from afar), a bleed-out, a wipe; a two-player run of every
## wave to the shared results card (each player's kills, downs, revives and accuracy); Enter's again; the visor in player
## 1's tile only; each body seen only by the partner; the Esc menu's entry, one world mode at a time; leaving puts back
## the window's 3D view, the HUD and the input map.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const MODE_CODE := ["res://scripts/coop/coop_hunt.gd", "res://scripts/coop/coop_screen.gd", "res://scripts/coop/coop_input.gd", "res://scripts/coop/coop_body.gd", "res://scripts/coop/coop_hud.gd", "res://scripts/coop/coop_tile_hud.gd", "res://scripts/coop/coop_sound.gd"]
## Nothing of the machine may be touched: no program, no compositor, no window, no socket, no file.
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "create_instance", "move_to_trash", "hyprctl", "hyprland_instance", "swaymsg", "wmctrl", "xdotool", "ydotool", "wtype", "omarchy-", "Window.new", "window_create", "DisplayServer.window", "popup", "AcceptDialog", "FileDialog", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "ENetConnection", "ENetMultiplayer", "WebRTC", "MultiplayerPeer", "IP.resolve", "FileAccess", "DirAccess", "store_", "ResourceSaver", "user://", "ConfigFile", "OS.get_environment", "set_environment", "parse_input_event", "Input.action_press", "warp_mouse", "clipboard_set", "print("]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _keys_before := {}
var _plain_windows := -1


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://coop-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	_keys_before = _input_map()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	_clear_modes()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_key_checks()
	await _arena_checks()
	await _run_checks()
	await _menu_checks()
	_check("acceptance (no conflicts): the regular arena's keys are unchanged after the mode: every action and its keys exactly as before, none of the mode's left", _input_map() == _keys_before and not InputMap.has_action("p2_fire") and not InputMap.has_action(CoopInput.NONE))
	await _cleanup()
	print("COOP: %d checks" % _checks)
	print("COOP RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _clear_modes() -> void:
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
	PacketTracer.clear()
	CoopHunt.clear()


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in MODE_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.to_lower().contains(word.to_lower()):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): nothing in the mode runs a program, calls the compositor (no hyprctl, no IPC, no window manager call), makes a window, opens a socket, touches a file or writes anything (nothing under user://), in any of its %d files" % MODE_CODE.size(), found.is_empty(), ", ".join(found))
	var maps := PackedStringArray()
	for path in MODE_CODE:
		if _code_of(path).contains("InputMap") and path != "res://scripts/coop/coop_input.gd":
			maps.append(path.get_file())
	_check("only the mode's input table touches the input map (adding its own actions as it begins, taking them out as it ends)", maps.is_empty(), ", ".join(maps))


## A file's code with its comments taken out.
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The keys (pure). ---

func _key_checks() -> void:
	CoopInput.ensure()
	var p2_actions := {}
	for a in CoopInput.P2_EVENTS:
		p2_actions[a] = true
	var p1_actions: Array = []
	for action in InputMap.get_actions():
		var s := str(action)
		if s.begins_with("ui_") or p2_actions.has(action) or action == CoopInput.NONE or s.begins_with("look_"):
			continue  # Godot's own, player 2's, the empty one, and the right stick (off for player 1 in co-op)
		p1_actions.append(action)
	var hits := PackedStringArray()
	for ev in CoopInput.p2_events():
		for action in p1_actions:
			if InputMap.event_is_action(ev, action):
				hits.append("%s -> %s" % [ev.as_text(), action])
	var back := PackedStringArray()
	for action in p1_actions:
		for ev in InputMap.action_get_events(action):
			for a2 in p2_actions:
				if InputMap.event_is_action(ev, a2):
					back.append("%s -> %s" % [ev.as_text(), a2])
	_check("acceptance (no conflicts): player 2's %d keys and buttons never trigger any of player 1's %d actions inside the mode, and none of player 1's keys or buttons triggers player 2's (%d actions)" % [CoopInput.p2_events().size(), p1_actions.size(), p2_actions.size()], hits.is_empty() and back.is_empty() and p1_actions.has(&"fire") and p1_actions.has(&"coop_grow_1"), ", ".join(hits + back))
	var ctrl_alt := PackedStringArray()
	var mods := PackedStringArray()
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventWithModifiers:
				var m := ev as InputEventWithModifiers
				if m.ctrl_pressed and m.alt_pressed:
					ctrl_alt.append(str(action))
				if CoopInput.added().has(action) and (m.ctrl_pressed or m.alt_pressed or m.meta_pressed or m.shift_pressed):
					mods.append(str(action))
	_check("acceptance: no Ctrl+Alt combo anywhere in the game's keys with the mode's in (every action of its own, %d), and none of the mode's keys needs a modifier" % InputMap.get_actions().filter(func(a): return not str(a).begins_with("ui_")).size(), ctrl_alt.is_empty() and mods.is_empty(), ", ".join(ctrl_alt + mods))
	var fixed := PackedStringArray()
	for ev in CoopInput.p1_events():
		var code: Key = (ev as InputEventKey).physical_keycode
		if Controls.SLOT_KEYS.has(code) or Controls.FIXED_KEYS.has(code):
			fixed.append(OS.get_keycode_string(code))
		for pair in Controls.REBINDABLE:
			if Controls.default_bind(pair[0]) == "key:%d" % code:
				fixed.append(OS.get_keycode_string(code))
	_check("player 1's tile keys (=, - and 0) are keys the game binds to nothing else: no weapon slot, no fixed key, no action's default", fixed.is_empty(), ", ".join(fixed))
	var shown: Dictionary = Controls.conflicts({"jump": "key:%d" % KEY_KP_8, "reload": "key:%d" % KEY_EQUAL})
	_check("a bind on one of the mode's keys is shown in conflict on the settings screen (keypad 8: %s; =: %s)" % [", ".join(shown.get("jump", PackedStringArray())), ", ".join(shown.get("reload", PackedStringArray()))], Array(shown.get("jump", [])).has("player 2 (co-op)") and Array(shown.get("reload", [])).has("grow tile (co-op)") and Controls.conflicts({}).is_empty())
	CoopInput.remove()
	_check("outside the mode its actions are not in the map at all", not InputMap.has_action("p2_move_forward") and not InputMap.has_action("coop_grow_1") and _input_map() == _keys_before)


func _input_map() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		var evs := PackedStringArray()
		for ev in InputMap.action_get_events(action):
			evs.append(ev.as_text())
		out[str(action)] = evs
	return out


# --- The arena. ---

func _arena(queue_mode: bool) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	_clear_modes()
	if queue_mode:
		CoopHunt.queue()
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = _abs.path_join("privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	current_scene = main
	await _ready_arena(main)
	return main


func _ready_arena(main: Node) -> void:
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	player.velocity = Vector3.ZERO
	await _frames(3)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	await _frames(2)
	return main


func _arena_checks() -> void:
	var plain := await _arena(false)
	var m0 := CoopHunt.of(plain)
	await _frames(10)
	_plain_windows = _windows(plain)
	var director := DaemonDirector.of(plain)
	_check("acceptance: off by default: the mode stands in the arena, not running, no second player, the window's own 3D view on, the daemons hunting player 1 alone", m0 != null and not m0.running and plain.get_node_or_null("Player2") == null and not plain.get_viewport().disable_3d and director.prey_ids() == [1])


func _run_checks() -> void:
	var windows_before := DisplayServer.get_window_list().size()
	var main := await _arena(true)
	var mode := CoopHunt.of(main)
	await _until(func(): return mode.running)
	await _frames(10)
	var p1 = main.get_node("Player")
	var p2 = main.get_node_or_null("Player2")
	var screen := mode.screen
	var director := DaemonDirector.of(main)
	var hud = main.get_node("Hud")
	var ports_ok: bool = screen != null and screen.port(1) != null and screen.port(2) != null and screen.port(1).world_3d == main.get_viewport().find_world_3d() and screen.port(2).world_3d == screen.port(1).world_3d and screen.camera(1).current and screen.camera(2).current
	_check("acceptance: queued (the Esc menu, or --coop), a second player beside the first (seat 2, its own keys), two tiles drawing the one world through their own cameras, the window's own 3D view off", p2 != null and p2.seat == 2 and not p2.actions.is_empty() and ports_ok and main.get_viewport().disable_3d and p1.global_position.distance_to(p2.global_position) < 4.0)
	_check("acceptance (guardrail): one game window: the OS windows as before (%d here, headless), the mode made no window of any kind (no Window node: the tiles are SubViewports inside the one window, every subwindow embedded)" % DisplayServer.get_window_list().size(), DisplayServer.get_window_list().size() == windows_before and windows_before <= 1 and _windows(main) == _plain_windows and _plain_windows >= 0 and root.gui_embed_subwindows, "window nodes %d, the plain arena's %d" % [_windows(main), _plain_windows])
	_check("the daemons hunt both players (prey 1 and 2), the arena's own four parked, ICE stood down, the arena's HUD play parts out of sight (each tile has its own)", director.prey_ids() == [1, 2] and director.prey_point(2).is_finite() and mode._parked.size() == 4 and main.get_node("IceDirector").stand_down and hud.coop_on() and not hud.combat_hud().visible and not hud.weapon_hud().visible)
	_check("co-op is weapons only: both players' abilities gated off (SIGSTOP would slow the one clock both share), player 1's right stick off (the pad is player 2's)", p1.abilities_gated and p2.abilities_gated and p1.abilities.is_empty() and not p1.stick_look and p2.stick_look)
	# Player 2 from simulated pad and keypad events; player 1 untouched.
	mode.lives[1]["protect"] = 999.0
	mode.lives[2]["protect"] = 999.0
	await _frames(2)
	var a1: Vector3 = p1.global_position
	var a2: Vector3 = p2.global_position
	var yaw1: float = p1.rotation.y
	var yaw2: float = p2.rotation.y
	_axis(JOY_AXIS_LEFT_Y, -1.0)
	_axis(JOY_AXIS_RIGHT_X, 1.0)
	await _frames(30)
	_axis(JOY_AXIS_LEFT_Y, 0.0)
	_axis(JOY_AXIS_RIGHT_X, 0.0)
	await _frames(2)
	var moved2: float = Vector2(p2.global_position.x - a2.x, p2.global_position.z - a2.z).length()
	var moved1: float = Vector2(p1.global_position.x - a1.x, p1.global_position.z - a1.z).length()
	_check("acceptance (input): player 2 walks and looks from a simulated pad's sticks (%.1f m, turned %.2f rad) while player 1 stands still and does not turn (the right stick is player 2's)" % [moved2, absf(p2.rotation.y - yaw2)], moved2 > 1.0 and absf(p2.rotation.y - yaw2) > 0.05 and moved1 < 0.05 and absf(p1.rotation.y - yaw1) < 0.0001)
	a1 = p1.global_position
	a2 = p2.global_position
	_key(KEY_KP_8, true)
	await _frames(20)
	_key(KEY_KP_8, false)
	await _frames(2)
	moved2 = Vector2(p2.global_position.x - a2.x, p2.global_position.z - a2.z).length()
	moved1 = Vector2(p1.global_position.x - a1.x, p1.global_position.z - a1.z).length()
	_check("acceptance (input): the keypad fallback walks player 2 (keypad 8, %.1f m), player 1 not" % moved2, moved2 > 0.5 and moved1 < 0.05)
	var s1: int = p1.shots_fired
	var s2: int = p2.shots_fired
	_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	await _frames(3)
	_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	await _frames(40)
	_key(KEY_KP_0, true)
	await _frames(3)
	_key(KEY_KP_0, false)
	await _frames(4)
	_check("acceptance (input): player 2 fires from the pad's trigger and the keypad's 0 (%d shots), player 1 fires nothing" % (p2.shots_fired - s2), p2.shots_fired - s2 >= 2 and p1.shots_fired == s1)
	a1 = p1.global_position
	_key(KEY_W, true)
	await _frames(15)
	_key(KEY_W, false)
	await _frames(2)
	moved1 = Vector2(p1.global_position.x - a1.x, p1.global_position.z - a1.z).length()
	_check("player 1 plays on its own keys as ever (W walks it %.1f m)" % moved1, moved1 > 0.3)
	await _tile_checks(main, mode, p1, p2)
	await _down_checks(main, mode, p1, p2)
	await _wave_checks(main, mode, p1, p2)
	await _view_checks(main, mode, p1, p2)


## A pad's axis moved to `value` (any pad: device 0, as one plugged in first).
func _axis(axis: JoyAxis, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.device = 0
	ev.axis = axis
	ev.axis_value = value
	Input.parse_input_event(ev)


func _button(button: JoyButton, down: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.device = 0
	ev.button_index = button
	ev.pressed = down
	Input.parse_input_event(ev)


func _key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)


func _tap_key(code: Key) -> void:
	_key(code, true)
	await _frames(2)
	_key(code, false)
	await _frames(2)


func _tap_button(button: JoyButton) -> void:
	_button(button, true)
	await _frames(2)
	_button(button, false)
	await _frames(2)


func _tile_checks(_main: Node, mode: CoopHunt, p1, p2) -> void:
	var screen := mode.screen
	await _frames(int(CoopScreen.COOLDOWN_S * 60.0) + 2)
	var even1 := screen.view_degrees(1)
	var even2 := screen.view_degrees(2)
	_check("the split starts even, side by side: both tiles the same, no trade (aim x1, spread x1)", is_equal_approx(screen.share, 0.5) and not screen.stacked and absf(even1.x - even2.x) < 1.0 and is_equal_approx(p1.aim_scale, 1.0) and is_equal_approx(p2.steady_scale, 1.0))
	await _tap_key(KEY_EQUAL)
	await _frames(int(CoopScreen.RESIZE_S * 60.0) + 4)
	var grown1 := screen.share_of(1)
	await _tap_key(KEY_EQUAL)
	await _frames(4)
	var cooled := is_equal_approx(screen.share_of(1), grown1)
	await _frames(int(CoopScreen.COOLDOWN_S * 60.0))
	await _tap_key(KEY_EQUAL)
	await _frames(int(CoopScreen.RESIZE_S * 60.0) + 4)
	var v1 := screen.view_degrees(1)
	var v2 := screen.view_degrees(2)
	var r1: Rect2 = screen.view_rect(1)
	var r2: Rect2 = screen.view_rect(2)
	_check("acceptance (the split moves): player 1's = grows its tile a step (%.0f%%), a second press inside the cooldown does nothing, after it the tile grows to its limit (%.0f%%)" % [grown1 * 100.0, screen.share_of(1) * 100.0], is_equal_approx(grown1, 0.5 + CoopScreen.STEP) and cooled and is_equal_approx(screen.share_of(1), CoopScreen.SHARE_HIGH) and r1.size.x > r2.size.x * 1.6)
	_check("acceptance (the trade, one way): the bigger tile sees more (%.0f° across against %.0f°) and aims slower and wider (aim x%.2f, spread x%.2f); the smaller aims faster and steadier (aim x%.2f, spread x%.2f)" % [v1.x, v2.x, p1.aim_scale, p1.steady_scale, p2.aim_scale, p2.steady_scale], v1.x > v2.x + 20.0 and p1.aim_scale < 1.0 and p1.steady_scale > 1.0 and p2.aim_scale > 1.0 and p2.steady_scale < 1.0 and is_equal_approx(p2.aim_scale, CoopScreen.AIM_FAST) and is_equal_approx(p2.steady_scale, CoopScreen.STEADY_SMALL))
	# The trade applies, not only shows: the same stick turns the smaller tile's player faster, its shotgun's pellets tighter.
	var turn_small := await _turn_of(p2)
	var spread_small := _spread_of(p2)
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(int(CoopScreen.COOLDOWN_S * 60.0) + 2)
	await _tap_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(int(CoopScreen.COOLDOWN_S * 60.0) + 2)
	await _tap_key(KEY_KP_ADD)
	await _frames(int(CoopScreen.COOLDOWN_S * 60.0) + 2)
	await _tap_key(KEY_KP_ADD)
	await _frames(int(CoopScreen.RESIZE_S * 60.0) + 4)
	var w1 := screen.view_degrees(1)
	var w2 := screen.view_degrees(2)
	var turn_big := await _turn_of(p2)
	var spread_big := _spread_of(p2)
	_check("acceptance (the trade, the other way): player 2's pad RB and keypad + grow its tile to the limit (%.0f%%): now it sees more (%.0f° against %.0f°), turns slower (%.3f rad against %.3f for the same stick) and its shotgun spreads wider (%.1f° against %.1f°)" % [screen.share_of(2) * 100.0, w2.x, w1.x, turn_big, turn_small, spread_big, spread_small], is_equal_approx(screen.share_of(2), CoopScreen.SHARE_HIGH) and w2.x > w1.x + 20.0 and turn_big < turn_small * 0.7 and spread_big > spread_small * 1.6 and p1.aim_scale > 1.0 and p2.aim_scale < 1.0)
	await _tap_key(KEY_0)
	await _frames(int(CoopScreen.FLIP_S * 60.0) + 4)
	var t1: Rect2 = screen.tile_rect(1)
	var t2: Rect2 = screen.tile_rect(2)
	await _tap_button(JOY_BUTTON_BACK)
	await _frames(4)
	var still := screen.stacked
	_check("acceptance: player 1's 0 flips the split to stacked (tile 1 over tile 2, both full width), player 2's Back inside the flip's shared cooldown does not flip it back", screen.stacked and still and t1.end.y < t2.position.y and absf(t1.size.x - t2.size.x) < 1.0 and t1.size.x > 1000.0)
	await _frames(int(CoopScreen.FLIP_COOLDOWN_S * 60.0))
	await _tap_button(JOY_BUTTON_BACK)
	await _frames(int(CoopScreen.FLIP_S * 60.0) + 4)
	_check("and player 2's Back flips it back to side by side, its tile the active one (its border lit)", not screen.stacked and screen.focus == 2)
	var hud := _tile_hud(mode, 2)
	var tt: Dictionary = hud.trade_text() if hud != null else {}
	_check("the trade shown on each tile: its view in degrees, its aim and spread (\"%s  %s  %s\")" % [tt.get("view", ""), tt.get("aim", ""), tt.get("spread", "")], str(tt.get("view", "")).begins_with("VIEW ") and str(tt.get("aim", "")) == "AIM x%.2f" % CoopScreen.AIM_SLOW and str(tt.get("spread", "")) == "SPREAD +%d%%" % int(round((CoopScreen.STEADY_BIG - 1.0) * 100.0)))
	screen.share = 0.5
	screen._share_shown = 0.5
	screen._share_t = CoopScreen.RESIZE_S
	await _frames(2)


## How far player `p` turns for one second of a full stick to the right (radians).
func _turn_of(p) -> float:
	var before: float = p.rotation.y
	p.look_with_stick(Vector2(1.0, 0.0), 0.2)
	var turned := absf(angle_difference(before, p.rotation.y))
	p.rotation.y = before
	return turned


## The widest pellet of player `p`'s shotgun (SIGTERM), degrees off its aim, over a few shots' worth of pellets.
func _spread_of(p) -> float:
	var slot: int = p.inventory.slot_of("sigterm")
	var was: int = p.inventory.current
	p._w = p.inventory.defs[slot]
	var widest := 0.0
	for i in 12:
		for d in p._pellets(Vector3.FORWARD):
			widest = maxf(widest, rad_to_deg(Vector3.FORWARD.angle_to(d)))
	p._w = p.inventory.defs[was]
	return widest


func _tile_hud(mode: CoopHunt, seat: int) -> CoopTileHud:
	var found := mode.screen.overlay(seat).find_children("*", "CoopTileHud", true, false)
	return found[0] if not found.is_empty() else null


func _down_checks(_main: Node, mode: CoopHunt, p1, p2) -> void:
	var director := DaemonDirector.of(_main)
	mode.lives[2]["protect"] = 0.0
	mode.lives[1]["protect"] = 999.0
	p1.global_position = p2.global_position + Vector3(9.0, 0.0, 0.0)
	await _frames(2)
	var took := mode.damage(2, 500.0, null, Vector3.FORWARD)
	await _frames(40)
	_check("acceptance (down): player 2's health at 0 is a down, not a death: the job stopped, it cannot move or shoot, its view sunk and drained, the daemons hunting player 1 alone", took and mode.state(2) == "down" and not p2.alive and p2.slump > 0.5 and mode.screen.down[2] > 0.5 and not director.prey_valid(2) and director.prey_valid(1) and mode.events.any(func(e): return str(e["text"]).begins_with("[2]+  Stopped")))
	await _frames(60)
	_check("from afar (%.0f m) nothing revives it: no progress" % CoopHunt.REVIVE_M, mode.state(2) == "down" and float(mode.lives[2]["revive"]) == 0.0)
	p1.global_position = p2.global_position + Vector3(1.2, 0.0, 0.0)
	await _frames(int(CoopHunt.REVIVE_S * 60.0 * 0.5))
	var half := float(mode.lives[2]["revive"])
	p1.global_position = p2.global_position + Vector3(9.0, 0.0, 0.0)
	await _frames(30)
	var fell := float(mode.lives[2]["revive"])
	_check("standing close fills the revive (%.0f%% at half the time) and stepping away lets it fall back (%.0f%%)" % [half * 100.0, fell * 100.0], half > 0.35 and half < 0.65 and fell < half and mode.state(2) == "down")
	p1.global_position = p2.global_position + Vector3(1.2, 0.0, 0.0)
	await _until(func(): return mode.state(2) == "up")
	await _frames(30)
	_check("acceptance (revive): the partner standing close brings it back (fg %%2): up at %d health, briefly protected, walking and shooting again, player 1's revive counted" % int(mode.health(2)), mode.state(2) == "up" and p2.alive and is_equal_approx(mode.health(2), CoopHunt.REVIVE_HEALTH) and int(mode.per[1]["revives"]) == 1 and int(mode.per[2]["downs"]) == 1 and director.prey_valid(2) and mode.events.any(func(e): return str(e["text"]).begins_with("fg %2")))
	# A bleed-out.
	mode.lives[1]["protect"] = 0.0
	mode.lives[2]["protect"] = 999.0
	p1.global_position = p2.global_position + Vector3(9.0, 0.0, 0.0)
	mode.damage(1, 500.0, null, Vector3.FORWARD)
	await _frames(2)
	mode.lives[1]["bleed"] = 0.3
	await _frames(40)
	_check("left alone, a downed player bleeds out: out (derezzed) until the wave ends, the partner still up", mode.state(1) == "out" and mode.state(2) == "up" and not mode._bodies[1].visible)
	mode.lives[2]["protect"] = 0.0
	mode.damage(2, 500.0, null, Vector3.FORWARD)
	await _frames(4)
	_check("acceptance: both players down or out at once: wiped, the run over", mode.phase == "wiped" and bool(CoopHunt.stats.get("wiped", false)))
	await _until(func(): return mode.phase == "results")
	_check("a wipe ends on the shared results card (\"%s\")" % mode.result_lines()[0], mode.phase == "results" and mode.result_lines()[0].begins_with("WIPED ON WAVE"))
	_press_accept()
	await _frames(6)
	_check("acceptance: Enter on the card runs it again: both players up, full, the waves from the start", mode.phase == "ready" and mode.wave == 0 and mode.state(1) == "up" and mode.state(2) == "up" and p1.alive and p2.alive and is_equal_approx(mode.health(1), CoopHunt.MAX_HEALTH))


func _press_accept() -> void:
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)


func _wave_checks(main: Node, mode: CoopHunt, p1, p2) -> void:
	mode.lives[1]["protect"] = 9999.0
	mode.lives[2]["protect"] = 9999.0
	var counts: Array = []
	var total := 0
	var seat := 1
	for n in CoopHunt.WAVES.size():
		await _until(func(): return mode.phase == "wave" and mode.wave == n + 1 and mode._queue.is_empty())
		await _until(func(): return not mode.enemies.any(func(e): return is_instance_valid(e["body"]) and e["body"].climbing()))
		var standing := mode.standing()
		counts.append(standing)
		if n == 0:
			var solo := 0
			for k in CoopHunt.WAVES[0]:
				solo += int(CoopHunt.WAVES[0][k])
			_check("acceptance (waves for two): wave 1 forks in %d daemons, the solo wave's %d times %.1f, at the floor's far spots, every one hunting" % [standing, solo, CoopHunt.SCALE], standing == CoopHunt.wave_list(1).size() and standing > solo and mode.enemies.all(func(e): return e["body"].brain != null and not e["body"].brain.dormant))
		if n == CoopHunt.WAVES.size() - 1:
			var b := mode.boss()
			_check("acceptance: the last wave brings the boss (the pegged core, %d health for two) with its daemons" % int(CoopHunt.HEALTH["boss"]), b != null and b.is_alive() and is_equal_approx(b.max_health, CoopHunt.HEALTH["boss"]) and standing == CoopHunt.wave_list(n + 1).size())
		if n == 0:
			# Real shots first, each player aimed at a daemon: accuracy is hits over shots.
			for who in [p1, p2]:
				var mark = null
				for e in mode.enemies:
					if is_instance_valid(e["body"]) and e["body"].is_alive():
						mark = e["body"]
						break
				if mark != null:
					who.look_at(Vector3(mark.global_position.x, who.global_position.y, mark.global_position.z), Vector3.UP)
					who.get_node("Head").rotation.x = 0.0
				for i in 3:
					who.drive_input(Vector2.ZERO, false, false, true)
					await _frames(40)
		# Each kill landed by one player's weapon, turn about.
		while mode.standing() > 0:
			for e in mode.enemies:
				var body = e["body"]
				if is_instance_valid(body) and body.is_alive():
					var who = p1 if seat == 1 else p2
					who._strike(body, 100000.0, body.threat_point(), Vector3.FORWARD, "terminal_cannon")
					seat = 3 - seat
					total += 1
			await _frames(2)
	await _until(func(): return mode.phase == "results")
	total = 0
	for n in CoopHunt.WAVES.size():
		total += CoopHunt.wave_list(n + 1).size()
	var k1 := int(mode.per[1]["kills"])
	var k2 := int(mode.per[2]["kills"])
	_check("acceptance: a two-player run of every wave (%s) completes to the shared results card" % ", ".join(counts.map(func(c): return str(c))), mode.phase == "results" and bool(CoopHunt.stats.get("done", false)) and int(CoopHunt.stats["waves"]) == CoopHunt.WAVES.size())
	var lines := mode.result_lines()
	_check("acceptance: the card credits each player's own kills (p1 %d, p2 %d of %d, each from the player whose hit took it down, real shots and all) with each one's downs, revives and accuracy" % [k1, k2, total], k1 + k2 == total and absi(k1 - k2) <= 3 and lines[1].begins_with("p1 >_   kills %d" % k1) and lines[2].begins_with("p2 $_   kills %d" % k2) and lines[1].contains("accuracy") and lines[2].contains("revives"), " | ".join(lines))
	var acc_ok := true
	for s in [1, 2]:
		var p = p1 if s == 1 else p2
		var shots: int = p.shots_fired - int(mode.per[s]["shots0"])
		var hits: int = p.hits_landed - int(mode.per[s]["hits0"])
		acc_ok = acc_ok and mode.shots(s) == shots and is_equal_approx(mode.accuracy(s), float(hits) / float(shots) if shots > 0 else 0.0)
	_check("each player's accuracy is their own hits over their own shots this run (p1 %d of %d, p2 %d of %d)" % [p1.hits_landed - int(mode.per[1]["hits0"]), mode.shots(1), p2.hits_landed - int(mode.per[2]["hits0"]), mode.shots(2)], acc_ok and mode.shots(1) >= 3 and mode.shots(2) >= 3)
	var hud: CoopHud = mode.find_children("*", "CoopHud", true, false)[0]
	_check("the card is up over both tiles (the shared HUD in the results phase)", hud != null and mode.phase == "results")
	_press_accept()
	await _frames(4)


func _view_checks(main: Node, mode: CoopHunt, p1, p2) -> void:
	var screen := mode.screen
	var visor = main.get_node("AuditVisor")
	visor.toggle()
	await _frames(6)
	var vh = main.get_node("Hud").visor_hud()
	_check("acceptance: the visor (player 1's I) is drawn in player 1's tile only: its HUD inside that tile's view (reading that tile's camera), its lines on a layer only player 1's tile draws", vh != null and screen.port(1).is_ancestor_of(vh) and (screen.camera(1).cull_mask & CoopScreen.VISOR) != 0 and (screen.camera(2).cull_mask & CoopScreen.VISOR) == 0 and visor.on)
	visor.toggle()
	var b1 = mode._bodies[1]
	var b2 = mode._bodies[2]
	var own_ok: bool = (screen.camera(1).cull_mask & CoopScreen.BODY[1]) == 0 and (screen.camera(1).cull_mask & CoopScreen.BODY[2]) != 0 and (screen.camera(2).cull_mask & CoopScreen.BODY[2]) == 0 and (screen.camera(2).cull_mask & CoopScreen.BODY[1]) != 0
	var parts1: Array = b1.find_children("*", "MeshInstance3D", true, false)
	var parts2: Array = b2.find_children("*", "MeshInstance3D", true, false)
	var layered: bool = parts1.all(func(m): return m.layers == CoopScreen.BODY[1]) and parts2.all(func(m): return m.layers == CoopScreen.BODY[2])
	_check("acceptance (art): each player's body (%d and %d parts, its own figure) is seen only by the partner's tile, never its own; each tile draws its own weapon and not the partner's" % [parts1.size(), parts2.size()], own_ok and layered and parts1.size() >= 20 and parts2.size() >= 20 and parts1.size() != parts2.size() and (screen.camera(1).cull_mask & CoopScreen.GUN[2]) == 0 and (screen.camera(2).cull_mask & CoopScreen.GUN[1]) == 0)
	_check("the players never read as copies: each its own colour (teal, azure) and prompt (>_ and $_), and neither the dark copy's red", CoopScreen.COLOR[1] != CoopScreen.COLOR[2] and CoopScreen.PROMPT[1] != CoopScreen.PROMPT[2] and b1.hue != b2.hue and CoopScreen.COLOR[2].r < 0.5)


func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.coop_button()
	var plain_ok: bool = b != null and b.text == "Split-screen co-op" and not b.disabled and b.is_visible_in_tree()
	menu.close()
	FolderMap.queued = true
	ProcHunt.queued = true
	ThemeShift.queued = true
	KeybindGunplay.queued = true
	PacketTracer.queued = true
	menu.toggle_coop()
	var one: bool = CoopHunt.queued and not FolderMap.queued and not ProcHunt.queued and not ThemeShift.queued and not KeybindGunplay.queued and not PacketTracer.queued
	var old_id := main.get_instance_id()
	main = await _after_reload(old_id)
	var mode := CoopHunt.of(main)
	await _until(func(): return mode != null and mode.running)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.coop_button().text == "Leave split-screen co-op"
	var p2 = main.get_node_or_null("Player2")
	var blocked: bool = p2 != null and p2.input_blocked
	menu.close()
	await _frames(2)
	_check("acceptance: the Esc menu reaches it: \"Split-screen co-op\" in the free arena, \"Leave split-screen co-op\" while it runs (both players waiting while the menu is open); one world mode at a time (the hunt, the map, the theme shift, keybind gunplay and the packet tracer end as it begins)", plain_ok and leave_ok and one and mode.running and blocked)
	menu.toggle_coop()
	old_id = main.get_instance_id()
	main = await _after_reload(old_id)
	await _frames(4)
	var hud = main.get_node("Hud")
	_check("acceptance: leaving puts it all back: no second player, the window's own 3D view on, the arena's HUD whole, the arena's own daemons and keys", not CoopHunt.queued and main.get_node_or_null("Player2") == null and not main.get_viewport().disable_3d and not hud.coop_on() and hud.combat_hud().visible and _input_map() == _keys_before and DaemonDirector.of(main).prey_ids() == [1])
	# Ended where it stands (as a match starting would end it): everything it changed put back without a reload.
	CoopHunt.queue()
	main = await _arena(true)
	mode = CoopHunt.of(main)
	await _until(func(): return mode.running)
	await _frames(4)
	mode.end()
	await _frames(4)
	_check("ended where it stands, player 1 is as it was (its stick, its view, its abilities), the arena's four daemons back, the input map as before", not mode.running and main.get_node_or_null("Player2") == null and main.get_node("Player").stick_look and is_equal_approx(main.get_node("Player").view_tan, 1.0) and not main.get_node("Player").abilities_gated and not main.get_viewport().disable_3d and _input_map() == _keys_before and main.get_tree().get_nodes_in_group("targets").filter(func(n): return main.is_ancestor_of(n)).size() == 4)


## Every Window node under `node` (the root itself counted), by path.
func _windows(node: Node) -> int:
	var n := 1 if node is Window else 0
	for c in node.get_children(true):
		n += _windows(c)
	return n


func _cleanup() -> void:
	MissionRunner.clear_pending()
	_clear_modes()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	AuditVisor.remembered = false
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://coop-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir() and not dir.is_link(name):
			_wipe(full)
		else:
			DirAccess.remove_absolute(full)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()

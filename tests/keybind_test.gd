extends SceneTree
## Headless test of keybind gunplay (W4, PRD 5.5). scripts/check.sh runs it as step 68, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/keybind_test.gd
##
## Fixtures are fake only: the game's own built-in table, and for the real layer's reader made-up bind files the test
## writes under its own folder (fake binds, planted words in commands and comments that must never come out, a file too
## big to read, a file beside them that must never be opened). The real layer is never turned on in the mode.
##
## The code: nothing of the mode can call the compositor, send or make a key press, touch the input map, write, switch or
## run anything; only the reader touches a file, through the opener's capped read. The table: Omarchy's public defaults,
## credited; no Ctrl or Alt combo anywhere; every drill's chord resolves; the stand-in collides with no game key and is
## shown in conflict if a bind takes it; every card says what the table says. The reader: combos and names only, comments,
## commands and long lines never kept, a big file refused, unbinds and later binds honoured, Ctrl+Alt never playable. The
## mode: off by default (nothing read); queued, its district, the drills one by one with each shortcut's effect (a terminal
## blasting open, a window folding shut, a split, a float and its tile, full screen, a workspace), the chord holding the
## player and the game's own actions, the cards, cooldowns, the keys that only teach; the waves; the results card and
## Enter's again; the visor's windows; the Esc menu's entry, one world mode at a time; the arena's keys unchanged.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

const MODE_CODE := ["res://scripts/keys/keybind_gunplay.gd", "res://scripts/keys/key_book.gd", "res://scripts/keys/key_fx.gd", "res://scripts/keys/key_window.gd", "res://scripts/keys/keybind_hud.gd", "res://scripts/keys/key_reader.gd"]
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "move_to_trash", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "store_", "ResourceSaver", ".remove(", "remove_absolute", "rename", ".copy(", "copy_absolute", "make_dir", "create_link", "set_unix_permissions", "FileAccess.WRITE", "FileAccess.READ_WRITE", "FileAccess.WRITE_READ", "user://", "OS.crash", "omarchy-", "set_environment", "print(", "hyprctl", "hyprland", "parse_input_event", "Input.action_press", "Input.action_release", "warp_mouse", "InputMap", "clipboard_set", "dispatch"]
const READER := "res://scripts/keys/key_reader.gd"
const PLANT := "PLANTED-WORD-NEVER-READ"
const MOST_FRAMES := 3000
const LONG_ROUND_S := 100000.0
## Pinned here, so a changed constant cannot move its own check: Omarchy's meanings for the six drills, and their chords.
const DRILL_MEANINGS := {"terminal": "Terminal", "close": "Close window", "split": "Toggle window split", "float": "Toggle window floating/tiling", "fullscreen": "Full screen", "workspace": "Next workspace"}
const DRILL_CHORDS := {"terminal": "SUPER + RETURN", "close": "SUPER + W", "split": "SUPER + J", "float": "SUPER + T", "fullscreen": "SUPER + F", "workspace": "SUPER + TAB"}
const CREDIT := "Keybind gunplay (W4) teaches Omarchy's default key bindings"

var _fails := 0
var _checks := 0
var _abs := ""
var _keys_before := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://keybind-test-%d" % OS.get_process_id())
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
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_table_checks()
	_reader_checks()
	await _arena_checks()
	await _chord_checks()
	await _drill_checks()
	await _wave_checks()
	await _menu_checks()
	await _cleanup()
	print("KEYBIND GUNPLAY: %d checks" % _checks)
	print("KEYBIND GUNPLAY RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


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
	_check("acceptance (safety): nothing in the mode can call the compositor (no hyprctl, no dispatch), send or make a key press (no parse_input_event, no action_press, no warp), touch the input map, write, switch, run or signal anything, in any of its %d files" % MODE_CODE.size(), found.is_empty(), ", ".join(found))
	var touch := PackedStringArray()
	for path in MODE_CODE:
		if path != READER and (_code_of(path).contains("FileAccess") or _code_of(path).contains("DirAccess")):
			touch.append(path.get_file())
	var reader := _code_of(READER)
	var reads_ok: bool = reader.contains("RealOpenerData._read_small(file, LARGEST)") and not reader.contains("FileAccess.open") and not reader.contains("get_file_as") and reader.count("DirAccess.") == 2 and reader.contains("DirAccess.get_files_at(dir)") and reader.contains("DirAccess.dir_exists_absolute(dir)")
	_check("acceptance (safety): only the reader touches a file, and only through the opener's capped read (RealOpenerData._read_small at LARGEST); its one listing is a binds folder's file names, to find its files", touch.is_empty() and reads_ok, ", ".join(touch))
	var keeps_ok: bool = reader.contains("{\"combo\": m.get_string(1).strip_edges(), \"name\": clean(m.get_string(2))}") and reader.contains("{\"unbind\": u.get_string(1).strip_edges()}")
	_check("acceptance (privacy): the reader keeps a bind's combo and its description and nothing else of a line (never its command)", keeps_ok)


func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		var keep := line.substr(0, at) if at >= 0 else line
		out.append(keep)
	return "\n".join(out)


# --- The table (pure). ---

func _table_checks() -> void:
	var table := KeyBook.resolve()
	_check("acceptance: the built-in table is Omarchy's public default bindings, Super with one key: %d of them, each its own key" % KeyBook.DEFAULTS.size(), table.size() == KeyBook.DEFAULTS.size() and KeyBook.DEFAULTS.size() >= 30)
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	_check("acceptance: the shortcuts' source is credited and linked in CREDITS.md (Omarchy's default bindings, at the commit copied)", credits.contains(CREDIT) and credits.contains(KeyBook.SOURCE_URL) and KeyBook.SOURCE_URL.begins_with("https://github.com/basecamp/omarchy/"))
	var ctrl_alt := PackedStringArray()
	for d in KeyBook.DEFAULTS:
		var c := KeyBook.normal(d[0])
		if c.contains("CTRL") or c.contains("ALT"):
			ctrl_alt.append(c)
	for key in table:
		if str(table[key]["combo"]).contains("CTRL") or str(table[key]["combo"]).contains("ALT"):
			ctrl_alt.append(str(table[key]["combo"]))
	var refused := not KeyBook.playable(KeyBook.normal("SUPER + CTRL + ALT + T")) and not KeyBook.playable(KeyBook.normal("CTRL + ALT + DELETE")) and not KeyBook.playable(KeyBook.normal("SUPER + ALT + F"))
	_check("acceptance: no Ctrl+Alt combo anywhere: none in the table, none playable whatever a bind file says (no Ctrl or Alt chord at all)", ctrl_alt.is_empty() and refused, ", ".join(ctrl_alt))
	var drills_ok := true
	var notes := PackedStringArray()
	for id in DRILL_MEANINGS:
		var chord := KeyBook.chord_for(table, id)
		var code := KeyBook.keycode_of(chord)
		var e: Dictionary = table.get(code, {})
		var ok: bool = chord == DRILL_CHORDS[id] and code != KEY_NONE and str(e.get("weapon", "")) == id and str(e.get("meaning", "")) == DRILL_MEANINGS[id]
		drills_ok = drills_ok and ok
		notes.append("%s=%s" % [id, chord])
	_check("acceptance: every drill's binding resolves to its Omarchy chord and meaning (%s)" % ", ".join(notes), drills_ok and KeyBook.DRILLS.size() == DRILL_MEANINGS.size())
	var game := _game_keys()
	var problems := KeyBook.problems(table, game)
	_check("acceptance (no conflicts): the stand-in for Super (%s) is no key the game uses (%d keys checked: every action's bare keys, the fixed keys, the panels' own), no modifier and not Esc, and no chord sits on it or on Esc" % [KeyBook.STANDIN_SAID, game.size()], problems.is_empty() and not game.has(KeyBook.STANDIN), ", ".join(problems))
	var clash := Controls.conflicts({"audit_visor": Controls.KEY_PREFIX + str(KeyBook.STANDIN)})
	_check("and the game keeps it free: a bind put on it is shown in conflict with the stand-in (so no action can take it)", clash.has("audit_visor") and ", ".join(clash["audit_visor"]).contains("Super stand-in"))
	var cards_ok := true
	var bad := PackedStringArray()
	for d in KeyBook.DEFAULTS:
		var code := KeyBook.keycode_of(KeyBook.normal(d[0]))
		var c := KeyBook.card(table[code])
		var ok: bool = c["meaning"] == d[1] and c["combo"] == KeyBook.normal(d[0]) and (c["caps"] as PackedStringArray)[0] == "SUPER" and str(c["played"]).begins_with(KeyBook.STANDIN_NAME + " + ")
		ok = ok and (str(c["here"]) == KeyBook.NOT_HERE if KeyBook.weapon_of(d[1]) == "" else str(c["here"]) == str(KeyBook.WEAPONS[KeyBook.weapon_of(d[1])]["here"]))
		if not ok:
			bad.append(d[0])
		cards_ok = cards_ok and ok
	_check("acceptance: every card's text matches the built-in table: its chord, Omarchy's own meaning, what it does here (or that it only teaches), how it is played", cards_ok, ", ".join(bad))
	var never_ok := true
	for combo in ["SUPER + ESCAPE", "SUPER + grave", "SUPER + PRINT", "SUPER + SHIFT + W", "W", "CTRL + W", "ALT + W", "SUPER + mouse:272"]:
		never_ok = never_ok and not KeyBook.playable(KeyBook.normal(combo))
	_check("never a chord: Super with Esc (the menu's), with the stand-in, with Print (the desktop's), with Shift, with the mouse, a key alone, or a Ctrl or Alt chord", never_ok)


## Every key the game itself uses: every input action's keys, the fixed keys (but the stand-in's own entry), and the keys
## a panel or a question reads while it is up.
func _game_keys() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var k := ev as InputEventKey
				if k.ctrl_pressed or k.alt_pressed or k.meta_pressed or k.command_or_control_autoremap:
					continue  # a chord (a text box's own Ctrl+key): not the bare key the stand-in is
				out[int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)] = str(action)
	for code in Controls.FIXED_KEYS:
		if int(code) != KeyBook.STANDIN:
			out[int(code)] = Controls.FIXED_KEYS[code]
	for code in [KEY_H, KEY_J, KEY_K, KEY_L, KEY_N, KEY_P, KEY_Y]:
		out[code] = "a panel's own"
	return out


func _input_map() -> Dictionary:
	var out := {}
	for action in InputMap.get_actions():
		var evs := PackedStringArray()
		for ev in InputMap.action_get_events(action):
			evs.append(ev.as_text())
		out[str(action)] = evs
	return out


# --- The reader (pure, fixtures only). ---

func _reader_checks() -> void:
	var home := _abs.path_join("home")
	_write(home.path_join("defaults/tiling.lua"), "\n".join([
		"o.bind(\"SUPER + W\", \"Close window\", hl.dsp.window.close())",
		"o.bind(\"SUPER + F\", \"Full screen\", hl.dsp.window.fullscreen())",
		"o.bind(\"SUPER + J\", \"Toggle window split\", hl.dsp.layout(\"togglesplit\"))",
		"o.bind(\"SUPER + T\", \"Toggle window floating/tiling\", hl.dsp.window.float())",
		"o.bind(\"SUPER + TAB\", \"Next workspace\", hl.dsp.focus())",
		"o.bind(\"SUPER + RETURN\", \"Terminal\", { fake = \"" + PLANT + "\" })",
		"o.bind(\"SUPER + G\", \"Toggle window grouping\", hl.dsp.group.toggle())",
	]))
	_write(home.path_join("defaults/notes.txt"), "o.bind(\"SUPER + B\", \"" + PLANT + "\", \"x\")")
	_write(home.path_join("over.lua"), "\n".join([
		"-- o.bind(\"SUPER + B\", \"" + PLANT + " in a comment\", \"x\")",
		"hl.unbind(\"SUPER + W\")",
		"o.bind(\"SUPER + X\", \"Close window\", \"" + PLANT + " --flag\")",
		"o.bind(\"SUPER + CTRL + ALT + T\", \"Terminal\", \"" + PLANT + "\")",
		"o.bind(\"SUPER + Y\", nil, \"" + PLANT + "\")",
		"o.bind(\"SUPER + U\", \"Fake\u0001 helper\", \"x\")",
		"o.bind(\"SUPER + Z\", \"Too long a line\", \"" + "x".repeat(KeyReader.LINE_LONGEST) + "\")",
	]))
	_write(home.path_join("over.conf"), "\n".join([
		"# bindd = SUPER, B, " + PLANT + ", exec, x",
		"unbind = SUPER, F",
		"bindd = SUPER, H, Full screen, fullscreen, 0",
		"bind = SUPER, N, exec, " + PLANT,
	]))
	_write(home.path_join("big.lua"), "o.bind(\"SUPER + B\", \"Too big\", \"x\")\n" + "-- pad\n".repeat(KeyReader.LARGEST / 7 + 10))
	var reads := KeyReader.reads
	KeyReader.opened = PackedStringArray()
	var binds := KeyReader.read(home, PackedStringArray(["defaults/*.lua", "over.lua", "over.conf", "big.lua", "missing.lua"]))
	var keys_ok := true
	var planted := false
	for b in binds:
		for k in b:
			keys_ok = keys_ok and (k == "combo" or k == "name" or k == "unbind")
			planted = planted or str(b[k]).contains(PLANT) or str(b[k]).contains("hl.dsp") or str(b[k]).contains("fake")
	_check("acceptance (privacy): the reader keeps combos and action names only: no command, no dispatcher, nothing from a comment, from a line longer than %d characters or from a file over %d bytes; control characters dropped" % [KeyReader.LINE_LONGEST, KeyReader.LARGEST], keys_ok and not planted and binds.size() > 0 and not binds.any(func(b): return str(b.get("name", "")).contains("Too")) and binds.any(func(b): return str(b.get("name", "")) == "Fake helper"), str(binds.size()))
	_check("it opens only the files it is pointed at (a folder's .lua files, then each file): never the note beside them (\"%s\")" % ", ".join(KeyReader.opened), KeyReader.reads == reads + 1 and not KeyReader.opened.has("notes.txt") and KeyReader.opened.has("tiling.lua") and KeyReader.opened.has("over.lua") and KeyReader.opened.has("over.conf"))
	var table := KeybindGunplay.with_defaults(KeyBook.resolve(binds))
	var close := KeyBook.chord_for(table, "close")
	var full := KeyBook.chord_for(table, "fullscreen")
	var term := KeyBook.chord_for(table, "terminal")
	var ok: bool = close == "SUPER + X" and full == "SUPER + H" and term == "SUPER + RETURN" and not table.has(KEY_W) and not table.has(KEY_F) and not table.has(KEY_Y) and not table.has(KEY_N)
	_check("the player's own binds drive the drills: a later bind or an unbind wins (Close window moved to %s, Full screen to %s by an Omarchy 3 line), a nameless bind teaches nothing, a Ctrl+Alt one is never played" % [close, full], ok)
	var card := KeyBook.card(table[KEY_X])
	_check("and its card shows the player's own chord with Omarchy's meaning (\"%s  %s\")" % [card["combo"], card["meaning"]], card["combo"] == "SUPER + X" and card["meaning"] == "Close window" and card["played"] == "` + X")


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- The arena. ---

func _arena(queue_mode: bool) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	if queue_mode:
		KeybindGunplay.queue()
	else:
		KeybindGunplay.clear()
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
	var reads := KeyReader.reads
	var plain := await _arena(false)
	var m0 := KeybindGunplay.of(plain)
	await _frames(10)
	_check("acceptance: off by default: the mode stands in the arena, not running, no district of its own, no chord read, nothing read", m0 != null and not m0.running and RuinsWorld.of(plain) == null and KeyReader.reads == reads and m0.find_children("*", "KeybindHud", true, false).is_empty())
	var ev := _key_event(KeyBook.STANDIN, true)
	m0._input(ev)
	_check("and off, the stand-in is nothing: no chord held", not m0.chord and not KeybindGunplay.holding)
	KeybindGunplay.drill_s = 1000.0
	KeybindGunplay.wave_s = 1000.0
	var main := await _arena(true)
	var mode := KeybindGunplay.of(main)
	await _until(func(): return mode.running)
	await _frames(70)
	_check("acceptance (safety): the real layer is off by default: a demo run plays the built-in table and reads nothing", KeybindGunplay.layer == "demo" and KeyReader.reads == reads and KeybindGunplay.table.size() == KeyBook.DEFAULTS.size())
	_check("acceptance: queued (the Esc menu, or --keys), it begins in its own district, the desktop (a clean Tron hall), on its first drill", mode.running and mode.world != null and mode.world.ruins.id == KeybindGunplay.SET_ID and mode.world.register == "tron" and mode.phase == "drill" and mode.drill == 0)
	var asleep: bool = mode.enemies.size() == 3
	var ahead := true
	var player = main.get_node("Player")
	for e in mode.enemies:
		var body = e["body"]
		asleep = asleep and body.brain.dormant and body.has_meta(&"world") and body.has_meta(&"keys")
		var to: Vector3 = body.global_position - player.global_position
		ahead = ahead and to.dot(-player.global_basis.z) > 0.0
	_check("the first drill's daemons stand asleep before the player (%d), the world modes' kills (the credit cap applies)" % mode.enemies.size(), asleep and ahead)
	var windows := mode.find_children("*", "KeyWindow", true, false)
	var shared := true
	for w in windows:
		shared = shared and (w as KeyWindow).material.shader == windows[0].material.shader
	_check("the desktop: windows tiled round the sky (%d) and a pad at every workspace (%d), one shader for all of them" % [windows.size() - mode.workspace_at.size(), mode.workspace_at.size()], windows.size() >= 12 + KeybindGunplay.WORKSPACES and mode.workspace_at.size() == KeybindGunplay.WORKSPACES and shared)
	var lines := "\n".join(mode._hud.lines())
	_check("its panel: the mode, its table, the stand-in, the drill and what it asks, its chord (\"%s\")" % lines.replace("\n", " / "), lines.contains("KEYBIND GUNPLAY") and lines.contains("built-in shortcuts") and lines.contains("hold `") and lines.contains("DRILL 1 of 6") and lines.contains("SUPER + RETURN   Terminal"))


func _key_event(code: int, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.keycode = code as Key
	ev.pressed = pressed
	return ev


func _key(code: int, pressed: bool) -> void:
	Input.parse_input_event(_key_event(code, pressed))


## The player's view turned onto `body`.
func _face(main: Node, body: Node3D) -> void:
	var player = main.get_node("Player")
	var head: Node3D = player.get_node("Head")
	var cam := main.get_viewport().get_camera_3d()
	var to: Vector3 = body.threat_point() - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _chord(code: int) -> void:
	_key(KeyBook.STANDIN, true)
	await _frames(2)
	_key(code, true)
	await _frames(2)
	_key(code, false)
	_key(KeyBook.STANDIN, false)
	await _frames(2)


func _chord_checks() -> void:
	var main := current_scene
	var mode := KeybindGunplay.of(main)
	var player = main.get_node("Player")
	var yaw: float = player.rotation.y
	player.rotation.y = yaw + PI  # facing away from the drill's daemons: nothing under the crosshair
	await _frames(2)
	player.select_slot(1)
	await _frames(25)
	player.select_slot(0)
	await _frames(25)
	_key(KeyBook.STANDIN, true)
	await _frames(2)
	_key(KEY_Q, true)
	await _frames(3)
	_key(KEY_Q, false)
	await _frames(25)
	_check("and the game's own key events stay out of it: Q with the stand-in held is SUPER + Q (Close window), never the last-weapon swap", player.inventory.current == 0 and str(mode.card.get("combo", "")) == "SUPER + Q")
	var moved_to: Vector3 = player.global_position
	_key(KEY_SPACE, true)
	_key(KEY_W, true)
	await _frames(20)
	var still: bool = Vector2(player.global_position.x - moved_to.x, player.global_position.z - moved_to.z).length() < 0.02 and player.global_position.y - moved_to.y < 0.05
	var lines: PackedStringArray = mode._hud.card_lines()
	_key(KEY_TAB, true)
	await _frames(20)
	var top = main.get_node("Hud").get("_top")
	var top_hidden: bool = top != null and is_instance_valid(top) and top.get("_shown") == false
	_check("acceptance (no conflicts): while the stand-in is held the keys with it are the mode's: the player stands (W and Space held: no walk, no jump; Tab held: no top table) and looking stays free", mode.chord and player.chord_open and still and top_hidden and KeybindGunplay.holding)
	_key(KEY_W, false)
	_key(KEY_SPACE, false)
	_key(KEY_TAB, false)
	await _frames(2)
	_check("the chord's W was the mode's: its card says SUPER + W, Close window, and with nothing under the crosshair it says so and spends nothing (\"%s\")" % " / ".join(lines), lines.size() == 4 and lines[0] == "SUPER + W" and lines[1] == "Close window" and lines[2].contains("no window under the crosshair") and lines[3].begins_with("played: ` + W") and int(KeybindGunplay.stats["close"]["uses"]) == 0 and float(mode.cooling["close"]) == 0.0)
	_key(KeyBook.STANDIN, false)
	await _frames(2)
	var start: Vector3 = player.global_position
	_key(KEY_W, true)
	await _frames(20)
	var walked: bool = Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length() > 0.05
	_key(KEY_W, false)
	await _frames(2)
	_check("let go, the game's keys are the game's again: W walks", not mode.chord and not player.chord_open and walked and not KeybindGunplay.holding)
	await _chord(KEY_S)
	var c: Dictionary = mode.card
	_check("a shortcut that is no weapon here still teaches: SUPER + S shows \"Toggle scratchpad\" and that it is the desktop's, nothing fires, no cooldown", c.get("meaning", "") == "Toggle scratchpad" and c.get("here", "") == KeyBook.NOT_HERE and KeybindGunplay.seen.has("SUPER + S"))
	await _chord(KEY_B)
	_check("a chord with nothing in the table says so (SUPER + B)", str(mode.card.get("combo", "")) == "SUPER + B" and str(mode.card.get("meaning", "")) == "nothing on this chord")
	await _chord(KEY_K)
	var list_on: bool = mode.list_open
	await _chord(KEY_K)
	_check("SUPER + K, Omarchy's keybindings list, opens and closes the table on screen", list_on and not mode.list_open)
	var menu = main.get_node("Hud").pause_menu()
	_key(KeyBook.STANDIN, true)
	await _frames(2)
	_key(KEY_ESCAPE, true)
	await _frames(3)
	_key(KEY_ESCAPE, false)
	var esc_ok: bool = not mode.chord and menu.is_open()
	menu.close()
	_key(KeyBook.STANDIN, false)
	await _frames(3)
	_check("Esc is the menu's even mid-chord: the chord lets go and the menu opens", esc_ok and not player.chord_open)
	_check("the regular arena's keys never change: every action's binding as it was (%d actions)" % _keys_before.size(), _input_map() == _keys_before)
	# Back where the drill stood, facing its daemons, the workspace's cooldown waited out.
	mode.go_to_workspace(0)
	player.rotation.y = yaw
	player.velocity = Vector3.ZERO
	mode.cooling["workspace"] = 0.0
	mode.cooling["goto"] = 0.0
	await _frames(25)


func _drill_checks() -> void:
	var main := current_scene
	var mode := KeybindGunplay.of(main)
	var player = main.get_node("Player")
	# Terminal: a terminal blasting open where the player aims.
	var first: Node3D = mode.enemies[1]["body"]
	_face(main, first)
	await _frames(2)
	await _chord(KEY_ENTER)
	var blasts := mode.find_children("*", "", true, false).filter(func(n): return n is KeyFx.TerminalBlast)
	var opening: bool = false
	if not blasts.is_empty():
		await _frames(6)
		var b = blasts[0]
		opening = is_instance_valid(b) and b.window.scale.x > 0.3 and b.window.size.x > 2.0
	await _until(func(): return mode.phase == "done" or mode.drill > 0)
	_check("acceptance: SUPER + RETURN fires the terminal: a terminal window flies out opening as it goes and blasts on the daemons; the drill is learned", not blasts.is_empty() and opening and str(KeybindGunplay.stats["terminal"]["drill"]) == "done" and int(KeybindGunplay.stats["terminal"]["kills"]) >= 1)
	_check("its card the first time: SUPER + RETURN, Terminal, marked new", mode.card.is_empty() or str(mode.card.get("combo", "")) == "SUPER + RETURN" or KeybindGunplay.seen.has("SUPER + RETURN"))
	await _until(func(): return mode.phase == "drill" and mode.drill == 1)
	await _frames(70)
	# Close: the daemon under the crosshair folded shut.
	var target: Node3D = mode.enemies[0]["body"]
	_face(main, target)
	await _frames(2)
	var body: Node3D = target.get_node("Body")
	var rest_y := body.scale.y
	await _chord(KEY_W)
	await _frames(16)
	var folding: bool = is_instance_valid(target) and target.is_alive() and body.scale.y < rest_y * 0.6 and not mode.find_children("*", "", true, false).filter(func(n): return n is KeyFx.CloseFold).is_empty()
	await _until(func(): return mode.phase == "done" or mode.drill > 1)
	_check("acceptance: SUPER + W closes the daemon under the crosshair: a window round it folds shut (flat to a line mid-fold), and it is gone", folding and int(KeybindGunplay.stats["close"]["kills"]) >= 1 and str(KeybindGunplay.stats["close"]["drill"]) == "done")
	await _chord(KEY_W)
	_check("a weapon cools down: SUPER + W again at once shows its card cooling and does nothing", float(mode.card.get("cooling", 0.0)) > 0.0 and int(KeybindGunplay.stats["close"]["uses"]) == 1)
	await _until(func(): return mode.phase == "drill" and mode.drill == 2)
	await _frames(70)
	# Split.
	target = mode.enemies[0]["body"]
	_face(main, target)
	await _frames(2)
	await _chord(KEY_J)
	await _frames(20)
	var halves := 0
	for s in mode.find_children("*", "", true, false).filter(func(n): return n is KeyFx.SplitPane):
		halves += (s as Node).get("halves").size()
	await _until(func(): return mode.phase == "done" or mode.drill > 2)
	_check("acceptance: SUPER + J splits it: a seam down its middle, the window in two panes sliding apart", halves == 2 and str(KeybindGunplay.stats["split"]["drill"]) == "done")
	await _until(func(): return mode.phase == "drill" and mode.drill == 3)
	await _frames(70)
	# Float.
	target = mode.enemies[0]["body"]
	_face(main, target)
	await _frames(2)
	var ground := target.global_position.y
	await _chord(KEY_T)
	await _frames(50)
	var lifted: bool = is_instance_valid(target) and target.global_position.y > ground + 2.0
	await _until(func(): return mode.phase == "done" or mode.drill > 3)
	_check("acceptance: SUPER + T floats it in a window (lifted %s) and tiles it into the floor" % ("past 2 m" if lifted else "not"), lifted and str(KeybindGunplay.stats["float"]["drill"]) == "done")
	await _until(func(): return mode.phase == "drill" and mode.drill == 4)
	await _frames(70)
	# Full screen: every daemon on the screen.
	_face(main, mode.enemies[0]["body"])
	await _frames(2)
	var on := mode.on_screen().size()
	await _chord(KEY_F)
	var border := mode.full_t >= 0.0
	await _until(func(): return mode.phase == "done" or mode.drill > 4)
	_check("acceptance: SUPER + F goes full screen: a border thrown to the screen's edges, every daemon on the screen hit (%d in view)" % on, border and on >= 2 and int(KeybindGunplay.stats["fullscreen"]["hits"]) >= 2 and str(KeybindGunplay.stats["fullscreen"]["drill"]) == "done")
	await _until(func(): return mode.phase == "drill" and mode.drill == 5)
	await _frames(10)
	# Workspace: awake daemons; the player slides away.
	var awake: bool = mode.enemies.all(func(e): return not e["body"].brain.dormant)
	var before: Vector3 = player.global_position
	await _chord(KEY_TAB)
	var moved: bool = Vector2(player.global_position.x - mode.workspace_at[1].x, player.global_position.z - mode.workspace_at[1].z).length() < 0.3 and absf(player.global_position.y - mode.workspace_at[1].y - 0.9) < 0.2 and before.distance_to(player.global_position) > 5.0
	_check("acceptance: SUPER + TAB slides the player to the next workspace (the slide over the screen, workspace 2's pad); its drill's daemons come awake", awake and moved and mode.workspace == 1 and mode.slide_t >= 0.0 and str(KeybindGunplay.stats["workspace"]["drill"]) == "done")
	mode.visor.set_on(true)
	await _until(func(): return mode.phase == "wave")
	await _frames(70)
	var marks := 0
	for m in mode._marks.values():
		if is_instance_valid(m) and (m as Label3D).visible and (m as Label3D).no_depth_test and (m as Label3D).text.begins_with("window 0x"):
			marks += 1
	var through: bool = mode._lines.through_walls and mode._lines._line_mat.shader.code.contains("depth_test_disabled")
	_check("acceptance: under the visor (I) every daemon is a window, as the compositor lists its clients: its corners and \"window 0x..., its name, its workspace\" through walls (%d)" % marks, marks == mode.standing() and marks > 0 and mode._lines.drawn_lines == 8 * marks and through)
	mode.visor.set_on(false)
	await _frames(2)


func _wave_checks() -> void:
	var main := current_scene
	var mode := KeybindGunplay.of(main)
	_check("after the drills, the waves: the arena's kinds, awake, every shortcut live (%d standing)" % mode.standing(), mode.phase == "wave" and mode.wave == 0 and mode.standing() == KeybindGunplay.WAVES[0] and mode.enemies.all(func(e): return not e["body"].brain.dormant))
	KeybindGunplay.wave_s = mode.phase_time() + 0.05
	await _until(func(): return mode.wave == 1 and mode.phase == "wave")
	KeybindGunplay.wave_s = mode.phase_time() + 0.05
	await _until(func(): return mode.phase == "results")
	var rows: PackedStringArray = mode._hud.result_lines()
	var learned_all: bool = rows.size() == KeyBook.DRILLS.size() + 2 and rows[rows.size() - 1].contains("6 of 6 learned")
	_check("acceptance: the mode completes to its results card: a row a shortcut (its chord, Omarchy's meaning, uses, kills, its drill, learned) and the totals (\"%s\")" % rows[rows.size() - 1], mode.phase == "results" and learned_all and rows[1].begins_with("SUPER + RETURN") and rows[1].contains("Terminal") and rows[1].ends_with("yes"))
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	mode._unhandled_input(ev)
	await _frames(3)
	_check("Enter runs it again from its first drill", mode.phase == "drill" and mode.drill == 0 and str(KeybindGunplay.stats["terminal"]["drill"]) == "")
	KeybindGunplay.drill_s = KeybindGunplay.DRILL_S
	KeybindGunplay.wave_s = KeybindGunplay.WAVE_S


func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.keys_button()
	var plain_ok: bool = b != null and b.text == "Keybind gunplay" and not b.disabled and b.is_visible_in_tree()
	menu.close()
	FolderMap.queued = true
	ProcHunt.queued = true
	ThemeShift.queued = true
	menu.toggle_keybind_gunplay()
	var one: bool = KeybindGunplay.queued and not FolderMap.queued and not ProcHunt.queued and not ThemeShift.queued
	var old_id := main.get_instance_id()
	main = await _after_reload(old_id)
	var mode := KeybindGunplay.of(main)
	await _until(func(): return mode != null and mode.running)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.keys_button().text == "Leave keybind gunplay"
	menu.close()
	_check("acceptance: the Esc menu reaches it: \"Keybind gunplay\" in the free arena, \"Leave keybind gunplay\" while it runs; one world mode at a time (the hunt, the map and the theme shift end as it begins)", plain_ok and leave_ok and one and mode.running)
	menu.toggle_theme_shift()
	_check("and it ends as another world mode begins", not KeybindGunplay.queued and ThemeShift.queued)
	old_id = main.get_instance_id()
	main = await _after_reload(old_id)
	ThemeShift.clear()
	KeybindGunplay.clear()


func _cleanup() -> void:
	MissionRunner.clear_pending()
	ProcHunt.clear()
	FolderMap.clear()
	ThemeShift.clear()
	KeybindGunplay.clear()
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
	if not path.begins_with(ProjectSettings.globalize_path("user://keybind-test-")):
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

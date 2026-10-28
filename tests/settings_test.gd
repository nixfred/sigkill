extends SceneTree
## Headless settings test for SIGKILL (C16b). scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/settings_test.gd
##
## The settings screen end to end, against the five acceptance points of the C16b brief:
## (1) invert Y flips the pitch for the mouse and for a gamepad's right stick, through real
## input events into the real player; (2) every setting and key bind survives a save and a
## fresh load, from the model and from the screen itself, and the privacy answers in the
## same file survive both ways; (3) Ctrl+Alt (and every other Ctrl, Alt or Super chord, and
## Esc) is refused as a bind, from the model and from a real key press on the screen, and
## conflicts with other actions and with fixed keys are found and shown; (4) the defaults
## load, quietly, when the file is missing or damaged in any of a dozen ways, and the arena
## runs on them; (5) the menu stops only local input: a host and a joiner over ENet on
## 127.0.0.1 keep their clocks, state and combat going while a menu is open. Then: Esc still
## skips the boot screen, the menu opens on the player's own Esc and swallows game keys,
## each setting reaches what it drives, and the whole screen fits at 1280x720 and 1920x1080
## with only the key list scrolling (Law 17). Settings files live in a temporary folder;
## the player's own file is never read or written (a headless run has no settings path).
## Nothing outside this process is touched.

const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const CombatTuningScript = preload("res://scripts/net/combat_tuning.gd")
const Controls = preload("res://scripts/controls.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const PauseMenu = preload("res://scripts/hud/pause_menu.gd")
const Palette = preload("res://scripts/palette.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const RoundHud = preload("res://scripts/round/round_hud.gd")
const MainScene = preload("res://scenes/main.tscn")
const BootScene = preload("res://scenes/boot.tscn")
const WATCHDOG_MS := 10000
const CLIENT_OFFSET := Vector3(1000.0, 0.0, 0.0)
const STAND_Y := 0.95
## A clear line across the arena at z 15 (the weapon test's): no cover on it.
const LINE_Z := 15.0
const SOURCE_NEVER := ["OS.execute", "OS.create_process", "OS.kill", "OS.shell_open", "OS.get_environment", "OS.get_user", "execute_with_pipe", "StreamPeerTCP", "TCPServer", "HTTPRequest", "HTTPClient", "UDPServer", "PacketPeerUDP", "ENetMultiplayerPeer", "JSON", "RichTextLabel", "bbcode", "str_to_var", "bytes_to_var", "load(", "ResourceLoader"]
const SETTINGS_SOURCES := ["res://scripts/settings/settings_file.gd", "res://scripts/settings/game_settings.gd", "res://scripts/settings/settings_apply.gd", "res://scripts/hud/pause_menu.gd", "res://scripts/boot/guide_settings.gd"]
const PRIVACY_LINES := "[privacy]\nai_consent_source=\"claude\"\nai_consent=\"yes\"\n"

var _fails := 0
var _checks := 0
var _tmp := ""
var _arenas: Array = []
var _branches: Array = []


func _initialize() -> void:
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_tmp = OS.get_temp_dir().path_join("sigkill-settings-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_tmp):
		print("FAIL the test's temporary folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_tmp)
	Controls.ensure()
	_model_checks()
	_bind_checks()
	_persist_checks()
	_file_checks()
	_source_checks()
	await _corrupt_arena_checks()
	await _invert_checks()
	await _player_checks()
	await _menu_checks()
	await _hud_checks()
	await _layout_checks()
	await _boot_checks()
	await _match_checks()
	await _cleanup()
	for name in DirAccess.get_files_at(_tmp):
		DirAccess.remove_absolute(_tmp.path_join(name))
	DirAccess.remove_absolute(_tmp)
	print("SETTINGS: %d checks" % _checks)
	print("SETTINGS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The model: defaults, values, binds. ---

func _model_checks() -> void:
	var s := GameSettings.new()
	_check("the defaults are the game as it shipped: no invert, 1x sensitivity, the tuning's FOV and port, high quality (bloom, shadows, code rain), full volume, shake and the speed effect on, subtitles on, no binds changed", s.value("controls", "invert_y") == false and s.value("controls", "mouse_sensitivity") == 1.0 and s.value("video", "fov") == 0 and s.value("video", "window_mode") == "windowed" and s.value("video", "fps_cap") == 0 and s.value("video", "vsync") == true and s.quality() == {"bloom": true, "shadows": true, "code_rain": true} and s.value("audio", "master") == 1.0 and s.value("audio", "announcer") == 1.0 and s.value("hud", "crosshair_style") == "cross" and s.value("hud", "crosshair_color") == "mint" and s.value("hud", "colorblind") == false and s.value("hud", "screen_shake") and s.value("hud", "motion_blur") and s.value("hud", "subtitles") and s.value("multiplayer", "port") == 0 and s.value("multiplayer", "display_name") == "" and s.value("multiplayer", "net_stats") == false and s.binds().is_empty() and s.conflicts().is_empty())
	var current := GameSettings.current()
	_check("a headless run's settings have no path: the player's own file is never read or written", current.path == "" and current.last_load == "defaults" and not current.save())
	var refused := PackedStringArray()
	for c in [["video", "fov", 59], ["video", "fov", 121], ["video", "fov", 90.0], ["multiplayer", "port", 80], ["multiplayer", "port", 70000], ["video", "quality", "ultra"], ["video", "fps_cap", 61], ["controls", "invert_y", "yes"], ["controls", "mouse_sensitivity", NAN], ["controls", "mouse_sensitivity", "2"], ["hud", "crosshair_color", "red"], ["audio", "master", INF], ["nowhere", "x", 1], ["video", "nothing", 1]]:
		if s.set_value(c[0], c[1], c[2]):
			refused.append("%s/%s=%s" % c)
	_check("a value of the wrong type, out of range or not a choice is refused, and an unknown setting too", refused.is_empty(), ", ".join(refused))
	var taken := s.set_value("video", "fov", 95) and s.set_value("multiplayer", "port", 9123) and s.set_value("controls", "mouse_sensitivity", 9.0) and s.set_value("audio", "music", -1.0) and s.set_value("controls", "ads_sensitivity", 0.333333)
	_check("in-range values are taken; a float past its range is clamped and snapped to 0.01", taken and s.value("video", "fov") == 95 and s.value("multiplayer", "port") == 9123 and s.value("controls", "mouse_sensitivity") == 5.0 and s.value("audio", "music") == 0.0 and is_equal_approx(s.value("controls", "ads_sensitivity"), 0.33))
	_check("the display name is cleaned: letters, digits, spaces, - _ . only, spaces folded, at most 24", GameSettings.clean_name("  Neo <the> \"One\"\\\t\n  ") == "Neo the One" and GameSettings.clean_name("../../etc/passwd") == "....etcpasswd" and GameSettings.clean_name("x".repeat(40)).length() == 24 and GameSettings.clean_name("Daemon-1") == "Daemon-1" and GameSettings.clean_name(char(0x263A)) == "")
	var events := []
	s.changed.connect(func(section, key): events.append(section + "/" + key))
	s.set_value("hud", "colorblind", true)
	s.set_value("hud", "colorblind", true)
	s.reset()
	_check("changed fires once per real change, and once for a reset; reset is every default again", events == ["hud/colorblind", "/"] and s.value("hud", "colorblind") == false and s.value("video", "fov") == 0, str(events))
	_check("the quality presets: low has no bloom, shadows or code rain, medium no shadows, high everything", _three(GameSettings.PRESETS["low"]) == {"bloom": false, "shadows": false, "code_rain": false} and _three(GameSettings.PRESETS["medium"]) == {"bloom": true, "shadows": false, "code_rain": true} and _three(GameSettings.PRESETS["high"]) == {"bloom": true, "shadows": true, "code_rain": true})


func _bind_checks() -> void:
	var s := GameSettings.new()
	var ctrl_alt := _key_event(KEY_J, true, true)
	_check("acceptance 3: a Ctrl+Alt bind is refused, by name, and nothing changes", s.set_bind("jump", ctrl_alt) == Controls.CTRL_ALT_REFUSED and s.bind("jump") == Controls.default_bind("jump") and s.binds().is_empty())
	var ctrl_alt_mouse := InputEventMouseButton.new()
	ctrl_alt_mouse.button_index = MOUSE_BUTTON_MIDDLE
	ctrl_alt_mouse.ctrl_pressed = true
	ctrl_alt_mouse.alt_pressed = true
	ctrl_alt_mouse.pressed = true
	_check("a Ctrl+Alt mouse button is refused the same way", s.set_bind("fire", ctrl_alt_mouse) == Controls.CTRL_ALT_REFUSED and s.binds().is_empty())
	var chords := {
		"Ctrl+J": _key_event(KEY_J, true), "Alt+J": _key_event(KEY_J, false, true), "Super+J": _key_event(KEY_J, false, false, true),
		"Ctrl alone": _key_event(KEY_CTRL, true), "Alt alone": _key_event(KEY_ALT, false, true), "Super alone": _key_event(KEY_META, false, false, true),
		"Ctrl with no flag": _key_event(KEY_CTRL), "Ctrl+Alt+Super+Del": _key_event(KEY_DELETE, true, true, true),
	}
	var let_in := PackedStringArray()
	for name in chords:
		if s.set_bind("jump", chords[name]) == "":
			let_in.append(name)
	_check("every other Ctrl, Alt or Super chord, and the bare modifier keys, are refused", let_in.is_empty() and s.binds().is_empty(), ", ".join(let_in))
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	_check("Esc is the menu's and a pad button is not a bind: both refused", s.set_bind("jump", _key_event(KEY_ESCAPE)) == Controls.ESC_REFUSED and s.set_bind("jump", pad) == Controls.UNKNOWN_REFUSED and s.set_bind("release_mouse", _key_event(KEY_V)) == Controls.UNKNOWN_REFUSED and s.binds().is_empty())
	_check("a plain key is taken; binding the default again clears the bind", s.set_bind("jump", _key_event(KEY_V)) == "" and s.bind("jump") == "key:%d" % KEY_V and s.binds() == {"jump": "key:%d" % KEY_V} and s.set_bind("jump", _key_event(KEY_SPACE)) == "" and s.binds().is_empty())
	_check("no conflicts in the shipped binds", s.conflicts().is_empty())
	s.set_bind("jump", _key_event(KEY_W))
	var c := s.conflicts()
	_check("acceptance 3: a bind another action uses is a conflict for both", c.get("jump", []) == PackedStringArray(["move forward"]) and c.get("move_forward", []) == PackedStringArray(["jump"]) and c.size() == 2, str(c))
	s.set_bind("slide", _key_event(KEY_W))
	c = s.conflicts()
	_check("three on one key: each lists the other two", c.get("move_forward", []) == PackedStringArray(["jump", "slide"]) and c.get("slide", []) == PackedStringArray(["move forward", "jump"]), str(c))
	s.reset_binds()
	s.set_bind("reload", _key_event(KEY_UP))
	s.set_bind("crouch", _key_event(KEY_3))
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	s.set_bind("aim", wheel)
	c = s.conflicts()
	_check("fixed keys conflict too: an arrow, a weapon slot key, the wheel", c.get("reload", []) == PackedStringArray(["move forward (arrow)"]) and c.get("crouch", []) == PackedStringArray(["weapon slot 3"]) and c.get("aim", []) == PackedStringArray(["next weapon"]), str(c))
	s.reset_binds()
	_check("reset binds clears every bind and conflict", s.binds().is_empty() and s.conflicts().is_empty())
	Controls.apply_binds({"jump": "key:%d" % KEY_V, "fire": "mouse:%d" % MOUSE_BUTTON_XBUTTON1, "slide": "key:%d" % KEY_CTRL, "crouch": "nonsense"})
	var jump := InputMap.action_get_events("jump")
	var fire := InputMap.action_get_events("fire")
	var slide := InputMap.action_get_events("slide")
	var crouch := InputMap.action_get_events("crouch")
	var forward := InputMap.action_get_events("move_forward")
	_check("binds reach the input map; a refused or broken bind falls back to its default; the arrows stay beside the movement keys", jump.size() == 1 and (jump[0] as InputEventKey).physical_keycode == KEY_V and fire.size() == 1 and (fire[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_XBUTTON1 and (slide[0] as InputEventKey).physical_keycode == KEY_C and (crouch[0] as InputEventKey).physical_keycode == KEY_X and forward.size() == 2 and (forward[1] as InputEventKey).physical_keycode == KEY_UP)
	Controls.apply_binds({})
	_check("no binds: the shipped map again", (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_SPACE and (InputMap.action_get_events("fire")[0] as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	var chorded := PackedStringArray()
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			continue  # Godot's own text-editing actions, for its LineEdits; never a game key
		for event in InputMap.action_get_events(action):
			if event is InputEventWithModifiers and (event.ctrl_pressed or event.alt_pressed or event.meta_pressed):
				chorded.append(String(action))
			if event is InputEventKey and [KEY_CTRL, KEY_ALT, KEY_META].has((event as InputEventKey).physical_keycode):
				chorded.append(String(action))
	_check("no Ctrl, Alt or Super key or chord bound to any game action", chorded.is_empty(), ", ".join(chorded))
	_check("X crouches, the right mouse button aims, the right stick looks: new defaults on free inputs", Controls.default_bind("crouch") == "key:%d" % KEY_X and Controls.default_bind("aim") == "mouse:%d" % MOUSE_BUTTON_RIGHT and InputMap.has_action("look_up") and InputMap.has_action("look_down") and InputMap.has_action("look_left") and InputMap.has_action("look_right"))
	_check("bind labels read as keys and buttons", Controls.bind_label("key:%d" % KEY_W) == "W" and Controls.bind_label("mouse:%d" % MOUSE_BUTTON_RIGHT) == "right mouse" and Controls.bind_label("junk") == "none" and Controls.event_of("key:-5") == null and Controls.event_of("mouse:99") == null and Controls.event_of("key:%d" % KEY_ESCAPE) == null)


# --- The file: save, load, privacy beside it. ---

func _persist_checks() -> void:
	var path := _tmp.path_join("persist.cfg")
	var asked := Privacy.save("claude", true, path)
	var a := GameSettings.new()
	a.path = path
	var changes := [["controls", "invert_y", true], ["controls", "mouse_sensitivity", 1.75], ["controls", "ads_sensitivity", 0.5], ["controls", "crouch_mode", "toggle"], ["controls", "aim_mode", "toggle"], ["video", "window_mode", "borderless"], ["video", "resolution_scale", 0.75], ["video", "fps_cap", 144], ["video", "vsync", false], ["video", "fov", 100], ["video", "quality", "medium"], ["audio", "master", 0.4], ["audio", "effects", 0.55], ["audio", "music", 0.0], ["audio", "announcer", 0.9], ["hud", "crosshair_style", "circle"], ["hud", "crosshair_color", "magenta"], ["hud", "colorblind", true], ["hud", "screen_shake", false], ["hud", "motion_blur", false], ["hud", "subtitles", false], ["multiplayer", "display_name", "Neo"], ["multiplayer", "port", 9123], ["multiplayer", "net_stats", true], ["gameplay", "difficulty", "hard"], ["gameplay", "practice", true]]
	var all_set := true
	for c in changes:
		all_set = all_set and a.set_value(c[0], c[1], c[2])
	a.set_bind("jump", _key_event(KEY_V))
	var side := InputEventMouseButton.new()
	side.button_index = MOUSE_BUTTON_XBUTTON1
	side.pressed = true
	a.set_bind("fire", side)
	_check("every setting changed from its default, two binds changed, and saved", asked and all_set and a.save())
	var b := GameSettings.new()
	b.path = path
	var how := b.load_file()
	var differ := PackedStringArray()
	for section in GameSettings.SCHEMA:
		for key in GameSettings.SCHEMA[section]:
			if typeof(a.value(section, key)) != typeof(b.value(section, key)) or a.value(section, key) != b.value(section, key):
				differ.append("%s/%s" % [section, key])
	_check("acceptance 2: a fresh load reads back every setting, value and type, and both binds", how == "loaded" and differ.is_empty() and b.binds() == a.binds() and b.binds().size() == 2, "%s %s" % [how, ", ".join(differ)])
	_check("the privacy answer in the same file survived the settings' save", Privacy.answer_for("claude", path) == Privacy.Answer.ALLOWED and not Privacy.roast_on(path) and Privacy.real_data_on(path))
	var roast_saved := Privacy.save_roast(true, path) and Privacy.save_real_data(false, path) and Privacy.save("claude", false, path)
	var c2 := GameSettings.new()
	c2.path = path
	c2.load_file()
	_check("and the other way: saving each privacy answer keeps every setting", roast_saved and c2.value("video", "fov") == 100 and c2.value("multiplayer", "display_name") == "Neo" and c2.binds() == a.binds() and Privacy.roast_on(path) and not Privacy.real_data_on(path) and Privacy.answer_for("claude", path) == Privacy.Answer.DECLINED)
	var text := FileAccess.get_file_as_string(path)
	_check("one ConfigFile, versioned: [meta] version=1, the privacy answers, every section, plain values only", text.contains("[meta]\n\nversion=1") and text.contains("[privacy]") and text.contains("[controls]") and text.contains("[binds]") and text.contains("[multiplayer]") and text.contains("display_name=\"Neo\"") and text.contains("real_machine_data=\"off\"") and not text.contains("(") and not text.contains("{"), text.c_escape().left(300))
	_check("nothing is written into the project or to a relative path", not SettingsFile.write_sections("res://settings.cfg", {"video": {"vsync": true}}) and not SettingsFile.write_sections("settings.cfg", {"video": {"vsync": true}}) and not SettingsFile.write_sections("/tmp/../etc/x.cfg", {"video": {"vsync": true}}) and not FileAccess.file_exists("res://settings.cfg"))
	var kept_path := _tmp.path_join("kept-old-value.cfg")
	var k := FileAccess.open(kept_path, FileAccess.WRITE)
	k.store_string("ai_consent_source=claude\nai_consent=yes\nroast_announcer=o\"n\n")
	k.close()
	var kept := GameSettings.new()
	kept.path = kept_path
	kept.load_file()
	kept.set_value("hud", "subtitles", false)
	_check("an old file's unreadable value (a quote) is left out of the next save instead of blocking it", kept.save() and Privacy.answer_for("claude", kept_path) == Privacy.Answer.ALLOWED and not Privacy.roast_on(kept_path) and not FileAccess.get_file_as_string(kept_path).contains("o\"n"))
	_check("a value the file could not read back is never written: quotes, backslashes, objects", not SettingsFile.write_sections(path, {"hud": {"x": "a\"b"}}) and not SettingsFile.write_sections(path, {"hud": {"x": "a\\b"}}) and not SettingsFile.write_sections(path, {"hud": {"x": Color.RED}}) and not SettingsFile.write_sections(path, {"hud": {"x": INF}}) and FileAccess.get_file_as_string(path) == text)


func _file_checks() -> void:
	var fresh := GameSettings.new()
	var missing := GameSettings.new()
	missing.path = _tmp.path_join("never-written.cfg")
	_check("acceptance 4: no file: every default, quietly", missing.load_file() == "missing" and _same(missing, fresh))
	var v1 := "[meta]\nversion=1\n" + PRIVACY_LINES
	var damaged := {
		"binary": PackedByteArray([0x5B, 0x6D, 0x00, 0xFF, 0x0A]),
		"a Color": (v1 + "[hud]\ncrosshair_color=Color(1, 0, 0, 1)\n").to_ascii_buffer(),
		"an Object": (v1 + "[controls]\ninvert_y=Object(Node,\"script\":null)\n").to_ascii_buffer(),
		"a Resource": (v1 + "[video]\nquality=Resource(\"res://scripts/main.gd\")\n").to_ascii_buffer(),
		"a dictionary": (v1 + "[audio]\nmaster={\"a\": 1}\n").to_ascii_buffer(),
		"a list": (v1 + "[audio]\nmaster=[1, 2]\n").to_ascii_buffer(),
		"a bare word": (v1 + "[video]\nquality=low\n").to_ascii_buffer(),
		"an escaped quote": (v1 + "[multiplayer]\ndisplay_name=\"a\\\"b\"\n").to_ascii_buffer(),
		"a key twice": (v1 + "[video]\nvsync=false\nvsync=true\n").to_ascii_buffer(),
		"a section twice": (v1 + "[video]\nvsync=false\n[video]\nfps_cap=60\n").to_ascii_buffer(),
		"half a section name": (v1 + "[video\nvsync=false\n").to_ascii_buffer(),
		"no version": (PRIVACY_LINES + "[video]\nvsync=false\n").to_ascii_buffer(),
		"a newer version": ("[meta]\nversion=99\n" + PRIVACY_LINES + "[video]\nvsync=false\n").to_ascii_buffer(),
		"a version that is text": ("[meta]\nversion=\"1\"\n" + PRIVACY_LINES).to_ascii_buffer(),
		"oversized": (v1 + ";" + "x".repeat(5000) + "\n[video]\nvsync=false\n").to_ascii_buffer(),
		"a key before any section": ("vsync=false\n[meta]\nversion=1\n" + PRIVACY_LINES).to_ascii_buffer(),
		"a line with no =": (v1 + "[video]\nvsync\n").to_ascii_buffer(),
		"a capital key": (v1 + "[video]\nVsync=false\n").to_ascii_buffer(),
		"a control byte": (v1 + "[video]\nvsync=false" + char(1) + "\n").to_ascii_buffer(),
	}
	var let_in := PackedStringArray()
	for name in damaged:
		var file_path := _tmp.path_join("damaged-%d.cfg" % let_in.size() + name.md5_text().left(6) + ".cfg")
		var f := FileAccess.open(file_path, FileAccess.WRITE)
		f.store_buffer(damaged[name])
		f.close()
		var s := GameSettings.new()
		s.path = file_path
		if s.load_file() != "unreadable" or not _same(s, fresh) or Privacy.answer_for("claude", file_path) != Privacy.Answer.NOT_ASKED or not SettingsFile.read(file_path).is_empty():
			let_in.append(name)
	_check("acceptance 4: a damaged file gives every default and counts the AI as never asked, quietly: binary, a Color, an Object, a Resource, a dictionary, a list, a bare word, an escaped quote, a key twice, a section twice, half a section name, no version, a newer version, a text version, oversized, a key before any section, a line with no =, a capital key, a control byte", let_in.is_empty(), ", ".join(let_in))
	var mixed_path := _tmp.path_join("mixed.cfg")
	var m := FileAccess.open(mixed_path, FileAccess.WRITE)
	m.store_string(v1 + "[video]\nfov=500\nvsync=false\nquality=\"ultra\"\nfps_cap=60\n[controls]\ninvert_y=\"yes\"\nmouse_sensitivity=2\n[binds]\njump=\"key:%d\"\nfire=\"key:%d\"\nslide=\"mouse:99\"\nnot_an_action=\"key:%d\"\n" % [KEY_V, KEY_CTRL, KEY_V])
	m.close()
	var mixed := GameSettings.new()
	mixed.path = mixed_path
	_check("a readable file with a few bad values keeps the good ones and defaults the rest, binds too", mixed.load_file() == "loaded" and mixed.value("video", "fov") == 0 and mixed.value("video", "vsync") == false and mixed.value("video", "quality") == "high" and mixed.value("video", "fps_cap") == 60 and mixed.value("controls", "invert_y") == false and mixed.value("controls", "mouse_sensitivity") == 2.0 and mixed.binds() == {"jump": "key:%d" % KEY_V}, str(mixed.binds()))
	var old_path := _tmp.path_join("before-c16b.cfg")
	var o := FileAccess.open(old_path, FileAccess.WRITE)
	o.store_string("# SIGKILL settings: the answer to the AI opt-in and the roast announcer switch.\nai_consent_source=claude\nai_consent=yes\nroast_announcer=on\n")
	o.close()
	var old := GameSettings.new()
	old.path = old_path
	var old_how := old.load_file()
	_check("the file from before C16b still reads: its privacy answers carry over, every setting is a default", old_how == "old" and _same(old, fresh) and Privacy.answer_for("claude", old_path) == Privacy.Answer.ALLOWED and Privacy.roast_on(old_path) and Privacy.real_data_on(old_path))
	old.set_value("hud", "subtitles", false)
	var migrated := old.save()
	var text := FileAccess.get_file_as_string(old_path)
	var again := GameSettings.new()
	again.path = old_path
	_check("its first save writes version 1 and keeps the answers", migrated and text.contains("version=1") and text.contains("ai_consent=\"yes\"") and text.contains("roast_announcer=\"on\"") and again.load_file() == "loaded" and again.value("hud", "subtitles") == false and Privacy.answer_for("claude", old_path) == Privacy.Answer.ALLOWED and Privacy.roast_on(old_path))
	_check("an empty file is the defaults too", _write_and_load("empty.cfg", "") and true)


func _write_and_load(name: String, text: String) -> bool:
	var file_path := _tmp.path_join(name)
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var s := GameSettings.new()
	s.path = file_path
	s.load_file()
	return _same(s, GameSettings.new()) and Privacy.answer_for("claude", file_path) == Privacy.Answer.NOT_ASKED


func _source_checks() -> void:
	var found := PackedStringArray()
	for path in SETTINGS_SOURCES:
		var code := _code(path)
		for word in SOURCE_NEVER:
			if code.contains(word) and not (word == "load(" and (code.contains("load_file(") or code.contains("preload("))) :
				# load( appears only as load_file( or preload( in these files
				var stripped := code.replace("load_file(", "").replace("preload(", "").replace("load_threaded", "")
				if word != "load(" or stripped.contains("load("):
					found.append("%s: %s" % [path.get_file(), word])
	_check("the settings code runs nothing, opens no socket, parses no JSON or rich text and loads no resource or script from data", found.is_empty(), ", ".join(found))
	var store := _code("res://scripts/settings/settings_file.gd")
	_check("the file is scanned line by line before ConfigFile ever sees it, and the scan refuses constructors, lists and dictionaries", store.find("literal.search(value) == null") > 0 and store.find("literal.search(value) == null") < store.find("config.parse(text)") and not GameSettings.SCHEMA.is_empty())
	var menu := _code("res://scripts/hud/pause_menu.gd")
	_check("the menu keeps no privacy state of its own: AI is O's toggle, roast is B's, real data is the privacy answer", menu.contains("guide.toggle_ai()") and menu.contains("round_hud.toggle_roast()") and menu.contains("Privacy.save_real_data(on, link.settings_path)") and not menu.contains("save_roast") and not menu.contains("set_consent") and not menu.contains("Privacy.save("))
	_check("the menu never pauses the tree", not menu.contains("paused") and not _code("res://scripts/hud.gd").contains("paused") and not _code("res://scripts/player.gd").contains("paused"))


# --- The arena on a damaged file. ---

func _corrupt_arena_checks() -> void:
	var bad := _tmp.path_join("arena-damaged.cfg")
	var f := FileAccess.open(bad, FileAccess.WRITE)
	f.store_string("[meta]\nversion=1\n[video]\nfov=Object(Node)\n")
	f.close()
	var current := GameSettings.current()
	current.path = bad
	var how := current.load_file()
	var arena := await _arena()
	await _frames(30)
	var cam: Camera3D = arena["player"].get_node("Head/Camera")
	_check("acceptance 4: the arena loads and runs on the defaults when the settings file is damaged", how == "unreadable" and is_equal_approx(cam.fov, 80.0) and arena["player"].standard_fov() == 80.0 and arena["main"].is_inside_tree())
	current.path = ""
	current.reset()
	_drop(arena)


# --- Acceptance 1: invert Y. ---

func _invert_checks() -> void:
	var arena := await _arena()
	var p: Node = arena["player"]
	var s := GameSettings.current()
	await _level(p)
	await _mouse(Vector2(0.0, 40.0))
	var mouse_normal: float = p.view_pitch()
	s.set_value("controls", "invert_y", true)
	await _level(p)
	await _mouse(Vector2(0.0, 40.0))
	var mouse_inverted: float = p.view_pitch()
	_check("acceptance 1: invert Y flips the mouse's pitch: the same motion looks down, then up, by the same angle", mouse_normal < -0.05 and mouse_inverted > 0.05 and is_equal_approx(mouse_normal, -mouse_inverted), "%.4f then %.4f" % [mouse_normal, mouse_inverted])
	s.set_value("controls", "invert_y", false)
	await _level(p)
	var yaw0: float = p.rotation.y
	await _stick(Vector2(0.4, 1.0), 12)
	var stick_normal: float = p.view_pitch()
	var yaw_normal: float = p.rotation.y - yaw0
	s.set_value("controls", "invert_y", true)
	await _level(p)
	yaw0 = p.rotation.y
	await _stick(Vector2(0.4, 1.0), 12)
	var stick_inverted: float = p.view_pitch()
	var yaw_inverted: float = p.rotation.y - yaw0
	_check("acceptance 1: invert Y flips the right stick's pitch too, through real pad events, and leaves its yaw alone", stick_normal < -0.05 and stick_inverted > 0.05 and absf(stick_normal + stick_inverted) < 0.02 and yaw_normal < -0.01 and absf(yaw_normal - yaw_inverted) < 0.01, "pitch %.4f then %.4f, yaw %.4f and %.4f" % [stick_normal, stick_inverted, yaw_normal, yaw_inverted])
	await _level(p)
	p.look_with_stick(Vector2(0.0, 1.0), 0.1)
	var hook_inverted: float = p.view_pitch()
	s.set_value("controls", "invert_y", false)
	await _level(p)
	p.look_with_stick(Vector2(0.0, 1.0), 0.1)
	_check("the stick at full tilt turns 150 degrees a second, flipped by invert Y", is_equal_approx(p.view_pitch(), -deg_to_rad(15.0)) and is_equal_approx(hook_inverted, deg_to_rad(15.0)), "%.4f %.4f" % [p.view_pitch(), hook_inverted])
	s.reset()
	_drop(arena)


# --- What each setting does to the player. ---

func _player_checks() -> void:
	var arena := await _arena()
	var p: Node = arena["player"]
	var s := GameSettings.current()
	var cam: Camera3D = p.get_node("Head/Camera")
	await _level(p)
	await _mouse(Vector2(0.0, 20.0))
	var at_one: float = p.view_pitch()
	s.set_value("controls", "mouse_sensitivity", 2.0)
	await _level(p)
	await _mouse(Vector2(0.0, 20.0))
	_check("mouse sensitivity multiplies the turn: 2x turns twice as far", is_equal_approx(p.view_pitch(), at_one * 2.0), "%.5f vs %.5f" % [p.view_pitch(), at_one])
	Input.action_press("aim")
	await _frames(60)
	var aimed: bool = p.is_aiming()
	var ads_fov := cam.fov
	await _level(p)
	await _mouse(Vector2(0.0, 20.0))
	var ads_pitch: float = p.view_pitch()
	Input.action_release("aim")
	await _frames(60)
	_check("aim (right mouse, held) narrows the view to 0.7 of it and turns at the aim sensitivity, not the mouse's", aimed and absf(ads_fov - 56.0) < 0.5 and is_equal_approx(ads_pitch, at_one * 0.7) and not p.is_aiming() and absf(cam.fov - 80.0) < 0.5, "fov %.2f pitch %.5f" % [ads_fov, ads_pitch])
	s.set_value("controls", "aim_mode", "toggle")
	await _tap_action("aim")
	var toggled_on: bool = p.is_aiming()
	await _frames(5)
	var still_on: bool = p.is_aiming()
	await _tap_action("aim")
	_check("aim as a toggle: a tap aims and stays aimed, a second tap stops", toggled_on and still_on and not p.is_aiming())
	await _home(p)
	Input.action_press("crouch")
	await _frames(60)
	var crouched: bool = p.is_crouching()
	var head_y: float = p.get_node("Head").position.y
	Input.action_press("move_forward")
	await _frames(30)
	var crouch_speed: float = p.horizontal_speed()
	Input.action_release("crouch")
	await _frames(20)
	var walk_speed: float = p.horizontal_speed()
	Input.action_release("move_forward")
	await _frames(30)
	_check("crouch (X, held) lowers the view to the crouch height and holds the pace to 3.5 m/s; letting go walks at 7 again", crouched and absf(head_y - 0.35) < 0.02 and absf(crouch_speed - 3.5) < 0.05 and absf(walk_speed - 7.0) < 0.05 and not p.is_crouching(), "head %.3f, %.2f then %.2f m/s" % [head_y, crouch_speed, walk_speed])
	s.set_value("controls", "crouch_mode", "toggle")
	await _tap_action("crouch")
	var crouch_on: bool = p.is_crouching()
	await _frames(5)
	await _tap_action("crouch")
	_check("crouch as a toggle: a tap crouches, a second tap stands", crouch_on and not p.is_crouching())
	p.input_blocked = true
	await _tap_action("crouch")
	var blocked_toggle: bool = p.is_crouching()
	p.input_blocked = false
	await _frames(2)
	await _tap_action("crouch")
	_check("no crouch while input is stopped (the menu); a toggled one is kept until the player is back", not blocked_toggle and p.is_crouching())
	await _tap_action("crouch")
	s.set_value("video", "fov", 100)
	await _frames(60)
	var wide := cam.fov
	s.set_value("video", "fov", 0)
	await _frames(60)
	_check("the field of view setting replaces the tuning's at rest; 0 is the tuning's own", absf(wide - 100.0) < 0.3 and absf(cam.fov - 80.0) < 0.3 and p.standard_fov() == 80.0, "%.2f then %.2f" % [wide, cam.fov])
	await _home(p)
	await _settle(p, 0.5)
	await _fire(p)
	await _frames(2)
	var jolt: Vector2 = p.shake_offset()
	var cam_still := cam.position.is_zero_approx()
	s.set_value("hud", "screen_shake", false)
	await _settle(p, 0.5)
	await _fire(p)
	await _frames(2)
	_check("screen shake: a shot jolts the picture (camera offset, never the camera's place or aim); off, none", jolt.length() > 0.000001 and cam_still and p.shake_offset().is_zero_approx(), "%s" % jolt)
	var bob_off := await _walk_bob(p)
	s.set_value("hud", "screen_shake", true)
	var bob_on := await _walk_bob(p)
	_check("screen shake off also stops the head bob while running", bob_off < 0.0001 and bob_on > 0.005, "%.5f vs %.5f" % [bob_off, bob_on])
	var kick_on := await _slide_fov(p)
	s.set_value("hud", "motion_blur", false)
	var kick_off := await _slide_fov(p)
	_check("motion blur: the view stretches wider in a slide; off, it stays at rest", kick_on > 82.0 and kick_off < 80.3, "%.2f vs %.2f" % [kick_on, kick_off])
	var buses := [p.get("_fire_sfx").bus, p.get("_hit_sfx").bus, p.get("_reload_sfx").bus]
	_check("the weapons' sounds play on the Effects bus", buses == [&"Effects", &"Effects", &"Effects"], str(buses))
	s.reset()
	_drop(arena)


# --- The menu: Esc, swallowing, saving, rebinding, privacy. ---

func _menu_checks() -> void:
	var arena := await _arena()
	var p: Node = arena["player"]
	var hud: Node = arena["main"].get_node("Hud")
	var menu: PauseMenu = hud.pause_menu()
	var s := GameSettings.current()
	await _key(KEY_ESCAPE)
	_check("Esc in the arena opens the menu: the player's input is stopped, nothing is paused, Resume has the focus for keys and pads", menu.is_open() and not menu.showing_settings() and p.input_blocked and not paused and menu._resume.has_focus())
	var slot_before: int = p.inventory.current
	await _key(KEY_M)
	await _key(KEY_T)
	await _key(KEY_2)
	await _key(KEY_B)
	var link = hud.guide().session_link()
	_check("with the menu open no game key acts behind it: M, T, 2 and B do nothing", not hud.net_hud().is_open() and not hud.guide().is_typing() and p.inventory.current == slot_before and not link.roast_on())
	await _key(KEY_ESCAPE)
	_check("Esc closes it again and gives the player input back", not menu.is_open() and not p.input_blocked)
	hud.net_hud().toggle()
	await _key(KEY_ESCAPE)
	_check("Esc that closes the multiplayer panel is the panel's: the menu stays shut", not hud.net_hud().is_open() and not menu.is_open())
	s.path = _tmp.path_join("menu.cfg")
	hud.open_menu()
	menu.open_settings()
	await _frames(2)
	menu._rows["controls/invert_y"]["widget"].button_pressed = true
	menu._rows["controls/mouse_sensitivity"]["widget"].value = 2.5
	menu._rows["video/quality"]["widget"].item_selected.emit(0)
	menu._rows["hud/crosshair_style"]["widget"].item_selected.emit(1)
	menu._name.text_changed.emit("Neo <b>")
	menu._port.value = 9200
	menu._fov.value = 90
	await _frames(2)
	_check("the screen's own widgets set the settings, the name cleaned as it is typed", s.value("controls", "invert_y") == true and s.value("controls", "mouse_sensitivity") == 2.5 and s.value("video", "quality") == "low" and s.value("hud", "crosshair_style") == "dot" and s.value("multiplayer", "display_name") == "Neo b" and s.value("multiplayer", "port") == 9200 and s.value("video", "fov") == 90)
	await _key(KEY_ESCAPE)
	var reread := GameSettings.new()
	reread.path = s.path
	_check("acceptance 2: leaving the settings screen saves, says so on the menu, and a fresh load reads it all back", menu.is_open() and not menu.showing_settings() and menu.status_text() == PauseMenu.SAVED_LINE and menu._pause_note.text.ends_with("\n" + PauseMenu.SAVED_LINE) and reread.load_file() == "loaded" and reread.value("controls", "invert_y") == true and reread.value("controls", "mouse_sensitivity") == 2.5 and reread.value("video", "quality") == "low" and reread.value("multiplayer", "display_name") == "Neo b" and reread.value("multiplayer", "port") == 9200 and reread.value("video", "fov") == 90, menu.status_text())
	menu.open_settings()
	menu.begin_rebind("jump")
	var capturing := menu.is_capturing()
	await _key(KEY_J, true, true)
	_check("acceptance 3: on the screen, Ctrl+Alt+J pressed for jump is refused and says why; jump keeps Space", capturing and not menu.is_capturing() and menu.status_text() == Controls.CTRL_ALT_REFUSED and s.bind("jump") == Controls.default_bind("jump") and (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_SPACE, menu.status_text())
	menu.begin_rebind("jump")
	await _key(KEY_ALT, false, true)
	_check("a bare Alt pressed for a bind is refused too", menu.status_text() == Controls.CHORD_REFUSED and s.binds().is_empty())
	menu.begin_rebind("jump")
	await _key(KEY_ESCAPE)
	_check("Esc while listening cancels the bind, and the screen stays up", not menu.is_capturing() and menu.showing_settings() and s.binds().is_empty())
	menu.begin_rebind("jump")
	await _key(KEY_W)
	var clash: String = menu._keys["jump"]["clash"].text
	var other: String = menu._keys["move_forward"]["clash"].text
	_check("acceptance 3: W for jump is taken and the conflict is shown on both rows and in the status line", s.bind("jump") == "key:%d" % KEY_W and clash == "also move forward" and other == "also jump" and menu.status_text().contains("conflict: also move forward") and (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_W, "%s | %s | %s" % [clash, other, menu.status_text()])
	menu.begin_rebind("reload")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	mouse.pressed = true
	Input.parse_input_event(mouse)
	await _frames(2)
	var up := mouse.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)
	_check("a mouse button can be a bind, from a real click on the screen", s.bind("reload") == "mouse:%d" % MOUSE_BUTTON_MIDDLE and menu._keys["reload"]["button"].text == "middle mouse")
	menu._on_reset_keys()
	_check("reset keys puts every key back", s.binds().is_empty() and menu._keys["jump"]["clash"].text == "" and (InputMap.action_get_events("jump")[0] as InputEventKey).physical_keycode == KEY_SPACE)
	var ai_before: bool = link.ai_on()
	menu._ai_button.pressed.emit()
	var ai_after: bool = link.ai_on()
	menu._roast.toggled.emit(true)
	var roast_after: bool = link.roast_on()
	menu._real_data.toggled.emit(false)
	var real_after := Privacy.real_data_on(link.settings_path)
	_check("privacy: the AI row is O's toggle, the roast row is B's, real-machine data is the saved privacy answer", ai_after != ai_before and roast_after and not real_after and menu._real_note.text == PauseMenu.REAL_DATA_DEMO, "%s %s %s" % [ai_after, roast_after, real_after])
	var next := Link.new()
	next.settings_path = link.settings_path
	next.start()
	_check("real-machine data off: the next launch's link is demo data, as --demo is", next.demo)
	next.shut_down(null)
	menu._real_data.toggled.emit(true)
	var guarded := Link.new()
	guarded.settings_path = link.settings_path
	guarded.start()
	_check("and back on: real data again", Privacy.real_data_on(link.settings_path) and not guarded.demo)
	guarded.shut_down(null)
	menu._on_defaults()
	_check("Defaults puts every setting back and leaves the privacy answers alone", _same(s, GameSettings.new()) and Privacy.real_data_on(link.settings_path) and link.roast_on())
	menu.close()
	_check("closing saves what changed", FileAccess.get_file_as_string(s.path).contains("invert_y=false") and not menu.is_open())
	s.path = ""
	s.reset()
	_drop(arena)


# --- HUD, audio and the arena's quality. ---

func _hud_checks() -> void:
	var arena := await _arena()
	var main: Node = arena["main"]
	var hud: Node = main.get_node("Hud")
	var s := GameSettings.current()
	var cross = hud.get("_crosshair")
	s.set_value("hud", "crosshair_style", "circle")
	s.set_value("hud", "crosshair_color", "magenta")
	_check("the crosshair takes its style and colour from the settings", cross.look() == ["circle", Palette.CROSSHAIR_MAGENTA])
	s.set_value("hud", "colorblind", true)
	var filter_on: bool = hud.colorblind_filter_on()
	var shader: Shader = (hud.get("_filter").get_child(0) as ColorRect).material.shader
	s.set_value("hud", "colorblind", false)
	_check("the colorblind-safe palette is a filter over the whole screen, on and off with the setting", filter_on and not hud.colorblind_filter_on() and shader != null and shader.get_mode() == Shader.MODE_CANVAS_ITEM and hud.get("_filter").layer == 100)
	var round: RoundHud = hud.round_hud()
	round.call("_callout", "first_derezz")
	var shown_on := round.callout_text()
	await _frames(int(round.get("_t").callout_min_interval_s * 60.0) + 2)
	s.set_value("hud", "subtitles", false)
	var shown_count := round.callouts_shown
	round.call("_callout", "first_derezz")
	round.call("_refresh")
	_check("subtitles: the announcer's words show while on; off, the callout still happens (and rings) but shows no words", shown_on == RoundHud.FIRST_DOWN_LINE and round.callouts_shown == shown_count + 1 and round.callout_text() == "" and round.get("_chime").bus == &"Announcer", shown_on)
	var made := PackedStringArray()
	for bus in ["Effects", "Music", "Announcer"]:
		var at := AudioServer.get_bus_index(bus)
		if at > 0 and AudioServer.get_bus_send(at) == &"Master":
			made.append(bus)
	s.set_value("audio", "master", 0.5)
	s.set_value("audio", "music", 0.0)
	var master_db := AudioServer.get_bus_volume_db(0)
	var music := AudioServer.get_bus_index("Music")
	_check("the audio buses are made under Master, and each volume setting reaches its bus; 0 mutes", Array(made) == ["Effects", "Music", "Announcer"] and is_equal_approx(master_db, linear_to_db(0.5)) and AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(0), "%s %.2f" % [made, master_db])
	var env: Environment = (main.find_child("WorldEnvironment", true, false) as WorldEnvironment).environment
	var sun: DirectionalLight3D = main.get_node("Sun")
	var rain: Node = main.get_node("Arena/CodeRain")
	var high := [env.glow_enabled, sun.shadow_enabled, rain.is_enabled()]
	s.set_value("video", "quality", "low")
	var low := [env.glow_enabled, sun.shadow_enabled, rain.is_enabled()]
	s.set_value("video", "quality", "medium")
	var medium := [env.glow_enabled, sun.shadow_enabled, rain.is_enabled()]
	_check("the quality preset reaches the arena: high bloom, shadows and rain, medium no shadows, low none", high == [true, true, true] and medium == [true, false, true] and low == [false, false, false], "%s %s %s" % [high, medium, low])
	s.set_value("video", "resolution_scale", 0.75)
	var scaled := root.scaling_3d_scale
	s.reset()
	_check("resolution scale is the 3D render scale; the window, vsync and frame cap are never touched headless", is_equal_approx(scaled, 0.75) and is_equal_approx(root.scaling_3d_scale, 1.0) and Engine.max_fps == 0)
	_drop(arena)


# --- Law 17: every setting on one screen. ---

func _layout_checks() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(960, 540)]:
		root.size = size
		var arena := await _arena()
		var menu: PauseMenu = arena["main"].get_node("Hud").pause_menu()
		menu.open_settings()
		await _frames(3)
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		var outside := PackedStringArray()
		var widgets := 0
		var list: ScrollContainer = menu.find_child("KeyList", true, false)
		for node in menu.find_children("*", "Control", true, false):
			var c := node as Control
			if not c.is_visible_in_tree() or list.is_ancestor_of(c):
				continue
			if c is BaseButton or c is Range or c is LineEdit:
				widgets += 1
			if not screen.encloses(c.get_global_rect().grow(-0.5)):
				outside.append("%s %s" % [c.get_class(), c.get_global_rect()])
		# Visible ones only: each OptionButton's closed popup holds a scroller of its own.
		var scrollers := menu.find_children("*", "ScrollContainer", true, false).filter(func(n): return n.is_visible_in_tree())
		var box := list.get_global_rect()
		_check("at %dx%d every setting is on screen at once, nothing clipped off the edge" % [size.x, size.y], outside.is_empty() and widgets >= 30, "%d widgets; %s" % [widgets, " | ".join(outside.slice(0, 4))])
		var k: float = menu.fit_scale()
		_check("at %dx%d the only scroller is the key list, a fixed box inside the screen (Law 17)" % [size.x, size.y], scrollers.size() == 1 and scrollers[0] == list and screen.encloses(box) and is_equal_approx(box.size.y, PauseMenu.KEYS_BOX_H * k))
		_check("at %dx%d the screen is %s" % [size.x, size.y, "shrunk whole to fit, not clipped" if size.x < 1280 else "at full size"], (k < 1.0 and k > 0.6) if size.x < 1280 else k == 1.0, "scale %.3f" % k)
		menu.close()
		_drop(arena)
	root.size = Vector2i(1280, 720)


# --- Esc still skips the boot screen. ---

func _boot_checks() -> void:
	var boot = BootScene.instantiate()
	boot.settings_path = _tmp.path_join("boot.cfg")
	boot.hand_off = false
	boot.demo = true
	var state := {"done": false, "skipped": false}
	boot.finished.connect(func(skipped: bool):
		state["done"] = true
		state["skipped"] = skipped)
	root.add_child(boot)
	await _frames(20)
	var waiting: bool = not state["done"]
	await _key(KEY_ESCAPE)
	await _until(func(): return state["done"], 3000)
	_check("Esc still skips the boot screen to the arena", waiting and state["done"] and state["skipped"])
	if is_instance_valid(boot):
		boot.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame


# --- Acceptance 5: the menu stops local input only. ---

func _match_checks() -> void:
	var s := GameSettings.current()
	s.set_value("multiplayer", "display_name", "Neo")
	var host := _branch("Host", Vector3.ZERO)
	var client := _branch("Client", CLIENT_OFFSET)
	var joined := await _join(host, client)
	var hs: Session = host["session"]
	var cs: Session = client["session"]
	var hp: Node = host["player"]
	var cp: Node = client["player"]
	var cid: int = cs.my_id
	var session_code := _code("res://scripts/net/net_session.gd")
	_check("a host and a joiner over ENet on 127.0.0.1; the joiner set the display name Neo: it is Daemon-2 all the same (C14), Neo is a label on its own screen only, and the hello still carries the tuning's placeholder", joined and cs.my_name() == "Daemon-2" and hs.players[cid]["name"] == "Daemon-2" and cs.display_label() == "Neo" and cs.roster_text() == "Daemon-1, Daemon-2 (you, Neo)" and hs.roster_text() == "Daemon-1 (you, Neo), Daemon-2" and session_code.contains("hello_bytes(protocol, _t.display_name)") and session_code.count("display_label()") == 2, cs.roster_text())
	await _until(func(): return hs.avatars.has(cid) and cs.avatars.has(1) and not hs.dead.get(1, false) and hs.protect_left.get(1, 0.0) <= 0.0 and hs.protect_left.get(cid, 0.0) <= 0.0, 6000)
	var menu: PauseMenu = host["hud"].pause_menu()
	host["hud"].open_menu()
	var clock0: float = hs.get("_clock")
	var sent0: int = hs.sent
	var start: Vector3 = hp.position
	Input.action_press("move_forward")
	await _frames(40)
	Input.action_release("move_forward")
	_check("acceptance 5: with the host's menu open its player takes no input (W held, no step) and nothing is paused", menu.is_open() and hp.input_blocked and not paused and hp.horizontal_speed() < 0.01 and Vector2(hp.position.x - start.x, hp.position.z - start.z).length() < 0.01)
	_check("acceptance 5: the host's simulation runs on: its clock and its sends to the joiner", hs.get("_clock") - clock0 > 0.6 and hs.sent > sent0 + 8, "clock %.2f sends %d" % [hs.get("_clock") - clock0, hs.sent - sent0])
	var spot := Vector3(-8.0, STAND_Y, LINE_Z)
	hp.respawn_at(host["main"].to_global(spot))
	var seen := await _until(func(): return cs.avatars.has(1) and cs.avatars[1].latest_position().distance_to(spot) < 0.2, 3000)
	_check("acceptance 5: the joiner still sees the host move while the host's menu is open", seen)
	cp.respawn_at(client["main"].to_global(Vector3(-15.0, STAND_Y, LINE_Z)))
	await _frames(10)
	var health0: float = hs.health.get(1, 0.0)
	_aim(cp, client["main"].to_global(spot + Vector3(0.0, 0.05, 0.0)))
	await _settle(cp, 0.3)
	await _fire(cp)
	var hit := await _until(func(): return hs.health.get(1, 100.0) < health0, 3000)
	_check("acceptance 5: and can still hit the host: combat goes on behind the menu", hit and menu.is_open(), "health %.1f -> %.1f" % [health0, hs.health.get(1, 0.0)])
	var cmenu: PauseMenu = client["hud"].pause_menu()
	client["hud"].open_menu()
	var cspot := Vector3(-14.0, STAND_Y, LINE_Z + 2.0)
	cp.respawn_at(client["main"].to_global(cspot))
	var host_sees := await _until(func(): return hs.avatars.has(cid) and hs.avatars[cid].latest_position().distance_to(cspot) < 0.2, 3000)
	_check("acceptance 5: the joiner's menu stops nothing either: the host keeps getting the joiner's state", cmenu.is_open() and cp.input_blocked and host_sees)
	s.set_value("multiplayer", "net_stats", true)
	await _frames(3)
	var stats_host: String = host["hud"].net_hud().stats_text()
	var stats_client: String = client["hud"].net_hud().stats_text()
	s.set_value("multiplayer", "net_stats", false)
	await _frames(3)
	_check("net stats: an overlay with the round trip, loss, send rate and peers while online, gone when off", stats_host.begins_with("net stats: rtt ") and stats_host.ends_with("sync 20/s   peers 1") and stats_client.begins_with("net stats: rtt ") and host["hud"].net_hud().stats_text() == "", stats_host + " | " + stats_client)
	menu.close()
	cmenu.close()
	_check("closing the menus gives both players their input back", not hp.input_blocked and not cp.input_blocked)
	s.set_value("multiplayer", "port", 9123)
	var chosen := hs.default_port()
	s.set_value("multiplayer", "port", 0)
	_check("the default port: the settings' own, or the tuning's while left alone", chosen == 9123 and hs.default_port() == hs.tuning_in_use().port and Session.parse_address("127.0.0.1", hs.default_port())["port"] == hs.tuning_in_use().port)
	s.reset()
	_drop(host)
	_drop(client)


# --- Helpers. ---

func _arena() -> Dictionary:
	var link := Link.new()
	link.settings_path = _tmp.path_join("arena-privacy.cfg")
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	var hud = main.get_node("Hud")
	hud.guide().focus_check = func(): return false
	hud.pause_menu().focus_check = func(): return false
	var player = main.get_node("Player")
	player.assume_captured = true
	await _frames(3)
	return {"main": main, "player": player, "hud": hud}


func _drop(side: Dictionary) -> void:
	var node: Node = side.get("branch", side.get("main"))
	if is_instance_valid(node):
		for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		var session = side.get("session")
		if session != null and is_instance_valid(session):
			session.leave()
		node.free()
	_arenas.erase(node)
	_branches.erase(node)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)


func _net_tuning() -> Resource:
	var t := NetTuningScript.new()
	t.bind_address = "127.0.0.1"
	t.connect_timeout_ms = 1500
	t.peer_timeout_ms = 4000
	return t


func _combat_tuning() -> Resource:
	var t := CombatTuningScript.new()
	t.respawn_delay_s = 1.0
	t.spawn_protection_s = 0.3
	t.kill_feed_fade_s = 30.0
	return t


func _branch(name: String, offset: Vector3) -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = name
	branch.position = offset
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = _net_tuning()
	session.combat_tuning = _combat_tuning()
	branch.add_child(session)
	_branches.append(branch)
	var link := Link.new()
	link.settings_path = _tmp.path_join("%s-privacy.cfg" % name)
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	branch.add_child(main)
	var hud = main.get_node("Hud")
	var out := {"branch": branch, "session": session, "main": main, "player": main.get_node("Player"), "hud": hud}
	out["player"].assume_captured = true
	hud.guide().focus_check = func(): return false
	hud.pause_menu().focus_check = func(): return false
	return out


func _join(host: Dictionary, client: Dictionary) -> bool:
	host["session"].host(0)
	await _frames(2)
	client["session"].join("127.0.0.1:%d" % host["session"].listen_port())
	return await _until(func(): return client["session"].state == Session.State.JOINED and host["session"].players.size() == 2 and client["session"].players.size() == 2)


func _same(a: GameSettings, b: GameSettings) -> bool:
	for section in GameSettings.SCHEMA:
		for key in GameSettings.SCHEMA[section]:
			if typeof(a.value(section, key)) != typeof(b.value(section, key)) or a.value(section, key) != b.value(section, key):
				return false
	return a.binds() == b.binds()


func _key_event(code: Key, ctrl: bool = false, alt: bool = false, meta: bool = false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	e.ctrl_pressed = ctrl
	e.alt_pressed = alt
	e.meta_pressed = meta
	return e


func _key(code: Key, ctrl: bool = false, alt: bool = false, meta: bool = false) -> void:
	var down := _key_event(code, ctrl, alt, meta)
	Input.parse_input_event(down)
	await process_frame
	await process_frame
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame
	await process_frame


func _mouse(relative: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.relative = relative
	motion.screen_relative = relative
	Input.parse_input_event(motion)
	await process_frame
	await process_frame


func _stick(stick: Vector2, frames: int) -> void:
	for axis_value in [[JOY_AXIS_RIGHT_X, stick.x], [JOY_AXIS_RIGHT_Y, stick.y]]:
		var motion := InputEventJoypadMotion.new()
		motion.device = 0
		motion.axis = axis_value[0]
		motion.axis_value = axis_value[1]
		Input.parse_input_event(motion)
	await _frames(frames)
	for axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		var rest := InputEventJoypadMotion.new()
		rest.device = 0
		rest.axis = axis
		rest.axis_value = 0.0
		Input.parse_input_event(rest)
	await _frames(2)


## The view level and still: pitch 0, no recoil.
func _level(p: Node) -> void:
	await _frames(2)
	p.get_node("Head").rotation.x = 0.0


func _tap_action(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


func _settle(p: Node, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		p.drive_input(Vector2.ZERO)
		await physics_frame


func _fire(p: Node) -> void:
	p.drive_input(Vector2.ZERO, false, false, true)
	await physics_frame


func _aim(player: Node, target: Vector3) -> void:
	var cam: Node3D = player.get_node("Head/Camera")
	var to: Vector3 = target - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Back at the spawn, facing down the open middle of the arena, at rest.
func _home(p: Node) -> void:
	p.respawn_at(Vector3(0.0, STAND_Y, 10.0))
	p.rotation.y = 0.0
	p.get_node("Head").rotation.x = 0.0
	await _settle(p, 0.4)


## The largest camera bob seen while running forward for a second.
func _walk_bob(p: Node) -> float:
	await _home(p)
	var cam: Camera3D = p.get_node("Head/Camera")
	var most := 0.0
	for i in 60:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		most = maxf(most, cam.position.length())
	await _settle(p, 0.5)
	return most


## The widest field of view seen in a slide from a run.
func _slide_fov(p: Node) -> float:
	var cam: Camera3D = p.get_node("Head/Camera")
	await _home(p)
	for i in 30:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
	p.drive_input(Vector2(0.0, -1.0), false, true)
	await physics_frame
	var widest := 0.0
	for i in 30:
		p.drive_input(Vector2(0.0, -1.0))
		await physics_frame
		widest = maxf(widest, cam.fov)
	await _settle(p, 1.0)
	return widest


func _until(condition: Callable, ms: int = WATCHDOG_MS) -> bool:
	var t0 := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - t0 > ms:
			return false
		await physics_frame
	return true


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


## A script's code with comments and string contents' # signs left alone.
func _code(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var quote := ""
		var cut := line.length()
		var i := 0
		while i < line.length():
			var ch := line[i]
			if quote != "":
				if ch == "\\":
					i += 1
				elif ch == quote:
					quote = ""
			elif ch == "\"" or ch == "'":
				quote = ch
			elif ch == "#":
				cut = i
				break
			i += 1
		out.append(line.substr(0, cut).rstrip(" \t"))
	return "\n".join(out)


func _cleanup() -> void:
	for node in _arenas.duplicate() + _branches.duplicate():
		if is_instance_valid(node):
			var session = node.get_node_or_null(Session.NODE_NAME)
			if session != null:
				session.leave()
			node.free()
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	GameSettings.current().path = ""
	GameSettings.current().reset()
	GameSettings.current().set_value("gameplay", "practice", true)  # these checks predate C27b: the daemons stay the old never-attack dummies
	await process_frame
	OS.delay_msec(300)
	await process_frame


## A preset's C16b keys (bloom, shadows and the code rain); A4 added more.
func _three(preset: Dictionary) -> Dictionary:
	return {"bloom": preset["bloom"], "shadows": preset["shadows"], "code_rain": preset["code_rain"]}

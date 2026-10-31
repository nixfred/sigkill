extends SceneTree
## Headless test of the opener for SIGKILL (C38: PRD 5.7, "you got tricked into this", 0:00 to 0:35; C40: the
## shrink-away and the fall, 0:35 to 1:10). scripts/check.sh runs it as step 48, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/opener_test.gd
##
## The code: nothing of the opener opens a file outside res:// (it loads only its own resources and writes nothing),
## reads an environment variable or the clock, runs a program, opens a network connection, holds the main loop or
## touches the window's close; every sound is made in code. The data seam: the demo data fixed and invented; a stub
## source's user, host, palette and folders reaching the screen only through clean(); an empty source falling back;
## a long name still typed inside its window. The palettes: all six whole and readable, under Omarchy's names. The
## typing: jitter, beats before the punchlines, a typo taken back, squeezed to fit. A whole run: every beat in order
## and inside its PRD window, the PRD's words exactly, the prompt from the data in bash's colours, the palette
## applied, the uptime ticking, the hold, the 3 seconds the terminal ignores typing, "you're in now.", the reveal, the
## fall, the landing and the hand-back (C40; tests/opener_fall_test.gd, step 50, checks the city and the camera's
## way); the main loop ticking through the crash with the frozen
## frame held, the darkness and the pop-in drawn from the brightness model, and that model never flashing 3 or more
## times in any second. Esc leaving mid-crash, mid-typing, in the hold, while it ignores typing, mid-reveal, mid-fall
## and landed (and a pad's cancel), the game behind let go and the machine dropped each time. In the real arena: the Esc menu's "Play the opener", the arena paused behind it, Esc back to the
## menu as it was, greyed out in a match, the --opener flag. Deterministic: frames counted, outcomes printed.
##
## C39 added the real reader (scripts/opener/real_opener_data.gd), the one opener file that reads the machine: it is
## left out of the no-real-reads check here by name, and tests/opener_real_test.gd (step 49) checks it instead.
## Every other opener file, the two C39 added among them (cell_width.gd, theme_colors.gd) and C40's city and machine
## (tree_layout.gd, tree_fall.gd and their shaders), still reads nothing.

const MainScene = preload("res://scenes/main.tscn")
const OpenerScene = preload("res://scenes/opener.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")

## The opener's code paths: its own scripts, scene, resources and shaders, and the menu's and the arena's parts
## that start it; every script in scripts/opener/ but READER (the check also finds any new one there).
const OPENER_CODE := ["res://scripts/opener/opener.gd", "res://scripts/opener/opener_data.gd", "res://scripts/opener/demo_opener_data.gd", "res://scripts/opener/opener_palette.gd", "res://scripts/opener/opener_tuning.gd", "res://scripts/opener/fake_terminal.gd", "res://scripts/opener/typist.gd", "res://scripts/opener/cell_width.gd", "res://scripts/opener/theme_colors.gd", "res://scripts/opener/tree_layout.gd", "res://scripts/opener/tree_fall.gd", "res://scripts/opener/opener_link.gd", "res://scripts/opener/link_beat.gd", "res://scripts/opener/pit_beat.gd", "res://scripts/opener/copy_art.gd", "res://scripts/opener/intro_menu.gd", "res://scripts/opener/opener_score.gd", "res://scripts/opener/forge_beat.gd", "res://scripts/opener/title_beat.gd", "res://scenes/opener.tscn", "res://resources/opener.tres", "res://shaders/opener_glitch.gdshader", "res://shaders/opener_screen.gdshader", "res://shaders/opener_tower.gdshader", "res://shaders/opener_panel.gdshader", "res://shaders/opener_terrace.gdshader", "res://shaders/opener_maze.gdshader", "res://shaders/opener_stream.gdshader", "res://shaders/opener_speed.gdshader", "res://shaders/opener_sky.gdshader", "res://shaders/opener_core.gdshader", "res://shaders/opener_signal.gdshader", "res://shaders/opener_floor.gdshader", "res://shaders/opener_forge.gdshader", "res://shaders/opener_print.gdshader", "res://shaders/opener_post.gdshader"]
## The one opener file that reads the machine (C39), checked by tests/opener_real_test.gd instead.
const READER := "res://scripts/opener/real_opener_data.gd"
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "shell_open", "shell_show_in_file_manager", "get_environment", "has_environment", "set_environment", "unset_environment", "get_unix_time_from_system", "_dict_from_system", "_string_from_system", "get_time_zone_from_system", "get_ticks", "get_unique_id", "get_processor", "get_model_name", "get_executable_path", "get_system_dir", "get_user_data_dir", "get_cmdline", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "ENetMultiplayerPeer", "WebSocket", "WebRTC", "FileAccess", "DirAccess", "ResourceSaver", "save_png", "save_jpg", "save_webp", "save_exr", "store_", "JavaScriptBridge", "http://", "https://", "auto_accept_quit", "WM_CLOSE_REQUEST", "_notification", "delay_msec", "delay_usec", "while true", ".ogg", ".mp3", ".wav", "AudioStreamOggVorbis", "AudioStreamMP3"]
## The PRD's words, as PRD 5.7 has them.
const PRD_THANKS := "thanks for running me."
const PRD_INSTALL := "you never read the install script, did you?"
const PRD_SINCE := "I've been in here since you booted."
const PRD_IN := "you're in now."
const DEMO_PROMPT := "user@workstation:~$ "
const DEMO_LATE := "you were still up at 03:12 last night. so was I."
const KEYS_OMARCHY := ["accent", "background", "foreground", "bright_foreground", "darker_background", "red", "green", "yellow", "blue", "magenta", "cyan", "bright_red", "bright_green", "bright_yellow", "bright_blue", "bright_magenta", "bright_cyan"]
## WCAG's least contrast for text, and for a large shape (the cursor).
const TEXT_CONTRAST := 4.5
const SHAPE_CONTRAST := 3.0
## A flash: a pair of opposing brightness changes of at least this much (WCAG 2.3.1's general flash).
const FLASH_STEP := 0.1
const MOST_FLASHES := 2
const FPS := 60.0
## Frames any one run may take before the test gives up on it.
const MOST_FRAMES := 7600
const LONG_ROUND_S := 100000.0


## A data source of the test's own, behind the opener's seam.
class StubData extends OpenerData:
	var u := ""
	var h := ""
	var pal: OpenerPalette = null
	var dirs := PackedStringArray()
	var up := 0
	var times := PackedInt64Array()
	var at := 0

	func kind() -> String:
		return "stub"

	func user() -> String:
		return u

	func host() -> String:
		return h

	func palette() -> OpenerPalette:
		return pal

	func folders() -> PackedStringArray:
		return dirs

	func uptime_s() -> int:
		return up

	func file_times() -> PackedInt64Array:
		return times

	func now() -> int:
		return at


## A session that says it is in a match.
class OnlineSession extends Node:
	func is_online() -> bool:
		return true


var _fails := 0
var _checks := 0
var _finished: Array = []
var _arenas: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	Controls.ensure()
	GameSettings.current().reset()
	_source_checks()
	_data_checks()
	_palette_checks()
	_typist_checks()
	_words_checks()
	_flash_counter_checks()
	await _run_checks()
	await _stub_checks()
	await _escape_checks()
	await _menu_checks()
	await _cleanup()
	print("OPENER: %d checks" % _checks)
	print("OPENER RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _source_checks() -> void:
	var found := PackedStringArray()
	var loads := PackedStringArray()
	var all := ""
	for path in OPENER_CODE:
		var code := _code(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
		for bad in _loads_outside(code):
			loads.append("%s: %s" % [path.get_file(), bad])
	var menu := _code("res://scripts/hud/pause_menu.gd")
	var main := _code("res://scripts/main.gd")
	var starts := _body(menu, "open_opener") + _body(menu, "_opener_source") + _body(menu, "_on_opener_finished") + _body(main, "_play_opener")
	var unlisted := PackedStringArray()
	for file in DirAccess.get_files_at("res://scripts/opener"):
		var script := "res://scripts/opener/" + file
		if file.ends_with(".gd") and not OPENER_CODE.has(script) and script != READER:
			unlisted.append(file)
	for file in DirAccess.get_files_at("res://shaders"):
		var shader := "res://shaders/" + file
		if file.begins_with("opener_") and file.ends_with(".gdshader") and not OPENER_CODE.has(shader):
			unlisted.append(file)
	for word in NEVER:
		if starts.contains(word):
			found.append("the menu's or the arena's start: " + word)
	_check("acceptance: the opener's code paths read no environment variable or clock, run no program, open no network connection and write no file (no execute, environment, system time, HTTP, socket, ENet, WebSocket, FileAccess, DirAccess or saver in its %d files, nor where the menu and the arena start it); the reader is the one file left out, and every other script in scripts/opener/ and every opener_ shader is in the list" % OPENER_CODE.size(), found.is_empty() and unlisted.is_empty() and all.length() > 0 and starts.length() > 0 and FileAccess.file_exists(READER), ", ".join(found + unlisted))
	_check("acceptance: the only files it opens are its own under res:// (every load names a res:// literal or a res:// constant; nothing is opened by a path made at run time)", loads.is_empty() and all.contains("load(DEFAULT_TUNING_PATH)") and all.contains("load(DIR + palette_id"), ", ".join(loads))
	var source := _body(menu, "_opener_source")
	_check("acceptance: nothing real without the player's yes (C39): the menu and the --opener flag play the demo data unless the opener data answer is on and the run is not on demo data, and the opener falls back to it when given none", _body(menu, "open_opener").contains("_opener.data = _opener_source()") and source.contains("link == null or link.demo") and source.contains("Privacy.real_data_on(link.settings_path)") and source.contains("Privacy.opener_real_on(link.settings_path)") and source.count("return DemoOpenerData.new()") == 2 and _code("res://scripts/opener/opener.gd").contains("_data = data if data != null else DemoOpenerData.new()") and DemoOpenerData.new().kind() == "demo")
	_check("no real freeze and the window's close untouched: nothing waits on the main loop (no delay, no endless loop), nothing handles the close request or changes auto-quit; Esc is read in _input, before anything else", not all.contains("delay_") and not all.contains("WM_CLOSE") and all.contains("func _input(event: InputEvent)") and _code("res://scripts/opener/opener.gd").contains("process_mode = Node.PROCESS_MODE_ALWAYS"))
	var sounds := _code("res://scripts/sfx_synth.gd")
	_check("every sound is made in code (scripts/sfx_synth.gd's opener_key, opener_buzz, opener_crackle, opener_hum, and C40's opener_whoosh, opener_wind, opener_thud, opener_beat), no audio file loaded", sounds.contains("static func opener_key(") and sounds.contains("static func opener_buzz(") and sounds.contains("static func opener_crackle(") and sounds.contains("static func opener_hum(") and sounds.contains("static func opener_whoosh(") and sounds.contains("static func opener_wind(") and sounds.contains("static func opener_thud(") and sounds.contains("static func opener_beat(") and not all.contains(".ogg") and not all.contains(".wav"))


## Every load( and preload( in `code` whose path is not a res:// literal or a constant holding one.
static func _loads_outside(code: String) -> PackedStringArray:
	var consts := {}
	var named := RegEx.create_from_string("const (\\w+) := \"([^\"]*)\"")
	for m in named.search_all(code):
		consts[m.get_string(1)] = m.get_string(2)
	var out := PackedStringArray()
	var calls := RegEx.create_from_string("(?:pre)?load\\(([^)]*)\\)")
	for m in calls.search_all(code):
		var arg := m.get_string(1).strip_edges()
		var head := arg.get_slice(" ", 0)
		var path := ""
		if head.begins_with("\""):
			path = head.trim_prefix("\"")
		elif consts.has(head):
			path = consts[head]
		if not path.begins_with("res://"):
			out.append(arg)
	return out


# --- The data seam and the demo data. ---

func _data_checks() -> void:
	var a := DemoOpenerData.new()
	var b := DemoOpenerData.new()
	var when := Time.get_datetime_dict_from_unix_time(a.now())
	var late := Time.get_datetime_dict_from_unix_time(a.file_times()[2])
	_check("acceptance: the demo data is fixed and invented: user \"%s\", host \"%s\", %d folders, up %d s, a 03:12 file time on a fixed Tuesday; two copies the same" % [a.user(), a.host(), a.folders().size(), a.uptime_s()], a.user() == "user" and a.host() == "workstation" and a.folders().size() == 28 and a.uptime_s() == 3 * 86400 + 7 * 3600 + 42 * 60 + 15 and when["year"] == 2025 and when["weekday"] == 2 and when["hour"] == 22 and late["hour"] == 3 and late["minute"] == 12 and a.user() == b.user() and a.folders() == b.folders() and a.file_times() == b.file_times() and a.now() == b.now())
	var odd := PackedStringArray()
	for name in a.folders():
		if name.contains("@") or name.begins_with("/") or name.contains("..") or name != OpenerData.clean(name, OpenerData.FOLDER_LONGEST):
			odd.append(name)
	_check("the demo folders are plain names under the home folder, nothing that looks like a path off it or an address", odd.is_empty(), ", ".join(odd))
	var empty := OpenerData.new()
	_check("the seam itself hands over nothing (an implementation fills it): empty names, no palette, no folders, no times", empty.kind() == "" and empty.user() == "" and empty.host() == "" and empty.palette() == null and empty.folders().is_empty() and empty.uptime_s() == 0 and empty.file_times().is_empty() and empty.now() == 0)
	var esc := String.chr(0x1b)
	var cases := [
		[esc + "[31mred" + esc + "[0m", "red"],
		["two\nlines\tand\r", "two lines and"],
		["bell" + String.chr(7) + String.chr(0x7f) + String.chr(0x9b) + "!", "bell!"],
		["  spaced  ", "spaced"],
		["x".repeat(40), "x".repeat(29) + "..."],
		["", ""],
	]
	var wrong := PackedStringArray()
	for c in cases:
		var got := OpenerData.clean(c[0], 32)
		if got != c[1]:
			wrong.append("%s -> %s" % [c[0].c_escape(), got.c_escape()])
	_check("clean(): escape sequences and control characters dropped, line breaks and tabs as spaces, the ends trimmed, cut at its length with \"...\": a name can never move the cursor, colour the screen or break a line", wrong.is_empty(), ", ".join(wrong))


# --- The palettes. ---

func _palette_checks() -> void:
	var bad := PackedStringArray()
	var low := PackedStringArray()
	for id in OpenerPalette.IDS:
		var p := OpenerPalette.named(id)
		if p == null or p.id != id or p.inspired_by == "":
			bad.append(id)
			continue
		for key in OpenerPalette.KEYS:
			if not Color.html_is_valid(p.colors.get(key, "")):
				bad.append("%s.%s" % [id, key])
		var text := _contrast(p.color("foreground"), p.color("background"))
		var cursor := _contrast(p.cursor(), p.color("background"))
		var blue := _contrast(p.color("blue"), p.color("background"))
		if text < TEXT_CONTRAST or cursor < SHAPE_CONTRAST or blue < SHAPE_CONTRAST:
			low.append("%s %.1f/%.1f/%.1f" % [id, text, cursor, blue])
	_check("acceptance: six demo palettes, each whole: every one of Omarchy's %d colour names a valid colour, its id and the open theme it takes its colours from" % OpenerPalette.KEYS.size(), OpenerPalette.IDS.size() == 6 and bad.is_empty(), ", ".join(bad))
	_check("each is readable: its text %.1f:1 or more on its background, its cursor and its folders' blue %.1f:1 or more" % [TEXT_CONTRAST, SHAPE_CONTRAST], low.is_empty(), ", ".join(low))
	var night := OpenerPalette.named(OpenerPalette.DEFAULT_ID)
	_check("the default is Tokyo-Night-like (\"night\": background #1a1b26, accent #7aa2f7); an unknown id falls back to it; latte is the light one", night.id == "night" and night.inspired_by == "Tokyo Night" and night.colors["background"] == "#1a1b26" and night.colors["accent"] == "#7aa2f7" and OpenerPalette.named("nope").id == "night" and OpenerPalette.named("latte").mode == "light" and night.mode == "dark")
	var shape := true
	for key in KEYS_OMARCHY:
		shape = shape and OpenerPalette.KEYS.has(key)
	var partial := OpenerPalette.new()
	partial.colors = {"background": "#101010", "foreground": "#e0e0e0", "red": "#ff0000"}
	var nothing := OpenerPalette.new()
	_check("the shape is a theme's colors.toml, key for key, so C39 maps a real theme straight on; a theme missing keys still draws (bright_red reads red, accent reads blue then the foreground, darker_background the background, a garbled value its fallback)", shape and partial.color("bright_red") == Color.html("#ff0000") and partial.color("accent") == Color.html("#e0e0e0") and partial.color("darker_background") == Color.html("#101010") and nothing.color("background") == OpenerPalette.LAST_BACKGROUND and nothing.color("cursor_text") == OpenerPalette.LAST_FOREGROUND and _garbled().color("green") == Color.html("#e0e0e0"))


func _garbled() -> OpenerPalette:
	var p := OpenerPalette.new()
	p.colors = {"background": "#000000", "foreground": "#e0e0e0", "green": "not a colour"}
	return p


# --- Typing like a hand. ---

func _typist_checks() -> void:
	var line := "you never read the install script"
	var keys := Typist.plan([line], 7, 0.08)
	var gaps := PackedFloat32Array()
	for i in range(1, keys.size()):
		gaps.append(keys[i]["at"] - keys[i - 1]["at"])
	var mean := 0.0
	for g in gaps:
		mean += g
	mean /= gaps.size()
	var spread := 0.0
	for g in gaps:
		spread += (g - mean) * (g - mean)
	spread = sqrt(spread / gaps.size())
	var least := 99.0
	var distinct := {}
	for g in gaps:
		least = minf(least, g)
		distinct[snappedf(g, 0.0001)] = true
	_check("acceptance: typing feels human, per character: every key its own wait (%d different waits in %d keys; mean %.3f s, spread %.3f s, the quickest %.3f s), never a machine's even beat" % [distinct.size(), gaps.size(), mean, spread, least], distinct.size() >= gaps.size() * 0.6 and spread > mean * 0.25 and least >= 0.02 and mean > 0.04 and mean < 0.14 and Typist.text_of(keys) == line)
	var beat := Typist.plan(["you never read the install script,", 0.75, " did you?"], 9, 0.08)
	var before := -1.0
	for i in range(1, beat.size()):
		if beat[i]["key"] == " " and beat[i - 1]["key"] == ",":
			before = beat[i]["at"] - beat[i - 1]["at"]
	_check("acceptance: a beat before the punchline: %.2f s between \"script,\" and \" did you?\"" % before, before >= 0.75)
	var typo := Typist.plan(["the ", Typist.typo("isn", 2), "nstall"], 3, 0.08)
	var backs := 0
	for key in typo:
		if key["key"] == Typist.BACKSPACE:
			backs += 1
	_check("a typo typed, noticed and taken back: \"isn\" and two backspaces leave \"the install\"", Typist.text_of(typo) == "the install" and backs == 2 and Typist.text_of_segments(["the ", Typist.typo("isn", 2), "nstall"]) == "the install")
	var again := Typist.plan([line], 7, 0.08)
	var other := Typist.plan([line], 8, 0.08)
	_check("seeded: the same line and seed type the same way every time, another seed differently", _same_plan(keys, again) and not _same_plan(keys, other))
	var squeezed := Typist.fit(Typist.plan(["x".repeat(80)], 1, 0.1), 2.0)
	var roomy := Typist.fit(keys, 30.0)
	_check("a line given more than its time types faster to fit (80 keys in 2 s: done at %.2f s), and one that fits is left alone" % Typist.duration(squeezed), Typist.duration(squeezed) <= 2.0 + 0.0001 and Typist.text_of(squeezed) == "x".repeat(80) and _same_plan(roomy, keys))


static func _same_plan(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i]["key"] != b[i]["key"] or absf(a[i]["at"] - b[i]["at"]) > 0.000001:
			return false
	return true


# --- The words. ---

func _words_checks() -> void:
	_check("acceptance: the PRD's words, exactly: \"%s\" / \"%s\" / \"%s\"" % [Opener.THANKS, Opener.INSTALL, Opener.SINCE], Opener.THANKS == PRD_THANKS and Opener.INSTALL == PRD_INSTALL and Opener.SINCE == PRD_SINCE)
	var demo := DemoOpenerData.new()
	var line := Typist.text_of_segments(Opener.late_line(demo.file_times(), demo.now(), 0.8))
	var segs := Opener.late_line(demo.file_times(), demo.now(), 0.8)
	_check("acceptance: the late-night line from the demo's file times: \"%s\", a beat before its echo" % line, line == DEMO_LATE and segs.size() == 3 and segs[1] == 0.8 and segs[2] == " so was I.")
	var now := _local(2025, 11, 7, 12, 0)
	var older := Opener.late_line(PackedInt64Array([_local(2025, 11, 4, 2, 30), _local(2025, 11, 6, 22, 0)]), now, 0.5)
	var none_late := Opener.late_line(PackedInt64Array([_local(2025, 11, 6, 22, 0), _local(2025, 11, 7, 9, 0)]), now, 0.5)
	var nothing := Opener.late_line(PackedInt64Array(), now, 0.5)
	var outside := Opener.late_line(PackedInt64Array([_local(2025, 10, 20, 3, 0), _local(2025, 11, 8, 1, 0)]), now, 0.5)
	var no_clock := Opener.late_line(PackedInt64Array([_local(2025, 11, 4, 2, 30)]), 0, 0.5)
	_check("the late-night line from mtimes alone: a late hour three days back is its weekday (\"%s\"); none late, none at all, and times outside the week each get a line that needs none; with no clock, no \"last night\"" % Typist.text_of_segments(older), Typist.text_of_segments(older) == "you were still up at 02:30 on tuesday. so was I." and Typist.text_of_segments(none_late) == Opener.NEVER_LATE + Opener.NEVER_LATE_ECHO and Typist.text_of_segments(nothing) == Opener.NO_TIMES + Opener.NO_TIMES_ECHO and Typist.text_of_segments(outside) == Opener.NEVER_LATE + Opener.NEVER_LATE_ECHO and Typist.text_of_segments(no_clock) == "you were still up at 02:30. so was I.")
	_check("the uptime as it ticks: \"%s\", \"%s\", \"%s\"" % [Opener.uptime_text(DemoOpenerData.UPTIME_S), Opener.uptime_text(86400 + 61), Opener.uptime_text(59)], Opener.uptime_text(DemoOpenerData.UPTIME_S) == "up 3 days, 07:42:15" and Opener.uptime_text(86400 + 61) == "up 1 day, 00:01:01" and Opener.uptime_text(59) == "up 00:00:59")
	var t := load("res://resources/opener.tres") as OpenerTuning
	_check("the shipped timeline holds together and keeps the PRD's windows (the prompt ends by 0:15, the lines run 0:15 to 0:35, the glitch steps at most 12 times a second)", t != null and t.problems().is_empty(), ", ".join(t.problems()) if t != null else "no tuning")
	var broken := OpenerTuning.new()
	broken.thanks_at = 14.0
	var strobing := OpenerTuning.new()
	strobing.glitch_hz = 30.0
	var fine := OpenerTuning.new()
	fine.hold_until = 35.8
	fine.end_after = 10.6
	fine.end_at = 117.8
	var short_ignore := OpenerTuning.new()
	short_ignore.ignore_s = 1.5
	var late_landing := OpenerTuning.new()
	late_landing.land_at = 72.0
	late_landing.handoff_at = 72.5
	late_landing.end_at = 73.0
	_check("a timeline that breaks a window or strobes is refused for the shipped one (\"%s\"); one that keeps them is used as given" % ", ".join(broken.problems()), not broken.problems().is_empty() and not strobing.problems().is_empty() and Opener.usable_tuning(broken) == t and Opener.usable_tuning(strobing) == t and Opener.usable_tuning(null) == t and Opener.usable_tuning(fine) == fine)
	_check("C40's windows are held too: a terminal that ignores typing for 1.5 s (\"%s\") and a fall landing after 1:10 (\"%s\") are refused for the shipped one" % [", ".join(short_ignore.problems()), ", ".join(late_landing.problems())], short_ignore.problems().has("the terminal does not ignore typing for 3 seconds") and late_landing.problems().has("the fall ends after 1:10") and Opener.usable_tuning(short_ignore) == t and Opener.usable_tuning(late_landing) == t)


static func _local(year: int, month: int, day: int, hour: int, minute: int) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": day, "hour": hour, "minute": minute, "second": 0})


# --- The flash counter. ---

## Flashes in the worst one-second window of `levels` (one a frame at FPS): a flash is a pair of opposing changes
## of FLASH_STEP or more, both inside the window.
static func _worst_flashes(levels: PackedFloat32Array) -> int:
	# The changes: each a run of moves one way (flat stretches inside it ignored), timed at its last move, kept when
	# it moves FLASH_STEP or more.
	var changes: Array = []
	var start := 0
	var last := 0
	var dir := 0.0
	for i in range(1, levels.size()):
		var d := signf(levels[i] - levels[i - 1])
		if d == 0.0:
			continue
		if d != dir:
			if dir != 0.0 and absf(levels[last] - levels[start]) >= FLASH_STEP:
				changes.append([float(last) / FPS, dir])
			start = i - 1
			dir = d
		last = i
	if dir != 0.0 and absf(levels[last] - levels[start]) >= FLASH_STEP:
		changes.append([float(last) / FPS, dir])
	var worst := 0
	for i in changes.size():
		var count := 0
		var j := i
		while j + 1 < changes.size() and changes[j + 1][0] - changes[i][0] < 1.0:
			if changes[j + 1][1] != changes[j][1]:
				count += 1
				j += 2
			else:
				j += 1
		worst = maxi(worst, count)
	return worst


func _flash_counter_checks() -> void:
	var strobe := PackedFloat32Array()
	var steady := PackedFloat32Array()
	for i in 120:
		strobe.append(1.0 if floori(i / 10.0) % 2 == 0 else 0.0)
		steady.append(0.5 + 0.04 * sin(i * 0.3))
	var two := PackedFloat32Array()
	for i in 120:
		two.append(0.0 if (i >= 30 and i < 33) or (i >= 72 and i < 75) else 1.0)
	_check("the flash counter catches a strobe (3 Hz black and back: %d flashes in a second), counts two drops 0.7 s apart as 2 (%d), and lets small changes through (%d)" % [_worst_flashes(strobe), _worst_flashes(two), _worst_flashes(steady)], _worst_flashes(strobe) >= 3 and _worst_flashes(two) == 2 and _worst_flashes(steady) == 0)


# --- A whole run, on the demo data. ---

func _run_checks() -> void:
	var mode_before := Input.mouse_mode
	var o := _opener(null, false)
	var t := o.timing()
	var mat := (o.get_node("FrozenFrame") as TextureRect).material as ShaderMaterial
	var term := o.terminal()
	var prev_ticks := o.ticks()
	var prev_engine := Engine.get_process_frames()
	var frozen := 0
	var ticks_bad := 0
	var dark_bad := 0
	var pop_bad := 0
	var held := true
	var hidden_3d := true
	var seeds := 0
	var last_seed := -1.0
	var amount_down := false
	var last_amount := 0.0
	var buzz_ok := true
	var crackle := false
	var silent_gap := true
	var hum := false
	var key := false
	var saw_typo := false
	var comma_at := -1.0
	var did_at := -1.0
	var head_at := -1.0
	var echo_at := -1.0
	var uptimes: Array = []
	var flips := 0
	var shown := term.cursor_showing()
	var paused_ever := false
	var frames := 0
	while o.playing() and frames < MOST_FRAMES:
		await process_frame
		frames += 1
		if not is_instance_valid(o) or not o.playing():
			break
		var e := o.elapsed()
		var phase := o.phase_name()
		paused_ever = paused_ever or paused
		if phase == "frozen":
			frozen += 1
			if o.ticks() - prev_ticks != 1 or Engine.get_process_frames() - prev_engine != 1:
				ticks_bad += 1
			held = held and o.frame_texture() != null
			hidden_3d = hidden_3d and root.disable_3d
			if absf(float(mat.get_shader_parameter("dark")) - (1.0 - o.luma_at(e))) > 0.0001:
				dark_bad += 1
			var seed := float(mat.get_shader_parameter("seed"))
			if seed != last_seed:
				seeds += 1
				last_seed = seed
			var amount := float(mat.get_shader_parameter("amount"))
			amount_down = amount_down or amount < last_amount - 0.0001
			last_amount = amount
			buzz_ok = buzz_ok and (o.get_node("Buzz") as AudioStreamPlayer).playing
			crackle = crackle or (o.get_node("Crackle") as AudioStreamPlayer).playing
		if phase == "black" and e < t.hum_from:
			for p in o.find_children("*", "AudioStreamPlayer", false, false):
				silent_gap = silent_gap and not (p as AudioStreamPlayer).playing
		if phase == "terminal" or phase == "hold":
			if absf(term.pop - o.luma_at(e)) > 0.0001:
				pop_bad += 1
			hum = hum or (o.get_node("Hum") as AudioStreamPlayer).playing
		for k in ["Key1", "Key2", "Key3"]:
			key = key or (o.get_node(k) as AudioStreamPlayer).playing
		var install := term.line_text(1)
		saw_typo = saw_typo or install == "you never read the isn"
		if comma_at < 0.0 and install.ends_with("script,"):
			comma_at = e
		if did_at < 0.0 and install.ends_with("script, d"):
			did_at = e
		var last := term.line_text(term.line_count() - 1)
		if last.begins_with("you were still up"):
			if head_at < 0.0 and last.ends_with("night."):
				head_at = e
			if echo_at < 0.0 and last.ends_with("night. s"):
				echo_at = e
		for n in term.line_count():
			var up := term.line_text(n)
			if up.begins_with("up ") and (uptimes.is_empty() or uptimes[-1][1] != up):
				uptimes.append([e, up])
		if (phase == "hold" or phase == "ignore") and e > t.rest_at + Typist.NOTICE_S:
			if term.cursor_showing() != shown:
				flips += 1
			shown = term.cursor_showing()
		prev_ticks = o.ticks()
		prev_engine = Engine.get_process_frames()
	await process_frame
	var ev := {}
	for e in o.events():
		if not ev.has(e[1]):
			ev[e[1]] = e[0]
	var order := ["live", "freeze", "dropout", "cut", "machine", "terminal", "prompt_start", "prompt_done", "thanks_start", "thanks_done", "install_start", "install_done", "folders_start", "folders_done", "uptime", "since_start", "since_done", "late_start", "late_done", "hold", "tear", "ignore", "ignore_done", "in_start", "in_done", "lift", "reveal", "fall", "land", "handoff", "done"]
	var in_order := true
	var missing := PackedStringArray()
	for i in order.size():
		if not ev.has(order[i]):
			missing.append(order[i])
		elif i > 0 and ev.has(order[i - 1]) and ev[order[i]] < ev[order[i - 1]]:
			in_order = false
	_check("acceptance: every beat happens, in order: %s" % " < ".join(order), missing.is_empty() and in_order, ", ".join(missing))
	var early := PackedStringArray()
	for name in ["freeze", "dropout", "cut", "terminal", "prompt_start", "prompt_done"]:
		if not ev.has(name) or ev[name] < 0.0 or ev[name] >= 15.0:
			early.append("%s %.2f" % [name, ev.get(name, -1.0)])
	_check("acceptance: 0:00 to 0:15 holds the fake crash, the black, the terminal and the prompt typing itself (freeze %.2f, cut %.2f, terminal %.2f, prompt %.2f to %.2f s)" % [ev.get("freeze", -1.0), ev.get("cut", -1.0), ev.get("terminal", -1.0), ev.get("prompt_start", -1.0), ev.get("prompt_done", -1.0)], early.is_empty(), ", ".join(early))
	var lines_out := PackedStringArray()
	for name in ["thanks_start", "thanks_done", "install_start", "install_done", "folders_start", "folders_done", "uptime", "since_start", "since_done", "late_start", "late_done"]:
		if not ev.has(name) or ev[name] < 15.0 or ev[name] > 35.0:
			lines_out.append("%s %.2f" % [name, ev.get(name, -1.0)])
	_check("acceptance: 0:15 to 0:35 holds every line (thanks %.2f, the install script %.2f, folders %.2f to %.2f, uptime %.2f, booted %.2f, the late night %.2f to %.2f s)" % [ev.get("thanks_start", -1.0), ev.get("install_start", -1.0), ev.get("folders_start", -1.0), ev.get("folders_done", -1.0), ev.get("uptime", -1.0), ev.get("since_start", -1.0), ev.get("late_start", -1.0), ev.get("late_done", -1.0)], lines_out.is_empty(), ", ".join(lines_out))
	var shrink_out := PackedStringArray()
	for name in ["ignore", "ignore_done", "in_start", "in_done", "lift", "reveal"]:
		if not ev.has(name) or ev[name] < 35.0 or ev[name] > 50.0:
			shrink_out.append("%s %.2f" % [name, ev.get(name, -1.0)])
	var ignored_s: float = ev.get("ignore_done", 0.0) - ev.get("ignore", 0.0)
	_check("acceptance (C40): 0:35 to 0:50 holds the shrink-away: the terminal ignores typing for 3 seconds (%.2f to %.2f s, %.2f s), \"%s\" at %.2f to %.2f s, the window shrinking away from %.2f s" % [ev.get("ignore", -1.0), ev.get("ignore_done", -1.0), ignored_s, PRD_IN, ev.get("in_start", -1.0), ev.get("in_done", -1.0), ev.get("reveal", -1.0)], shrink_out.is_empty() and absf(ignored_s - 3.0) < 2.0 / FPS, ", ".join(shrink_out))
	_check("acceptance (C40): 0:50 to 1:10 holds the fall: it starts at %.2f s, lands at %.2f s and hands off at %.2f s (C41's beat starts there)" % [ev.get("fall", -1.0), ev.get("land", -1.0), ev.get("handoff", -1.0)], absf(ev.get("fall", -1.0) - 50.0) < 0.5 and ev.get("land", 99.0) <= 70.0 and ev.get("handoff", 99.0) <= 70.5 and ev.get("land", -1.0) > ev.get("fall", 99.0))
	var expected := PackedStringArray([DEMO_PROMPT + PRD_THANKS, PRD_INSTALL])
	for name in DemoOpenerData.FOLDERS:
		expected.append("~/" + name)
	var written := term.all_text().split("\n")
	var upline := expected.size()
	var words_ok := written.size() == expected.size() + 4
	for i in expected.size():
		words_ok = words_ok and i < written.size() and written[i] == expected[i]
	words_ok = words_ok and written.size() > upline + 3 and written[upline].begins_with("up 3 days, 07:4") and written[upline + 1] == PRD_SINCE and written[upline + 2] == DEMO_LATE and written[upline + 3] == DEMO_PROMPT + PRD_IN
	_check("acceptance: the screen, word for word: the prompt and \"%s\", \"%s\", the 28 folders, the uptime, \"%s\", \"%s\", then a fresh prompt, and at it (C40) \"%s\"" % [PRD_THANKS, PRD_INSTALL, PRD_SINCE, DEMO_LATE, PRD_IN], words_ok, term.all_text().c_escape().left(300))
	_check("acceptance: the prompt built from the data and typed itself: \"%s\", in bash's colours (user@host bold green, ~ bold blue)" % o.prompt_text(), o.prompt_text() == DEMO_PROMPT and term.attr_at(0, 0) == "green*" and term.attr_at(0, 15) == "green*" and term.attr_at(0, 16) == "foreground" and term.attr_at(0, 17) == "blue*" and term.attr_at(0, 18) == "foreground" and term.attr_at(2, 0) == "blue" and term.attr_at(upline, 0) == "yellow")
	var night := OpenerPalette.named("night")
	var drawn := term.colors()
	_check("acceptance: the palette applied: the desktop, border, background, text and cursor drawn in the demo palette's darker_background, accent, background, foreground and bright_foreground", drawn["desktop"] == night.color("darker_background") and drawn["border"] == night.color("accent") and drawn["background"] == night.color("background") and drawn["foreground"] == night.color("foreground") and drawn["cursor"] == night.cursor() and o.palette() == night)
	_check("acceptance: the main loop ticks through the crash: %d frozen frames, each one tick of the opener and one of the engine (%d off), the frozen frame held on screen all the while, the arena's 3D view not drawn under it" % [frozen, ticks_bad], frozen > 100 and ticks_bad == 0 and held and hidden_3d)
	var glitch_s := t.cut_at - t.live_s
	_check("the crash comes apart and never strobes: the glitch only grows, its pattern changing %d times in %.1f s (at most %.0f a second), the buzz on through it and the crackle with it, then silence until the hum" % [seeds, glitch_s, t.glitch_hz], not amount_down and seeds <= ceili(glitch_s * t.glitch_hz) + 1 and seeds >= 10 and buzz_ok and crackle and silent_gap and hum)
	var levels := PackedFloat32Array()
	for i in int(t.end_at * FPS) + 1:
		levels.append(o.luma_at(i / FPS))
	_check("acceptance: the flash-rate cap: the screen's brightness drops to black and back at most %d times in any second (worst %d), and the darkness and the pop-in are drawn from that model (%d and %d frames off)" % [MOST_FLASHES, _worst_flashes(levels), dark_bad, pop_bad], _worst_flashes(levels) <= MOST_FLASHES and dark_bad == 0 and pop_bad == 0)
	_check("acceptance: the beats before the punchlines, in the run: %.2f s between \"script,\" and \"d\", %.2f s between \"last night.\" and \"so was I.\"; the typo seen and taken back" % [did_at - comma_at, echo_at - head_at], did_at - comma_at >= t.install_beat * 0.9 and echo_at - head_at >= t.late_beat * 0.9 and saw_typo)
	var span: float = ev.get("done", 0.0) - ev.get("uptime", 0.0)
	var ticking := uptimes.size() >= floori(span) and uptimes.size() <= ceili(span) + 1
	for i in uptimes.size():
		ticking = ticking and uptimes[i][1] == Opener.uptime_text(DemoOpenerData.UPTIME_S + floori(uptimes[i][0]))
	_check("acceptance: the uptime ticks live, a second at a time from where it started (%s ... %s)" % [uptimes[0][1] if not uptimes.is_empty() else "", uptimes[-1][1] if not uptimes.is_empty() else ""], ticking)
	_check("the hold and the wait: the cursor blinking on its own line and at the fresh prompt (%d changes), the torn band at %.2f s; then, past the fall, the hand-back at %.2f s: finished once, not skipped, the machine dropped" % [flips, ev.get("tear", -1.0), ev.get("done", -1.0)], flips >= 3 and absf(ev.get("tear", -1.0) - t.tear_at) < 2.0 / FPS and absf(ev.get("done", -1.0) - t.end_at) < 2.0 / FPS and _finished == [false] and o.events()[-1][1] == "done" and o.fall() == null and o.layout() == null)
	_check("standalone (not from the menu) it pauses nothing, and it gives everything back as it ends: the 3D view drawn again, the mouse as it was, every sound stopped; key clicks heard while it typed", not paused_ever and not root.disable_3d and Input.mouse_mode == mode_before and _all_quiet(o) and key)
	o.free()


# --- A stub behind the seam. ---

func _stub_checks() -> void:
	var esc := String.chr(0x1b)
	var stub := StubData.new()
	stub.u = "ada" + esc + "[31m"
	stub.h = "engine\nroom"
	stub.pal = OpenerPalette.named("latte")
	stub.dirs = PackedStringArray(["alpha", "", esc + "[2Jbeta", "x".repeat(100)])
	stub.up = 59
	var o := _opener(stub, false)
	await _until(o, func(): return o.event_time("late_done") >= 0.0)
	var term := o.terminal()
	var text := term.all_text()
	var control := false
	for i in text.length():
		var c := text.unicode_at(i)
		control = control or (c < 32 and c != 10) or c == 0x7f
	var lines := text.split("\n")
	_check("acceptance: the data reaches the screen only through the seam: a stub's user and host make the prompt (\"%s\"), cleaned of its escape and line break" % o.prompt_text(), o.prompt_text() == "ada@engine room:~$ " and lines[0].begins_with("ada@engine room:~$ ") and not control)
	var latte := OpenerPalette.named("latte")
	var paint := (o.get_node("Screen") as ColorRect).material as ShaderMaterial
	_check("acceptance: its palette is the one drawn (latte, a light one, made readable, with the glow off so nothing blooms)", term.colors()["background"] == latte.color("background") and term.colors()["foreground"] == latte.color("foreground") and o.palette().id == latte.id and o.palette().colors == latte.readable().colors and float(paint.get_shader_parameter("glow")) == 0.0)
	_check("its folders as given, cleaned and cut: an empty name skipped, an escape dropped, a long one cut at %d (\"%s\"); its uptime ticking on from 59 s; no file times: \"%s\"" % [OpenerData.FOLDER_LONGEST, lines[4].left(24) + "...", o.late_text()], lines[2] == "~/alpha" and lines[3] == "~/beta" and lines[4] == "~/" + "x".repeat(OpenerData.FOLDER_LONGEST - 3) + "..." and lines[5].begins_with("up 00:01:") and o.late_text() == Opener.NO_TIMES + Opener.NO_TIMES_ECHO)
	o.skip()
	o.free()
	var long := StubData.new()
	long.u = "u".repeat(200)
	long.h = "h".repeat(200)
	var lo := _opener(long, false)
	await _until(lo, func(): return lo.event_time("prompt_done") >= 0.0)
	_check("a long name is cut to %d and still types itself inside 0:00 to 0:15 (done at %.2f s)" % [OpenerData.NAME_LONGEST, lo.event_time("prompt_done")], lo.prompt_text() == "u".repeat(29) + "...@" + "h".repeat(29) + "...:~$ " and lo.event_time("prompt_done") < 15.0 and lo.event_time("prompt_done") > 0.0)
	lo.skip()
	lo.free()
	var bare := _opener(OpenerData.new(), false)
	await _until(bare, func(): return bare.event_time("since_start") >= 0.0)
	var bare_lines := bare.terminal().all_text().split("\n")
	_check("an empty source still plays every beat: the demo's user and host, the default palette, no folders (the uptime straight after the install line)", bare.prompt_text() == DEMO_PROMPT and bare.palette().id == "night" and bare_lines.size() >= 3 and bare_lines[1] == PRD_INSTALL and bare_lines[2].begins_with("up 00:00:"))
	bare.skip()
	bare.free()


# --- Esc, always. ---

func _escape_checks() -> void:
	var cases := [[1.5, "frozen", "mid-crash"], [16.0, "terminal", "mid-typing"], [35.6, "hold", "in the hold"], [37.5, "ignore", "while it ignores typing"], [45.0, "reveal", "mid-reveal"], [58.0, "fall", "mid-fall"], [69.0, "landed", "landed"]]
	for c in cases:
		var mode_before := Input.mouse_mode
		var o := _opener(null, true)
		await _until(o, func(): return o.elapsed() >= c[0])
		var phase := o.phase_name()
		var was_paused := paused
		var typing: bool = c[2] == "mid-typing" and o.event_time("thanks_start") >= 0.0 and o.event_time("thanks_done") < 0.0
		var ignored := true
		var built: bool = o.fall() != null
		if c[2] == "mid-typing" or c[2] == "while it ignores typing":
			var before := o.terminal().all_text()
			for k in [KEY_A, KEY_SPACE, KEY_ENTER]:
				_key(k)
				ignored = ignored and root.is_input_handled()
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			root.push_input(click)
			ignored = ignored and root.is_input_handled() and o.playing() and o.terminal().all_text() == before
		_finished.clear()
		_key(KEY_ESCAPE)
		var at := o.elapsed()
		var held := o.is_paused() and o.menu().showing() and o.playing() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
		for f in 5:
			await process_frame
		held = held and o.elapsed() == at and _all_held(o)
		# C42: Esc pauses in the intro's own Esc menu; its "Skip intro" (focused: Enter) leaves.
		if c[2] == "mid-typing":
			_key(KEY_ENTER)
			_key(KEY_ENTER, false)
			await process_frame
		else:
			o.menu().buttons()[1].pressed.emit()
		var left: bool = not o.playing() and _finished == [true] and o.events()[-1][1] == "skipped"
		_check("acceptance (C42): Esc %s (at %.2f s, %s%s) pauses the intro at once in its own Esc menu (its clock and sounds held, the mouse shown), and %s leaves: finished, skipped" % [c[2], at, phase, ", typing \"thanks for running me.\"" if typing else "", "Enter on its focused \"Skip intro\"" if c[2] == "mid-typing" else "its \"Skip intro\""], phase == c[1] and held and left and (typing or c[2] != "mid-typing") and ignored)
		_check("... and lets go of everything: the game behind un-paused (it was paused: %s), its 3D view drawn, the mouse as it was, every sound stopped, the machine and its city dropped (built: %s)" % [str(was_paused), str(built)], was_paused and not paused and not root.disable_3d and Input.mouse_mode == mode_before and _all_quiet(o) and o.fall() == null and o.layout() == null and (built or c[0] < 3.1))
		o.free()
	var pad := _opener(null, true)
	await _until(pad, func(): return pad.elapsed() >= 2.0)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	var stopped := pad.is_paused() and pad.playing()
	root.push_input(cancel)
	var back := not pad.is_paused() and pad.playing()
	await process_frame
	_check("a pad's cancel (ui_cancel) pauses it too, mid-crash, and a second resumes it", stopped and back and pad.elapsed() > 2.0)
	pad.skip()
	_check("... and its skip leaves, the game behind let go", not pad.playing() and not paused)
	pad.free()


# --- In the arena, from the Esc menu. ---

func _menu_checks() -> void:
	var main := await _lab(PackedStringArray())
	var hud = main.get_node("Hud")
	var menu = hud.pause_menu()
	var player = main.get_node("Player")
	menu.open()
	await process_frame
	var texts := PackedStringArray()
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			texts.append((b as Button).text)
	var entry: Button = null
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == "Play the opener":
			entry = b
	# C35 put Missions after Resume; the mission's own two rows show only while one runs.
	_check("acceptance: the Esc menu has the entry, between Loadout and Settings: %s" % " | ".join(texts.slice(0, 6)), texts.slice(0, 6) == PackedStringArray(["Resume", "Missions", "Loadout", "Play the opener", "Settings", "Quit SIGKILL"]) and entry != null and not entry.disabled)
	entry.pressed.emit()
	await process_frame
	var o: Opener = menu.opener()
	_check("picking it plays the opener over everything, on demo data, the menu out of sight but still open", o != null and menu.showing_opener() and not menu.visible and menu.is_open() and o.data is DemoOpenerData and o.pause_world and o.layer > 100)
	await _until(o, func(): return o.elapsed() >= 1.0)
	_check("acceptance: alone, the arena is paused behind it from the freeze (nothing can hit the player while it plays) while the opener runs on; the window's close is Godot's own (auto-quit on)", paused and not main.can_process() and o.can_process() and o.phase_name() == "frozen" and player.input_blocked and auto_accept_quit)
	await _until(o, func(): return o.elapsed() >= 20.0)
	_key(KEY_ESCAPE)
	var stopped: bool = o.is_paused() and menu.showing_opener() and menu.is_open()
	o.menu().buttons()[1].pressed.emit()
	var back: bool = menu.visible and menu.is_open() and not menu.showing_opener() and not menu.showing_settings() and not menu.showing_loadout() and menu.version_text() != ""
	await process_frame
	_check("acceptance: Esc mid-typing pauses it in the intro's Esc menu (C42), and \"Skip intro\" brings the menu back as it was (its panel, the version in its corner), the arena running again and drawn, the player's input still held by the menu", stopped and back and not paused and main.can_process() and not root.disable_3d and player.input_blocked and not is_instance_valid(o))
	_key(KEY_ESCAPE)
	await process_frame
	_check("that Esc was the opener's alone: the next one closes the menu, as Esc does", not menu.is_open())
	var real = menu.session
	var fake := OnlineSession.new()
	main.add_child(fake)
	menu.session = fake
	menu.open()
	await process_frame
	var refused = menu.open_opener()
	_check("acceptance: in a match the entry is greyed out (\"%s\") and nothing plays: the match cannot pause for it" % entry.tooltip_text, entry.disabled and entry.tooltip_text != "" and refused == null and not menu.showing_opener() and not paused)
	menu.close()
	menu.session = real
	fake.free()
	await _drop(main)
	var flagged := await _lab(PackedStringArray(["--opener"]))
	var fmenu = flagged.get_node("Hud").pause_menu()
	await process_frame
	await process_frame
	_check("acceptance: the --opener flag plays it from the Esc menu as the arena loads, on demo data", fmenu.showing_opener() and fmenu.is_open() and fmenu.opener().data is DemoOpenerData)
	_key(KEY_ESCAPE)
	fmenu.opener().menu().buttons()[1].pressed.emit()
	await process_frame
	_check("... and Esc, then \"Skip intro\", brings that menu back", fmenu.is_open() and fmenu.visible and not fmenu.showing_opener() and not paused)
	await _drop(flagged)
	var reloaded := await _lab(PackedStringArray(["--opener"]))
	await process_frame
	await process_frame
	_check("the flag is taken once a run: the arena loaded again (as R reloads it) does not play it again", not reloaded.get_node("Hud").pause_menu().showing_opener() and not reloaded.get_node("Hud").pause_menu().is_open())
	await _drop(reloaded)


# --- Helpers. ---

## An opener on `data` (null: its own demo data) in the tree, playing.
func _opener(data: OpenerData, pause_world: bool) -> Opener:
	_finished.clear()
	var o: Opener = OpenerScene.instantiate()
	o.data = data
	o.pause_world = pause_world
	o.finished.connect(func(skipped: bool): _finished.append(skipped))
	root.add_child(o)
	return o


## Frames until `condition` holds (or the opener stops, or MOST_FRAMES).
func _until(o: Opener, condition: Callable) -> void:
	var frames := 0
	while frames < MOST_FRAMES and is_instance_valid(o) and o.playing() and not condition.call():
		await process_frame
		frames += 1


func _key(code: Key, pressed: bool = true) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = pressed
	root.push_input(down)


## Every sound the opener holds paused where it was (its Esc menu up, C42).
func _all_held(o: Opener) -> bool:
	for p in o.find_children("*", "AudioStreamPlayer", true, false):
		if (p as AudioStreamPlayer).playing and not (p as AudioStreamPlayer).stream_paused:
			return false
	return true


func _all_quiet(o: Opener) -> bool:
	for p in o.find_children("*", "AudioStreamPlayer", false, false):
		if (p as AudioStreamPlayer).playing:
			return false
	return true


## The arena alone, practice on (the dummies never attack), a demo link parked for its guide HUD.
func _lab(args: PackedStringArray) -> Node:
	GameSettings.current().set_value("gameplay", "practice", true)
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = "res://tests/fixtures/opener-test-no-privacy-file.cfg"
	link.demo = true
	Link.park(link)
	var main = MainScene.instantiate()
	main.launch_args = args
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	await process_frame
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		main.free()
	_arenas.erase(main)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame


func _cleanup() -> void:
	for node in _arenas.duplicate():
		await _drop(node)
	paused = false
	GameSettings.current().reset()
	Controls.apply_binds({})
	await process_frame
	# A stopped sound is let go on the audio thread's next mix, in real time: give it that before quitting.
	OS.delay_msec(300)
	await process_frame


## WCAG's contrast ratio between two colours.
static func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(x: float) -> float: return x / 12.92 if x <= 0.04045 else pow((x + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


func _code(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## The text of function `name` in `source`, up to the next function.
func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return source.substr(at, end - at if end >= 0 else -1)

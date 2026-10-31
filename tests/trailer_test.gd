extends SceneTree
## Headless test of the teaser footage tool (T1, tools/trailer.gd and tools/trailer_capture.sh). scripts/check.sh runs
## it as step 51, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/trailer_test.gd
##
## The shot list parses: every shot an id fit for a file name, a length and a line on what is in it, every id played
## by its own function, about 80 seconds in all. The tool keeps to demo data: its refusal rules (no --demo, the
## opener's real data on in its user data, headless), checked on a privacy file in the test's own folder (never the
## player's settings); the tool itself, run headless, refusing without --demo and refusing to draw with it, and
## listing its shots; its code parking a demo guide link with the real data written off, checking the opener is on
## the demo's data, and reading nothing of the machine; the shell rendering on its private display only. Nothing is
## rendered here.

const Trailer = preload("res://tools/trailer.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")
const TOOL := "res://tools/trailer.gd"
const SHELL := "res://tools/trailer_capture.sh"
## The running order's length, in seconds: about 80, so the edit can cut to 70.
const LEAST_S := 75.0
const MOST_S := 90.0

var _fails := 0
var _checks := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var folder := "user://trailer-test-%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	_shot_checks()
	_refusal_checks(folder)
	_run_checks()
	_code_checks()
	print("TRAILER: %d checks" % _checks)
	print("TRAILER RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _shot_checks() -> void:
	var ids := {}
	var total := 0.0
	var bad := PackedStringArray()
	var source := FileAccess.get_file_as_string(TOOL)
	var id_rule := RegEx.create_from_string("^[0-9a-z]+(-[0-9a-z]+)*$")
	for shot in Trailer.SHOTS:
		var id: String = shot.get("id", "")
		var s = shot.get("s", 0.0)
		var about: String = shot.get("about", "")
		if id_rule.search(id) == null or ids.has(id) or not (s is float) or s < 1.0 or s > 8.0 or about.length() < 20:
			bad.append(id)
		if not source.contains("func _shot_%s() -> void:" % id.replace("-", "_")):
			bad.append(id + " (no function)")
		ids[id] = true
		total += float(s)
	_check("the shot list: %d shots, every one a file-name id, a length of 1 to 8 s, a line on what is in it and its own function" % Trailer.SHOTS.size(), bad.is_empty() and Trailer.SHOTS.size() >= 20, ", ".join(bad))
	_check("the running order is about 80 s (%.1f s), so the edit can cut it to 70" % total, total >= LEAST_S and total <= MOST_S)
	var weapons := 0
	for shot in Trailer.SHOTS:
		if String(shot["id"]).begins_with("05-"):
			weapons += 1
	_check("every one of the 13 weapons has its shot (%d)" % weapons, weapons == 13)
	_check("shot_named finds a shot by its id, and nothing for an unknown one", Trailer.shot_named("07-title").get("id", "") == "07-title" and Trailer.shot_named("nope").is_empty())


func _refusal_checks(folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path := folder.path_join("privacy.cfg")
	var demo := PackedStringArray(["--demo", "--shot=07-title"])
	Privacy.save_opener_real(false, path)
	_check("on demo data, with the opener's real data off, on a display: it goes ahead", Trailer.refusal(demo, "x11", path) == "")
	_check("without --demo it refuses", Trailer.refusal(PackedStringArray(["--shot=07-title"]), "x11", path).begins_with("demo data only"))
	_check("headless it refuses (it draws)", Trailer.refusal(demo, "headless", path).begins_with("headless"))
	Privacy.save_opener_real(true, path)
	var why := Trailer.refusal(demo, "x11", path)
	_check("with the opener's real data on in its user data it refuses (\"%s\")" % why, why.contains("real data"))
	Privacy.save_opener_real(false, path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(folder))
	_check("the test's own folder is gone", not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)))


## The tool itself, run headless as a separate Godot: it lists its shots, and refuses to render.
func _run_checks() -> void:
	var listed := _tool(["--list"])
	var ids := PackedStringArray()
	for line in String(listed[1]).split("\n"):
		if line.begins_with("trailer: shot "):
			ids.append(line.substr(14).strip_edges())
	_check("run with --list it lists every shot and exits 0 (%d)" % ids.size(), listed[0] == 0 and ids.size() == Trailer.SHOTS.size())
	var no_demo := _tool(["--shot=07-title"])
	_check("run without --demo it refuses and exits 3", no_demo[0] == 3 and String(no_demo[1]).contains("trailer: refused: demo data only"))
	var headless := _tool(["--demo", "--shot=07-title"])
	_check("run headless with --demo it refuses to draw and exits 3", headless[0] == 3 and String(headless[1]).contains("trailer: refused: headless"))
	var unknown := _tool(["--demo", "--shot=99-nothing"])
	_check("an unknown shot is refused, exit 3", unknown[0] == 3 and String(unknown[1]).contains("trailer: refused:"))


func _tool(user_args: Array) -> Array:
	var output := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", TOOL, "--"] + user_args
	var code := OS.execute(OS.get_executable_path(), PackedStringArray(args), output, true)
	return [code, "\n".join(output)]


func _code_checks() -> void:
	var tool := FileAccess.get_file_as_string(TOOL)
	_check("the tool parks a demo guide link with real machine data and the opener's real data written off", tool.contains("link.demo = true") and tool.contains("Privacy.save_real_data(false, PRIVACY_PATH)") and tool.contains("Privacy.save_opener_real(false, PRIVACY_PATH)"))
	_check("the tool checks the opener is on the demo's data before keeping a frame of it", tool.contains("opener.data is DemoOpenerData"))
	var reads := PackedStringArray()
	for word in ["RealOpenerData", "real_opener_source", "OS.execute", "OS.shell_open", "OS.create_process", "HTTPRequest", "OS.get_environment", "DirAccess.open(\"/", "FileAccess.open(\"/"]:
		if tool.contains(word):
			reads.append(word)
	_check("the tool reads nothing of the machine, runs nothing and calls nothing", reads.is_empty(), ", ".join(reads))
	var shell := FileAccess.get_file_as_string(SHELL)
	var safe := shell.contains("-nolisten tcp") and shell.contains("-rfbunixmode 384") and shell.contains("XDG_RUNTIME_DIR=\"$run/xdg\"") and shell.contains("-u WAYLAND_DISPLAY") and shell.contains("-- --demo") and shell.contains("archive \"$commit\"")
	_check("the shell renders a git archive copy on its private display only, demo data, fresh user data a take", safe)
	_check("the shell deletes nothing", not shell.contains("rm ") and not shell.contains("-delete"))

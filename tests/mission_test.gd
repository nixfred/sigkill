extends SceneTree
## Headless test of the mission framework for SIGKILL (C35, PRD 5.6, docs/STORY.md section 6). scripts/check.sh runs it
## as step 54, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission_test.gd
##
## The code: nothing of the chunk runs a program, opens a connection, reads the player's machine or calls an AI; its one
## write is the mission save through the settings file's writer. The data: the seven missions and the test range load
## and validate, in STORY.md's order and titles; nothing of the story shows before its mission. The handout: every
## weapon from the mission STORY.md names, all thirteen by mission 6 and never sooner, through the C33 unlocks (told
## once). The saves: written and read back; an old C33 progress.cfg loads unchanged and keeps its unlocks beside the
## missions; a missing or damaged mission save is no progress. The runner, in the real arena on the hidden test range:
## every objective kind, a log picked up, your AI's lines in the guide panel (no AI call), the Auditor's and `~`'s in the
## mission's terminal, a weapon handed over, a register transition, completion, a death failing it, Retry reloading
## into the next try, the mission's own time limit failing it. The Esc menu mid-mission (resume, restart, quit to the
## Missions screen; the clock held and the player shielded), R restarting it. The Missions screen: locked ones
## redacted, Enter starting the next one (the arena reloaded into it), whole on screen at 960x540. Net modes refused,
## and a match starting mid-mission ending it. Mission 1 played through: the rail handed over, the three weapons kept,
## mission 2 open. The opener's score stopping at once when the game quits (the C42 leftover). Its files live in its own
## folder under user://, removed at the end; nothing of the player's is read or written. Frames counted, outcomes printed.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Session = preload("res://scripts/net/net_session.gd")
const NetTuningScript = preload("res://scripts/net/net_tuning.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsFile = preload("res://scripts/settings/settings_file.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const PauseMenu = preload("res://scripts/hud/pause_menu.gd")

const C35_CODE := ["res://scripts/missions/mission_def.gd", "res://scripts/missions/mission_book.gd", "res://scripts/missions/mission_progress.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_log_pickup.gd", "res://scripts/missions/mission_beacon.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/mission_end_screen.gd", "res://scripts/hud/missions_screen.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "ENetMultiplayerPeer", "WebSocket", "WebRTC", "FileAccess.open", "get_file_as_string", "get_file_as_bytes", "DirAccess", "store_var", "get_var", "bytes_to_var", "str_to_var", "JavaScriptBridge", "http://", "https://", "OS.get_environment", "get_user_data_dir", "get_executable_path", "OpenerData", "AiSourceDetector", "session_link", "Adapter", "GuideRequest", "nvidia", "/proc", "/sys/", "/home"]
const TITLES := ["login", "defunct", "while true", "permission denied", "sudo !!", "nohup", "kill -9"]
## STORY.md section 6, "New in your hands", by mission.
const HANDOUT := [["terminal_cannon", "sigterm", "sigkill_rail"], ["ping_sonar", "fork_bomb", "fork_shotgun"], ["grep_seeker", "pipe_chain"], ["chmod_000"], ["cron_mines", "rm_rf_cannon"], ["sighup", "dev_null"], []]
const MOST_FRAMES := 3000
const LONG_ROUND_S := 100000.0
const FRONT := Vector3(0, 0.95, 10)

var _fails := 0
var _checks := 0
var _root := ""
var _abs := ""
var _toasts: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://mission-test-%d" % OS.get_process_id()
	_abs = ProjectSettings.globalize_path(_root)
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	_check("a headless run's mission progress has no path and nothing done: the player's own save is never read or written", MissionProgress.current().path == "" and MissionProgress.current().done.is_empty() and not MissionProgress.current().save())
	Progress.current().unlocked.connect(_on_toast)
	_code_checks()
	_data_checks()
	_handout_checks()
	_save_checks()
	_score_checks()
	await _runner_checks()
	await _fail_checks()
	await _menu_checks()
	await _net_checks()
	await _login_checks()
	await _cleanup()
	print("MISSIONS: %d checks" % _checks)
	print("MISSIONS RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _on_toast(weapon: String, item: String, _title: String) -> void:
	_toasts.append([weapon, item])


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	var all := ""
	for path in C35_CODE:
		var code := FileAccess.get_file_as_string(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no reads of the player's machine anywhere in mission code, and no real AI call: nothing of the chunk runs a program, opens a connection or a file of its own, reads the environment, a path, a process, the GPU or the opener's data, or reaches an AI adapter or the guide's link", found.is_empty() and all.length() > 20000, ", ".join(found))
	var writes := 0
	for path in C35_CODE:
		writes += FileAccess.get_file_as_string(path).count("SettingsFile.write_sections(")
	var progress := FileAccess.get_file_as_string("res://scripts/missions/mission_progress.gd")
	_check("acceptance: the one write is the mission save, [missions] of user://progress.cfg, through the settings file's strict, atomic writer (never outside user://)", writes == 1 and progress.count("SettingsFile.write_sections(path, {SECTION: keys})") == 1 and MissionProgress.DEFAULT_PATH == Progress.DEFAULT_PATH and Progress.DEFAULT_PATH == "user://progress.cfg")
	var runner := FileAccess.get_file_as_string("res://scripts/missions/mission_runner.gd")
	var hud := FileAccess.get_file_as_string("res://scripts/hud/mission_hud.gd")
	_check("acceptance: your AI's mission lines are story lines: they reach the guide panel through story_line() alone, never the player's own AI", hud.contains("guide.story_line(text, ms)") and not runner.contains("story_line") and not runner.contains("GuideHud") and FileAccess.get_file_as_string("res://scripts/hud/guide_hud.gd").contains("func story_line(text: String, ms: float = -1.0) -> bool:"))
	var data_files := PackedStringArray()
	for name in DirAccess.get_files_at("res://resources/missions"):
		if name.ends_with(".tres"):
			data_files.append("res://resources/missions/" + name)
	var listed := PackedStringArray(MissionBook.CAMPAIGN)
	listed.append(MissionBook.TEST_RANGE)
	var all_listed := data_files.size() == listed.size()
	for path in data_files:
		all_listed = all_listed and listed.has(path)
	_check("the missions are data, not code: one .tres each in resources/missions/, every one of them in the book's fixed list (no folder scan at run time)", all_listed and data_files.size() == 8 and not FileAccess.get_file_as_string("res://scripts/missions/mission_book.gd").contains("DirAccess"), ", ".join(data_files))


# --- The data. ---

func _data_checks() -> void:
	var problems := MissionBook.problems()
	_check("acceptance: all 7 mission defs load and validate (and the test range): MissionBook.problems() is empty", problems.is_empty(), "; ".join(problems))
	var defs := MissionBook.campaign()
	var titles := PackedStringArray()
	var orders := []
	for def in defs:
		titles.append(def.title)
		orders.append(def.order)
	_check("the seven are STORY.md's, in its order: %s" % ", ".join(titles), titles == PackedStringArray(TITLES) and orders == [1, 2, 3, 4, 5, 6, 7])
	var registers := PackedStringArray()
	for def in defs:
		registers.append(def.register)
	_check("each in STORY.md's register (Tron into ruins, ruins, Matrix, Tron, Tron into Matrix, the deepest ruins, all three), with its own transition where it changes", registers == PackedStringArray(["tron", "cyberpunk", "matrix", "tron", "tron", "cyberpunk", "all"]) and _shifts_to(defs[0]) == "cyberpunk" and _shifts_to(defs[4]) == "matrix")
	var skeletons := true
	for i in range(1, defs.size()):
		skeletons = skeletons and not defs[i].playable and not defs[i].draft and not defs[i].objectives.is_empty()
	_check("mission 1 is a playable first cut on today's arena (C37 builds it for real); 2 to 7 are skeletons with their objectives, logs and lines in place, listed but not yet startable", defs[0].playable and defs[0].draft and skeletons)
	var t := MissionBook.test_range()
	var kinds := {}
	var gives := false
	for o in t.objectives:
		kinds[o["kind"]] = true
		gives = gives or not o.get("gives", []).is_empty()
	var whos := {}
	var triggers := {}
	for line in t.lines:
		whos[line["who"]] = true
		triggers[str(line["on"]).get_slice(":", 0)] = true
	for shift in t.transitions:
		triggers[str(shift["on"]).get_slice(":", 0)] = true
	_check("acceptance: the stub mission (hidden, not one of the seven, recording nothing) has every objective kind, a weapon handed over, an optional log, lines by your AI, the Auditor and `~`, transitions, and every kind of trigger", t.hidden and t.order == 0 and t.playable and kinds.keys().size() == 4 and gives and t.logs.size() == 2 and whos.size() == 3 and not t.transitions.is_empty() and triggers.has("start") and triggers.has("begin") and triggers.has("done") and triggers.has("log") and triggers.has("at") and triggers.has("complete") and triggers.has("fail") and not MissionBook.campaign().has(t))
	var bad := t.duplicate(true) as MissionDef
	bad.objectives = [{"id": "x", "kind": "kill", "daemon": "dragon", "count": 0, "text": "x"}, {"id": "x", "kind": "fly", "text": ""}]
	bad.lines = [{"on": "done:nowhere", "who": "narrator", "text": "x"}]
	bad.grants = PackedStringArray(["bfg"])
	_check("a mission's validator refuses bad data by name: an unknown daemon, a zero count, a repeated id, an unknown kind, a trigger naming nothing, an unknown speaker, an unknown weapon", bad.problems(MissionBook.weapon_ids()).size() >= 7, "; ".join(bad.problems(MissionBook.weapon_ids())))
	# Spoilers (STORY.md): who `~` is lands in mission 5, the ending in mission 7; nothing earlier shows either.
	var leaks := PackedStringArray()
	for def in defs:
		var words := _shown_words(def).to_lower()
		if def.order < 5:
			for w in ["6666", "nohup", "never logged out", "never hung up"]:
				if words.contains(w):
					leaks.append("%s: %s" % [def.id, w])
		if def.order < 7:
			for w in ["session restored", "welcome back", "you won't", "sigkill sent by you"]:
				if words.contains(w):
					leaks.append("%s: %s" % [def.id, w])
	_check("acceptance: nothing a player can see before the right mission tells who `~` is (missions 1 to 4 never say 6666 or nohup) or the ending (only mission 7 has it)", leaks.is_empty(), ", ".join(leaks))


func _shifts_to(def: MissionDef) -> String:
	return str(def.transitions[0]["to"]) if not def.transitions.is_empty() else ""


## Every word of `def` a player could see in it: title, goal, objectives, logs, lines.
func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", ""))
	for entry in def.logs:
		out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	return out


# --- The handout. ---

func _handout_checks() -> void:
	var ids := MissionBook.weapon_ids()
	var cumulative := PackedStringArray()
	var by_book := true
	var never_sooner := true
	for i in MissionBook.campaign().size():
		var def: MissionDef = MissionBook.campaign()[i]
		cumulative.append_array(PackedStringArray(HANDOUT[i]))
		by_book = by_book and _same(MissionBook.granted_by(def.order), cumulative) and _same(def.grants, PackedStringArray(HANDOUT[i]))
		for w in def.carried_ever():
			never_sooner = never_sooner and cumulative.has(w)
	_check("acceptance: each mission hands out what STORY.md says it teaches (cannon, SIGTERM and the rail; ping, fork bomb and fork(); grep and pipe; chmod 000; cron and rm -rf; SIGHUP and /dev/null; the finale nothing)", by_book)
	_check("acceptance: never earlier than STORY.md says: no mission ever puts a weapon in hand before the mission that hands it out", never_sooner)
	_check("acceptance: all 13 by mission 6, not one fewer: %d after mission 5, %d after mission 6" % [MissionBook.granted_by(5).size(), MissionBook.granted_by(6).size()], MissionBook.granted_by(6).size() == 13 and MissionBook.granted_by(5).size() == 11 and _same(MissionBook.granted_by(6), ids))
	# Through the save: the C33 unlocks keep each, told once.
	var file := _abs.path_join("handout.cfg")
	var p := Progress.current()
	var m := MissionProgress.current()
	p.path = file
	p.clear()
	m.path = file
	m.clear()
	_toasts.clear()
	var in_step := true
	var told_once := true
	for i in MissionBook.campaign().size():
		var def: MissionDef = MissionBook.campaign()[i]
		var before := _toasts.size()
		var kept := m.record(def, 100.0 + i, 0)
		in_step = in_step and _same(kept["granted"], PackedStringArray(HANDOUT[i]))
		for w in ids:
			in_step = in_step and p.has_weapon(w) == MissionBook.granted_by(def.order).has(w)
		told_once = told_once and _toasts.size() - before == HANDOUT[i].size()
	var again := m.record(MissionBook.at(1), 50.0, 1)
	_check("acceptance: finishing missions 1 to 7 in turn unlocks, through the C33 unlocks, exactly the weapons handed out so far after each (never one early), each told once by the unlock toast (a replay tells nothing new)", in_step and told_once and (again["granted"] as PackedStringArray).is_empty() and again["best"] and not again["first"])
	var p2 := Progress.new()
	p2.path = file
	p2.load_file()
	var m2 := MissionProgress.new()
	m2.path = file
	m2.load_file()
	var all_held := true
	for w in ids:
		all_held = all_held and p2.has_weapon(w)
	_check("acceptance: progress saves and reloads: a fresh load holds all 13 campaign weapons and all 7 missions done, with their best times", all_held and m2.done.size() == 7 and absf(float(m2.best_s["login"]) - 50.0) < 0.05 and m2.last_load == "loaded" and p2.last_load == "loaded")
	var hidden := m.record(MissionBook.test_range(), 1.0, 0)
	_check("the test range is never recorded", not hidden["first"] and not m.is_done("test_range"))
	p.reset()
	m.reset()
	_check("reset progress wipes the missions and the weapons they handed out", m.done.is_empty() and not p.has_weapon("sigterm"))
	p.path = ""
	m.path = ""


func _same(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


# --- The saves. ---

func _save_checks() -> void:
	var missing := MissionProgress.new()
	missing.path = _abs.path_join("none.cfg")
	missing.load_file()
	_check("acceptance: a missing mission save is no progress: nothing done, mission 1 next and open, mission 2 locked", missing.last_load == "missing" and missing.done.is_empty() and missing.next_up() == MissionBook.at(1) and missing.is_open(MissionBook.at(1)) and not missing.is_open(MissionBook.at(2)))
	var old := _abs.path_join("c33.cfg")
	_write(old, "[meta]\nversion=1\n\n[progress]\nformat=1\n\n[feats]\nkills_terminal_cannon=30\nrail_heads=2\n\n[unlocked]\nterminal_cannon__tty1=true\nterminal_cannon__overclock=true\n\n[loadout]\nskin_terminal_cannon=\"tty1\"\nmod_terminal_cannon=true\n")
	var p := Progress.new()
	p.path = old
	p.load_file()
	var m := MissionProgress.new()
	m.path = old
	m.load_file()
	_check("acceptance: an old C33 progress.cfg still loads: its unlocks, choices and counts as they were, and no mission done (it has no [missions] yet)", p.last_load == "loaded" and p.has("terminal_cannon", "tty1") and p.skin_of("terminal_cannon") == "tty1" and p.mod_on("terminal_cannon") and p.count_of("kills_terminal_cannon") == 30 and m.last_load == "loaded" and m.done.is_empty())
	var cp := Progress.current()
	cp.path = old
	cp.load_file()
	m.record(MissionBook.at(1), 61.25, 1)
	var p2 := Progress.new()
	p2.path = old
	p2.load_file()
	var m2 := MissionProgress.new()
	m2.path = old
	m2.load_file()
	var text := FileAccess.get_file_as_string(old)
	_check("acceptance: and keeps its unlocks once a mission saves beside them: tty1, the overclock mod and the 30 kills still there, the mission done and its weapons held, in one file", p2.has("terminal_cannon", "tty1") and p2.mod_on("terminal_cannon") and p2.count_of("kills_terminal_cannon") == 30 and p2.has_weapon("sigkill_rail") and m2.is_done("login") and absf(float(m2.best_s["login"]) - 61.3) < 0.051 and text.contains("[missions]") and text.contains("terminal_cannon__tty1=true") and text.contains("done_login=true"))
	cp.path = ""
	cp.clear()
	var damaged := _abs.path_join("damaged.cfg")
	_write(damaged, "[missions" + char(1) + "garbage = = Object(Node)\n")
	var md := MissionProgress.new()
	md.path = damaged
	md.load_file()
	_write(_abs.path_join("newer.cfg"), "[meta]\nversion=1\n\n[missions]\nformat=2\ndone_login=true\n")
	var mn := MissionProgress.new()
	mn.path = _abs.path_join("newer.cfg")
	mn.load_file()
	_write(_abs.path_join("wrong.cfg"), "[meta]\nversion=1\n\n[missions]\nformat=1\ndone_login=\"yes\"\ndone_bogus=true\nbest_defunct=30.0\ndone_defunct=true\nlogs_defunct=99\n")
	var mw := MissionProgress.new()
	mw.path = _abs.path_join("wrong.cfg")
	mw.load_file()
	_check("acceptance: a damaged mission save is no progress, never a crash: garbage, a newer format, and a wrong kind of value each read as nothing done for it (an unknown mission and an impossible log count dropped)", md.last_load == "unreadable" and md.done.is_empty() and mn.last_load == "unreadable" and mn.done.is_empty() and not mw.is_done("login") and not mw.done.has("bogus") and mw.is_done("defunct") and absf(float(mw.best_s.get("defunct", 0.0)) - 30.0) < 0.01 and not mw.best_logs.has("defunct"))


func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- The opener's score, stopped as the game quits (the C42 leftover). ---

func _score_checks() -> void:
	OpenerScore.forget()
	OpenerScore.begin()
	OS.delay_msec(60)
	var t0 := Time.get_ticks_msec()
	OpenerScore.cancel()
	OpenerScore.forget()
	var waited := Time.get_ticks_msec() - t0
	_check("the C42 leftover: quitting while the opener's score is being made no longer waits out the build: cancel() stops the worker at its next note (waited %d ms; the whole build is about 3000), nothing half made is kept" % waited, waited < 600 and not OpenerScore.done() and OpenerScore.stream("bed") == null)
	_check("the window's close cancels it (the arena's own close request)", FileAccess.get_file_as_string("res://scripts/main.gd").contains("OpenerScore.cancel()"))


# --- The runner, on the test range in the real arena. ---

func _runner_checks() -> void:
	var main := await _arena(true)
	var runner := MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var player = main.get_node("Player")
	var link: Link = hud.guide().session_link()
	var calls_before := link.calls
	var t := MissionBook.test_range()
	_check("the arena has its mission runner, idle, and the mission HUD showing nothing", runner != null and runner.state == MissionRunner.State.IDLE and mh.shown_text().is_empty())
	var began := runner.begin(t)
	var second := runner.begin(MissionBook.at(1))
	await _frames(2)
	_check("one mission runs at a time: a second begin() is refused while the first runs", not second and runner.def == t)
	_check("acceptance: begin() starts it: the card up (its title, its goal), the round clock held and its line gone, ICE stood down, only its loadout carried (the cannon: SIGTERM refuses to draw, the strip shows the rest as dashes)", began and runner.state == MissionRunner.State.INTRO and mh.showing_card() and mh.shown_text().has(t.goal) and hud.round_hud().held and not hud.round_hud().round_label().visible and runner.ice.stand_down and not player.select_slot(1) and player.carried == PackedStringArray(["terminal_cannon"]) and hud.weapon_hud().slots_text().contains("-"))
	_check("the Auditor's \"start\" line waits under the card (the terminal holds it back)", mh.showing_card() and not _shown_has(mh, "audit: user=test"))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	_check("after its card, the first objective runs, typed in on the panel: \"> Stay up for a second\" with its survive bar", runner.index == 0 and await _until(func(): return _shown_has(mh, "> Stay up for a second")) and mh.progress_text().contains("/ 00:01"))
	await _until(func(): return runner.index == 1)
	_check("acceptance (survive): a second of play does it; the next objective, kill, begins", runner.index == 1 and runner.objective()["kind"] == "kill")
	_check("acceptance (AI dialogue trigger): \"begin:shoot\" puts your AI's story line in the guide panel as \"your AI\", the scripted guide's, with no AI call", await _until(func(): return hud.guide().panel_text().contains("Range is live. One rogue.d, no tricks.")) and hud.guide().panel_text().begins_with("your AI\n") and link.calls == calls_before)
	_check("then the Auditor's \"start\" line types into the mission's terminal as the card goes", await _until(func(): return _shown_has(mh, "audit: user=test action=enter path=/range result=OK")))
	_check("the `~` line at:0.5 typed into the terminal in its own prompt", await _until(func(): return _shown_has(mh, "~ $ range online")))
	var zombie = main.get_node("Arena/Targets/DummyB")
	zombie.hit(1000.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	await _frames(2)
	_check("acceptance (kill N by type): a zombie down does not count toward \"Take down the rogue.d\"", runner.index == 1 and runner.progress == 0.0 and runner.kills == 1)
	var rogue = main.get_node("Arena/Targets/DummyA")
	rogue.hit(1000.0, Vector3.INF, Vector3.ZERO, "terminal_cannon")
	await _frames(2)
	_check("acceptance (kill N by type) and the weapon grant: the rogue.d down finishes it, SIGTERM handed over (said in the terminal) and now drawn by its key", runner.index == 2 and runner.carried.has("sigterm") and player.select_slot(1) and await _until(func(): return _shown_has(mh, ">> SIGTERM handed to you")))
	var at: Vector3 = t.log_of("note")["at"]
	_check("acceptance (log pickup): the log stands in the arena as a terminal, and the marker points at it", runner.pickup("note") != null and runner.target_point().distance_to(at) < 0.01 and mh.progress_text().begins_with("find range.txt"))
	player.global_position = at
	await _frames(3)
	_check("acceptance (log pickup): walking through it picks it up: the reader shows \"$ cat range.txt\", the objective is done, and its \"done\" transition shifts the register to matrix", runner.logs_found.has("note") and mh.showing_log() and _shown_has(mh, "$ cat range.txt") and runner.index == 3 and runner.register == "matrix")
	_check("the beacon stands at the reach point, the HUD's marker on it", runner.beacon() != null and runner.beacon().global_position.distance_to(t.objectives[3]["at"]) < 0.01 and mh.progress_text().begins_with("marker"))
	player.global_position = t.objectives[3]["at"] + Vector3(0.6, 0, 0.4)
	await _frames(3)
	_check("acceptance (reach a point): standing inside its radius completes the mission: every objective done, the register back to tron, the player shielded", runner.state == MissionRunner.State.COMPLETE and runner.register == "tron" and runner.life.protected())
	_check("its result: the objectives' kills, 1 of 2 logs (the spare one optional), its first try; the test range records nothing and hands out nothing for keeps", runner.result["kills"] == 2 and runner.result["logs"] == 1 and runner.result["logs_total"] == 2 and runner.result["attempt"] == 1 and not MissionProgress.current().is_done("test_range") and (runner.result["granted"] as PackedStringArray).is_empty() and MissionRunner.pending() == "")
	var end := mh.end_screen()
	await _until(func(): return end.is_up())
	_check("acceptance: complete shows its end screen: \"exit 0\", COMPLETE, its numbers; no next mission for the range, so Missions has the focus; the mouse free and the player stopped", end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and not end.buttons()[0].visible and end.buttons()[1].has_focus() and player.input_blocked)
	_check("no AI was called through the whole mission (the guide link's count unchanged)", link.calls == calls_before)
	end.hide_screen()
	# The mission's own fail rule: its time limit.
	var timed := t.duplicate(true) as MissionDef
	timed.fail_time_s = 0.8
	var main2 := await _arena(true)
	var runner2 := MissionRunner.of(main2)
	runner2.begin(timed)
	await _until(func(): return runner2.state == MissionRunner.State.FAILED)
	_check("acceptance (fail by the mission's own rule): its time limit runs out: failed, \"the timeslice ran out\", its logs and beacon cleared away", runner2.state == MissionRunner.State.FAILED and runner2.reason == MissionRunner.TIMED_OUT and runner2.pickup("note") == null)
	_check("a mission that is not built yet is refused (mission 2 is a skeleton)", not runner2.begin(MissionBook.at(2)) and runner2.state == MissionRunner.State.FAILED)


# --- A death failing it, and Retry. ---

func _fail_checks() -> void:
	var main := await _arena(false)
	var runner := MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	MissionRunner.queue("test_range", 1)
	main = await _reload(main)
	runner = MissionRunner.of(main)
	hud = main.get_node("Hud")
	mh = hud.mission_hud()
	_check("acceptance: a queued mission begins as the arena loads (the Missions screen's way in), as its first try", runner.state == MissionRunner.State.INTRO and runner.def.id == "test_range" and runner.attempt == 1 and MissionRunner.pending() == "test_range")
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var life: SoloLife = runner.life
	var rogue = main.get_node("Arena/Targets/DummyA")
	life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	life.damage(10000.0, rogue, Vector3.FORWARD)
	await _frames(2)
	_check("acceptance (fail by death): the player derezzed fails it, said by what", runner.state == MissionRunner.State.FAILED and runner.reason == "derezzed by rogue.d")
	_check("its \"fail\" line goes to your AI", await _until(func(): return hud.guide().panel_text().contains("Again. It's a range.")))
	var end := mh.end_screen()
	await _until(func(): return end.is_up())
	_check("acceptance: failed shows \"exit 137\" in red, why, how far it got, and Retry focused (Enter retries)", end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and _text_has(end.shown_text(), "derezzed by rogue.d") and _text_has(end.shown_text(), "1/4  Stay up for a second") and end.buttons()[0].text == "Retry" and end.buttons()[0].has_focus())
	var old_id := main.get_instance_id()
	end.buttons()[0].pressed.emit()
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	mh = main.get_node("Hud").mission_hud()
	_check("acceptance (retry): Retry reloads the arena into the same mission's next try: a fresh floor, a full life, \"try 2\" on its card", runner != null and runner.running() and runner.def.id == "test_range" and runner.attempt == 2 and runner.life.alive() and _shown_has(mh, "try 2"))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	old_id = main.get_instance_id()
	_key(KEY_R)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	_check("R (respawn) mid-mission reloads into its next try, as Retry does", runner != null and runner.running() and runner.attempt == 3)
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	runner = MissionRunner.of(main)
	_check("Free play: a fresh arena with no mission, the round clock running, everything carried", runner.state == MissionRunner.State.IDLE and not main.get_node("Hud").round_hud().held and main.get_node("Player").carried.is_empty() and MissionRunner.pending() == "")
	await _drop(main)


# --- The Esc menu and the Missions screen. ---

func _menu_checks() -> void:
	MissionProgress.current().clear()
	var main := await _arena(true)
	var hud = main.get_node("Hud")
	var menu: PauseMenu = hud.pause_menu()
	menu.open()
	await _frames(1)
	var shown := _visible_buttons(menu)
	_check("acceptance: the main (Esc) menu has Missions, after Resume: %s" % " | ".join(shown), shown.slice(0, 3) == PackedStringArray(["Resume", "Missions", "Loadout"]))
	menu.open_missions()
	await _frames(20)
	var screen := menu.missions_screen()
	var texts := screen.texts()
	var locked_hidden := true
	for i in range(1, 7):
		var def: MissionDef = MissionBook.campaign()[i]
		locked_hidden = locked_hidden and texts.has("%s ??? LOCKED" % def.number())
		for line in texts:
			locked_hidden = locked_hidden and not line.contains(def.goal) and not (line.contains(def.title) and def.title != "login")
	_check("acceptance: the Missions screen lists the 7: mission 1 NEXT, the locked six shown locked as \"???\", their titles and goals redacted", screen.is_open() and texts.has("01 login NEXT") and locked_hidden, " | ".join(texts))
	screen.select(3)
	_check("a locked one cannot start (START reads LOCKED)", not screen.can_start(3) and not screen.start_selected() and screen.texts().has(MissionsScreen.LOCKED))
	screen.select(0)
	var old_id := main.get_instance_id()
	_key(KEY_ENTER)
	main = await _after_reload(old_id)
	var runner := MissionRunner.of(main)
	_check("acceptance: picking one starts it: Enter on login closes the menu and reloads the arena into mission 1", runner != null and runner.running() and runner.def.id == "login" and not main.get_node("Hud").pause_menu().is_open())
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	hud = main.get_node("Hud")
	menu = hud.pause_menu()
	var player = main.get_node("Player")
	_key(KEY_ESCAPE)
	await _frames(2)
	shown = _visible_buttons(menu)
	var clock := runner.clock
	await _frames(30)
	_check("acceptance: Esc mid-mission opens the menu with resume, restart mission and quit (to the Missions screen); Missions itself and the opener give way while it runs: %s" % " | ".join(shown), menu.is_open() and shown.slice(0, 3) == PackedStringArray(["Resume", "Restart mission", "Quit mission"]) and not shown.has("Missions") and _button(menu, "Play the opener").disabled)
	_check("while the menu is up the mission's clock holds and nothing can hurt the player", runner.clock == clock and not runner.engaged() and runner.life.protected())
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("Esc again resumes: the menu shut, the clock running", not menu.is_open() and await _until(func(): return runner.clock > clock))
	menu.open()
	await _frames(1)
	old_id = main.get_instance_id()
	_button(menu, "Restart mission").pressed.emit()
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	_check("Restart mission reloads into its next try", runner != null and runner.running() and runner.def.id == "login" and runner.attempt == 2)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(1)
	old_id = main.get_instance_id()
	_button(menu, "Quit mission").pressed.emit()
	main = await _after_reload(old_id)
	menu = main.get_node("Hud").pause_menu()
	await _frames(2)
	_check("acceptance: Quit mission goes back to the menu: a fresh arena with no mission and the Missions screen open over it", MissionRunner.of(main).state == MissionRunner.State.IDLE and menu.showing_missions() and MissionRunner.pending() == "")
	MissionProgress.current().done["login"] = true
	MissionProgress.current().best_s["login"] = 75.0
	menu.missions_screen().open()
	await _frames(2)
	texts = menu.missions_screen().texts()
	_check("with login done: 01 DONE (with its best), 02 defunct open but IN PRODUCTION (not built yet: START says so), 03 still redacted", texts.has("01 login DONE") and texts.has("02 defunct IN PRODUCTION") and texts.has("03 ??? LOCKED") and not menu.missions_screen().can_start(1), " | ".join(texts))
	for size in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		var frame := menu.missions_screen().frame_rect()
		var view := Rect2(Vector2.ZERO, Vector2(size))
		var rows_in := true
		for i in 7:
			rows_in = rows_in and frame.encloses(menu.missions_screen().row_rect(i))
		_check("acceptance (Law 17) at %dx%d: the whole screen fits the window, every row and START inside it, no scroll anywhere in it" % [size.x, size.y], view.encloses(frame) and rows_in and frame.encloses(menu.missions_screen().start_rect()) and menu.missions_screen().find_children("*", "ScrollContainer", true, false).is_empty())
	root.size = Vector2i(1280, 720)
	_key(KEY_ESCAPE)
	await _frames(2)
	_check("Esc on the Missions screen goes back to the menu", not menu.showing_missions() and menu.is_open())
	MissionProgress.current().clear()
	menu.close()
	await _drop(main)


# --- Net modes. ---

func _net_checks() -> void:
	var side := _branch()
	await _frames(3)
	var main: Node = side["main"]
	var runner := MissionRunner.of(main)
	var menu: PauseMenu = main.get_node("Hud").pause_menu()
	var session = side["session"]
	runner.begin(MissionBook.test_range())
	await _frames(2)
	_check("alone (a session beside the arena, not in a match) a mission runs", runner.running())
	session.host(0)
	await _frames(3)
	_check("acceptance: a match starting mid-mission ends it where it stands: its loadout lifted, the round clock and ICE back", runner.state == MissionRunner.State.IDLE and main.get_node("Player").carried.is_empty() and not main.get_node("Hud").round_hud().held and not runner.ice.stand_down and MissionRunner.pending() == "")
	_check("acceptance: missions are refused in net modes: begin() refuses in a match", session.is_online() and not runner.begin(MissionBook.test_range()) and not runner.running())
	menu.open()
	await _frames(1)
	_check("acceptance: and the Esc menu's Missions is greyed out in a match (solo only); the screen will not open", _button(menu, "Missions").disabled and not menu.open_missions() and not menu.showing_missions())
	var screen := menu.missions_screen()
	screen.session = session
	_check("the Missions screen itself starts nothing in a match (START says SOLO ONLY)", not screen.can_start(0) and screen.texts().has("SOLO ONLY"))
	menu.close()
	session.leave()
	await _drop_branch(side)


# --- Mission 1 played through. ---

func _login_checks() -> void:
	MissionProgress.current().path = _abs.path_join("login.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("login.cfg")
	Progress.current().clear()
	var main := await _arena(true)
	var runner := MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var player = main.get_node("Player")
	var login := MissionBook.at(1)
	_toasts.clear()
	runner.begin(login)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	_check("mission 1 starts with the cannon and SIGTERM in hand (the rail not yet), the floor to hold for 20 s, \"MISSION 01\" on the panel", player.carried == PackedStringArray(["terminal_cannon", "sigterm"]) and not player.select_slot(2) and runner.objective()["id"] == "floor" and _shown_has(mh, "MISSION 01"))
	_check("your AI's first line: \"Arena's quiet...\"", await _until(func(): return hud.guide().panel_text().contains("Arena's quiet.")))
	await _until(func(): return runner.index == 1)
	_check("20 seconds of play hold the floor", runner.index == 1 and runner.clock >= 20.0)
	var rogue = main.get_node("Arena/Targets/DummyA")
	for i in 2:
		await _until(func(): return rogue.is_alive())
		rogue.hit(1000.0, Vector3.INF, Vector3.ZERO, "sigterm")
		await _frames(2)
	_check("two rogue.d down: the rail is handed over (\"kill -9 handed to you\") and draws on 3", runner.index == 2 and runner.carried.has("sigkill_rail") and player.select_slot(2) and await _until(func(): return _shown_has(mh, ">> kill -9 handed to you")))
	player.global_position = login.log_of("temporary")["at"]
	await _frames(3)
	_check("the first log: \"# temporary. remove after the migration.\" in the reader", runner.index == 3 and await _until(func(): return _shown_has(mh, "# temporary. remove after the migration.")))
	player.global_position = login.objectives[3]["at"]
	await _frames(3)
	_check("acceptance: mission 1 completes at the vent: the grid splits into the ruins (the register shifts to cyberpunk)", runner.state == MissionRunner.State.COMPLETE and runner.register == "cyberpunk")
	var held := true
	for w in HANDOUT[0]:
		held = held and Progress.current().has_weapon(w)
	_check("acceptance: its three weapons kept for keeps through the unlocks (three toasts), mission 1 recorded done with its time, mission 2 now open", held and _toasts.size() == 3 and MissionProgress.current().is_done("login") and MissionProgress.current().is_open(MissionBook.at(2)) and not Progress.current().has_weapon("ping_sonar"))
	var end := mh.end_screen()
	await _until(func(): return end.is_up())
	var lines := end.shown_text()
	_check("its end screen: \"exit 0\", the weapons HANDED TO YOU, and Next: 02 defunct shown but in production (not yet built), so Missions has the focus", _text_has(lines, "exit 0") and _text_has(lines, "HANDED TO YOU") and _text_has(lines, "kill -9  [3]") and end.buttons()[0].visible and end.buttons()[0].disabled and end.buttons()[0].text.contains("02  defunct") and end.buttons()[1].has_focus(), " | ".join(lines))
	for size in [Vector2i(960, 540), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		var panel := end.panel_rect()
		_check("the end screen at %dx%d: whole in the window, under the unlock toast's strip (the weapons are told there as it comes up), never clipped" % [size.x, size.y], Rect2(Vector2.ZERO, Vector2(size)).encloses(panel) and panel.position.y >= end._toast_clear() - 1.0, str(panel))
	root.size = Vector2i(1280, 720)
	await _frames(2)
	var old_id := main.get_instance_id()
	_key(KEY_ESCAPE)
	main = await _after_reload(old_id)
	_check("acceptance: Esc on the end screen goes back to the menu (the Missions screen over a fresh arena)", main.get_node("Hud").pause_menu().showing_missions())
	_check("the loadout screen sees the campaign: SIGTERM \"yours, from mission 01 login\", ping \"mission 02\"", _loadout_campaign(main))
	main.get_node("Hud").pause_menu().close()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	await _drop(main)


func _loadout_campaign(main: Node) -> bool:
	var menu: PauseMenu = main.get_node("Hud").pause_menu()
	menu.open_loadout()
	var screen := menu.loadout_screen()
	screen.select(1)
	var sigterm := screen.texts()
	screen.select(8)
	var ping := screen.texts()
	screen.close()
	return _text_has(sigterm, "yours, from mission 01 login") and _text_has(ping, "mission 02")


# --- Helpers. ---

func _arena(practice: bool) -> Node:
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	GameSettings.current().set_value("gameplay", "practice", practice)
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
	player.global_position = FRONT
	player.velocity = Vector3.ZERO
	await _frames(2)


func _reload(main: Node) -> Node:
	var old_id := main.get_instance_id()
	reload_current_scene()
	return await _after_reload(old_id)


## The arena reloaded (a new one in place of `old_id`), made ready like the first.
func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	return main


func _branch() -> Dictionary:
	var api := SceneMultiplayer.new()
	var branch := Node3D.new()
	branch.name = "NetBranch"
	root.add_child(branch)
	set_multiplayer(api, branch.get_path())
	var session := Session.new()
	session.name = Session.NODE_NAME
	session.tuning = load("res://resources/net.tres")
	branch.add_child(session)
	var main = MainScene.instantiate()
	branch.add_child(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	main.get_node("Player").assume_captured = true
	return {"branch": branch, "session": session, "main": main}


func _drop_branch(side: Dictionary) -> void:
	var branch: Node = side["branch"]
	if is_instance_valid(branch):
		_quiet(branch)
		branch.free()
	await _frames(2)


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		_quiet(main)
		if current_scene == main:
			current_scene = null
		main.free()
	await _frames(2)


func _quiet(node: Node) -> void:
	for sfx in node.find_children("*", "AudioStreamPlayer", true, false):
		(sfx as AudioStreamPlayer).stop()
	for sfx in node.find_children("*", "AudioStreamPlayer3D", true, false):
		(sfx as AudioStreamPlayer3D).stop()


func _cleanup() -> void:
	MissionRunner.clear_pending()
	if Progress.current().unlocked.is_connected(_on_toast):
		Progress.current().unlocked.disconnect(_on_toast)
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
	await process_frame
	OS.delay_msec(300)
	await process_frame


## The test's own folder removed: only under it, a link removed as itself and never followed.
func _wipe(path: String) -> void:
	if not path.begins_with(_abs):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var files := []
	var folders := []
	var name := dir.get_next()
	while name != "":
		if dir.is_link(name) or not dir.current_is_dir():
			files.append(name)
		else:
			folders.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	for f in files:
		DirAccess.remove_absolute(path.path_join(f))
	for f in folders:
		_wipe(path.path_join(f))
	DirAccess.remove_absolute(path)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Frames until `condition` holds (at most MOST_FRAMES); its last answer.
func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = pressed
		root.push_input(key)


func _shown_has(mh: MissionHud, text: String) -> bool:
	return _text_has(mh.shown_text(), text)


func _text_has(lines: PackedStringArray, text: String) -> bool:
	for line in lines:
		if line.contains(text):
			return true
	return false


func _visible_buttons(menu: Control) -> PackedStringArray:
	var out := PackedStringArray()
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).is_visible_in_tree():
			out.append((b as Button).text)
	return out


func _button(menu: Control, text: String) -> Button:
	for b in menu.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			return b
	return null

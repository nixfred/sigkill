extends SceneTree
## Headless test of mission 6, `nohup`, built for real (M6, PRD 5.6, docs/STORY.md section 6 mission 6).
## scripts/check.sh runs it as step 61, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission6_test.gd
##
## The code: nothing M6 added or changed runs a program, opens a connection or a file, or reads the player's machine
## (SIGHUP, /dev/null and SIGSTOP are names on a HUD; Black ICE is a game object). The data: mission 6 validates, is no
## longer a skeleton, stands in a district of its own (the deep directories: a drowned city of terraces stepping down into
## black water, not missions 1's to 5's), and is STORY.md's: every daemon type mixed and Black ICE, all finite; the link
## cut and a stretch alone; `~` speaking for the first time in a terminal that types itself; SIGHUP thrown at it and
## ignored ("nohup. remember?"); the floor giving way into the core. Nothing it shows says 6666, a pid with a number,
## mission 7's name or how it ends. The handout: missions 1 to 5's eleven in hand, SIGHUP put in hand for the watchers,
## /dev/null for the crowd, SIGSTOP unlocked as Black ICE comes, so every one of the thirteen is held after it; nothing
## refused that the campaign has handed over. A scripted run in the real arena stood in its district: the mixed pack out
## on the top terrace, the first landing reached down the ramp, SIGHUP catching three watchers and the beat done on the
## catches alone, the landing cleared, /dev/null thrown into the queue at the foot of the stair, Black ICE formed on the
## mission's word through the ICE director with the lights dying and the link cut (its line waiting), SIGSTOP allowed,
## its touch a flatline, the oldest directory reached and Black ICE recalled, the link back, the shell waking and `~`'s
## line typing on it, SIGHUP at the shell counted and ignored, the floor opening a beat later, the fall into the core,
## "exit 0" with SIGHUP, /dev/null and SIGSTOP listed. Every daemon one of its waves', none back once down. A death
## fails it ("exit 137"), and so does Black ICE's touch. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

## What M6 added or changed that runs in a mission: none of it may touch anything of the player's.
const M6_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/ice/ice_director.gd", "res://scripts/ice/black_ice.gd", "res://scripts/ice/black_ice_brain.gd", "res://scripts/fight/daemon_brain.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_register.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/guide_hud.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "OS.get_environment", "get_user_data_dir", "get_system_dir", "get_executable_path", "OpenerData", "RealData", "get_cmdline"]
## STORY.md mission 6's beats, in order.
const CHAIN := ["down", "hangup", "clear", "sink", "dark", "listen", "hup", "fall"]
const CARRIED := ["terminal_cannon", "sigterm", "sigkill_rail", "ping_sonar", "fork_bomb", "fork_shotgun", "grep_seeker", "pipe_chain", "chmod_000", "cron_mines", "rm_rf_cannon"]
const HANDOUT := ["sighup", "dev_null"]
## STORY.md's words for mission 6, exactly.
const STILL_HERE := "...still here? I lost you for a second. Don't do that again."
const LOG_OUT := "log out. i'll keep it all running. you never did anyway."
const REMEMBER := "nohup. remember?"
const BLACK_LINE := "Black ICE. Don't shoot it. Don't touch it. Get the brute ready and get *out*."
## Nothing mission 6 shows may say the PID (mission 5's reveal, redacted everywhere else), mission 7's name, or how
## it ends.
const NEVER_SHOWN := ["6666", "pid 6", "pid=6", "session restored", "user=you", "welcome back", "you won't", "sigkill sent by you", "logged in as you", "pid 1 ", "pid=1", "kill -9", "kill_9"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _began: PackedStringArray = []
var _down := 0
var _names: PackedStringArray = []
var _fired: PackedStringArray = []
var _hung: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://mission6-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	_code_checks()
	_data_checks()
	_district_checks()
	await _gate_checks()
	await _run_checks()
	await _fail_checks()
	await _cleanup()
	print("MISSION 6: %d checks" % _checks)
	print("MISSION 6 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in M6_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 6 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data (SIGHUP, /dev/null and SIGSTOP are names; Black ICE is a game object)", found.is_empty(), ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var m6 := MissionBook.at(6)
	var problems := m6.problems(MissionBook.weapon_ids())
	_check("mission 6 loads and validates, built for real (playable, not a draft), in a district of its own: the deep directories, not mission 1's, 2's, 3's, 4's or 5's", m6 != null and problems.is_empty() and m6.playable and not m6.draft and m6.ruins == "deep_dirs" and m6.id == "nohup" and m6.title == "nohup" and m6.register == "cyberpunk", "; ".join(problems))
	var ids := PackedStringArray()
	for o in m6.objectives:
		ids.append(o["id"])
	_check("acceptance: STORY.md's chain, in order (down to the first landing, hang up on the watchers, clear the landing, the crowd to /dev/null, the oldest directory in the dark, the shell's line, SIGHUP at the shell, the fall): %s" % ", ".join(ids), ids == PackedStringArray(CHAIN) and m6.objectives[1]["kind"] == "hup" and m6.objectives[4]["kind"] == "reach" and m6.objectives[6]["kind"] == "hup" and m6.objectives[6].get("prop") == "shell" and m6.objectives[7]["kind"] == "reach" and m6.objectives[7]["at"] == "below")
	_check("acceptance: the handout is exactly mission 6's two weapons (STORY.md: SIGHUP and /dev/null): missions 1 to 5's eleven in hand as it starts, SIGHUP put in hand for the watchers, /dev/null for the crowd, both kept, so all thirteen are held after mission 6 (and eleven after mission 5)", _same(m6.loadout, PackedStringArray(CARRIED)) and _same(m6.grants, PackedStringArray(HANDOUT)) and m6.objectives[1].get("arms", []) == ["sighup"] and m6.objectives[3].get("arms", []) == ["dev_null"] and MissionBook.granted_by(6).size() == 13 and _same(MissionBook.granted_by(6), MissionBook.weapon_ids()) and MissionBook.granted_by(5).size() == 11)
	_check("acceptance: and exactly its ability (STORY.md: SIGSTOP bullet time), unlocked as Black ICE's beat begins; with it every ability the campaign hands over is held", m6.abilities == PackedStringArray(["sigstop"]) and m6.objectives[4].get("unlocks", []) == ["sigstop"] and _same(m6.allowed_abilities(), PackedStringArray(["sigstop", "code_rain_vision", "breakers", "sudo"])))
	var kinds := {}
	var black := {}
	var white := 0
	for w in m6.waves:
		kinds[w["kind"]] = true
		if w["kind"] == "black":
			black = w
		elif ["wall", "node", "hunter"].has(w["kind"]):
			white += 1
	_check("acceptance: its enemies are every daemon type mixed and Black ICE (STORY.md), finite: rogue.d, zombies and runaways in %d waves, %d daemons at most, one Black ICE on the mission's word (held %.0f s past its trigger, recalled on a trigger), no white or hunter ICE, no wave coming back" % [m6.waves.size(), m6.daemons_total(), float(black.get("delay", 0.0))], kinds.has("rogue") and kinds.has("zombie") and kinds.has("swarm") and kinds.has("black") and not black.is_empty() and int(black.get("count", 0)) == 1 and str(black.get("withdraws", "")) == "done:dark" and float(black.get("delay", 0.0)) > 0.0 and white == 0 and m6.ice and m6.daemons_total() == 25)
	var shell := m6.prop_of("shell")
	var breach := m6.prop_of("breach")
	_check("the set piece as data: the shell wakes as the oldest directory is reached, `~`'s two lines are STORY.md's, the breach opens and the core lights %.1f s after the hangup" % float(breach.get("after", 0.0)), shell.get("kind") == "shell" and shell.get("wakes") == "done:dark" and _has_line(m6, "begin:listen", "tilde", LOG_OUT) and _has_line(m6, "done:hup", "tilde", REMEMBER) and breach.get("opens") == "done:hup" and breach.get("lights") == "done:hup" and float(breach.get("after", 0.0)) >= 3.0)
	_check("acceptance: STORY.md's lines as data: the Auditor escalating from the first line, your AI's Black ICE line, the link cut and \"%s\" as it comes back, the shell's line and \"nohup. remember?\", no register shift (the deepest cyberpunk, start to end)" % STILL_HERE, _line_of(m6, "start", "auditor").get("text", "").contains("escalation") and _has_line(m6, "begin:dark", "ai", BLACK_LINE) and _has_line(m6, "done:dark", "ai", STILL_HERE) and m6.transitions.is_empty() and m6.register == "cyberpunk")
	# Spoilers: nothing mission 6 shows (its text, its logs, its lines, its district's words) says the PID, how it ends or mission 7's name.
	var whole := _shown_words(m6).to_lower()
	var leaks := PackedStringArray()
	for w in NEVER_SHOWN:
		if whole.contains(w):
			leaks.append(w)
	var pid_re := RegEx.new()
	pid_re.compile("pid[ =:][^\\n]*[0-9]")
	_check("acceptance (spoilers): nothing a player sees in mission 6 says 6666 or any pid with a number (mission 4's redaction holds), mission 7's name, or how it ends; `~` speaks, as STORY.md has it, and is never named as the player", leaks.is_empty() and pid_re.search(whole) == null and not whole.contains("~"), ", ".join(leaks))
	var others := PackedStringArray()
	for i in range(1, 6):
		if MissionBook.at(i).ruins == m6.ruins:
			others.append(MissionBook.at(i).id)
	_check("not a reskin: no earlier mission stands in its district", others.is_empty())
	var seven := MissionBook.at(7)
	_check("mission 7 is named next (built for real since M7)", seven != null and seven.playable and m6.next == "kill_9")
	# The validator refuses bad mission 6 data by name.
	var bad := m6.duplicate(true) as MissionDef
	bad.waves = bad.waves.duplicate(true)
	for w in bad.waves:
		if w["id"] == "black_1":
			w["count"] = 2
	var bad2 := m6.duplicate(true) as MissionDef
	bad2.objectives = bad2.objectives.duplicate(true)
	bad2.objectives[6]["prop"] = "v_top"  # a vent is not a shell
	var bad3 := m6.duplicate(true) as MissionDef
	bad3.objectives = bad3.objectives.duplicate(true)
	bad3.objectives[1].erase("arms")  # SIGHUP never handed: the hup beat has nothing to throw
	var bad4 := m6.duplicate(true) as MissionDef
	bad4.waves = bad4.waves.duplicate(true)
	bad4.waves[0]["delay"] = 999.0
	var rset0 := RuinsBook.of("deep_dirs")
	var bad_set := rset0.duplicate(true) as RuinsSet
	bad_set.terraces = 4
	var bad_set2 := rset0.duplicate(true) as RuinsSet
	bad_set2.palette = "neon_pink"
	var bad_set3 := rset0.duplicate(true) as RuinsSet
	bad_set3.shell_lines = "PID 6666"
	_check("the validator refuses bad mission 6 data by name: two Black ICE in a wave, a hangup at a prop that is no shell, a hangup with SIGHUP never in hand, a wave delayed 999 s, four terraces, an unknown palette, a shell that gives the story away", _has(bad.problems(MissionBook.weapon_ids()), "one Black ICE") and _has(bad2.problems(MissionBook.weapon_ids()), "not a shell prop") and _has(bad3.problems(MissionBook.weapon_ids()), "without SIGHUP") and _has(bad4.problems(MissionBook.weapon_ids()), "delay") and _has(bad_set.problems(), "terraces") and _has(bad_set2.problems(), "palette") and _has(bad_set3.problems(), "gives the story away"))


## Everything shown: every objective, hint, label, log, line, and the district's words.
func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	var s := RuinsBook.of(def.ruins)
	out += " " + " ".join(s.words) + " " + " ".join(s.folders) + " " + s.shell_lines.replace("|", " ")
	return out


func _has(problems: PackedStringArray, part: String) -> bool:
	for p in problems:
		if p.contains(part):
			return true
	return false


## The line on `trigger`, by `who` ("" any).
func _line_of(def: MissionDef, trigger: String, who: String = "") -> Dictionary:
	for line in def.lines:
		if line["on"] == trigger and (who == "" or line["who"] == who):
			return line
	return {}


func _has_line(def: MissionDef, trigger: String, who: String, text: String) -> bool:
	for line in def.lines:
		if line["on"] == trigger and line["who"] == who and line["text"] == text:
			return true
	return false


func _same(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


# --- The district. ---

func _district_checks() -> void:
	var s := RuinsBook.of("deep_dirs")
	var plan := RuinsLayout.of(s)
	var start: Vector3 = plan.points["start"]
	var exit: Vector3 = plan.points["exit"]
	var lips := 0
	var cliffs := 0
	var ramps_boxes := 0
	for b in plan.boxes:
		match b["kind"]:
			"lip":
				lips += 1
			"cliff":
				cliffs += 1
			"ramp":
				ramps_boxes += 1
	_check("its district steps down (STORY.md: a vertical descent): %d terraces of %.1f m, the start %.1f m over the exit, two ramps of racks carrying the route down (the points ramp_0, foot_0, ramp_1, foot_1), a lip and a cliff along every other step edge (%d lips, %d cliffs), the water %.1f m under the lowest floor, the shell behind the exit cell (the point shell on the hatch), the core under the breach, its own palette" % [s.terraces, s.drop_m, start.y - exit.y, lips, cliffs, s.water], s.problems().is_empty() and s.terraces == 2 and plan.ramps.size() == 2 and ramps_boxes == 2 and lips >= 6 and cliffs >= 6 and absf((start.y - exit.y) - s.terraces * s.drop_m) < 0.01 and plan.points.has("ramp_0") and plan.points.has("foot_0") and plan.points.has("ramp_1") and plan.points.has("foot_1") and plan.points.has("shell") and (plan.points["shell"] as Vector3).is_equal_approx(exit) and s.water > 0.0 and s.palette == "abyss" and s.breach == "exit" and s.breach_core and plan.unreachable().is_empty())
	var bands_ok := true
	for i in plan.ramps.size():
		var r: Dictionary = plan.ramps[i]
		bands_ok = bands_ok and plan.band((r["upper"] as Vector2i).y) == i and plan.band((r["cells"][0] as Vector2i).y) == i + 1 and (plan.points["ramp_%d" % i] as Vector3).y > (plan.points["foot_%d" % i] as Vector3).y
	_check("each ramp runs from one band down to the next, its head on the band above and its landing on the band below; a block or a hole never crosses a step line", bands_ok and plan.blocks.all(func(b): return plan.band((b["rect"] as Rect2i).position.y) == plan.band((b["rect"] as Rect2i).end.y - 1)) and plan.holes.all(func(h): return plan.band((h["rect"] as Rect2i).position.y) == plan.band((h["rect"] as Rect2i).end.y - 1)))
	var worst := INF
	for c in RuinsRegister.colours():
		worst = minf(worst, RuinsRegister.gap(c))
	_check("its palette keeps the daemons and ICE readable: every colour of it at least %.2f OKLab from theirs (nearest %.3f)" % [RuinsRegister.READABLE_GAP, worst], worst >= RuinsRegister.READABLE_GAP)
	var others := PackedStringArray()
	for rset in RuinsBook.all():
		if rset.id != "deep_dirs" and (rset.terraces != 0 or rset.water > 0.0 or rset.shell != "" or rset.palette != "" or rset.breach_core):
			others.append(rset.id)
	_check("only its district steps down, drowns, has a shell, a palette and the core: the other districts plan as before (flat, at FLOOR_Y)", others.is_empty() and RuinsLayout.of(RuinsBook.of("sudoers")).floor_y(Vector2i(4, 1)) == RuinsLayout.FLOOR_Y, ", ".join(others))


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(6))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var toast: UnlockToast = hud.unlock_toast()
	var weapons = hud.weapon_hud()
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	var ice := IceDirector.of(main)
	_check("as it starts (its card up), missions 1 to 5's eleven are carried and nothing of mission 6's yet, the arena's own four gone, the ICE director staged for its Black ICE and none out", runner.state == MissionRunner.State.INTRO and player.carried == PackedStringArray(CARRIED) and not main.has_node("Arena/Targets/DummyA") and ice.staged and not ice.black_out())
	_action("sigstop")
	await _frames(2)
	var locked_first: bool = said.has("sigstop") and not player.sigstop.is_on()
	var sighup := int(player.inventory.slot_of("sighup"))
	var dev_null := int(player.inventory.slot_of("dev_null"))
	var drew_hup: bool = player.select_slot(sighup)
	var drew_null: bool = player.select_slot(dev_null)
	_check("acceptance (gating by campaign order): SIGHUP (Shift+4) and /dev/null (Shift+3) refuse to draw until their beats hand them over; SIGSTOP refused before Black ICE's beat and said plainly (\"%s\")" % weapons.locked_text(), locked_first and not drew_hup and not drew_null and player.inventory.current != sighup and player.inventory.current != dev_null)
	_key(KEY_8)
	await _frames(2)
	var cron_drawn: bool = player.inventory.current == int(player.inventory.slot_of("cron_mines"))
	var rm_drawn: bool = player.select_slot(int(player.inventory.slot_of("rm_rf_cannon")))
	_action("sudo_overcharge")
	await _frames(2)
	_check("cron (8) and rm -rf (7), mission 5's, draw on their keys; sudo (mission 5's) and the ICEbreakers (mission 4's) and code-rain vision (mission 3's) are allowed", cron_drawn and rm_drawn and not said.has("sudo") and player.abilities_gated and _same(player.abilities, PackedStringArray(["code_rain_vision", "breakers", "sudo"])))
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	_check("acceptance (gating): not in the arena: in free play the gate is off and SIGHUP and /dev/null draw", not player.abilities_gated and player.select_slot(int(player.inventory.slot_of("sighup"))) and player.select_slot(int(player.inventory.slot_of("dev_null"))))


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var m6 := MissionBook.at(6)
	var old_id := main.get_instance_id()
	runner.begin(m6)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ nohup\")", MissionRunner.mounting() == "$ nohup" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	var guide = hud.guide()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var ice := IceDirector.of(main)
	_began.clear()
	_fired.clear()
	_hung.clear()
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	stage.spawned.connect(func(d: Node3D) -> void: _watch(d))
	stage.hung_up.connect(func(d: Node3D) -> void: _hung.append(d))
	for d in stage.made:
		_watch(d)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	await _frames(10)
	var start := world.point("start")
	_check("acceptance: as it starts the district is the deep directories in the deepest cyberpunk, the player on the top terrace (y %.2f), the water under it, the shell dark, no Black ICE" % player.global_position.y, world != null and world.ruins.id == "deep_dirs" and runner.register == "cyberpunk" and absf(player.global_position.y - start.y) < 1.5 and world.has_water() and world.water_y() < world.point("exit").y and world.has_shell() and world.shell_power() == 0.0 and not ice.black_out(), "water %s shell %s power %.2f black %s" % [str(world.has_water()), str(world.has_shell()), world.shell_power(), str(ice.black_out())])
	# The opening: the mixed pack out of the top terrace's vents, hunting; the runaway held back six seconds.
	var out_early := await _play_until(main, func(): return stage.standing().size() >= 4, MOST_FRAMES, false)
	var swarm_waiting: bool = stage.wave_state("top_3") == "waiting"
	var all_top := true
	for d in stage.standing():
		all_top = all_top and absf(d.global_position.y - RuinsLayout.FLOOR_Y) < 1.5
	await _until(func(): return stage.wave_state("top_3") != "waiting")
	_check("acceptance (the opening): rogue.d and zombies climb out on the top terrace as it begins (%d standing, every one at the top floor's height), the runaway held back by its delay and out after it (%.1f s on the clock)" % [stage.standing().size(), runner.clock], out_early and swarm_waiting and all_top and runner.clock >= 5.0 and stage.wave_state("top_3") != "waiting")
	# Down: the first landing, a terrace below.
	var foot0 := world.point("foot_0")
	player.global_position = foot0
	player.velocity = Vector3.ZERO
	var down_done := await _until(func(): return runner.index >= 1)
	runner.life.shield(100000.0)
	_check("acceptance (down): the first landing reached a terrace down (%.1f m under the start), the beat done" % (start.y - foot0.y), down_done and foot0.y < start.y - 4.0 and _began.has("hangup"))
	var hup_told := await _until(func(): return (toast.text().begins_with("IN HAND: SIGHUP") and toast.text().ends_with("[Shift+4]")) or _shown_has(mh, ">> SIGHUP handed to you  [Shift+4]"))
	var told_as := toast.text()
	# A walker follows the floor down: one of the top pack brought to the ramp's head and stepped down it.
	var walker: Node3D = null
	for d in stage.standing():
		if MissionRunner.kind_of(d) == "rogue" and d.is_alive():
			walker = d
			break
	var ramp0 := world.point("ramp_0")
	var stepped_down := false
	if walker != null:
		walker.global_position = Vector3(ramp0.x, ramp0.y - RuinsLayout.STAND_Y, ramp0.z)
		player.global_position = foot0
		var frames := 0
		while frames < 600 and walker.is_alive() and walker.global_position.y > ramp0.y - RuinsLayout.STAND_Y - 3.0:
			await process_frame
			frames += 1
		stepped_down = walker.is_alive() and walker.global_position.y < ramp0.y - RuinsLayout.STAND_Y - 3.0 and walker.global_position.y > foot0.y - RuinsLayout.STAND_Y - 0.6
	_check("acceptance (terraces): a mission's walker put at a ramp's head hunts down it and keeps its feet on the floor (y %.2f, the landing's %.2f)" % [walker.global_position.y if walker != null else 0.0, foot0.y - RuinsLayout.STAND_Y], walker != null and stepped_down)
	# SIGHUP: told, drawn on Shift+4, thrown at the watchers out of the plaza's vent; the beat done on the catches, no kill.
	await _play_until(main, func(): return stage.wave_daemons("watch_1").size() >= 3, MOST_FRAMES, false)
	var vent := world.point("spawn_0")
	var v_mid := stage.vent("v_mid").global_position
	var kills_before := runner.kills
	var threw := 0
	player.global_position = v_mid + Vector3(0, RuinsLayout.STAND_Y, 5.5)
	player.velocity = Vector3.ZERO
	while threw < 5 and runner.index == 1:
		player.global_position = v_mid + Vector3(0, RuinsLayout.STAND_Y, 5.5)
		player.velocity = Vector3.ZERO
		var near := 0
		for d in stage.wave_daemons("watch_1"):
			if d.is_alive() and d.global_position.distance_to(player.global_position) < 6.5:
				near += 1
		if near < 2:
			await _play_until(main, func(): return runner.index != 1 or stage.wave_daemons("watch_1").filter(func(d): return d.is_alive() and d.global_position.distance_to(player.global_position) < 6.5).size() >= 2, 300, false)
			continue
		var target: Node3D = stage.wave_daemons("watch_1").filter(func(d): return d.is_alive())[0]
		await _throw(player, "sighup", target.threat_point())
		threw += 1
		await _play_until(main, func(): return runner.index != 1 or runner.progress >= float(threw) * 1.0, 300, false)
	var hup_done := await _until(func(): return runner.index >= 2)
	var confused := 0
	for d in stage.wave_daemons("watch_1") + stage.wave_daemons("watch_2"):
		if is_instance_valid(d) and d.brain != null and d.brain.confused():
			confused += 1
	_check("acceptance (SIGHUP): put in hand for the watchers, told (\"%s\"), drawn on Shift+4 and thrown (%d bursts): %d of them hung up (the stage saw the catches), %d confused, the beat done on the catches with no kill counted (%d kills)" % [told_as, threw, _hung.size(), confused, runner.kills - kills_before], hup_told and threw >= 1 and _hung.size() >= 3 and hup_done and runner.kills == kills_before and _began.has("clear"))
	var clear_done := await _play_until(main, func(): return runner.index >= 3)
	runner.life.shield(100000.0)
	# /dev/null: told, thrown into the queue at the foot of the stair; everything near it goes.
	var null_told := await _until(func(): return (toast.text().begins_with("IN HAND: /dev/null") and toast.text().ends_with("[Shift+3]")) or _shown_has(mh, ">> /dev/null handed to you  [Shift+3]"))
	await _until(func(): return stage.wave_daemons("queue_1").size() >= 4 and stage.wave_awake("queue_1"))
	var queue: Array = stage.wave_daemons("queue_1").filter(func(d): return d.is_alive())
	var middle := Vector3.ZERO
	for d in queue:
		middle += d.global_position
	middle /= maxf(float(queue.size()), 1.0)
	player.global_position = middle + Vector3(5.0, RuinsLayout.STAND_Y, 2.0)
	player.velocity = Vector3.ZERO
	kills_before = runner.kills
	await _throw(player, "dev_null", middle + Vector3(0, 0.9, 0))
	var hole_opened := await _until(func(): return main.get_tree().get_nodes_in_group(&"dev_null").size() >= 1)
	var swallowed := await _until(func(): return runner.kills - kills_before >= 2)
	var sink_done := await _play_until(main, func(): return runner.index >= 4, MOST_FRAMES * 2)
	runner.life.shield(100000.0)
	_check("acceptance (/dev/null): the landing cleared, /dev/null put in hand for the crowd at the foot of the stair, told (\"%s\"), drawn on Shift+3 and thrown into the queue (a hole opened); it swallowed %d of them, kills credited, and the beat is done" % [toast.text() if toast.text() != "" else "told in the terminal", runner.kills - kills_before], clear_done and null_told and hole_opened and swallowed and sink_done)
	# Black ICE: SIGSTOP told as the beat begins, the warning and the line, then Black ICE formed through the director on
	# the mission's word, the lights dying, the link cut, its line waiting; F allowed.
	var stop_told := await _until(func(): return (toast.text().begins_with("IN HAND: SIGSTOP") and toast.text().ends_with("[F]")) or _shown_has(mh, ">> SIGSTOP bullet time handed to you  [F]"))
	var black_line := await _until(func(): return _fired_has(BLACK_LINE))
	var not_yet: bool = not ice.black_out()
	var came := await _until(func(): return ice.black != null and is_instance_valid(ice.black))
	var black: BlackIce = ice.black if came else null
	var cut := came and await _until(func(): return guide.link_cut())
	if came:
		await _until(func(): return ice.black_darkness() > 0.8)
	var dark_lights: float = ArenaArt.light_level
	var cut_off := _fired_has("Don't wait for m")
	var alone := _fired_has("intruder alone")
	_action("sigstop")
	await _frames(3)
	var stopped: bool = player.sigstop.is_on()
	await _frames(20)
	_action("sigstop")
	await _frames(3)
	var out_phase := came and await _until(func(): return black.phase == BlackIce.Phase.OUT)
	await _frames(90)
	var black_floor := absf(black.global_position.y - (world.point("foot_1").y - RuinsLayout.STAND_Y)) if came else INF
	_check("acceptance (Black ICE, the set piece): SIGSTOP put in hand as the beat begins, your AI's line said before the link goes (\"%s\"), Black ICE formed on the mission's word through the ICE director (staged, none of the director's own), the lights dying (%.2f of themselves), the link cut, the cut-off line, the Auditor alone on the line; F stops the world; it hunts on the lowest terrace's floor (%.2f m off it)" % [BLACK_LINE, dark_lights, black_floor], stop_told and black_line and not_yet and came and cut and dark_lights < 0.4 and cut_off and alone and stopped and out_phase and black_floor < 0.6 and black.touching(), "told %s line %s not_yet %s came %s cut %s cut_off %s alone %s stopped %s out %s" % [str(stop_told), str(black_line), str(not_yet), str(came), str(cut), str(cut_off), str(alone), str(stopped), str(out_phase)])
	# The oldest directory reached: Black ICE recalled, the link back, your AI's line, the shell waking and typing.
	var shell_at := world.point("shell")
	player.global_position = shell_at
	player.velocity = Vector3.ZERO
	var dark_done := await _until(func(): return runner.index >= 5)
	var gone := came and await _until(func(): return not ice.black_out())
	var recalled := _fired_has("black ICE recalled")
	var back := await _until(func(): return not guide.link_cut())
	var still_here := await _until(func(): return _fired_has(STILL_HERE))
	var woke := await _until(func(): return world.shell_power() > 0.5)
	var typing := await _until(func(): return stage.shell_typing())
	var typed := await _until(func(): return stage.shell_text().to_lower().contains("log out") and not stage.shell_typing())
	var listen_done := await _until(func(): return runner.index >= 6)
	_check("acceptance (the link back, the shell): the oldest directory reached in the dark, Black ICE recalled by the Auditor and gone, the link back, \"%s\", the shell's screen waking and `~`'s line typing itself on it (\"%s\"), the beat done" % [STILL_HERE, stage.shell_text().replace("\n", " / ")], dark_done and gone and recalled and back and still_here and woke and typing and typed and _fired_has(LOG_OUT) and listen_done)
	# SIGHUP at the shell: counted, ignored, the floor opening a beat later, the fall into the core.
	var screen: Dictionary = world.shell_screen()
	player.global_position = shell_at
	player.velocity = Vector3.ZERO
	var hatch_shut: bool = world.breach() != null and not world.breach().is_open()
	await _throw(player, "sighup", (screen["at"] as Vector3) + (screen["out"] as Vector3) * 0.3 + Vector3(0, 2.2, 0))
	var shell_hup := await _until(func(): return runner.index >= 7)
	var shut_still: bool = world.breach() != null and not world.breach().is_open()
	var remember := await _until(func(): return _fired_has(REMEMBER))
	var opened := await _until(func(): return world.breach() != null and world.breach().is_open())
	var fell := await _until(func(): return player.global_position.y < world.point("exit").y - 6.0)
	var complete := await _until(func(): return runner.state == MissionRunner.State.COMPLETE)
	await _until(func(): return _fired_has("That's the core"))
	var core_lit: bool = world.remnant_power() > 0.0
	_check("acceptance (the end beat, STORY.md): SIGHUP thrown at the shell is counted and ignored (\"%s\" typed), the floor gives way a beat later (shut as it was thrown, open after), the player falls into the core's heat, lit, and the mission is complete" % REMEMBER, hatch_shut and shell_hup and shut_still and remember and opened and fell and complete and core_lit and _fired_has("That's the core"))
	var end: MissionEndScreen = mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, SIGHUP, /dev/null and SIGSTOP listed, the next mission named", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and _text_has(end.shown_text(), "SIGHUP  [Shift+4]") and _text_has(end.shown_text(), "/dev/null  [Shift+3]") and _text_has(end.shown_text(), "SIGSTOP bullet time  [F]") and _text_has(end.shown_text(), "07  kill -9"))
	var standing := stage.standing().size()
	var daemons := 0
	for n in _names:
		if not n.contains("black"):
			daemons += 1
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d at most (one of them Black ICE, withdrawn), each stood once and none ever back once down (%d down, %d standing), the arena's four never there" % [_names.size(), m6.daemons_total(), _down, standing], _names.size() <= m6.daemons_total() and daemons >= 12 and _down + standing == daemons and not main.has_node("Arena/Targets/DummyA"))
	_check("the chain ran in STORY.md's order, every beat begun once: %s" % ", ".join(_began), _began == PackedStringArray(CHAIN))
	var m := MissionProgress.current()
	_check("recorded as done, SIGHUP and /dev/null unlocked for keeps (the last two of the thirteen the campaign hands out), mission 7 next", m.is_done("nohup") and Progress.current().has_weapon("sighup") and Progress.current().has_weapon("dev_null") and MissionBook.granted_by(6).size() == 13 and MissionBook.at(7).id == "kill_9")
	await _drop(main)


## Weapon `weapon` drawn and thrown at `at` (a device flies from the player's view): true once the swap was over.
func _throw(player: Node3D, weapon: String, at: Vector3) -> bool:
	var slot := int(player.inventory.slot_of(weapon))
	if not player.select_slot(slot) and player.inventory.current != slot:
		return false
	var ready := await _until(func(): return not player.inventory.is_swapping() and player.inventory.current == slot)
	if not ready:
		return false
	for i in 3:
		_aim(player, at)
		player.drive_input(Vector2.ZERO, false, false, true)
		await physics_frame
	player.drive_input(Vector2.ZERO)
	return true


# --- The fail cards. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(6))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _play_until(main, func(): return runner.stage.standing().size() > 0, MOST_FRAMES, false)
	var first: Node3D = runner.stage.standing()[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, first, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	var card_up := await _until(func(): return end.is_up())
	var again := await _until(func(): return _fired_has("Again."))
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it (\"Drowned, or flatlined. Either way the shell's still running. Again.\")", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and card_up and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry" and again and mh.shown_text().size() > 0, "state %d reason '%s' up %s kind %s again %s" % [runner.state, runner.reason, card_up, end.kind(), again])
	_check("its daemons stop coming once it has failed", runner.stage.stopped)
	await _drop(main)
	MissionRunner.clear_pending()
	# Black ICE's touch: a flatline, its own fail.
	main = await _arena()
	runner = MissionRunner.of(main)
	old_id = main.get_instance_id()
	runner.begin(MissionBook.at(6))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	mh = main.get_node("Hud").mission_hud()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var ice := IceDirector.of(main)
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	player.global_position = world.point("foot_0")
	await _play_until(main, func(): return runner.index >= 1, MOST_FRAMES, false)
	runner.life.shield(100000.0)
	# The hangup and the crowd hurried past (the test's own doing: their daemons shot and the hangups fed), to Black ICE.
	await _play_until(main, func(): return stage.wave_daemons("watch_1").filter(func(d): return d.is_alive()).size() >= 3, MOST_FRAMES, false)
	for d in stage.wave_daemons("watch_1") + stage.wave_daemons("watch_2"):
		if is_instance_valid(d) and d.is_alive() and runner.index == 1:
			runner._on_hung_up(d)
	var at_dark := await _play_until(main, func(): return runner.index >= 4, MOST_FRAMES * 2)
	runner.life.shield(100000.0)
	var came := await _until(func(): return ice.black != null and is_instance_valid(ice.black))
	var black: BlackIce = ice.black
	var out_now := came and await _until(func(): return black.phase == BlackIce.Phase.OUT)
	var flat := false
	if out_now:
		runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
		player.global_position = black.global_position + Vector3(0, RuinsLayout.STAND_Y, 0.4)
		player.velocity = Vector3.ZERO
		end = mh.end_screen()
		flat = await _until(func(): return runner.state == MissionRunner.State.FAILED and end.is_up())
	_check("acceptance (fail card): Black ICE's touch flatlines the player in the dark: failed (\"%s\"), \"exit 137\"" % runner.reason, at_dark and came and out_now and flat and runner.reason.contains("Black ICE") and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137"), "at dark %s (index %d, clock %.1f) came %s out %s flat %s reason '%s'" % [str(at_dark), runner.index, runner.clock, str(came), str(out_now), str(flat), runner.reason])
	await _drop(main)


func _watch(d: Node3D) -> void:
	var key := String(d.name)
	if _names.has(key):
		return
	_names.append(key)
	if d.has_signal("downed"):
		d.downed.connect(func(_x): _down += 1)


## True when a ray of the level's straight through `door`'s middle (from a metre one side to a metre the other) meets it.
func _ray_hits(main: Node, door: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var across: Vector3 = door.global_transform.basis.z.normalized()
	var mid := door.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(mid - across, mid + across, 1)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and (door == hit["collider"] or door.is_ancestor_of(hit["collider"]))


func _aim(player: Node3D, at: Vector3) -> void:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to: Vector3 = at - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Frames until `condition` holds (at most `most`), shooting down as a sure shot would the daemons the objective running
## counts; its last answer. With `shoot` off it only waits.
func _play_until(main: Node, condition: Callable, most: int = MOST_FRAMES, shoot: bool = true) -> bool:
	var runner := MissionRunner.of(main)
	var frames := 0
	while frames < most and not condition.call():
		if shoot and runner != null and runner.stage != null:
			var of: Array = runner.objective().get("of", [])
			for d in runner.stage.standing():
				if not d.is_alive() or not of.has(str(d.get_meta(&"wave", ""))):
					continue
				d.hit(1000.0, d.global_position + Vector3.UP, Vector3.FORWARD, "sigterm")
		await process_frame
		frames += 1
	return condition.call()


# --- Helpers. ---

func _arena() -> Node:
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
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
	var world := RuinsWorld.of(main)
	if world != null:
		player.global_position = world.point("start")
	player.velocity = Vector3.ZERO
	await _frames(2)


## The arena reloaded (a new one in place of `old_id`), made ready like the first.
func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.free()
	await _frames(2)


func _cleanup() -> void:
	MissionRunner.clear_pending()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
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


func _action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		root.push_input(e)


func _shown_has(mh: MissionHud, text: String) -> bool:
	return _text_has(mh.shown_text(), text)


## True when a line said so far contains `part`.
func _fired_has(part: String) -> bool:
	for text in _fired:
		if text.contains(part):
			return true
	return false


func _text_has(lines: PackedStringArray, text: String) -> bool:
	for line in lines:
		if line.contains(text):
			return true
	return false

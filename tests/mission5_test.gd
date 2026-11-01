extends SceneTree
## Headless test of mission 5, `sudo !!`, built for real (M5, PRD 5.6, docs/STORY.md section 6 mission 5).
## scripts/check.sh runs it as step 60, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission5_test.gd
##
## The code: nothing M5 added or changed runs a program, opens a connection or a file, or reads the player's machine
## (sudo, cron and rm -rf are words on a HUD). The data: mission 5 validates, is no longer a skeleton, stands in a district
## of its own (the sudoers' ladder: Tron decaying into Matrix, not missions 1's to 4's), and is STORY.md's: elites of all
## three types and jobs that come on a timer, all finite; the doubt beat (a crontab signed by an assistant, your AI's
## line on it); a sealed room only root may enter; the oldest log read as root, naming the shell under nohup still
## running as PID 6666, its author field forged, and your AI's "6666 isn't how many there are. It's who."; nothing a
## player sees before that read says 6666, nohup or `~`, nothing anywhere says who `~` is or how it ends, and the
## session-holder's PID of mission 4 stays redacted (no "held by pid" with a number). The handout: missions 1 to 4's nine
## in hand, sudo unlocked for the first job with a toast, cron put in hand for the job that must be mined, rm -rf for the
## job that must be stopped; what later missions hand over refused. A scripted run in the real arena stood in its
## district: the first job counting down on the crontab and climbing out on time, three kills earning a sudo charge, Z
## making the player root# and the objective done, the watchdog an elite rogue.d that tells from farther than any rogue
## (its pounce), the register decaying toward Matrix without a tear, cron's job running twice fifteen seconds apart and
## a mine placed at its vent, the crontab's author read and the doubt lines said, the wipe job counting down in red with
## its zombie elite charging instead of throwing, killed and the job removed from the crontab, the runaway elite's bursts
## twice as long, the root door standing shut until root# sinks it and shutting again after, the oldest log standing
## only from the door's beat, read, and "exit 0" with cron, rm -rf and sudo listed. Every daemon one of its waves', none
## back once down, every job done or removed. A death fails it ("exit 137"), and so does the wipe job's countdown
## running out, with its own reason. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

## What M5 added or changed that runs in a mission: none of it may touch anything of the player's.
const M5_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/missions/root_door.gd", "res://scripts/fight/daemon_brain.gd", "res://scripts/daemons/runaway_swarm.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/hud/mission_hud.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "OS.get_environment", "get_user_data_dir", "get_system_dir", "get_executable_path", "OpenerData", "RealData", "get_cmdline"]
## STORY.md mission 5's beats, in order.
const CHAIN := ["jobs", "root", "watchdog", "cron", "author", "wipe", "elites", "door", "oldest"]
const CARRIED := ["terminal_cannon", "sigterm", "sigkill_rail", "ping_sonar", "fork_bomb", "fork_shotgun", "grep_seeker", "pipe_chain", "chmod_000"]
const HANDOUT := ["cron_mines", "rm_rf_cannon"]
## STORY.md's words for mission 5, exactly.
const DOUBT := "I don't remember writing it. I don't remember anything from before tonight. That's not the same as not doing it."
const WHO := "6666 isn't how many there are. It's who."
## Nothing a player sees before the oldest log is read may say who `~` is (6666 and nohup are that log's own reveal, as
## STORY.md writes it; `~` itself is mission 6's), nothing anywhere how it ends, and mission 4's redaction holds.
const BEFORE := ["~", "6666", "nohup", "tilde", "never logged out", "never hung up", "shell"]
const ENDING := ["session restored", "user=you", "welcome back", "you won't", "sigkill sent by you", "logged in as you", "pid 1 ", "pid=1", "log out. i'll keep"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _began: PackedStringArray = []
var _down := 0
var _names: PackedStringArray = []
var _fired: PackedStringArray = []
var _ran: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://mission5-test-%d" % OS.get_process_id())
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
	print("MISSION 5: %d checks" % _checks)
	print("MISSION 5 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in M5_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 5 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data (sudo, cron and rm -rf are words)", found.is_empty(), ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var m5 := MissionBook.at(5)
	var problems := m5.problems(MissionBook.weapon_ids())
	_check("mission 5 loads and validates, built for real (playable, not a draft), in a district of its own: the sudoers' ladder, not mission 1's, 2's, 3's or 4's", m5 != null and problems.is_empty() and m5.playable and not m5.draft and m5.ruins == "sudoers" and m5.id == "sudo_bang" and m5.title == "sudo !!", "; ".join(problems))
	var ids := PackedStringArray()
	for o in m5.objectives:
		ids.append(o["id"])
	_check("acceptance: STORY.md's chain, in order (the first job, root, the watchdog, cron, the crontab's author, rm -rf stopped, the last elite, the root door, the oldest log): %s" % ", ".join(ids), ids == PackedStringArray(CHAIN) and m5.objectives[1]["kind"] == "root" and m5.objectives[7]["kind"] == "reach" and m5.objectives[8]["kind"] == "log")
	_check("acceptance: the handout is exactly mission 5's two weapons (STORY.md: cron mines and the rm -rf cannon): missions 1 to 4's nine in hand as it starts, cron put in hand at the job to mine, rm -rf at the job to stop, both kept", _same(m5.loadout, PackedStringArray(CARRIED)) and _same(m5.grants, PackedStringArray(HANDOUT)) and m5.objectives[3].get("arms", []) == ["cron_mines"] and m5.objectives[5].get("arms", []) == ["rm_rf_cannon"] and MissionBook.granted_by(5).size() == 11 and MissionBook.granted_by(4).size() == 9)
	_check("acceptance: and exactly its ability (STORY.md: sudo and root#), unlocked as the first job's beat begins; SIGSTOP, SIGHUP and /dev/null still later missions'", m5.abilities == PackedStringArray(["sudo"]) and m5.objectives[0].get("unlocks", []) == ["sudo"] and _same(m5.allowed_abilities(), PackedStringArray(["sudo", "code_rain_vision", "breakers"])))
	var elites := 0
	var kinds := {}
	var job_waves := PackedStringArray()
	for jp in m5.job_props():
		for wid in jp.get("waves", []):
			job_waves.append(str(wid))
	var elite_kinds := PackedStringArray()
	for w in m5.waves:
		kinds[w["kind"]] = true
		if int(w.get("elites", 0)) > 0:
			elites += int(w["elites"])
			elite_kinds.append(w["kind"])
	_check("acceptance: its enemies are elites of all three types and jobs that come on a timer (STORY.md), finite: %d elites (%s) of %d daemons in %d waves, %d jobs scheduling %d of the waves, no ICE, no wave coming back" % [elites, ", ".join(elite_kinds), m5.daemons_total(), m5.waves.size(), m5.job_props().size(), job_waves.size()], elites == 3 and _same(elite_kinds, PackedStringArray(["rogue", "zombie", "swarm"])) and kinds.size() == 3 and not m5.ice and m5.job_props().size() == 4 and job_waves.size() == 7 and m5.daemons_total() == 24 and m5.door_props().size() == 1)
	var wipe := {}
	for jp in m5.job_props():
		if jp["id"] == "wipe":
			wipe = jp
	_check("the set piece as data: the wipe job counts down to rm -rf (its fail), scheduled as its beat begins and removed as it is done, its runner a zombie elite", not wipe.is_empty() and str(wipe.get("fails", "")).begins_with("rm -rf") and wipe.get("on") == "begin:wipe" and wipe.get("until") == "done:wipe" and _wave(m5, "wiper_1").get("elites", 0) == 1 and _wave(m5, "wiper_1").get("kind") == "zombie")
	# Spoilers: what the player sees before the oldest log, and what the oldest log itself says (STORY.md's reveal).
	var before := _shown_before(m5)
	var leaks := PackedStringArray()
	for w in BEFORE + ENDING:
		if before.to_lower().contains(w):
			leaks.append(w)
	var oldest := m5.log_of("oldest")
	var whole := _shown_words(m5).to_lower()
	for w in ENDING:
		if whole.contains(w):
			leaks.append("ending: " + w)
	var redacted := true
	var pid_re := RegEx.new()
	pid_re.compile("held by pid[^\\n]*[0-9]")
	if pid_re.search(whole) != null:
		redacted = false
	_check("acceptance (spoilers): nothing a player sees before the oldest log says 6666, nohup, `~` or how it ends; the oldest log, read as root, names the shell under nohup still running as pid 6666 with its author field forged and never `~`; the session-holder's PID of mission 4 stays redacted", leaks.is_empty() and not oldest.is_empty() and str(oldest["text"]).contains("nohup") and str(oldest["text"]).contains("pid 6666") and str(oldest["text"]).contains("forged") and not str(oldest["text"]).contains("~") and str(oldest.get("on", "")) == "begin:door" and redacted, ", ".join(leaks))
	_check("acceptance: STORY.md's lines and beats as data: the Auditor refusing sudo as it starts, the doubt line on the crontab's author, your AI's line on the oldest log, the register Tron decaying into Matrix (a slow shift without the tear) from the watchdog's beat", _line_of(m5, "start", "auditor").get("text", "").contains("not in sudoers") and _line_of(m5, "log:author", "ai").get("text", "") == DOUBT and _has_line(m5, "log:oldest", "ai", WHO) and m5.register == "tron" and m5.transitions.size() == 1 and m5.transitions[0]["to"] == "matrix" and m5.transitions[0]["on"] == "begin:watchdog" and float(m5.transitions[0].get("seconds", 0)) >= 60.0 and m5.transitions[0].get("tear", true) == false)
	var others := PackedStringArray()
	for i in range(1, 5):
		if MissionBook.at(i).ruins == m5.ruins:
			others.append(MissionBook.at(i).id)
	_check("not a reskin: no earlier mission stands in its district", others.is_empty())
	# The validator refuses bad mission 5 data by name.
	var bad := m5.duplicate(true) as MissionDef
	bad.waves = bad.waves.duplicate(true)
	bad.waves[0]["on"] = "start"  # reap_1 is the reap job's: no trigger of its own
	var bad2 := m5.duplicate(true) as MissionDef
	bad2.abilities = PackedStringArray()  # no sudo: no root objective, no root door
	var bad3 := m5.duplicate(true) as MissionDef
	bad3.props = bad3.props.duplicate(true)
	for p in bad3.props:
		if p.get("kind") == "job":
			p["every"] = 1.0
	var bad4 := m5.duplicate(true) as MissionDef
	bad4.transitions = bad4.transitions.duplicate(true)
	bad4.transitions[0]["seconds"] = 999.0
	var rset0 := RuinsBook.of("sudoers")
	var bad_set := rset0.duplicate(true) as RuinsSet
	bad_set.pristine = true
	var bad_set2 := rset0.duplicate(true) as RuinsSet
	bad_set2.room_names = "ROOT"
	_check("the validator refuses bad mission 5 data by name: a job's wave with its own trigger, root and a root door without sudo, a job every second, a shift over 999 s, decay in a pristine set, a room with one name", _has(bad.problems(MissionBook.weapon_ids()), "has a trigger of its own") and _has(bad2.problems(MissionBook.weapon_ids()), "not handed sudo") and _has(bad3.problems(MissionBook.weapon_ids()), "runs every") and _has(bad4.problems(MissionBook.weapon_ids()), "0 to 180 seconds") and _has(bad_set.problems(), "pristine") and _has(bad_set2.problems(), "three names"))


## Everything shown before the oldest log is read: every objective, hint, label, line not on the oldest log's trigger or
## after, every other log, the district's words.
func _shown_before(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		if entry["id"] != "oldest":
			out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		if line["on"] != "log:oldest" and line["on"] != "complete":
			out += " " + str(line["text"])
	var s := RuinsBook.of(def.ruins)
	out += " " + " ".join(s.words) + " " + " ".join(s.folders) + " " + s.board_lines.replace("|", " ") + " " + s.room_names.replace("|", " ")
	return out


func _shown_words(def: MissionDef) -> String:
	var out := _shown_before(def)
	out += " " + str(def.log_of("oldest").get("text", ""))
	for line in def.lines:
		out += " " + str(line["text"])
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


func _wave(def: MissionDef, id: String) -> Dictionary:
	for w in def.waves:
		if w["id"] == id:
			return w
	return {"count": 0}


func _same(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


# --- The district. ---

func _district_checks() -> void:
	var s := RuinsBook.of("sudoers")
	var plan := RuinsLayout.of(s)
	var start: Vector3 = plan.points["start"]
	var exit: Vector3 = plan.points["exit"]
	var clean_holes := 0
	for h in plan.holes:
		if plan.decay_at(plan.center(h["rect"].position)) < RuinsLayout.DECAY_BROKEN:
			clean_holes += 1
	var clean_cover := 0
	for c in plan.cover:
		if plan.decay_at(c["at"]) < RuinsLayout.DECAY_CLEAN:
			clean_cover += 1
	var clean_towers := 0
	var dirty_towers := 0
	for t in plan.towers:
		if t.get("pristine", false):
			clean_towers += 1
		elif plan.decay_at(t["at"]) >= RuinsLayout.DECAY_CLEAN:
			dirty_towers += 1
	_check("its district decays from the start to the exit (STORY.md: the grid starts to rain as you go down): 0.00 at the start, %.2f midway, 1.00 at the exit; the start clean (no hole or cover before the decay, %d towers pristine), the exit end the ruins' (%d holes, %d cover, %d towers leaning or dying)" % [plan.decay_at((start + exit) * 0.5), clean_towers, plan.holes.size(), plan.cover.size(), dirty_towers], s.problems().is_empty() and s.decay == "exit" and not s.pristine and plan.decay_at(start) == 0.0 and plan.decay_at(exit) == 1.0 and absf(plan.decay_at((start + exit) * 0.5) - 0.5) < 0.05 and clean_holes == 0 and clean_cover == 0 and plan.holes.size() >= 2 and plan.cover.size() >= 6 and clean_towers >= 4 and dirty_towers >= 4 and plan.pristine_at(start) and not plan.pristine_at(exit))
	var walls := plan.blocks.filter(func(b): return b["kind"] == "wall")
	var door: Vector2i = plan.room.get("door", Vector2i(-9, -9))
	var inside: Vector2i = plan.room.get("inside", Vector2i(-9, -9))
	var ring := true
	if not plan.room.is_empty():
		var rect: Rect2i = plan.room["rect"]
		for x in range(rect.position.x, rect.end.x):
			for z in range(rect.position.y, rect.end.y):
				var c := Vector2i(x, z)
				var open := c == inside or c == door
				ring = ring and (plan.cell(c) == RuinsLayout.Cell.BLOCK) != open
	_check("the sealed room at the exit end: the exit cell walled in by %d named stacks with one doorway facing the start on the route, the points room (inside) and room_door (the doorway), the crontab board on the plaza's edge (the point board in front of it), every point walkable" % walls.size(), not plan.room.is_empty() and walls.size() == 7 and ring and plan.route.has(door) and plan.route.back() == inside and plan.points.has("room") and plan.points.has("room_door") and (plan.points["room"] as Vector3).z < (plan.points["room_door"] as Vector3).z and not plan.board.is_empty() and plan.points.has("board") and plan.blocks.filter(func(b): return b["kind"] == "board").size() == 1 and plan.unreachable().is_empty())
	var others := PackedStringArray()
	for rset in RuinsBook.all():
		if rset.id != "sudoers" and (rset.decay != "" or rset.room != "" or rset.board != ""):
			others.append(rset.id)
	var vault := RuinsBook.of("records_vault")
	_check("only its district decays, has a room and a board: the other districts plan as before (the records vault still pristine, with its vault)", others.is_empty() and vault.pristine and vault.vault == "exit" and RuinsLayout.of(vault).decay_at(Vector3.ZERO) == 0.0, ", ".join(others))


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(5))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	_check("as it starts (its card up), missions 1 to 4's nine are carried and nothing of mission 5's yet, the arena's own four gone, no ICE", runner.state == MissionRunner.State.INTRO and player.carried == PackedStringArray(CARRIED) and not main.has_node("Arena/Targets/DummyA") and IceDirector.of(main).stand_down)
	_action("sudo_overcharge")
	await _frames(2)
	var locked_first: bool = said.has("sudo") and not player.abilities.has("sudo")
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var told := await _until(func(): return toast.text() == "IN HAND: sudo and root#  [Z]")
	var shown := toast.text()
	var typed := await _until(func(): return _shown_has(mh, ">> sudo and root# handed to you"))
	_check("acceptance (handout): sudo refused before the first job's beat and unlocked as it begins, told at the top (\"%s\") and in the terminal; in mission 5 the gate is on: code-rain vision and the ICEbreakers (missions 3's and 4's) allowed, sudo now, nothing else" % shown, locked_first and told and typed and player.abilities_gated and _same(player.abilities, PackedStringArray(["code_rain_vision", "breakers", "sudo"])))
	var weapons = hud.weapon_hud()
	var cron_slot := int(player.inventory.slot_of("cron_mines"))
	var rm_slot := int(player.inventory.slot_of("rm_rf_cannon"))
	var drew_cron: bool = player.select_slot(cron_slot)
	var drew_rm: bool = player.select_slot(rm_slot)
	_check("acceptance (gating by campaign order): cron (8) and rm -rf (7) refuse to draw until their beats hand them over", not drew_cron and not drew_rm and player.inventory.current != cron_slot and player.inventory.current != rm_slot and not player.carried.has("cron_mines") and not player.carried.has("rm_rf_cannon"))
	_action("sigstop")
	await _frames(2)
	var dev_null := int(player.inventory.slot_of("dev_null"))
	var sighup := int(player.inventory.slot_of("sighup"))
	var drew_null: bool = dev_null >= 0 and player.select_slot(dev_null)
	var drew_hup: bool = sighup >= 0 and player.select_slot(sighup)
	_check("and what mission 6 hands over: SIGSTOP, /dev/null and SIGHUP refused, said plainly (\"%s\")" % weapons.locked_text(), not player.sigstop.is_on() and said.has("sigstop") and not drew_null and not drew_hup)
	_key(KEY_6)
	await _frames(2)
	var grep_drawn: bool = player.inventory.current == int(player.inventory.slot_of("grep_seeker"))
	var chmod_drawn: bool = player.select_slot(int(player.inventory.slot_of("chmod_000")))
	_check("grep (mission 3's) and chmod 000 (mission 4's) draw on their keys", grep_drawn and chmod_drawn)
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	_check("acceptance (gating): not in the arena: in free play the gate is off and cron and rm -rf draw", not player.abilities_gated and player.select_slot(int(player.inventory.slot_of("cron_mines"))) and player.select_slot(int(player.inventory.slot_of("rm_rf_cannon"))))


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var m5 := MissionBook.at(5)
	var old_id := main.get_instance_id()
	runner.begin(m5)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ sudo !!\")", MissionRunner.mounting() == "$ sudo !!" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	_began.clear()
	_fired.clear()
	_ran.clear()
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	stage.spawned.connect(func(d: Node3D) -> void: _watch(d))
	stage.job_ran.connect(func(id: String, run: int, _runs: int) -> void: _ran.append([id, run, runner.clock]))
	for d in stage.made:
		_watch(d)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	await _frames(10)
	var rows: Array = mh.jobs_rows()
	var reap_row: Dictionary = rows[0] if rows.size() > 0 else {}
	_check("acceptance: as it starts the crontab on the panel shows the first job counting down (\"%s\" in %.0f s), nothing standing yet, the register Tron, the district the sudoers' ladder with its door shut and its board lit" % [reap_row.get("name", ""), reap_row.get("left", -1.0)], world != null and world.ruins.id == "sudoers" and rows.size() == 1 and reap_row.get("name") == "reap.sh" and reap_row.get("live") == true and float(reap_row.get("left", -1.0)) > 8.0 and stage.standing().is_empty() and runner.register == "tron" and stage.doors().size() == 1 and (stage.doors()[0] as RootDoor).blocking() and world.has_board())
	var climbed := await _play_until(main, func(): return stage.wave_state("reap_1") != "waiting", MOST_FRAMES, false)
	var at_vent := stage.standing().size() > 0 and Vector2(stage.standing()[0].global_position.x - world.point("spawn_2").x, stage.standing()[0].global_position.z - world.point("spawn_2").z).length() < 2.5
	_check("acceptance (timed jobs): the first job runs on time (%.1f s on the clock, scheduled every 12), its three zombies climbing out of its vent, the Auditor logging the run" % runner.clock, climbed and absf(runner.clock - 12.0) < 1.5 and _ran.size() == 1 and _ran[0][0] == "reap" and at_vent and _fired_has("cron ran reap.sh (run 1 of 1)"))
	var jobs_done := await _play_until(main, func(): return runner.index >= 1)
	runner.life.shield(100000.0)
	_check("acceptance (sudo): three kills in one life earn a sudo charge, the first beat done (%d kills, %d charges)" % [runner.kills, player.sudo.charges()], jobs_done and runner.kills == 3 and player.sudo.charges() == 1 and not player.sudo.is_root() and _began.has("root"))
	await _frames(30)
	var not_yet: bool = runner.index == 1  # the root beat waits for Z: it is not done on its own
	_action("sudo_overcharge")
	var rooted := await _until(func(): return player.sudo.is_root())
	var root_done := await _until(func(): return runner.index >= 2)
	_check("acceptance (root): Z makes the player root# (the password line, then root for %.0f s) and the objective is done; the Auditor allows it on the proof of three kills" % player.sudo.tuning_in_use().root_s, not_yet and rooted and root_done and player.sudo.charges() == 0 and _fired_has("action=sudo result=ALLOWED (proof: 3 kills)"))
	# The watchdog: an elite rogue.d out of the plaza's vent; the player stood 4.5 m before it in the open.
	var watchdog: Node3D = null
	await _play_until(main, func(): return stage.wave_daemons("watchdog_1").size() > 0, MOST_FRAMES, false)
	watchdog = stage.wave_daemons("watchdog_1")[0]
	var brain: DaemonBrain = watchdog.brain
	var vent: Vector3 = world.point("spawn_1")
	player.global_position = Vector3(vent.x, vent.y, vent.z + 4.5)
	player.velocity = Vector3.ZERO
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0  # attackable: a daemon never tells on a protected player
	var gap_at_tell := -1.0
	var frames := 0
	while frames < 900 and brain.tells < 1 and (watchdog.climbing() or watchdog.is_alive()):
		await process_frame
		frames += 1
	if brain.tells >= 1:
		gap_at_tell = Vector2(player.global_position.x - watchdog.global_position.x, player.global_position.z - watchdog.global_position.z).length()
	runner.life.shield(100000.0)
	var reach: float = brain.dummy.get("tuning").rogue_reach_m if brain.dummy.get("tuning") != null else 2.4
	_check("acceptance (elites): the watchdog is an elite rogue.d (its art's and its brain's: %.0f health, elite %s) that tells from farther than any rogue reaches (%.1f m at its tell, a rogue's reach %.1f m): the pounce; the register decaying toward Matrix from its beat, no tear" % [watchdog.max_health, str(brain.elite), gap_at_tell, reach], watchdog.art_node().elite and brain.elite and MissionRunner.kind_of(watchdog) == "rogue" and watchdog.max_health >= 100.0 and brain.tells >= 1 and gap_at_tell > reach + 0.5 and runner.register == "matrix" and world.shifting() and world.tear == 0.0 and world.mix.z > 0.0 and world.mix.z < 1.0)
	var watchdog_down := await _play_until(main, func(): return runner.index >= 3)
	runner.life.shield(100000.0)
	var cron_told := await _until(func(): return (toast.text().begins_with("IN HAND: cron") and toast.text().ends_with("[8]")) or _shown_has(mh, ">> cron handed to you  [8]"))
	var told_as := toast.text()
	var cron_slot := int(player.inventory.slot_of("cron_mines"))
	var drew: bool = player.select_slot(cron_slot)
	# A mine placed at the job's vent, as the hint says, before the job runs: drawn, the swap over, then one press.
	var mine_vent: Vector3 = world.point("spawn_4")
	player.global_position = Vector3(mine_vent.x, mine_vent.y, mine_vent.z + 3.0)
	player.velocity = Vector3.ZERO
	await _until(func(): return not player.inventory.is_swapping() and player.inventory.current == cron_slot)
	for i in 3:
		_aim(player, mine_vent)
		player.drive_input(Vector2.ZERO, false, false, true)
		await physics_frame
	player.drive_input(Vector2.ZERO)
	var mined := await _until(func(): return main.get_tree().get_nodes_in_group(&"cron_mine").size() >= 1)
	_check("acceptance (cron): the watchdog down, cron put in hand for the job that must be mined, told (\"%s\"), drawn on 8 and a mine placed at the job's vent" % told_as, watchdog_down and cron_told and drew and player.carried.has("cron_mines") and mined, "drew %s current %d mined %s" % [drew, player.inventory.current, mined])
	var fork_twice := await _play_until(main, func(): return _ran.size() >= 3, MOST_FRAMES * 2)
	var gap := float(_ran[2][2]) - float(_ran[1][2]) if _ran.size() >= 3 else -1.0
	_check("the fork job runs twice, fifteen seconds apart (%.1f s), each run a wave of rogues out of its vent, and the beat is done once its four are down" % gap, fork_twice and _ran[1][0] == "fork" and _ran[2][0] == "fork" and absf(gap - 15.0) < 1.5 and await _play_until(main, func(): return runner.index >= 4))
	# The crontab's author: the log in front of the board, read; the doubt lines.
	var author = runner.pickup("author")
	var at_board: bool = author != null and author.global_position.distance_to(world.point("board")) < 0.5
	player.global_position = author.global_position if author != null else player.global_position
	var read_author := await _until(func(): return runner.logs_found.has("author"))
	var doubt := await _until(func(): return _fired_has(DOUBT))
	var anyway := await _until(func(): return _fired_has("run the kill -9 anyway"))
	_check("acceptance (the doubt beat): the crontab read at its board, signed by an assistant, your AI's line on it (STORY.md's) and, after a moment, \"If it was me, run the kill -9 anyway. I mean that.\"", at_board and read_author and str(m5.log_of("author")["text"]).contains("scheduled by: assistant") and doubt and anyway and runner.index >= 5)
	# The wipe: the job counting down in red on the crontab and the board, its runner a zombie elite that charges.
	await _until(func(): return stage.wave_daemons("wiper_1").size() > 0)
	var wiper: Node3D = stage.wave_daemons("wiper_1")[0]
	var wbrain: DaemonBrain = wiper.brain
	var wipe_row := {}
	for row in mh.jobs_rows():
		if row["id"] == "wipe":
			wipe_row = row
	var rm_told := await _until(func(): return (toast.text().begins_with("IN HAND: rm -rf") and toast.text().ends_with("[7]")) or _shown_has(mh, ">> rm -rf handed to you  [7]"))
	var rm_drawn: bool = player.select_slot(int(player.inventory.slot_of("rm_rf_cannon")))
	player.global_position = wiper.global_position + Vector3(0, 0.95, 7.0)
	player.velocity = Vector3.ZERO
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	frames = 0
	while frames < 1200 and wbrain.charges < 1 and (wiper.climbing() or wiper.is_alive()):
		await process_frame
		frames += 1
	runner.life.shield(100000.0)
	_check("acceptance (the set piece): the wipe job on the crontab counting down to rm -rf (\"%s\", %d runs, %.0f s to the first), in red; rm -rf put in hand and drawn on 7; its runner a zombie elite (%.0f health, tagged %s) that charges instead of throwing (%d charges, %d attacks, %d rams)" % [wipe_row.get("name", ""), int(wipe_row.get("runs", 0)), float(wipe_row.get("left", 0.0)), wiper.max_health, str(wiper.get("tag_text")), wbrain.charges, wbrain.attacks, wbrain.rams], wipe_row.get("fails") == true and int(wipe_row.get("runs", 0)) == 3 and float(wipe_row.get("left", 0.0)) > 20.0 and rm_told and rm_drawn and player.carried.has("rm_rf_cannon") and wiper.art_node().elite and wbrain.elite and MissionRunner.kind_of(wiper) == "zombie" and wbrain.charges >= 1 and wbrain.charges == wbrain.attacks and _fired_has("rm -rf /var/log scheduled. runs in 90 s"))
	var wipe_done := await _play_until(main, func(): return runner.index >= 6)
	var wipe_after := {}
	for row in runner.jobs():
		if row["id"] == "wipe":
			wipe_after = row
	_check("the runner killed, the job removed from the crontab before its run (the Auditor: \"process killed before its run\"), the mission not failed", wipe_done and wipe_after.get("done") == true and wipe_after.get("live") == false and _fired_has("crontab: rm -rf /var/log removed") and _fired_has("process killed before its run") and runner.running())
	# The last elite: the runaway at the door, its bursts twice as long.
	await _until(func(): return stage.wave_daemons("guard_1").size() > 0)
	var swarm: Node3D = stage.wave_daemons("guard_1")[0]
	var sbrain: DaemonBrain = swarm.brain
	player.global_position = swarm.global_position + Vector3(0, 0.0, 5.0)
	player.global_position.y = 0.95
	player.velocity = Vector3.ZERO
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	frames = 0
	while frames < 900 and sbrain.tells < 1 and (swarm.climbing() or swarm.is_alive()):
		await process_frame
		frames += 1
	var burst := sbrain.burst_left
	runner.life.shield(100000.0)
	_check("acceptance (elites): the last elite is a runaway whose flock flies as two rings (elite %s, %d drones) and whose dives come in bursts twice as long (%d left as its first tell begins, a runaway's %d)" % [str(sbrain.elite), swarm.art_node().get("_drones"), burst, swarm.get("tuning").swarm_burst if swarm.get("tuning") != null else 3], swarm.art_node().elite and sbrain.elite and MissionRunner.kind_of(swarm) == "swarm" and sbrain.tells >= 1 and burst >= 5)
	var no_log_yet: bool = runner.pickup("oldest") == null
	var elites_done := await _play_until(main, func(): return runner.index >= 7)
	# The root door: shut until root#, sunk while it holds, shut again after; the oldest log standing only now.
	var door: RootDoor = stage.doors()[0]
	var log_now: bool = runner.pickup("oldest") != null
	var shut_first: bool = door.blocking() and _ray_hits(main, door)
	var charge_held: bool = player.sudo.charges() >= 1
	_action("sudo_overcharge")
	var opened := await _until(func(): return player.sudo.is_root() and not door.blocking())
	var passes: bool = not _ray_hits(main, door)
	player.global_position = world.point("room")
	var door_done := await _until(func(): return runner.index >= 8)
	var shut_again := await _until(func(): return not player.sudo.is_root() and door.blocking())
	_check("acceptance (the sealed room): the door only root may pass stands shut (a ray meets it) until three kills and Z make the player root#, sinks out of the way (open %.2f, a ray passes), the room reached, and shuts again as root ends; the oldest log stood only from the door's beat" % door.open_share(), elites_done and no_log_yet and log_now and shut_first and charge_held and opened and passes and door_done and shut_again and _fired_has("mode=0700 owner=root") and _fired_has("root entered path=/root"))
	# The oldest log, read as root: STORY.md's reveal, and exit 0.
	var oldest = runner.pickup("oldest")
	player.global_position = oldest.global_position if oldest != null else world.point("room")
	var read := await _until(func(): return runner.logs_found.has("oldest"))
	var who := await _until(func(): return _fired_has(WHO))
	var forged := _fired_has("Forged. It signs with whoever you'd trust least")
	_check("acceptance (the end beat, STORY.md): the oldest log read as root, the Auditor allowing it and the root session expiring, your AI on the forged author field and \"%s\"" % WHO, read and who and forged and _fired_has("root read path=/root/oldest result=ALLOWED") and runner.state == MissionRunner.State.COMPLETE)
	var end: MissionEndScreen = mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, cron, rm -rf and sudo listed, the next mission named", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and _text_has(end.shown_text(), "cron  [8]") and _text_has(end.shown_text(), "rm -rf  [7]") and _text_has(end.shown_text(), "sudo and root#  [Z]") and _text_has(end.shown_text(), "06  nohup"))
	var standing := stage.standing().size()
	var all_done := true
	for row in runner.jobs():
		all_done = all_done and row["done"] == true and row["live"] == false
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d at most (a job removed before a run never runs it), each stood once and none ever back once down (%d down, %d standing), every job done or removed, the arena's four never there" % [_names.size(), m5.daemons_total(), _down, standing], _names.size() <= m5.daemons_total() and _names.size() >= 12 and _down + standing == _names.size() and all_done and not main.has_node("Arena/Targets/DummyA"))
	_check("the chain ran in STORY.md's order, every beat begun once: %s" % ", ".join(_began), _began == PackedStringArray(CHAIN))
	var m := MissionProgress.current()
	_check("recorded as done, cron and rm -rf unlocked for keeps, mission 6 next", m.is_done("sudo_bang") and Progress.current().has_weapon("cron_mines") and Progress.current().has_weapon("rm_rf_cannon") and MissionBook.at(6).id == "nohup")
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


# --- The fail cards. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(5))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _play_until(main, func(): return runner.stage.standing().size() > 0, MOST_FRAMES, false)
	var zombie: Node3D = runner.stage.standing()[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, zombie, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	var card_up := await _until(func(): return end.is_up())
	var again := await _until(func(): return _fired_has("Again."))
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it (\"Root's gone with the life. Three kills buys it back. Again.\")", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and card_up and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry" and again and mh.shown_text().size() > 0, "state %d reason '%s' up %s kind %s again %s" % [runner.state, runner.reason, card_up, end.kind(), again])
	_check("its jobs stop coming once it has failed", runner.stage.stopped)
	await _drop(main)
	MissionRunner.clear_pending()  # the failed run's retry is kept across reloads: not this one's
	# The wipe job's countdown running out: its own fail, its own reason.
	main = await _arena()
	runner = MissionRunner.of(main)
	old_id = main.get_instance_id()
	runner.begin(MissionBook.at(5))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	mh = main.get_node("Hud").mission_hud()
	var player = main.get_node("Player")
	_fired.clear()
	_ran.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	runner.stage.job_ran.connect(func(id: String, run: int, _runs: int) -> void: _ran.append([id, run, runner.clock]))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	await _play_until(main, func(): return runner.index >= 1, MOST_FRAMES * 2)
	runner.life.shield(100000.0)
	_action("sudo_overcharge")
	await _play_until(main, func(): return runner.index >= 4, MOST_FRAMES * 3)
	runner.life.shield(100000.0)
	var author = runner.pickup("author")
	if author != null:
		player.global_position = author.global_position
	var at_wipe := await _play_until(main, func(): return runner.index >= 5, MOST_FRAMES, false)
	runner.life.shield(100000.0)
	# The job's three countdowns hurried (its data says 30 s each): the runs come, the runner is left standing.
	var stage := runner.stage
	for i in 3:
		runner.life.shield(100000.0)
		stage._jobs["wipe"]["left"] = 0.5
		await _until(func(): return int(stage._jobs["wipe"]["run"]) >= i + 1 or runner.state == MissionRunner.State.FAILED)
	end = mh.end_screen()
	var failed := await _until(func(): return runner.state == MissionRunner.State.FAILED and end.is_up())
	_check("acceptance (fail card): the wipe job's countdown running out fails it with its own reason (\"%s\"), \"exit 137\", after its two runs of queued zombies" % runner.reason, at_wipe and failed and runner.reason == "rm -rf /var/log ran. the oldest log is gone." and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and _ran_count("wipe") == 2 and runner.stage.wave_state("queue_1") != "waiting" and runner.stage.wave_state("queue_2") != "waiting", "at_wipe %s failed %s protect %.0f health %.0f clock %.1f runs %d" % [at_wipe, failed, runner.life.protect_left(), runner.life.health(), runner.clock, _ran_count("wipe")])
	await _drop(main)


func _ran_count(job: String) -> int:
	var n := 0
	for r in _ran:
		if r[0] == job:
			n += 1
	return n


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

extends SceneTree
## Headless test of mission 3, `while true`, built for real (M3, PRD 5.6, docs/STORY.md section 6 mission 3). scripts/
## check.sh runs it as step 58, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission3_test.gd
##
## The code: nothing M3 added or changed runs a program, opens a connection or a file, or reads the player's machine. The
## data: mission 3 validates, is no longer a skeleton, stands in a district of its own (the cache lines, Matrix, not
## missions 1's or 2's), and is STORY.md's: runaway swarms leading it, several cores at once; the first log written to
## you and signed, your AI quiet a moment and then its line; the last core down, the rain stopping for a second and a red
## `>_` on a wall; nothing of 6666, nohup or the ending in anything it shows, and `~` only where STORY.md puts it. The
## handout: missions 1's and 2's six in hand, grep put in hand for the runaways, pipe for the fork storm, code-rain vision
## unlocked for the cores, all told as they come. The gate: what the campaign has not handed over by mission 3 (or this
## mission not yet) is refused and said so. A scripted run in the real arena stood in its ruins: the cache field's walls
## written (solid, in the walk grid), mid-rewrite (shot and walked through) or gone, never written over the player; the
## loop's passes rewriting them, its cores forking, the cache filling; a core down scattering its own children; the last
## breaking the loop; "exit 0"; every daemon it made one of its waves', none back once down, the loop's forks within its
## limits. The cache full fails it ("exit 137", out of memory), as a death does. The M2 leftover it measures: the walk
## grid's route cost with a crowd of daemons. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

## What M3 added or changed that runs in a mission: none of it may touch anything of the player's.
const M3_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/ruins/cache_field.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/daemons/loop_core.gd", "res://scripts/abilities/code_rain_vision.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/mission_end_screen.gd", "res://scripts/hud/unlock_toast.gd", "res://scripts/arena/arena_art.gd", "res://scripts/fight/daemon_brain.gd", "res://scripts/hud.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "store_var", "get_var", "bytes_to_var", "str_to_var", "OS.get_environment", "get_user_data_dir", "get_executable_path", "OpenerData", "AiSourceDetector", "Adapter", "GuideRequest", "/proc", "/sys/", "/home"]
## STORY.md mission 3's beats, in order.
const CHAIN := ["hot", "lines", "storm", "signed", "cores"]
const CARRIED := ["terminal_cannon", "sigterm", "sigkill_rail", "ping_sonar", "fork_bomb", "fork_shotgun"]
const HANDOUT := ["grep_seeker", "pipe_chain"]
## STORY.md's words for mission 3, exactly.
const SIGNED := "it was your loop. i only let it run. ~"
const QUIET := "It signed it. Of course it signed it."
## Nothing mission 3 shows may say who `~` is or how it ends (6666 is mission 5's reveal, nohup mission 6's, the ending mission
## 7's); `~` itself only in the log STORY.md signs with it.
const SPOILERS := ["~", "6666", "nohup", "tilde", "never logged out", "never hung up", "session restored", "user=you", "welcome back", "you won't", "sigkill sent by you", "logged in as you", "shell"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _began: PackedStringArray = []
var _outs := {}
var _downed := 0
var _gone := 0
var _names: PackedStringArray = []
var _fired: PackedStringArray = []
## The frame each line was said on.
var _said_at := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://mission3-test-%d" % OS.get_process_id())
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
	await _cache_checks()
	await _fail_checks()
	await _cleanup()
	print("MISSION 3: %d checks" % _checks)
	print("MISSION 3 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	var all := ""
	for path in M3_CODE:
		var code := _code_of(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 3 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data", found.is_empty() and all.length() > 30000, ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var m3 := MissionBook.at(3)
	var login := MissionBook.at(1)
	var defunct := MissionBook.at(2)
	var problems := m3.problems(MissionBook.weapon_ids())
	_check("mission 3 loads and validates, built for real (playable, not a draft), in a district of its own: the cache lines, not mission 1's or 2's", problems.is_empty() and m3.playable and not m3.draft and m3.ruins == "cache_lines" and m3.ruins != login.ruins and m3.ruins != defunct.ruins and MissionBook.problems().is_empty(), "; ".join(problems + MissionBook.problems()))
	var ids := PackedStringArray()
	for o in m3.objectives:
		ids.append(o["id"])
	_check("acceptance: its objective chain is STORY.md's beats in order: %s" % " > ".join(ids), ids == PackedStringArray(CHAIN))
	var hot: Dictionary = m3.objectives[0]
	var storm: Dictionary = m3.objectives[2]
	var cores: Dictionary = m3.objectives[4]
	_check("acceptance: the handout is exactly mission 3's two weapons (STORY.md: grep, pipe |): missions 1's and 2's six in hand as it starts, grep put in hand for the runaways, pipe for the fork storm, those two kept", m3.loadout == PackedStringArray(CARRIED) and m3.grants == PackedStringArray(HANDOUT) and m3.carried_ever() == PackedStringArray(CARRIED + HANDOUT) and hot.get("arms", []) == ["grep_seeker"] and storm.get("arms", []) == ["pipe_chain"] and _same(MissionBook.granted_by(3), PackedStringArray(CARRIED + HANDOUT)) and _same(MissionBook.granted_by(2), PackedStringArray(CARRIED)))
	_check("acceptance: and exactly its ability (STORY.md: code-rain vision): refused as it starts, unlocked as the cores' beat begins, no other", m3.abilities == PackedStringArray(["code_rain_vision"]) and m3.abilities_at_start().is_empty() and m3.allowed_abilities() == PackedStringArray(["code_rain_vision"]) and cores.get("unlocks", []) == ["code_rain_vision"] and login.allowed_abilities().is_empty() and defunct.allowed_abilities().is_empty())
	var kills := 0
	for o in m3.objectives:
		if o["kind"] == "kill":
			kills += int(o["count"])
	var swarms := m3.daemons_total("swarm")
	_check("acceptance: its daemons are its own and finite, runaway swarms leading (STORY.md: runaway swarms, several cores at once): %d runaways, %d loop cores, no rogue.d, zombie or parent, %d in all, in %d waves, enough for its %d kills" % [swarms, m3.daemons_total("core"), m3.daemons_total(), m3.waves.size(), kills], swarms >= 16 and swarms * 2 > m3.daemons_total() and m3.daemons_total("core") == 4 and m3.daemons_total("rogue") == 0 and m3.daemons_total("zombie") == 0 and m3.daemons_total("parent") == 0 and m3.daemons_total() >= kills and m3.daemons_total() <= 40)
	var loop := m3.loop_prop()
	var forks := _wave(m3, str(loop.get("forks", "")))
	_check("acceptance: the loop always ends: its forks are a wave of %d it can never go past (%d a core at most, %d of a core's standing at once), every core it runs is one of its four, and the cache fills within %.0f s of one core running (out of memory), so nothing it does is endless" % [forks.get("count", 0), loop.get("each", 0), loop.get("standing", 0), float(loop.get("fill_s", 0.0)) * 4.0], not loop.is_empty() and forks.get("by") == loop["id"] and int(forks["count"]) <= MissionDef.WAVE_LAST and int(loop["each"]) * 4 >= int(forks["count"]) and int(loop["standing"]) < int(loop["each"]) + 1 and float(loop["fill_s"]) > 0.0 and float(loop["fill_s"]) <= 600.0 and _wave(m3, str(loop["cores"])).get("count") == 4)
	var words := _shown_words(m3)
	var lowered := words.to_lower()
	var leaks := PackedStringArray()
	for w in SPOILERS:
		if lowered.contains(w):
			leaks.append(w)
	var tilde_lines := m3.lines.filter(func(l): return l.get("who") == "tilde")
	_check("acceptance: no `~`, 6666, nohup or ending text in anything mission 3 shows beyond what STORY.md allows (its lines, its objectives and hints, its other logs, its daemons' tags, the district's signs, folders and the code on its walls); `~` signs the one log STORY.md has it sign and speaks no line of its own (that is mission 6's)", leaks.is_empty() and tilde_lines.is_empty() and words.length() > 1500, ", ".join(leaks))
	var signed: String = m3.log_of("signed").get("text", "")
	var quiet := _line_of(m3, "log:signed")
	_check("STORY.md's mission 3 lands: the first log written to you, not by you (\"%s\"), and your AI quiet a moment (%.1f s) before \"%s\"" % [signed, float(quiet.get("wait", 0.0)), quiet.get("text", "")], signed == SIGNED and not signed.replace("~", "").contains("6666") and quiet.get("text") == QUIET and float(quiet.get("wait", 0.0)) >= 2.0 and quiet.get("who") == "ai")
	var hush := m3.prop_of("silence")
	var watch := m3.prop_of("watching")
	_check("STORY.md's end beat as data: the last core down (done:cores), the rain stopped for one second, then a red `>_` on a wall", hush.get("kind") == "hush" and hush.get("on") == "done:cores" and absf(float(hush.get("seconds", 0.0)) - 1.0) < 0.01 and watch.get("kind") == "prompt" and watch.get("on") == "done:cores" and float(watch.get("after", 0.0)) > float(hush.get("after", 0.0)))
	_check("STORY.md's register: the Matrix, start to end, no shift (STORY.md asks for none), its own three to five logs, the Auditor refusing it as ever", m3.register == "matrix" and RuinsBook.of(m3.ruins).register == "matrix" and m3.transitions.is_empty() and m3.logs.size() >= 3 and m3.logs.size() <= 5 and _line_of(m3, "start").get("text", "").contains("result=DENIED reason=\"no session\""))
	_check("not a reskin of missions 1 or 2: no spawn vents (1's), no queue, shop or parent (2's); a loop running on four cores in a field of walls that rewrite themselves", m3.prop_ids("vent").is_empty() and m3.prop_ids("queue").is_empty() and m3.prop_ids("shop").is_empty() and m3.parent_wave().is_empty() and m3.prop_ids("loop").size() == 1 and RuinsBook.of(m3.ruins).field != "" and login.prop_ids("vent").size() > 0 and defunct.prop_ids("queue").size() == 1)
	var bad := m3.duplicate(true) as MissionDef
	bad.objectives = m3.objectives.duplicate(true)
	bad.objectives[4]["unlocks"] = ["sudo"]
	bad.lines = m3.lines.duplicate(true) + [{"on": "cache:42", "who": "ai", "text": "x"}, {"on": "start", "who": "ai", "text": "y", "wait": 20.0}]
	bad.waves = m3.waves.duplicate(true)
	bad.waves[3]["on"] = "start"
	bad.props = m3.props.duplicate(true)
	for p in bad.props:
		if p["kind"] == "loop":
			p["pass_least_s"] = 30.0
			p["each"] = 0
	var said := bad.problems(MissionBook.weapon_ids())
	_check("the validator refuses bad mission 3 data by name: an ability that is not its own unlocked, a cache mark it never says, a line waiting too long, a forked wave with a trigger, a loop slower on one core than on all, a core forking nothing", said.size() >= 6 and Array(said).any(func(p): return p.contains("unlocks \"sudo\"")) and Array(said).any(func(p): return p.contains("cache:42")) and Array(said).any(func(p): return p.contains("wait")) and Array(said).any(func(p): return p.contains("forked by a loop: no \"on\"")) and Array(said).any(func(p): return p.contains("slower on one core")) and Array(said).any(func(p): return p.contains("each")), "; ".join(said))
	var fieldless := m3.duplicate(true) as MissionDef
	fieldless.ruins = "tty_row"
	var refused := fieldless.problems(MissionBook.weapon_ids())
	_check("and a loop or a prompt in a district with no field", Array(refused).any(func(p): return p.contains("loop loop, but its ruins have no field")) and Array(refused).any(func(p): return p.contains("prompt watching, but its ruins have no field")), "; ".join(refused))


func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		out += " " + str(entry["name"])
		if entry["id"] != "signed":
			out += " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	for w in def.waves:
		out += " " + str(w.get("tag", "")) + " " + str(w.get("epitaph", ""))
	var s := RuinsBook.of(def.ruins)
	out += " " + " ".join(s.words) + " " + " ".join(s.folders) + " " + s.field_code.replace("|", " ")
	return out


func _line_of(def: MissionDef, trigger: String) -> Dictionary:
	for line in def.lines:
		if line["on"] == trigger:
			return line
	return {}


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
	var s := RuinsBook.of("cache_lines")
	var plan := RuinsLayout.of(s)
	var field := plan.field
	var inside := true
	for i in 4:
		inside = inside and (field["rect"] as Rect2i).has_point(plan.cell_at(plan.points["core_%d" % i]))
	_check("its district has its cache field: a 5 by 5 square of cells round the plaza, 60 walls on its lattice and 36 posts, its points (its middle, its edge, four cores' cells) in it, every point walkable", s.problems().is_empty() and (field["rect"] as Rect2i).size == Vector2i(5, 5) and field["walls"].size() == 60 and field["posts"].size() == 36 and inside and plan.points.has("field") and plan.points.has("field_edge") and plan.unreachable().is_empty(), "%s %s" % [str(field.get("rect")), str(plan.unreachable())])
	var always_open := true
	var same := true
	var screened := 0
	var screened_n := 0
	var other := 0
	var other_n := 0
	var cores: Array = field["cores"]
	for turn in 300:
		var st := plan.field_pattern(turn)
		always_open = always_open and plan.field_open(st)
		same = same and st == plan.field_pattern(turn)
		for i in st.size():
			var w: Dictionary = field["walls"][i]
			var standing := 1 if st[i] != RuinsLayout.Wall.GONE else 0
			if cores.has(w["a"]) or cores.has(w["b"]):
				screened += standing
				screened_n += 1
			else:
				other += standing
				other_n += 1
	_check("its rewrites: over 300 passes every cell of the field can always be walked to from outside it, each pass the same every time it is asked, and the walls round a core's cell standing more often (%.0f%% against %.0f%%), so its cores hide" % [100.0 * screened / screened_n, 100.0 * other / other_n], always_open and same and float(screened) / screened_n > float(other) / other_n + 0.15)
	var others := PackedStringArray()
	for set in RuinsBook.all():
		if set.id != "cache_lines" and not RuinsLayout.of(set).field.is_empty():
			others.append(set.id)
	_check("only its district has a field: the other districts plan as before", others.is_empty(), ", ".join(others))
	# The M2 leftover it measures: the walkers' route worked out for a crowd at once, on the biggest grid any mission uses.
	var started := Time.get_ticks_usec()
	var routes := 0
	var long := 0
	for k in 48:
		var from: Vector3 = plan.points["start"] + Vector3(float(k % 6) - 2.5, 0, 0)
		var to: Vector3 = plan.points["exit"] if k % 2 == 0 else plan.points["log_%d" % (k % 4)]
		var r := plan.walk_route(from, to)
		routes += 1
		long = maxi(long, r.size())
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	print("    route cost: %d routes start to exit or a log (up to %d squares long) in %.1f ms, %.2f ms a route" % [routes, long, ms, ms / routes])
	_check("the M2 leftover (route cost untested past a few dozen): 48 daemons' ways round the ruins worked out at once, the longest %d squares, in %.1f ms (%.2f ms a route; each walker asks once every %.1f s), well inside a frame's share" % [long, ms, ms / routes, DaemonBrain.ROUTE_EVERY_S], routes == 48 and long > 40 and ms / routes < 2.0)


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(3))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	_check("as it starts (its card up), missions 1's and 2's six are carried and nothing of mission 3's yet", runner.state == MissionRunner.State.INTRO and player.carried == PackedStringArray(CARRIED))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var told := await _until(func(): return toast.text() == "IN HAND: grep seeker  [6]")
	var shown := toast.text()
	var typed := await _until(func(): return _shown_has(mh, ">> grep handed to you"))
	_check("acceptance (handout): grep put in hand as the runaways' beat begins, told at the top (\"%s\") and in the terminal (\"grep handed to you\")" % shown, player.carried.has("grep_seeker") and told and typed)
	_check("in mission 3 the gate is on and nothing is allowed yet: code-rain vision is this mission's, and only once its beat begins", player.abilities_gated and player.abilities.is_empty())
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	var weapons = hud.weapon_hud()
	var pipe_slot := int(player.inventory.slot_of("pipe_chain"))
	var drawn: bool = player.select_slot(pipe_slot)
	_check("acceptance (gating by campaign order): pipe | refuses to draw until its beat hands it over", not drawn and player.inventory.current != pipe_slot)
	_action("code_rain_vision")
	await _frames(2)
	_check("and code-rain vision (V) refuses until the cores' beat, said plainly (\"%s\")" % weapons.locked_text(), not player.vision.is_on() and said.has("code_rain_vision") and weapons.locked_text() == "code-rain vision: not handed to you yet")
	var rm := int(player.inventory.slot_of("rm_rf_cannon"))
	_key(KEY_7)
	await _frames(2)
	_action("sigstop")
	await _frames(2)
	_action("sudo_overcharge")
	await _frames(2)
	var breakers := BreakerDirector.of(main)
	_check("and what later missions hand over: rm -rf (7), SIGSTOP and sudo refused, the ICEbreakers locked at their director", player.inventory.current != rm and said.has("rm_rf_cannon") and not player.sigstop.is_on() and said.has("sigstop") and said.has("sudo") and breakers != null and breakers.locked)
	_key(KEY_6)
	await _frames(2)
	_check("grep draws on its key once in hand", player.inventory.current == int(player.inventory.slot_of("grep_seeker")))
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	_check("acceptance (gating): not in the arena: in free play the gate is off, pipe draws, code-rain vision runs", not player.abilities_gated and player.select_slot(int(player.inventory.slot_of("pipe_chain"))) and player.ability_ok("code_rain_vision"))


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var m3 := MissionBook.at(3)
	var old_id := main.get_instance_id()
	runner.begin(m3)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ while true\")", MissionRunner.mounting() == "$ while true" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var field := world.field()
	_began.clear()
	_fired.clear()
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	runner.line_said.connect(func(_who: String, text: String) -> void:
		_fired.append(text)
		_said_at[text] = Engine.get_process_frames())
	stage.spawned.connect(func(d: Node3D) -> void: _watch(d))
	for d in stage.made:
		_watch(d)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _frames(30)
	var arena_four := false
	for n in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		arena_four = arena_four or main.has_node("Arena/Targets/" + n)
	_check("acceptance: its daemons are its own: the arena's four gone, its four runaways out in the cache lines, no core yet, the field standing (60 walls, some written)", not arena_four and world != null and world.ruins.id == "cache_lines" and stage.made.size() == 4 and stage.made.all(func(d): return MissionRunner.kind_of(d) == "swarm") and field != null and field.wall_count() == 60 and field.solid_count() > 0)
	runner.life.shield(LONG_ROUND_S)
	# The field: written walls solid and closed in the walk grid, mid-rewrite and gone ones open and shot through.
	var walls: Array = field.get("_walls")
	var astar: AStarGrid2D = world.layout.walk_astar()
	var solid := -1
	var dirty := -1
	for i in walls.size():
		if solid < 0 and walls[i]["solid"]:
			solid = i
		if dirty < 0 and walls[i]["state"] == RuinsLayout.Wall.DIRTY and walls[i]["storm"] > 0.9:
			dirty = i
	var n: Vector2i = field.get("_grid_n")
	var closed := solid >= 0 and Array(walls[solid]["squares"]).all(func(s): return astar.is_point_solid(Vector2i(s % n.x, s / n.x)))
	_check("a written wall is solid: it stops a step and a shot (its collision on), and its squares are closed in the walkers' way round (the walk grid's A* grid)", solid >= 0 and not (walls[solid]["shape"] as CollisionShape3D).disabled and closed and _ray_hits(main, field.wall_node(solid)))
	_check("a wall mid-rewrite stands as tall but nothing of it is solid: a shot (a ray of the level's) goes straight through it", dirty >= 0 and (walls[dirty]["shape"] as CollisionShape3D).disabled and not _ray_hits(main, field.wall_node(dirty)))
	# A wall never writes in over the player: it waits mid-write until they are out of its way.
	var gone := -1
	for i in walls.size():
		if walls[i]["state"] == RuinsLayout.Wall.GONE and walls[i]["fill"] == 0.0 and walls[i]["storm"] == 0.0:
			gone = i
			break
	field.driven = true  # no rewrite of its own while this one wall is watched
	var wall_node: MeshInstance3D = field.wall_node(gone)
	player.global_position = wall_node.global_position + Vector3(0, -RuinsLayout.FIELD_WALL_H * 0.5 + RuinsLayout.STAND_Y, 0)
	walls[gone]["state"] = RuinsLayout.Wall.WRITTEN
	await _frames(int(Engine.physics_ticks_per_second * (CacheField.STORM_S + CacheField.WRITE_S + 0.6)))
	var held: bool = not walls[gone]["solid"] and walls[gone]["fill"] > 0.9 and walls[gone]["fill"] < 1.0
	player.global_position = world.point("start")
	var written := await _until(func(): return walls[gone]["solid"])
	field.driven = false
	_check("a wall never writes in over the player: it waits mid-write with them in it, and closes once they are out of its way", gone >= 0 and held and written)
	await _play_until(main, func(): return runner.index >= 1)
	_check("find what's running hot: four runaways down", runner.index == 1 and stage.wave_state("hot") == "cleared")
	player.global_position = world.point("field_edge")
	await _play_until(main, func(): return runner.index >= 2, 120, false)
	await _frames(2)
	var piped := await _until(func(): return _shown_has(mh, ">> pipe handed to you"))
	_check("acceptance (handout): at the cache lines the fork storm pours out of them and pipe | is put in hand to run down it, told", runner.index == 2 and stage.wave_state("storm") != "waiting" and player.carried.has("pipe_chain") and piped and _fired.has("It's forking. A whole storm of them, in a line. Pipe them: one shot runs down the chain."))
	await _play_until(main, func(): return runner.index >= 3)
	_check("the fork storm broken: eight runaways down", runner.index == 3 and stage.wave_state("storm") == "cleared")
	player.global_position = runner.log_place("signed")
	await _until(func(): return runner.logs_found.has("signed"))
	var read_at := Engine.get_process_frames()
	var signed_shown := await _until(func(): return _shown_has(mh, SIGNED))
	await _until(func(): return _fired.has(QUIET))
	var quiet_s: float = float(int(_said_at.get(QUIET, read_at)) - read_at) / Engine.physics_ticks_per_second
	_check("acceptance (STORY.md): the first log written to you, not by you, read in the middle of the lines (\"%s\"); your AI quiet a moment (%.1f s of play), then \"%s\"" % [SIGNED, quiet_s, QUIET], signed_shown and _fired.has(QUIET) and quiet_s >= 2.5, "%.2f s" % quiet_s)
	await _until(func(): return runner.index >= 4)
	var ability_told := await _until(func(): return toast.text() == "IN HAND: code-rain vision  [V]" or _shown_has(mh, ">> code-rain vision handed to you"))
	var ability_typed := await _until(func(): return _shown_has(mh, ">> code-rain vision handed to you  [V]"))
	_check("acceptance (the ability): code-rain vision unlocked as the cores' beat begins, told at the top and in the terminal; the gate opened for it", runner.index == 4 and player.abilities.has("code_rain_vision") and player.ability_ok("code_rain_vision") and ability_told and ability_typed)
	await _until(func(): return stage.cores().size() == 4 and stage.cores().all(func(c): return not c.climbing()))
	var cores: Array = stage.cores()
	var on_cells := true
	for i in 4:
		on_cells = on_cells and cores.any(func(c): return Vector2(c.global_position.x - world.point("core_%d" % i).x, c.global_position.z - world.point("core_%d" % i).z).length() < 0.6)
	var tags := PackedStringArray()
	for c in cores:
		tags.append(c.tag_text)
	tags.sort()
	_check("its cores: four loop cores, rooted where they run (they never move or strike), one in each of the field's core cells, tagged by the core they run on (%s)" % ", ".join(tags), cores.all(func(c): return MissionRunner.kind_of(c) == "core" and c.sessile()) and on_cells and tags == PackedStringArray(["cpu0", "cpu1", "cpu2", "cpu3"]))
	# Code-rain vision: the cores' silhouettes through the walls, in their own colour where the world is green.
	_action_hold("code_rain_vision", true)
	await _frames(4)
	var marker: MeshInstance3D = player.vision.marker_of(cores[0]) if player.vision.marked().has(cores[0]) else null
	var colour: Color = marker.get_instance_shader_parameter("body_color") if marker != null else Color(0, 0, 0, 0)
	_check("acceptance (the ability's beat): code-rain vision on shows every core through the walls, each silhouette stretched round its wheel and in its own magenta (the Matrix register's world is the walls' green)", player.vision.is_on() and cores.all(func(c): return player.vision.marked().has(c)) and marker != null and marker.scale.x > 1.5 and colour.a > 0.5 and colour.is_equal_approx(Color(Palette.HOT_MAGENTA, 1.0)))
	_action_hold("code_rain_vision", false)
	# The loop runs: a pass rewrites the field and has every core fork one child at its hub; the cache fills.
	var turn := field.turn
	await _until(func(): return stage.passes >= 1)
	await _frames(int(Engine.physics_ticks_per_second * 0.6))
	var per_core := {}
	for k in stage.forks_made:
		per_core[k.get_meta(&"core")] = int(per_core.get(k.get_meta(&"core"), 0)) + 1
	_check("the loop runs: its first pass rewrote the field (pass %d) and had each core fork one runaway off its hub, hunting at once" % field.turn, field.turn > turn and stage.forks_made.size() == 4 and per_core.size() == 4 and stage.forks_made.all(func(k): return k.brain != null and k.brain.relentless and MissionRunner.kind_of(k) == "swarm"))
	var cache_shown := _shown_has(mh, "cache  ")
	_check("the cache fills while the cores run (%.1f%% now) and the panel shows it with the loop's i (\"%s\")" % [runner.cache_share() * 100.0, mh.cache_text()], runner.cache_share() > 0.0 and cache_shown and mh.cache_text().contains("i=%d" % stage.passes))
	# One core down: its own children scattered (reaped, credited to nobody), the others' standing; the rest run hotter.
	var first: Node3D = cores[0]
	var its_kids := stage.forks_made.filter(func(k): return k.get_meta(&"core") == first and k.is_alive())
	var others := stage.forks_made.filter(func(k): return k.get_meta(&"core") != first and k.is_alive())
	var kills := runner.kills
	var before: float = first.health()
	first.hit(1000.0, first.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
	_check("no one hit takes more than its cap off a core (%.0f of a 1000 kill -9): it outlasts a single rail" % (before - first.health()), absf((before - first.health()) - float(m3.waves[2]["hit_cap"])) < 0.01 and first.is_alive())
	while first.is_alive():
		first.hit(1000.0, first.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
		await process_frame
	await _frames(2)
	var hot_now: float = stage.cores()[0].art_node().heat
	_check("a core down scatters its own children: its %d forks reaped at once, credited to nobody (one kill counted, the core's), the other cores' %d still hunting, and the cores left run hotter (heat %.2f)" % [its_kids.size(), others.size(), hot_now], its_kids.size() >= 1 and its_kids.all(func(k): return not is_instance_valid(k) or (not k.is_alive() and k.credited == false)) and others.all(func(k): return k.is_alive()) and runner.kills == kills + 1 and hot_now > 0.0 and not stage.loop_broken_now)
	# The rest down: the loop broken, the field frozen, the rain stopped a second, a red `>_` on a wall.
	while stage.cores().size() > 0:
		for c in stage.cores():
			if c.is_alive():
				c.hit(1000.0, c.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
		await process_frame
	await _frames(2)
	var reaped := stage.forks_made.all(func(k): return not is_instance_valid(k) or not k.is_alive())
	var carets := 0
	for i in field.wall_count():
		if field.wall_state(i)["caret"]:
			carets += 1
	_check("acceptance (STORY.md's end beat): the last core down breaks the loop: every fork left reaped, the field frozen where it stood, `^C` over %d of its standing walls" % carets, stage.loop_broken_now and reaped and field.frozen and carets > 10)
	var hushed := await _until(func(): return world.hushed())
	var still := ArenaArt.clock_held()
	var prompt := await _until(func(): return field.prompt_node() != null)
	var prompt_wall: Node3D = field.prompt_node().get_parent() if field.prompt_node() != null else null
	var cam: Camera3D = main.get_viewport().get_camera_3d()
	var ahead: bool = prompt_wall != null and (-cam.global_transform.basis.z).dot((prompt_wall.global_position - cam.global_position).normalized()) > 0.0
	_check("and the rain stops for one second (the weather and the code in the walls held still), and in it a red `>_` blinks on a wall in front of the player: `~`, watching", hushed and still and prompt and ahead)
	var ran_on := await _until(func(): return not world.hushed() and not ArenaArt.clock_held())
	_check("then the rain runs on", ran_on)
	_check("acceptance: the objective chain completed in order with a scripted run: %s" % " > ".join(_began), runner.state == MissionRunner.State.COMPLETE and _began == PackedStringArray(CHAIN))
	var end := mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, the Auditor's interrupt and your AI's last line read first, code-rain vision listed with its two weapons", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and _text_has(end.shown_text(), "code-rain vision  [V]") and _fired.has("audit: pid 2271 (while true) interrupted. exit 130. cache flushed.") and _fired.has("...Tell me you saw that too."))
	await _frames(int(Engine.physics_ticks_per_second * 2.0))
	var most_outs := 0
	for k in _outs:
		most_outs = maxi(most_outs, int(_outs[k]))
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d, each up once and none ever back once down: %d down, %d gone for good" % [_names.size(), m3.daemons_total(), _downed, _gone], _names.size() <= m3.daemons_total() and _names.size() >= 19 and most_outs == 1 and _downed >= 19 and _gone == _downed and stage.stopped)
	_check("acceptance: its weapons kept and mission 3 recorded done", MissionProgress.current().is_done("while_true") and Progress.current().has_weapon("grep_seeker") and Progress.current().has_weapon("pipe_chain"))
	await _drop(main)


func _watch(d: Node3D) -> void:
	var key := String(d.name)
	if _names.has(key):
		return
	_names.append(key)
	d.respawned.connect(func(_x): _outs[key] = int(_outs.get(key, 0)) + 1)
	d.downed.connect(func(_x): _downed += 1)
	d.gone.connect(func(_x): _gone += 1)


## True when a ray of the level's straight through `wall`'s middle (from a metre one side to a metre the other) meets it.
func _ray_hits(main: Node, wall: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var across: Vector3 = wall.global_transform.basis.z.normalized()
	var mid := wall.global_position
	var q := PhysicsRayQueryParameters3D.create(mid - across, mid + across, 1)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and wall.is_ancestor_of(hit["collider"])


## Frames until `condition` holds (at most `most`), shooting down as a sure shot would the daemons the objective running
## counts and any runaway hunting (never a core before its own beat); its last answer. With `shoot` off it only waits.
func _play_until(main: Node, condition: Callable, most: int = MOST_FRAMES, shoot: bool = true) -> bool:
	var runner := MissionRunner.of(main)
	var frames := 0
	while frames < most and not condition.call():
		if shoot and runner != null and runner.stage != null:
			var of: Array = runner.objective().get("of", [])
			for d in runner.stage.standing():
				if not d.is_alive() or d.sessile() and not of.has(str(d.get_meta(&"wave", ""))):
					continue
				d.hit(1000.0, d.global_position + Vector3.UP, Vector3.FORWARD, "sigterm")
		await process_frame
		frames += 1
	return condition.call()


# --- The loop's limits, and the cache full. ---

func _cache_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(3))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	var player = main.get_node("Player")
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(LONG_ROUND_S)
	var stage := runner.stage
	await _play_until(main, func(): return runner.index >= 1)
	player.global_position = runner.world.point("field_edge")
	await _play_until(main, func(): return runner.index >= 3)
	player.global_position = runner.log_place("signed")
	await _until(func(): return runner.index >= 4 and stage.cores().size() == 4)
	# Its clock held (the Esc menu up, the mouse let go): the loop holds with it, nothing filling behind the menu.
	await _until(func(): return stage.loop_running)
	await _frames(30)
	var cache_before: float = stage.cache
	var passes_before: int = stage.passes
	player.assume_captured = false
	await _frames(int(Engine.physics_ticks_per_second * float(runner.def.loop_prop()["pass_s"]) * 1.2))
	var held_still: bool = stage.held and stage.cache == cache_before and stage.passes == passes_before
	player.assume_captured = true
	await _frames(30)
	_check("its loop holds with its clock: the Esc menu up (the mouse let go) for longer than a pass, no pass made and the cache not a byte fuller (%.2f%%), then it runs on" % (cache_before * 100.0), held_still and not stage.held and stage.cache > cache_before)
	# Nothing shot: pass after pass, the loop never forks past its limits.
	var loop := runner.def.loop_prop()
	for k in 12:
		stage.call("_pass")
		await _frames(3)
	var per_core := {}
	var most_standing := 0
	for k in stage.forks_made:
		per_core[k.get_meta(&"core")] = int(per_core.get(k.get_meta(&"core"), 0)) + 1
	for c in stage.cores():
		most_standing = maxi(most_standing, stage.forks_made.filter(func(k): return k.get_meta(&"core") == c and k.is_alive()).size())
	var most_per_core := 0
	for c in per_core:
		most_per_core = maxi(most_per_core, int(per_core[c]))
	_check("acceptance: the loop's daemons stay finite whatever it does: after %d passes with nothing shot, %d forks made (its wave's %d at most), no core more than %d (%d), never more than %d of a core's standing (%d)" % [stage.passes, stage.forks_made.size(), _wave(runner.def, str(loop["forks"]))["count"], loop["each"], most_per_core, loop["standing"], most_standing], stage.forks_made.size() <= int(_wave(runner.def, str(loop["forks"]))["count"]) and most_per_core <= int(loop["each"]) and most_standing <= int(loop["standing"]) and stage.passes >= 12)
	stage.cache = 0.995
	var failed := await _until(func(): return runner.state == MissionRunner.State.FAILED)
	var end := mh.end_screen()
	_check("acceptance (fail card): the cache full fails it, out of memory: \"exit 137\" and why, Retry focused", failed and runner.reason == MissionRunner.CACHE_FULL and await _until(func(): return end.is_up()) and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and _text_has(end.shown_text(), "out of memory") and end.buttons()[0].text == "Retry")
	_check("and the loop stops with it", stage.stopped and not stage.loop_broken_now)
	await _drop(main)


# --- A death. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(3))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var runaway: Node3D = runner.stage.wave_daemons("hot")[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, runaway, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and await _until(func(): return end.is_up()) and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry")
	_check("its daemons stop coming once it has failed", runner.stage.stopped)
	await _drop(main)


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


func _action_hold(action: String, on: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = on
	root.push_input(e)


func _shown_has(mh: MissionHud, text: String) -> bool:
	return _text_has(mh.shown_text(), text)


func _text_has(lines: PackedStringArray, text: String) -> bool:
	for line in lines:
		if line.contains(text):
			return true
	return false

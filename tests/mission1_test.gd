extends SceneTree
## Headless test of mission 1, `login`, built for real (C37, PRD 5.6, docs/STORY.md section 6 mission 1). scripts/check.sh
## runs it as step 56, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission1_test.gd
##
## The code: nothing C37 added runs a program, opens a connection or a file, or reads the player's machine. The data:
## mission 1 validates, is no longer a draft, and is STORY.md's: its objective chain (hold the floor, follow the trail,
## the pack in the plaza, the first log, the vent, the surge, the drop), the Auditor refusing it, the `# temporary` log,
## the white ICE wall at the exit, the grid splitting into the cyberpunk ruins, the AI's last line; nothing of `~` or
## the ending in anything it shows. The handout: exactly the cannon and SIGTERM in hand, the rail handed over by the
## first objective, those three kept. The gate: in a mission, a weapon or an ability it has not handed over is refused
## and said so on the HUD (a slot's key, SIGSTOP, vision, sudo, the ICEbreakers); in the arena every one works. A
## scripted run in the real arena stood in its ruins: the arena's own four gone, every daemon one of its waves', the
## chain done in order, the pack's leader an elite, the ICE wall unbreakable, the breach splitting open, the player
## falling through it into the pocket, the remnant's sign lit, the mission done with "exit 0"; every daemon it made one
## of its waves' count, none ever back once down. A death fails it with "exit 137". The C36 leftovers: the panel's
## register chip is the world's live register; a reload into the ruins waits a black frame with its command on it. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## What C37 added or changed that runs in a mission: none of it may touch anything of the player's.
const C37_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/ruins/ruins_vent.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/sudo_badge.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "store_var", "get_var", "bytes_to_var", "str_to_var", "OS.get_environment", "get_user_data_dir", "get_executable_path", "OpenerData", "AiSourceDetector", "Adapter", "GuideRequest", "/proc", "/sys/", "/home"]
## STORY.md mission 1's beats, in order.
const CHAIN := ["floor", "trail", "pack", "temporary", "gate", "surge", "drop"]
const HANDOUT := ["terminal_cannon", "sigterm", "sigkill_rail"]
## Nothing mission 1 shows may say who `~` is or how it ends (STORY.md: the reveal is mission 5, the ending mission 7,
## and `~` is first named in mission 3).
const SPOILERS := ["~", "6666", "nohup", "tilde", "never logged out", "never hung up", "session restored", "welcome back", "you won't", "sigkill sent by you"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _root := ""
var _abs := ""
var _began: PackedStringArray = []
var _outs := {}
var _downed := 0
var _gone := 0
var _names: PackedStringArray = []
var _most := 0
var _elites: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://mission1-test-%d" % OS.get_process_id()
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
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	_code_checks()
	_data_checks()
	await _gate_checks()
	await _run_checks()
	await _fail_checks()
	await _cleanup()
	print("MISSION 1: %d checks" % _checks)
	print("MISSION 1 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
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
	for path in C37_CODE:
		var code := _code_of(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 1 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data", found.is_empty() and all.length() > 20000, ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var login := MissionBook.at(1)
	var problems := login.problems(MissionBook.weapon_ids())
	_check("mission 1 loads and validates, built for real (playable, no longer a draft), in its ruins", problems.is_empty() and login.playable and not login.draft and login.ruins == "scheduler_breach", "; ".join(problems))
	var ids := PackedStringArray()
	for o in login.objectives:
		ids.append(o["id"])
	_check("acceptance: its objective chain is STORY.md's beats in order: %s" % " > ".join(ids), ids == PackedStringArray(CHAIN))
	_check("acceptance: the handout is exactly mission 1's three: the cannon and SIGTERM in hand, the rail handed over by the first objective, those three kept", login.loadout == PackedStringArray(HANDOUT.slice(0, 2)) and login.carried_ever() == PackedStringArray(HANDOUT) and _same(login.grants, PackedStringArray(HANDOUT)) and login.objectives[0].get("gives", []) == ["sigkill_rail"])
	var kills := 0
	for o in login.objectives:
		if o["kind"] == "kill":
			kills += int(o["count"])
	_check("acceptance: its daemons are its own and finite: %d rogue.d in %d waves out of its vents (no zombie, no swarm, none of the arena's), enough for its %d kills" % [login.daemons_total(), login.waves.size(), kills], login.daemons_total() == login.daemons_total("rogue") and login.daemons_total() >= kills and login.daemons_total() <= 40 and login.waves.size() >= 5)
	var words := _shown_words(login).to_lower()
	var leaks := PackedStringArray()
	for w in SPOILERS:
		if words.contains(w):
			leaks.append(w)
	var rx := RegEx.create_from_string("\\bpid\\b")
	if rx.search(words) != null:
		leaks.append("pid")
	var sign := RuinsBook.of(login.ruins).remnant.to_lower()
	for w in SPOILERS:
		if sign.contains(w):
			leaks.append("remnant: " + w)
	_check("acceptance: no `~` spoilers beyond what STORY.md allows in mission 1: nothing it shows (its lines, logs, objectives, hints, the remnant's sign) names `~`, 6666, nohup or the ending", leaks.is_empty(), ", ".join(leaks))
	_check("STORY.md's mission 1 lands: the Auditor refuses you (\"no session\"), the first log is `# temporary. remove after the migration.`, your AI's last line is \"Well. That's not in the arena brochure.\"", _line_on(login, "start").contains("result=DENIED reason=\"no session\"") and login.log_of("temporary")["text"].contains("# temporary. remove after the migration.") and _line_on(login, "complete") == "Well. That's not in the arena brochure.")
	var wall := login.prop_of("gate_ice")
	var breach := login.prop_of("breach")
	_check("STORY.md's end beat: one white ICE wall at the exit (you cannot pass it yet), the grid splitting under the vent into the cyberpunk ruins, the remnant's sign lit as you land", wall.get("kind") == "ice_wall" and wall.get("at") == "gate" and breach.get("opens") == "done:surge" and breach.get("lights") == "done:drop" and login.transitions == [{"on": "done:surge", "to": "cyberpunk"}])
	_check("its first fights are a few rogue.d at a time, then a pack, then its leader an elite, tougher than the arena's (STORY.md: a few at first, then a pack)", _wave(login, "first")["count"] <= 3 and _wave(login, "pack_a")["count"] + _wave(login, "pack_b")["count"] >= 6 and _wave(login, "lead").get("elites", 0) == 1 and float(_wave(login, "lead").get("health", 0.0)) > float(_wave(login, "pack_a").get("health", 0.0)) and float(_wave(login, "pack_a").get("health", 0.0)) > 25.0 and login.restores)
	_check("the abilities a mission may use come from the campaign: none in mission 1; code-rain vision from mission 3; all four by mission 6", login.allowed_abilities().is_empty() and MissionBook.at(3).allowed_abilities() == PackedStringArray(["code_rain_vision"]) and MissionBook.at(6).allowed_abilities().size() == 4 and MissionBook.at(2).allowed_abilities().is_empty())
	var bad := login.duplicate(true) as MissionDef
	bad.waves = [{"id": "x", "kind": "dragon", "count": 0, "from": ["nowhere"], "on": "done:nothing"}]
	bad.props = [{"id": "y", "kind": "teleporter"}]
	bad.abilities = PackedStringArray(["flight"])
	var said := bad.problems(MissionBook.weapon_ids())
	_check("the validator refuses bad waves, props and abilities by name: an unknown daemon, a zero count, a vent it has not, a trigger naming nothing, an unknown prop, an unknown ability, and kill objectives its waves cannot meet", said.size() >= 7, "; ".join(said))


func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	return out


func _line_on(def: MissionDef, trigger: String) -> String:
	for line in def.lines:
		if line["on"] == trigger:
			return line["text"]
	return ""


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


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var fork := int(player.inventory.slot_of("fork_bomb"))
	_check("in the arena the whole arsenal and every ability: the fork bomb draws, nothing gated", not player.abilities_gated and player.select_slot(fork) and player.ability_ok("sigstop") and player.ability_ok("sudo"))
	_action("sigstop")
	await _frames(2)
	_check("in the arena SIGSTOP starts on its key", player.sigstop.is_on())
	player.end_sigstop()
	await _frames(2)
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(1))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	player = main.get_node("Player")
	hud = main.get_node("Hud")
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	_check("in mission 1 the gate is on: only the cannon and SIGTERM carried, no ability allowed", player.abilities_gated and player.abilities.is_empty() and player.carried == PackedStringArray(HANDOUT.slice(0, 2)))
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	_key(KEY_4)
	await _frames(2)
	var weapons = hud.weapon_hud()
	_check("acceptance (gating): a weapon not handed over refuses to draw on its key (4, the fork bomb), and the HUD says so plainly: \"%s\"" % weapons.locked_text(), player.inventory.current != fork and said.has("fork_bomb") and weapons.locked_text() == "fork bomb: not handed to you yet" and weapons.slots_text().contains("-"))
	_action("sigstop")
	await _frames(2)
	_check("acceptance (gating): an ability not handed over does nothing on its key (SIGSTOP), said on the HUD, its line reading locked", not player.sigstop.is_on() and said.has("sigstop") and weapons.stop_text().ends_with("SIGSTOP  locked") and weapons.stop_dimmed())
	_action("code_rain_vision")
	await _frames(2)
	var vision_off: bool = not player.vision.is_on()
	_action("sudo_overcharge")
	await _frames(2)
	var badge_text: String = hud.sudo_badge().detail_text() if hud.has_method("sudo_badge") else ""
	_check("and code-rain vision and sudo the same: vision stays off (\"V vision  locked\"), the badge reads \"sudo: locked\"", vision_off and said.has("code_rain_vision") and said.has("sudo") and weapons.vision_text().ends_with("vision  locked") and (badge_text == "sudo: locked" or not hud.has_method("sudo_badge")), badge_text)
	var breakers := BreakerDirector.of(main)
	_check("and the ICEbreakers: locked at their director (none carried, no pickup laid)", breakers != null and breakers.locked and breakers.mode == BreakerDirector.Mode.OFF and breakers.pickups_out().is_empty())
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	_check("acceptance (gating): not in the arena: back in free play the gate is off again, the fork bomb draws", not player.abilities_gated and player.select_slot(fork) and not BreakerDirector.of(main).locked)


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var login := MissionBook.at(1)
	var old_id := main.get_instance_id()
	runner.begin(login)
	await process_frame
	_check("the C36 leftover (the first build's stutter): the reload into the ruins waits a black frame with its command typed (\"$ login\"), the district built behind black, the next arena in from it", MissionRunner.mounting() == "$ login" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var player = main.get_node("Player")
	var world := runner.world
	_began.clear()
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var arena_four := false
	for n in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		arena_four = arena_four or main.has_node("Arena/Targets/" + n)
	_check("acceptance: its daemons are its own: the arena's four are gone, no daemon stands as it starts, its vents leak in the ruins", not arena_four and _targets(main).is_empty() and runner.stage != null and runner.stage.vent("plaza_n") != null and world != null and world.ruins.id == "scheduler_breach")
	runner.life.shield(LONG_ROUND_S)
	var stage := runner.stage
	stage.spawned.connect(func(d: Node3D) -> void:
		var key := String(d.name)
		_names.append(key)
		d.respawned.connect(func(_x): _outs[key] = int(_outs.get(key, 0)) + 1)
		d.downed.connect(func(_x): _downed += 1)
		d.gone.connect(func(_x): _gone += 1)
		if d.art_node().elite:
			_elites.append(key))
	await _play_until(main, func(): return runner.index >= 1)
	var handed := await _until(func(): return _shown_has(mh, ">> kill -9 handed to you"))
	_check("hold the floor: a timeslice (40 s) survived, its rogue.d out of the start's vents in three waves of two, the rail handed over (\"kill -9 handed to you\")", runner.index == 1 and runner.clock >= 40.0 and _made_of(stage, ["first", "second", "third"]) == 6 and runner.carried.has("sigkill_rail") and handed, "index %d clock %.1f made %d carried %s handed %s" % [runner.index, runner.clock, _made_of(stage, ["first", "second", "third"]), str(runner.carried), handed])
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(35.0, null, Vector3.FORWARD)
	var hurt_to: float = runner.life.health()
	runner.life.shield(LONG_ROUND_S)
	player.global_position = world.point("plaza")
	await _play_until(main, func(): return runner.index >= 2)
	_check("each objective done is a checkpoint: health back to full (%.0f, then %.0f)" % [hurt_to, runner.life.health()], hurt_to < runner.life.max_health() and runner.life.health() == runner.life.max_health())
	_most = 0
	await _play_until(main, func(): return runner.index >= 3)
	await _frames(2)
	_check("the pack in the plaza: 10 rogue.d down in its waves (up to %d out at once to a sure shot), its leader its type's elite with two escorts" % _most, runner.index == 3 and _elites.has("Mission_lead_00") and _elites.size() == 1 and stage.wave_state("pack_a") == "cleared" and stage.wave_state("pack_b") == "cleared" and stage.wave_state("lead") == "cleared" and stage.wave_state("escort") == "cleared" and runner.kills >= 10, "index %d elites %s waves %s %s %s %s kills %d" % [runner.index, str(_elites), stage.wave_state("pack_a"), stage.wave_state("pack_b"), stage.wave_state("lead"), stage.wave_state("escort"), runner.kills])
	player.global_position = runner.log_place("temporary")
	await _play_until(main, func(): return runner.index >= 4)
	_check("the first log picked up: \"# temporary. remove after the migration.\" in the reader", runner.index == 4 and runner.logs_found.has("temporary") and await _until(func(): return _shown_has(mh, "# temporary. remove after the migration.")))
	player.global_position = world.point("gate")
	await _play_until(main, func(): return runner.index >= 5)
	var wall: IceBarrier = stage.walls()[0]
	_check("the vent at the exit, sealed past it by white ICE that no hit breaks (you cannot pass it yet)", runner.index == 5 and wall.sealed() and not wall.hit(1000.0, wall.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail") and wall.sealed())
	await _play_until(main, func(): return runner.index >= 6)
	await _frames(3)
	_check("the vent held for its 30 s against the surge out of the vents; the grid splits: the breach's hatch open, the world tearing into the cyberpunk ruins", runner.index == 6 and world.breach() != null and world.breach().is_open() and world.register == "cyberpunk" and runner.register == "cyberpunk")
	player.global_position = world.point("breach") + Vector3(0, 0.6, 0)
	player.velocity = Vector3.ZERO
	await _play_until(main, func(): return runner.state == MissionRunner.State.COMPLETE)
	_check("acceptance: you drop through it into the rain: the player fell into the pocket below and the drop completed it", runner.state == MissionRunner.State.COMPLETE and player.global_position.y < -10.0 and player.global_position.y > -15.0)
	_check("acceptance: the objective chain completed in order with a scripted run: %s" % " > ".join(_began), _began == PackedStringArray(CHAIN))
	_check("the remnant's sign flickers on in the dark as you land", await _until(func(): return world.remnant_power() > 0.5))
	var end := mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, the place lit first", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE"))
	await _frames(int(Engine.physics_ticks_per_second * 3.0))
	var most_outs := 0
	for k in _outs:
		most_outs = maxi(most_outs, int(_outs[k]))
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d (none once it was done), each out of its vent once and none ever back once down: %d down, %d gone for good" % [stage.made.size(), login.daemons_total(), _downed, _gone], stage.made.size() <= login.daemons_total() and stage.made.size() >= 15 and most_outs == 1 and _downed >= 11 and _gone == _downed and stage.stopped)
	_check("no draft note anywhere: the end screen and the Missions screen take it as built", not _text_has(end.shown_text(), "first cut"))
	_check("acceptance: its weapons kept and mission 1 recorded done; mission 2 now open", MissionProgress.current().is_done("login") and Progress.current().has_weapon("sigkill_rail") and MissionProgress.current().is_open(MissionBook.at(2)))
	world.set_register("matrix", 0.0)
	await _frames(2)
	_check("the C36 leftover: the panel's register chip is the world's live register (it never reads TRON while the world shows another)", mh.register_shown() == "matrix")
	await _drop(main)


## How many daemons the stage made in waves `ids` (by their names as they climbed out: the downed are freed).
func _made_of(_stage: MissionStage, ids: Array) -> int:
	var n := 0
	for key in _names:
		for id in ids:
			if key.begins_with("Mission_%s_" % id):
				n += 1
	return n


func _targets(main: Node) -> Array:
	return get_nodes_in_group("targets").filter(func(n): return main.is_ancestor_of(n) and n.is_alive())


## Frames until `condition` holds (at most `most`), every mission daemon out of its vent shot down as a sure shot
## would; its last answer.
func _play_until(main: Node, condition: Callable, most: int = MOST_FRAMES) -> bool:
	var runner := MissionRunner.of(main)
	var frames := 0
	while frames < most and not condition.call():
		if runner != null and runner.stage != null:
			_most = maxi(_most, runner.stage.standing().size())
			for d in runner.stage.standing():
				if d.is_alive():
					d.hit(1000.0, d.global_position + Vector3.UP, Vector3.FORWARD, "sigterm")
		await process_frame
		frames += 1
	return condition.call()


# --- A death. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(1))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _until(func(): return not runner.stage.standing().is_empty())
	var rogue: Node3D = runner.stage.standing()[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, rogue, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and await _until(func(): return end.is_up()) and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry")
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


func _shown_has(mh: MissionHud, text: String) -> bool:
	return _text_has(mh.shown_text(), text)


func _text_has(lines: PackedStringArray, text: String) -> bool:
	for line in lines:
		if line.contains(text):
			return true
	return false

extends SceneTree
## Headless test of mission 2, `defunct`, built for real (M2, PRD 5.6, docs/STORY.md section 6 mission 2). scripts/check.sh
## runs it as step 57, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission2_test.gd
##
## The code: nothing M2 added runs a program, opens a connection or a file, or reads the player's machine. The data:
## mission 2 validates, is no longer a skeleton, stands in a district of its own (the closed terminals, not mission 1's),
## and is STORY.md's: zombies leading it, many, a rogue.d elite guarding their parent; find them in the rain, the queue
## at the dead storefront, the storefront's log, their threads to the parent, its guard, the parent; the remnants' log,
## your AI's lines, the parent's owner field at the end; nothing of `~` or the ending in anything it shows. The handout:
## mission 1's three in hand, ping put in hand for the rain, the fork bomb and fork() for the queue, those three kept and
## told as each comes ("IN HAND"). The gate: what the campaign has not handed over by mission 2 is refused and said so.
## A scripted run in the real arena stood in its ruins: the arena's own four gone, its daemons asleep where they were
## left until woken, every daemon one of its waves', the queue in its line at the shop's door, the parent sealed until
## its guard is down and taking no more than its cap from any one hit, every zombie threaded to it, and when it goes down
## every zombie standing dropping at once, reaped and credited to nobody, the shop's lights going out, its owner field
## over it, "exit 0"; every daemon it made one of its waves' count, none back once down. A death fails it with "exit 137".
## The C37 leftovers it fixes: two of your AI's lines close together both play; toasts waiting through a reload are kept.
## Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## What M2 added or changed that runs in a mission: none of it may touch anything of the player's.
const M2_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/parent_threads.gd", "res://scripts/daemons/parent_process.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/unlock_toast.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/fight/daemon_brain.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "store_var", "get_var", "bytes_to_var", "str_to_var", "OS.get_environment", "get_user_data_dir", "get_executable_path", "OpenerData", "AiSourceDetector", "Adapter", "GuideRequest", "/proc", "/sys/", "/home"]
## STORY.md mission 2's beats, in order.
const CHAIN := ["rain", "trail", "queue", "shop", "threads", "guard", "parent"]
const CARRIED := ["terminal_cannon", "sigterm", "sigkill_rail"]
const HANDOUT := ["ping_sonar", "fork_bomb", "fork_shotgun"]
## Nothing mission 2 shows may say who `~` is or how it ends (STORY.md: `~` is first named in mission 3, 6666 is the
## reveal of mission 5, the ending mission 7's).
const SPOILERS := ["~", "6666", "nohup", "tilde", "never logged out", "never hung up", "session restored", "user=you", "welcome back", "you won't", "sigkill sent by you", "logged in as you"]
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
var _fired: PackedStringArray = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://mission2-test-%d" % OS.get_process_id()
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
	_district_checks()
	await _gate_checks()
	await _run_checks()
	await _fail_checks()
	await _leftover_checks()
	await _cleanup()
	print("MISSION 2: %d checks" % _checks)
	print("MISSION 2 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
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
	for path in M2_CODE:
		var code := _code_of(path)
		all += code
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 2 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data", found.is_empty() and all.length() > 20000, ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var defunct := MissionBook.at(2)
	var login := MissionBook.at(1)
	var problems := defunct.problems(MissionBook.weapon_ids())
	_check("mission 2 loads and validates, built for real (playable, not a draft), in a district of its own: the closed terminals, not mission 1's", problems.is_empty() and defunct.playable and not defunct.draft and defunct.ruins == "tty_row" and defunct.ruins != login.ruins and MissionBook.problems().is_empty(), "; ".join(problems + MissionBook.problems()))
	var ids := PackedStringArray()
	for o in defunct.objectives:
		ids.append(o["id"])
	_check("acceptance: its objective chain is STORY.md's beats in order: %s" % " > ".join(ids), ids == PackedStringArray(CHAIN))
	var first: Dictionary = defunct.objectives[0]
	var crowd: Dictionary = defunct.objectives[2]
	_check("acceptance: the handout is exactly mission 2's three (STORY.md: ping, the fork bomb, fork()): mission 1's three in hand as it starts, ping put in hand for the rain, the fork bomb and fork() for the crowd at the queue, those three kept", defunct.loadout == PackedStringArray(CARRIED) and defunct.grants == PackedStringArray(HANDOUT) and defunct.carried_ever() == PackedStringArray(CARRIED + HANDOUT) and first.get("arms", []) == ["ping_sonar"] and crowd.get("arms", []) == ["fork_bomb", "fork_shotgun"] and MissionBook.granted_by(2) == PackedStringArray(CARRIED + HANDOUT) and _same(MissionBook.granted_by(1), PackedStringArray(CARRIED)))
	var kills := 0
	for o in defunct.objectives:
		if o["kind"] == "kill":
			kills += int(o["count"])
	var zombies := defunct.daemons_total("zombie")
	_check("acceptance: its daemons are its own and finite, zombies leading (STORY.md: zombies, many, and a rogue.d elite guarding the parent): %d zombies, %d rogue.d (its elite), %d parent, no runaway, %d in all, in %d waves, enough for its %d kills" % [zombies, defunct.daemons_total("rogue"), defunct.daemons_total("parent"), defunct.daemons_total(), defunct.waves.size(), kills], zombies >= 20 and zombies * 2 > defunct.daemons_total() and defunct.daemons_total("rogue") == 1 and _wave(defunct, "guard").get("elites", 0) == 1 and defunct.daemons_total("parent") == 1 and defunct.daemons_total("swarm") == 0 and defunct.daemons_total() >= kills and defunct.daemons_total() <= 40)
	var words := _shown_words(defunct).to_lower()
	var leaks := PackedStringArray()
	for w in SPOILERS:
		if words.contains(w):
			leaks.append(w)
	_check("acceptance: no `~`, 6666, nohup or ending text in anything mission 2 shows beyond what STORY.md allows (its lines, logs, objectives, hints, its daemons' tags and the parent's owner field, the storefront's sign and screen, the district's signs and folders)", leaks.is_empty() and words.length() > 1500, ", ".join(leaks))
	_check("STORY.md's mission 2 lands: the remnants' log (\"the shop closed six years ago. the lights are on a timer nobody owns\"), your AI on reading it (\"These were jobs from a terminal you closed. You said you'd check on them tomorrow.\"), the parent's owner field read at the end (\"It's you. Not 'like you'. You.\")", defunct.log_of("storefront")["text"] == "the shop closed six years ago.\nthe lights are on a timer nobody owns." and _line_on(defunct, "log:storefront") == "These were jobs from a terminal you closed. You said you'd check on them tomorrow." and _line_on(defunct, "complete") == "It's you. Not 'like you'. You." and str(defunct.parent_wave().get("epitaph", "")).ends_with("owner: you"))
	_check("STORY.md's register: the cyberpunk ruins, start to end, no shift (STORY.md asks for none), its own three to five logs, the Auditor refusing it as ever", defunct.register == "cyberpunk" and RuinsBook.of(defunct.ruins).register == "cyberpunk" and defunct.transitions.is_empty() and defunct.logs.size() >= 3 and defunct.logs.size() <= 5 and _line_on(defunct, "start").contains("result=DENIED reason=\"no session\""))
	var vents := defunct.prop_ids("vent").size()
	_check("not a reskin of mission 1: no spawn vents (its zombies stand where they were left, asleep), a queue at a dead storefront, a parent sealed until its guard falls and reaping its children, the shop's lights put out at the end", vents == 0 and login.prop_ids("vent").size() > 0 and defunct.prop_ids("queue").size() == 1 and defunct.prop_ids("shop").size() == 1 and defunct.parent_wave().get("sealed") == "done:guard" and defunct.parent_wave().get("reaps") == "zombie" and defunct.prop_of("store").get("dark") == "done:parent")
	_check("the abilities mission 2 may use come from the campaign: none (code-rain vision is mission 3's)", defunct.allowed_abilities().is_empty())
	var bad := defunct.duplicate(true) as MissionDef
	bad.waves = [{"id": "a", "kind": "zombie", "count": 2, "from": ["rain_1"], "on": "start", "dormant": "yes"}, {"id": "b", "kind": "zombie", "count": 1, "from": ["rain_1"], "on": "start", "wakes": "begin:rain"}, {"id": "c", "kind": "zombie", "count": 1, "from": ["rain_1"], "on": "start", "reaps": "zombie", "epitaph": "x"}, {"id": "d", "kind": "parent", "count": 2, "from": ["nest"], "on": "start", "reaps": "dragon"}, {"id": "e", "kind": "parent", "count": 1, "from": ["nest"], "on": "start", "reaps": "zombie", "hit_cap": -5.0}]
	bad.props = defunct.props.duplicate(true) + [{"id": "q2", "kind": "queue", "at": "queue", "gap": 9.0}]
	bad.objectives = defunct.objectives.duplicate(true)
	bad.objectives[0]["arms"] = ["laser"]
	bad.objectives[1]["arms"] = ["terminal_cannon"]
	var said := bad.problems(MissionBook.weapon_ids())
	_check("the validator refuses bad mission 2 data by name: a dormant that is not true or false, a wake without sleep, a reap and an epitaph on a zombie, a parent of two and one reaping nothing, two parents, a bad cap, a queue's gap, a weapon that does not exist or is already in hand", said.size() >= 10, "; ".join(said))
	var shopless := defunct.duplicate(true) as MissionDef
	shopless.ruins = "scheduler_breach"
	var refused := shopless.problems(MissionBook.weapon_ids())
	_check("and a shop prop in a district with no shop", Array(refused).any(func(p): return p.contains("shop store, but its ruins have none")), "; ".join(refused))


func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	for w in def.waves:
		out += " " + str(w.get("tag", "")) + " " + str(w.get("epitaph", ""))
	var s := RuinsBook.of(def.ruins)
	out += " " + s.shop_sign + " " + s.shop_screen + " " + " ".join(s.words) + " " + " ".join(s.folders)
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


# --- The district. ---

func _district_checks() -> void:
	var defunct := MissionBook.at(2)
	var s := RuinsBook.of("tty_row")
	var plan := RuinsLayout.of(s)
	var grid := plan.walk_grid()
	var shop_blocks := plan.blocks.filter(func(b): return b["kind"] == "shop")
	var near: bool = not plan.shop.is_empty() and Vector2(plan.shop["face"].x - plan.points["plaza"].x, plan.shop["face"].z - plan.points["plaza"].z).length() < 12.0
	_check("its district has its dead storefront: one shop block on the floor's edge by the plaza, its front to the street, the queue's line out from its door; every point walkable", s.problems().is_empty() and shop_blocks.size() == 1 and near and plan.points.has("queue") and plan.points.has("queue_end") and plan.unreachable().is_empty(), "%s %s" % [str(plan.shop), str(plan.unreachable())])
	var off := PackedStringArray()
	for p in defunct.props:
		if not ["spot", "queue"].has(p.get("kind")):
			continue
		for key in ["at", "to"]:
			if not p.has(key):
				continue
			var at: Vector3 = p[key] if p[key] is Vector3 else plan.points[p[key]]
			if not _walkable(grid, plan, at):
				off.append("%s.%s" % [p["id"], key])
	_check("every place its daemons stand (its spots and its queue) is on walkable floor", off.is_empty(), ", ".join(off))
	var others := PackedStringArray()
	for other in RuinsBook.all():
		if other.id != "tty_row" and RuinsLayout.of(other).shop.size() > 0:
			others.append(other.id)
	_check("only its district has a shop: the other districts plan as before", others.is_empty(), ", ".join(others))


## True when `at` is on the walk grid's open floor (a player could stand there).
func _walkable(grid: Dictionary, plan: RuinsLayout, at: Vector3) -> bool:
	var n: Vector2i = grid["n"]
	var ext: Vector2 = grid["ext"]
	var c := Vector2i(floori((at.x + ext.x) / RuinsLayout.WALK_M), floori((at.z + ext.y) / RuinsLayout.WALK_M))
	if c.x < 0 or c.y < 0 or c.x >= n.x or c.y >= n.y:
		return false
	return grid["open"][c.y * n.x + c.x] == 1


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(2))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	_check("as it starts (its card up), mission 1's three are carried and nothing of mission 2's yet", runner.state == MissionRunner.State.INTRO and player.carried == PackedStringArray(CARRIED))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var told := await _until(func(): return toast.text() == "IN HAND: ping  [9]")
	var shown := toast.text()
	var typed := await _until(func(): return _shown_has(mh, ">> ping handed to you"))
	_check("acceptance (handout): ping put in hand as the rain begins, told at the top (\"%s\") and in the terminal (\"ping handed to you\")" % shown, player.carried.has("ping_sonar") and told and typed)
	_check("in mission 2 the gate is on: no ability allowed", player.abilities_gated and player.abilities.is_empty())
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	var fork := int(player.inventory.slot_of("fork_bomb"))
	_key(KEY_4)
	await _frames(2)
	var weapons = hud.weapon_hud()
	_check("acceptance (gating by campaign order): the fork bomb (4) refuses to draw until its beat hands it over, said plainly (\"%s\")" % weapons.locked_text(), player.inventory.current != fork and said.has("fork_bomb") and weapons.locked_text() == "fork bomb: not handed to you yet")
	_key(KEY_6)
	await _frames(2)
	_check("and grep (6), a weapon mission 3 hands over, refuses all mission long", said.has("grep_seeker") and weapons.locked_text() == "grep: not handed to you yet", weapons.locked_text())
	_action("sigstop")
	await _frames(2)
	_action("code_rain_vision")
	await _frames(2)
	_action("sudo_overcharge")
	await _frames(2)
	var breakers := BreakerDirector.of(main)
	_check("and the abilities: SIGSTOP, code-rain vision and sudo refused, the ICEbreakers locked at their director", not player.sigstop.is_on() and not player.vision.is_on() and said.has("sigstop") and said.has("code_rain_vision") and said.has("sudo") and breakers != null and breakers.locked)
	_key(KEY_9)
	await _frames(2)
	_check("ping draws on its key once in hand", player.inventory.current == int(player.inventory.slot_of("ping_sonar")))
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	_check("acceptance (gating): not in the arena: in free play the gate is off, grep draws", not player.abilities_gated and player.select_slot(int(player.inventory.slot_of("grep_seeker"))))


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var defunct := MissionBook.at(2)
	var old_id := main.get_instance_id()
	runner.begin(defunct)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ defunct\")", MissionRunner.mounting() == "$ defunct" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	_began.clear()
	_fired.clear()
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	stage.spawned.connect(func(d: Node3D) -> void: _watch(d))
	for d in stage.made:
		_watch(d)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _frames(30)
	var arena_four := false
	for n in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		arena_four = arena_four or main.has_node("Arena/Targets/" + n)
	var asleep := stage.made.filter(func(d): return d.brain != null and d.brain.dormant)
	_check("acceptance: its daemons are its own: the arena's four gone, its own standing where they were left in the closed terminals (%d), asleep (%d), none hunting" % [stage.made.size(), asleep.size()], not arena_four and world != null and world.ruins.id == "tty_row" and stage.made.size() == 21 and asleep.size() == 20 and stage.made.all(func(d): return d.brain == null or d.brain.state_name() == "home"))
	var line := stage.wave_daemons("queue")
	var head: Vector3 = world.point("queue")
	var facing := line.all(func(d): return (-d.global_transform.basis.z).dot((world.layout.shop["face"] - d.global_position).normalized()) > 0.3)
	_check("the queue: ten zombies in a line out from the dead storefront's door, each facing it, its jobs still queued outside", line.size() == 10 and line[0].global_position.distance_to(head - Vector3(0, RuinsLayout.STAND_Y, 0)) < 0.6 and line[9].global_position.distance_to(line[0].global_position) > 8.0 and facing)
	var parent: Node3D = stage.parent
	_check("their parent stands at the street's end, sealed, armoured shut (a hit lands nothing on it), a thread from every zombie to it", parent != null and parent.sealed and not parent.hit(1000.0, parent.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail") and parent.health() == parent.max_health and stage.threads() != null and stage.threads().drawn() == stage.children().size() and stage.children().size() == 19, "threads %d children %d" % [stage.threads().drawn() if stage.threads() != null else -1, stage.children().size()])
	var guide = hud.guide()
	runner.life.shield(LONG_ROUND_S)
	# The rain: the zombies wake as the player comes near, a wave at a time.
	var rain_a: Array = stage.wave_daemons("rain_a")
	player.global_position = rain_a[0].global_position + Vector3(3.0, RuinsLayout.STAND_Y, 0.0)
	await _frames(3)
	_check("a sleeping wave wakes as the player comes near, all of it at once, and hunts (the trigger woke:rain_a, your AI's line)", stage.wave_awake("rain_a") and not stage.wave_awake("rain_b") and rain_a.all(func(d): return not d.brain.dormant and d.brain.relentless) and _fired.has("Zombies. Dead, never reaped. Nobody told them."))
	await _play_until(main, func(): return runner.index >= 1)
	_check("find them in the rain: six zombies down, the rain's waves all woken and cleared", runner.index == 1 and stage.wave_state("rain_a") == "cleared" and stage.wave_state("rain_b") == "cleared" and stage.wave_state("rain_c") == "cleared" and not stage.wave_awake("queue"))
	player.global_position = world.point("plaza")
	await _play_until(main, func(): return runner.index >= 2, 120, false)
	await _frames(2)
	var crowd := await _until(func(): return _shown_has(mh, ">> fork bomb handed to you") and _shown_has(mh, ">> fork() handed to you"))
	_check("acceptance (handout): where they queued, the queue wakes as one and the fork bomb and fork() are put in hand for the crowd, each told", runner.index == 2 and stage.wave_awake("queue") and player.carried.has("fork_bomb") and player.carried.has("fork_shotgun") and crowd)
	await _play_until(main, func(): return runner.index >= 3)
	_check("the queue cleared: ten zombies down", runner.index == 3 and stage.wave_state("queue") == "cleared")
	player.global_position = runner.log_place("storefront")
	await _play_until(main, func(): return runner.index >= 4)
	_check("the storefront's log read: \"the shop closed six years ago.\" in the reader, your AI on it", runner.index == 4 and runner.logs_found.has("storefront") and await _until(func(): return _shown_has(mh, "the shop closed six years ago.")) and _fired.has("These were jobs from a terminal you closed. You said you'd check on them tomorrow."))
	player.global_position = world.point("daemon_3") + Vector3(0, RuinsLayout.STAND_Y, 0)
	await _play_until(main, func(): return runner.index >= 5, 120, false)
	_check("their threads followed to their parent; the strays and its guard woken on the way", runner.index == 5 and stage.wave_awake("strays") and stage.wave_awake("guard"))
	var guard: Node3D = stage.wave_daemons("guard")[0]
	_check("its guard: a rogue.d, its type's elite, highest priority", MissionRunner.kind_of(guard) == "rogue" and guard.art_node().elite and guard.max_health >= 200.0)
	await _play_until(main, func(): return runner.index >= 6)
	await _until(func(): return not parent.sealed)
	_check("the guard down, the parent opens: no longer sealed, its frames sliding out, forking children as it fights", runner.index == 6 and not parent.sealed and stage.wave_state("fork_a") != "waiting" and await _until(func(): return parent.art_node().opened() > 0.9))
	var before: float = parent.health()
	parent.hit(1000.0, parent.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
	_check("no one hit takes more than its cap off it (%.0f of a 1000 kill -9): it outlasts a single rail" % (before - parent.health()), absf((before - parent.health()) - float(defunct.parent_wave()["hit_cap"])) < 0.01 and parent.is_alive())
	# Its children standing as it goes: let the forks climb out, then bring it down with them still up.
	await _until(func(): return stage.children().size() >= 2)
	var standing := stage.children().filter(func(d): return d.is_alive())
	var kills := runner.kills
	while parent.is_alive():
		parent.hit(1000.0, parent.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
		await process_frame
	await _frames(2)
	_check("acceptance (STORY.md's end beat): the parent derezzes and every zombie standing drops at once, reaped: %d of them, credited to nobody (one kill counted, the parent's)" % standing.size(), standing.size() >= 2 and stage.reaped_count == standing.size() and standing.all(func(d): return not is_instance_valid(d) or (not d.is_alive() and d.credited == false)) and runner.kills == kills + 1)
	_check("acceptance: the objective chain completed in order with a scripted run: %s" % " > ".join(_began), runner.state == MissionRunner.State.COMPLETE and _began == PackedStringArray(CHAIN))
	var epitaph := stage.get_node_or_null("Epitaph") as Label3D
	_check("its owner field shows over where it stood (\"%s\"), and the Auditor writes it out: re-parented to init, reaped" % (epitaph.text if epitaph != null else ""), epitaph != null and epitaph.text == "4087  owner: you" and _fired.has("audit: pid 4087 exited. its children re-parented to init (pid 1). reaped."))
	_check("the storefront's lights go out for good, its timer stopped", await _until(func(): return world.shop_power() == 0.0))
	var end := mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, your AI's last line read first", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and _fired.has("It's you. Not 'like you'. You."))
	await _frames(int(Engine.physics_ticks_per_second * 2.0))
	var most_outs := 0
	for k in _outs:
		most_outs = maxi(most_outs, int(_outs[k]))
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d, each up once and none ever back once down: %d down, %d gone for good" % [_names.size(), defunct.daemons_total(), _downed, _gone], _names.size() <= defunct.daemons_total() and _names.size() >= 22 and most_outs == 1 and _downed >= 22 and _gone == _downed and stage.stopped)
	_check("acceptance: its weapons kept and mission 2 recorded done", MissionProgress.current().is_done("defunct") and Progress.current().has_weapon("ping_sonar") and Progress.current().has_weapon("fork_bomb") and Progress.current().has_weapon("fork_shotgun"))
	await _drop(main)


func _watch(d: Node3D) -> void:
	var key := String(d.name)
	if _names.has(key):
		return
	_names.append(key)
	d.respawned.connect(func(_x): _outs[key] = int(_outs.get(key, 0)) + 1)
	d.downed.connect(func(_x): _downed += 1)
	d.gone.connect(func(_x): _gone += 1)


func _targets(main: Node) -> Array:
	return get_nodes_in_group("targets").filter(func(n): return main.is_ancestor_of(n) and n.is_alive())


## Frames until `condition` holds (at most `most`), shooting down as a sure shot would the daemons the objective running
## counts and any that are awake and hunting (never a sleeper, never the parent before its own objective); its last
## answer. With `shoot` off it only waits.
func _play_until(main: Node, condition: Callable, most: int = MOST_FRAMES, shoot: bool = true) -> bool:
	var runner := MissionRunner.of(main)
	var frames := 0
	while frames < most and not condition.call():
		if shoot and runner != null and runner.stage != null:
			var of: Array = runner.objective().get("of", [])
			for d in runner.stage.standing():
				if not d.is_alive() or d.sessile() and not of.has(str(d.get_meta(&"wave", ""))):
					continue
				if of.has(str(d.get_meta(&"wave", ""))) or (d.brain != null and not d.brain.dormant):
					d.hit(1000.0, d.global_position + Vector3.UP, Vector3.FORWARD, "sigterm")
		await process_frame
		frames += 1
	return condition.call()


# --- A death. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(2))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var zombie: Node3D = runner.stage.wave_daemons("rain_a")[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, zombie, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and await _until(func(): return end.is_up()) and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry")
	_check("its daemons stop coming once it has failed", runner.stage.stopped)
	await _drop(main)


# --- The C37 leftovers it fixes. ---

func _leftover_checks() -> void:
	var main := await _arena()
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var guide = hud.guide()
	var shown := PackedStringArray()
	mh.call("_on_line", "ai", "first line, close together")
	await _frames(int(Engine.physics_ticks_per_second * 0.5))
	mh.call("_on_line", "ai", "second line, half a second after")
	var frames := 0
	while frames < 600 and shown.size() < 2:
		var body: String = guide.get("_body").text
		if body != "" and not shown.has(body):
			shown.append(body)
		await process_frame
		frames += 1
	_check("the C37 leftover: two of your AI's lines half a second apart both play, the first for its moment, then the second (%s)" % " / ".join(shown), shown == PackedStringArray(["first line, close together", "second line, half a second after"]))
	var toast: UnlockToast = hud.unlock_toast()
	await _until(func(): return toast.waiting() == 0 and not toast.showing())  # the run's own toasts told first
	UnlockToast.hold(5.0)
	Progress.current().unlocked.emit("ping_sonar", Progress.CAMPAIGN, "ping")
	var held: bool = not toast.showing() and toast.waiting() == 1
	var old_id := main.get_instance_id()
	main.get_tree().reload_current_scene()
	main = await _after_reload(old_id)
	toast = main.get_node("Hud").unlock_toast()
	var kept := await _until(func(): return toast.text() == "UNLOCKED: ping")
	_check("the C37 leftover: a toast held for a mission's end and waiting through a reload (quitting during the hold) is told on the next screen", held and kept, toast.text())
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

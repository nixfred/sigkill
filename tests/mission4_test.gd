extends SceneTree
## Headless test of mission 4, `permission denied`, built for real (M4, PRD 5.6, docs/STORY.md section 6 mission 4).
## scripts/check.sh runs it as step 59, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission4_test.gd
##
## The code: nothing M4 added or changed runs a program, opens a connection or a file, or reads the player's machine. The
## data: mission 4 validates, is no longer a skeleton, stands in a district of its own (the records vault: Tron, clean,
## guarded, not missions 1's, 2's or 3's), and is STORY.md's: white ICE (walls, jam and HUD nodes) and hunter ICE its
## enemies, all of them finite; the Auditor's lines escalating as you go deeper; the records saying every daemon belongs
## to your user and that the session is held by another process, its PID redacted (root only), nowhere a number; your
## AI's line on it; the end beat (`intruder confirmed. escalating.`, the lights stuttering once); nothing of 6666, nohup,
## `~` or the ending in anything it shows. The handout: missions 1 to 3's eight in hand, the ICEbreakers unlocked for the
## first deny rule with your AI's pick of which to load, chmod 000 put in hand for the hunter, all told as they come. The
## gate: what the campaign has not handed over by mission 4 (or this mission not yet) is refused and said so. A scripted
## run in the real arena stood in its ruins: a deny rule's wall sealing the aisle (a step and a shot stop at it), brute up
## close breaking it; the enforcement nodes' fields jamming the hand and scrambling the HUD; a brute pickup taken and the
## second rule broken; the hunter dispatched, frozen by chmod 000 and hit harder for it, profiling the weapon leaned on,
## broken and never back; the last rule and the deck; the hold with its second hunter and nodes; the record standing
## only once decrypted, read, the records screen lighting with the redaction bar; the Auditor's escalation and the lights'
## stutter; "exit 0" with chmod 000 and the ICEbreakers. Every piece of ICE it made one of its waves', none back once
## broken, no Black ICE. A death fails it ("exit 137"). Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

## What M4 added or changed that runs in a mission: none of it may touch anything of the player's.
const M4_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/ice/ice_director.gd", "res://scripts/ice/breaker_director.gd", "res://scripts/ice/blackout.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_pieces.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/hud/mission_hud.gd"]
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "OS.get_environment", "get_user_data_dir", "get_system_dir", "get_executable_path", "OpenerData", "RealData", "get_cmdline"]
## STORY.md mission 4's beats, in order.
const CHAIN := ["rule1", "enforce", "rule2", "hunter", "vault", "hold", "owner"]
const CARRIED := ["terminal_cannon", "sigterm", "sigkill_rail", "ping_sonar", "fork_bomb", "fork_shotgun", "grep_seeker", "pipe_chain"]
const HANDOUT := ["chmod_000"]
## STORY.md's words for mission 4, exactly.
const SESSION := "It's got your session. To the machine, it's the user. We're the break-in."
const FLAGGED := "audit: user=? flagged as intruder. session for this user is held by another process."
const ESCALATING := "audit: intruder confirmed. escalating."
## Nothing mission 4 shows may say who `~` is or how it ends (6666 is mission 5's reveal, nohup mission 6's, the ending
## mission 7's), and the session-holder's PID stays redacted: no number anywhere near it.
const SPOILERS := ["~", "6666", "nohup", "tilde", "never logged out", "never hung up", "session restored", "user=you", "welcome back", "you won't", "sigkill sent by you", "logged in as you", "shell", "pid 1 ", "pid=1"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _began: PackedStringArray = []
var _broke := 0
var _names: PackedStringArray = []
var _fired: PackedStringArray = []
## The frame each line was said on; where each piece stood as it was placed.
var _said_at := {}
var _stood := {}


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://mission4-test-%d" % OS.get_process_id())
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
	print("MISSION 4: %d checks" % _checks)
	print("MISSION 4 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in M4_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 4 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data", found.is_empty(), ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var m4 := MissionBook.at(4)
	var problems := m4.problems(MissionBook.weapon_ids())
	var others := PackedStringArray()
	for i in 3:
		others.append(MissionBook.at(i + 1).ruins)
	_check("mission 4 loads and validates, built for real (playable, not a draft), in a district of its own: the records vault, not mission 1's, 2's or 3's", problems.is_empty() and m4.playable and not m4.draft and m4.ruins == "records_vault" and not others.has(m4.ruins) and m4.order == 4, ", ".join(problems))
	var ids := PackedStringArray()
	for o in m4.objectives:
		ids.append(o["id"])
	_check("acceptance: its objective chain is STORY.md's beats in order: %s" % " > ".join(ids), ids == PackedStringArray(CHAIN))
	var arms := PackedStringArray()
	var unlocks := PackedStringArray()
	for o in m4.objectives:
		arms.append_array(o.get("arms", []))
		unlocks.append_array(o.get("unlocks", []))
	_check("acceptance: the handout is exactly mission 4's one weapon (STORY.md: chmod 000): missions 1 to 3's eight in hand as it starts, chmod 000 put in hand for the hunter, kept", _same(m4.loadout, PackedStringArray(CARRIED)) and _same(m4.grants, PackedStringArray(HANDOUT)) and arms == PackedStringArray(HANDOUT) and _same(m4.carried_ever(), PackedStringArray(CARRIED + HANDOUT)))
	_check("acceptance: and exactly its ability (STORY.md: the four ICEbreakers): refused as it starts, unlocked as the first deny rule's beat begins, your AI's pick of which to load with it, no other", _same(m4.abilities, PackedStringArray(["breakers"])) and unlocks == PackedStringArray(["breakers"]) and m4.objectives[0].get("unlocks", []) == ["breakers"] and m4.abilities_at_start() == PackedStringArray(["code_rain_vision"]) and _line_of(m4, "begin:rule1").get("pick", false) == true)
	var walls := 0
	var nodes := 0
	var hunters := 0
	var daemons := 0
	var kinds := {}
	for w in m4.waves:
		kinds[w["kind"]] = true
		match w["kind"]:
			"wall":
				walls += int(w["count"])
			"node":
				nodes += int(w["count"])
			"hunter":
				hunters += int(w["count"])
			_:
				daemons += int(w["count"])
	_check("acceptance: its enemies are its own ICE and finite (STORY.md: white ICE walls, jam nodes, HUD static, and hunter ICE): %d walls, %d nodes (jam and HUD), %d hunters in %d waves, no daemon at all, no Black ICE" % [walls, nodes, hunters, m4.waves.size()], m4.ice and walls == 3 and nodes == 4 and hunters == 2 and daemons == 0 and kinds.size() == 3 and _wave(m4, "nodes_1").get("nodes", []) == ["jam", "hud"] and m4.daemons_total() == 9)
	var shown := _shown_words(m4).to_lower()
	var spoiled := PackedStringArray()
	for word in SPOILERS:
		if shown.contains(word.to_lower()):
			spoiled.append(word)
	var owner := m4.log_of("owner")
	var digits := RegEx.create_from_string("[0-9]")
	var numbered := PackedStringArray()
	for entry in m4.logs:
		for line in str(entry["text"]).split("\n"):
			if line.to_lower().contains("pid") and digits.search(line) != null:
				numbered.append(line)
	_check("acceptance: no `~`, 6666, nohup or ending text in anything mission 4 shows (its lines, its objectives and hints, its logs, the district's signs, folders and the records screen), and the session-holder's PID stays redacted: \"[REDACTED: root only]\" and no digit on any log line that names a pid", spoiled.is_empty() and str(owner["text"]).contains("[REDACTED: root only]") and numbered.is_empty() and RuinsBook.of(m4.ruins).vault_lines.contains("########") and not RuinsBook.of(m4.ruins).vault_lines.to_lower().contains("pid"), ", ".join(spoiled) + " | " + ", ".join(numbered))
	_check("STORY.md's mission 4 lands: the records say every daemon belongs to your user and the session is held by another process (\"%s\"), your AI: \"%s\", the Auditor escalating from DENIED to \"%s\"" % [FLAGGED, SESSION, ESCALATING], str(owner["text"]).contains("owner(rogue.d)  = user") and str(owner["text"]).contains("held by pid") and _line_of(m4, "log:owner", "ai").get("text") == SESSION and _line_of(m4, "begin:rule2", "auditor").get("text") == FLAGGED and _line_of(m4, "complete", "auditor").get("text") == ESCALATING and str(_line_of(m4, "start", "auditor").get("text")).contains("DENIED"))
	_check("STORY.md's end beat as data: the escalation on complete, the sector's lights stuttering once after it (a stutter prop), Black ICE not fought here (no Black ICE in any wave)", m4.prop_of("escalation").get("kind") == "stutter" and m4.prop_of("escalation").get("on") == "complete" and not kinds.has("black") and m4.prop_of("records").get("kind") == "vault" and m4.prop_of("records").get("lights") == "log:owner")
	_check("STORY.md's register: Tron, start to end, a clean sector (its district pristine), its own three logs (the record only once decrypted), the Auditor refusing it as ever", m4.register == "tron" and m4.transitions.is_empty() and RuinsBook.of(m4.ruins).pristine and m4.logs.size() == 3 and owner.get("on") == "done:hold")
	_check("not a reskin of missions 1 to 3: no vents (1's), no queue, shop or parent (2's), no field or loop (3's); a guarded hall of record stacks with three sealed gates", m4.prop_ids("vent").is_empty() and m4.prop_ids("queue").is_empty() and m4.prop_ids("shop").is_empty() and m4.prop_ids("loop").is_empty() and m4.parent_wave().is_empty() and RuinsBook.of(m4.ruins).vault == "exit" and RuinsBook.of(m4.ruins).field == "" and RuinsBook.of(m4.ruins).shop == "")
	# The validator refuses bad mission 4 data by name.
	var bad := m4.duplicate(true) as MissionDef
	bad.ice = false
	var no_ice := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.waves[1]["nodes"] = ["jam", "lamp"]
	var bad_node := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.props[0]["breaker"] = "hammer"
	var bad_pickup := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.logs[0]["on"] = "done:nowhere"
	var bad_log := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.lines[2]["who"] = "auditor"
	var bad_pick := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.ruins = "cache_lines"
	var bad_vault := bad.problems(MissionBook.weapon_ids())
	bad = m4.duplicate(true) as MissionDef
	bad.waves[3]["count"] = 2
	var two_hunters := bad.problems(MissionBook.weapon_ids())
	_check("the validator refuses bad mission 4 data by name: ICE waves in a mission without ICE, a node of an unknown kind, a pickup of an unknown breaker, a log standing on a trigger that is nothing, a pick line by the Auditor, a vault prop in a district without one, a hunter wave of two", not no_ice.is_empty() and not bad_node.is_empty() and not bad_pickup.is_empty() and not bad_log.is_empty() and not bad_pick.is_empty() and not bad_vault.is_empty() and not two_hunters.is_empty(), "%s | %s | %s | %s | %s | %s | %s" % [no_ice, bad_node, bad_pickup, bad_log, bad_pick, bad_vault, two_hunters])


func _shown_words(def: MissionDef) -> String:
	var out := def.title + " " + def.goal
	for o in def.objectives:
		out += " " + str(o["text"]) + " " + str(o.get("label", "")) + " " + str(o.get("hint", ""))
	for entry in def.logs:
		out += " " + str(entry["name"]) + " " + str(entry["text"])
	for line in def.lines:
		out += " " + str(line["text"])
	var s := RuinsBook.of(def.ruins)
	out += " " + " ".join(s.words) + " " + " ".join(s.folders) + " " + s.vault_lines.replace("|", " ")
	return out


## The line on `trigger`, by `who` ("" any).
func _line_of(def: MissionDef, trigger: String, who: String = "") -> Dictionary:
	for line in def.lines:
		if line["on"] == trigger and (who == "" or line["who"] == who):
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
	var s := RuinsBook.of("records_vault")
	var plan := RuinsLayout.of(s)
	var gates: Array = plan.vault.get("gates", [])
	var stacks := plan.blocks.filter(func(b): return b["kind"] == "stack")
	var posts := plan.cover.filter(func(c): return c["kind"] == "post")
	var sealed := true
	for g in gates:
		# A gate row: every cell but the aisle's a stack, so the way through is one cell wide.
		for x in plan.size.x:
			var c := Vector2i(x, (g as Vector2i).y)
			sealed = sealed and (plan.cell(c) == RuinsLayout.Cell.BLOCK) == (x != (g as Vector2i).x)
	var on_aisle := true
	for name in ["gate_1", "gate_2", "vault_door", "hunter_post", "hunter_post_2", "pickup_1", "pickup_2", "vault", "records", "start", "exit"]:
		on_aisle = on_aisle and plan.points.has(name) and absf((plan.points[name] as Vector3).x) < 0.01
	_check("its district is a guarded hall: pristine (no hole, no cable, nothing broken), three gate rows of record stacks either side of a one-cell aisle (%d stacks), guard posts in pairs down it (%d), the records screen past the exit row and the console on the deck, its points on the aisle and every point walkable" % [stacks.size(), posts.size()], s.problems().is_empty() and s.pristine and plan.holes.is_empty() and plan.cables.is_empty() and gates.size() == 3 and sealed and stacks.size() == 12 and posts.size() >= 20 and posts.size() % 2 == 0 and on_aisle and not plan.vault["screen"].is_empty() and plan.unreachable().is_empty())
	var posts_ok := true
	for i in range(0, 4):
		posts_ok = posts_ok and plan.points.has("post_%d" % (i + 1))
	var g1: Vector2i = gates[0]
	var order: bool = (plan.points["gate_1"] as Vector3).z > (plan.points["gate_2"] as Vector3).z and (plan.points["gate_2"] as Vector3).z > (plan.points["vault_door"] as Vector3).z and (plan.points["vault_door"] as Vector3).z > (plan.points["vault"] as Vector3).z and (plan.points["vault"] as Vector3).z > (plan.points["records"] as Vector3).z
	_check("the gates come in order from the start (rule 1, rule 2, the vault door), the nodes' posts flank the first bay and the deck, the hunters' posts stand on the aisle, and the brute pickup before the second rule lies out of the nodes' reach (%.1f m from the nearest)" % Vector2((plan.points["pickup_1"] as Vector3).x - (plan.points["post_1"] as Vector3).x, (plan.points["pickup_1"] as Vector3).z - (plan.points["post_1"] as Vector3).z).length(), order and posts_ok and plan.cell_at(plan.points["post_1"]).y == g1.y - 1 and Vector2((plan.points["pickup_1"] as Vector3).x - (plan.points["post_1"] as Vector3).x, (plan.points["pickup_1"] as Vector3).z - (plan.points["post_1"] as Vector3).z).length() > 10.0)
	var others := PackedStringArray()
	for rset in RuinsBook.all():
		if rset.id != "records_vault" and (not RuinsLayout.of(rset).vault.is_empty() or rset.pristine):
			others.append(rset.id)
	_check("only its district is a vault and pristine: the other districts plan as before", others.is_empty(), ", ".join(others))


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(4))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	var breakers := BreakerDirector.of(main)
	var ice := IceDirector.of(main)
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	_check("as it starts (its card up), missions 1 to 3's eight are carried and nothing of mission 4's yet, the ICEbreakers locked at their director, the arena's own ICE stood aside for the mission's (staged)", runner.state == MissionRunner.State.INTRO and player.carried == PackedStringArray(CARRIED) and breakers.locked and ice.staged and not ice.stand_down)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var told := await _until(func(): return toast.text() == "IN HAND: ICEbreakers  [U]")
	var shown := toast.text()
	var typed := await _until(func(): return _shown_has(mh, ">> ICEbreakers handed to you"))
	var pick := ""
	for text in _fired:
		if text.begins_with("Four programs, one use each."):
			pick = text
	_check("acceptance (handout): the ICEbreakers unlocked as the first deny rule's beat begins, told at the top (\"%s\") and in the terminal, one of each carried, and your AI's pick of which to load from the standing ICE (\"%s\")" % [shown, pick], told and typed and player.abilities.has("breakers") and not breakers.locked and breakers.mode == BreakerDirector.Mode.RUN and breakers.mine.total() == 4 and pick.contains("Load brute: 3 ICE walls up"))
	_check("in mission 4 the gate is on: code-rain vision (mission 3's) allowed, the ICEbreakers now, nothing else", player.abilities_gated and _same(player.abilities, PackedStringArray(["code_rain_vision", "breakers"])))
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	var weapons = hud.weapon_hud()
	var chmod_slot := int(player.inventory.slot_of("chmod_000"))
	var drawn: bool = player.select_slot(chmod_slot)
	_check("acceptance (gating by campaign order): chmod 000 refuses to draw until the hunter's beat hands it over", not drawn and player.inventory.current != chmod_slot and not player.carried.has("chmod_000"))
	var rm := int(player.inventory.slot_of("rm_rf_cannon"))
	_key(KEY_7)
	await _frames(2)
	_action("sigstop")
	await _frames(2)
	_action("sudo_overcharge")
	await _frames(2)
	_check("and what later missions hand over: rm -rf (7), SIGSTOP and sudo refused, said plainly (\"%s\")" % weapons.locked_text(), player.inventory.current != rm and said.has("rm_rf_cannon") and not player.sigstop.is_on() and said.has("sigstop") and said.has("sudo"))
	_key(KEY_6)
	await _frames(2)
	_check("grep (mission 3's) draws on its key", player.inventory.current == int(player.inventory.slot_of("grep_seeker")))
	runner.free_play()
	main = await _after_reload(main.get_instance_id())
	player = main.get_node("Player")
	ice = IceDirector.of(main)
	breakers = BreakerDirector.of(main)
	_check("acceptance (gating): not in the arena: in free play the gate is off, chmod 000 draws, the arena's ICE and breakers are their own again (nothing staged)", not player.abilities_gated and player.select_slot(int(player.inventory.slot_of("chmod_000"))) and not ice.staged and not breakers.staged)


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var m4 := MissionBook.at(4)
	var old_id := main.get_instance_id()
	runner.begin(m4)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ permission denied\")", MissionRunner.mounting() == "$ permission denied" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var toast: UnlockToast = hud.unlock_toast()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var ice := IceDirector.of(main)
	var breakers := BreakerDirector.of(main)
	var blackout := Blackout.of(main)
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
	var at_gates := ice.walls.size() == 3
	for i in 3:
		at_gates = at_gates and Vector2(ice.walls[i].global_position.x - world.point(["gate_1", "gate_2", "vault_door"][i]).x, ice.walls[i].global_position.z - world.point(["gate_1", "gate_2", "vault_door"][i]).z).length() < 0.6
	_check("acceptance: its ICE is its own, placed through the director and judged by it: the arena's four daemons gone, three white ICE walls sealing the three gates, two nodes (a jam and a HUD) flanking the first bay, no hunter yet, no Black ICE, the director deciding", not arena_four and world != null and world.ruins.id == "records_vault" and at_gates and ice.nodes.size() == 2 and ice.nodes[0].kind == IceNode.JAM and ice.nodes[1].kind == IceNode.HUD and ice.hunter == null and ice.black == null and ice.decides() and ice.staged and stage.pieces().size() == 5)
	var pickups := breakers.pickups_out()
	_check("the beat's pickups laid where the mission puts them (two brutes, on the aisle before the second rule and the vault door), none of the director's own", pickups.size() == 2 and pickups.values().all(func(k): return k == Breakers.kind_of("brute")) and stage.pickups_due() == 0 and breakers.staged)
	# The first deny rule: the wall seals the aisle (a ray of the level's meets it, a shot lands and is capped), brute up close breaks it.
	var wall: IceBarrier = ice.walls[0]
	var before: float = wall.health()
	wall.hit(1000.0, wall.global_position + Vector3.UP * 1.5, Vector3.FORWARD, "sigterm")
	_check("a deny rule is a white ICE wall: it stops a step and a shot (its core on the level), and no one hit takes more than the cap off it (%.0f of a 1000)" % (before - wall.health()), wall.sealed() and _ray_hits(main, wall) and absf((before - wall.health()) - ice.tuning.hit_cap) < 0.01)
	player.global_position = world.point("gate_1") + Vector3(0, RuinsLayout.STAND_Y, 1.7)
	player.rotation.y = 0.0
	await _frames(3)
	var brutes: int = breakers.mine.count(Breakers.kind_of("brute"))
	breakers.press_run()
	var broken := await _until(func(): return wall.broken)
	await _frames(2)
	_check("acceptance (the breakers' beat): brute up close breaks the first rule's wall at once, one brute spent (%d held, then %d), the objective done and the Auditor noting the breach" % [brutes, breakers.mine.count(Breakers.kind_of("brute"))], broken and breakers.mine.count(Breakers.kind_of("brute")) == brutes - 1 and runner.index >= 1 and runner.kills == 1 and _fired_has("deny rule 1 breached"))
	# The enforcement nodes: their fields jam the hand and scramble the HUD; the pick says cloak; then broken.
	var pick_cloak := _fired_has("Load cloak")
	var jam: IceNode = ice.nodes[0]
	var hudnode: IceNode = ice.nodes[1]
	player.global_position = jam.global_position + Vector3(6.0, RuinsLayout.STAND_Y, -1.0)
	var jam_tell := await _until(func(): return jam.state_name() == "tell")
	var jammed := await _until(func(): return ice.jams_on_me > 0)
	player.global_position = hudnode.global_position + Vector3(-6.0, RuinsLayout.STAND_Y, -1.0)
	var hud_tell := await _until(func(): return hudnode.state_name() == "tell")
	var scrambled := await _until(func(): return ice.corruptions_on_me > 0 and ice.corrupt_left > 0.0)
	_check("acceptance (the enforcement): the jam node's field jams the weapon in hand and the HUD node's scrambles the HUD (each telegraphed, then fired), your AI's pick now cloak", pick_cloak and jam_tell and jammed and hud_tell and scrambled, "pick %s tell %s jammed %s tell %s scrambled %s" % [pick_cloak, jam_tell, jammed, hud_tell, scrambled])
	runner.life.shield(LONG_ROUND_S)
	player.global_position = world.point("pickup_1") + Vector3(0, RuinsLayout.STAND_Y, 0)
	await _play_until(main, func(): return runner.index >= 2)
	_check("the enforcement nodes broken: both down, the second rule engaged", runner.index == 2 and stage.wave_state("nodes_1") == "cleared" and _fired_has("deny rule 2 of 3 engaged"))
	# The second rule: the brute pickup on the aisle taken, the wall broken; the Auditor's intruder line (STORY.md).
	var taken := await _until(func(): return breakers.pickups_taken >= 1 and breakers.mine.count(Breakers.kind_of("brute")) >= 1)
	var wall2: IceBarrier = ice.walls[1]
	player.global_position = world.point("gate_2") + Vector3(0, RuinsLayout.STAND_Y, 1.7)
	player.rotation.y = 0.0
	await _frames(3)
	breakers.press_run()
	var broken2 := await _until(func(): return wall2.broken)
	await _until(func(): return runner.index >= 3)
	await _until(func(): return _fired.has(FLAGGED))
	_check("acceptance (the second rule): the brute pickup taken on the aisle, the wall broken with it, and the Auditor flags the intruder (\"%s\")" % FLAGGED, taken and broken2 and runner.index == 3 and _fired.has(FLAGGED))
	# The hunter: chmod 000 put in hand, the hunter dispatched; frozen, it does nothing and a hit lands harder; it profiles the weapon leaned on; broken, none comes back.
	var chmod_told := await _until(func(): return toast.text().begins_with("IN HAND: chmod") or _shown_has(mh, ">> chmod handed to you"))
	var hunter_out := await _until(func(): return ice.hunter != null and is_instance_valid(ice.hunter) and not ice.hunter.broken)
	var hunter: HunterIce = ice.hunter
	var stood: Vector3 = _stood.get(String(hunter.name), Vector3.INF) if hunter != null else Vector3.INF
	var at_post: bool = stood.is_finite() and Vector2(stood.x - world.point("hunter_post").x, stood.z - world.point("hunter_post").z).length() < 1.5
	var chmod_drawn: bool = player.select_slot(int(player.inventory.slot_of("chmod_000")))
	_check("acceptance (handout): chmod 000 put in hand as the hunter's beat begins, told (\"%s\"); the hunter dispatched at its post, the Auditor logging it" % toast.text(), chmod_told and player.carried.has("chmod_000") and chmod_drawn and hunter_out and at_post and _fired_has("hunter dispatched"), "told %s carried %s drawn %s out %s post %s logged %s" % [chmod_told, player.carried.has("chmod_000"), chmod_drawn, hunter_out, at_post, _fired_has("hunter dispatched")])
	player.global_position = world.point("hunter_post") + Vector3(0, RuinsLayout.STAND_Y, 7.0)
	for k in 6:
		hunter.hit(20.0, hunter.global_position + Vector3.UP, Vector3.FORWARD, "terminal_cannon")
		await process_frame
	var profiled: bool = ice.adapt_weapon != "" and ice.adapt_percent() > 0
	var froze := false
	var frames := 0
	while frames < 600 and not hunter.chmod_frozen():
		froze = hunter.chill(1.0 / Engine.physics_ticks_per_second * 4.0) or froze
		await process_frame
		frames += 1
	var frozen_now: bool = hunter.chmod_frozen()
	var before_h: float = hunter.health()
	hunter.hit(1000.0, hunter.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail")
	var landed: float = before_h - hunter.health()
	var expected: float = minf(before_h, ice.tuning.hit_cap * hunter.frost.tuning.frozen_hit_scale * (1.0 - ice.resist_for("sigkill_rail")))
	var pick_hunter := await _until(func(): return _fired_has("Load exploit") or _fired_has("Load decoy"))
	_check("acceptance (chmod 000 on the hunter): the hunter profiles the weapon leaned on (%s, %d%%); frozen by chmod 000 it does nothing, and the next hit lands %.1f times harder (%.0f of a capped 100, %.0f expected with its resistance)" % [ice.adapt_weapon, ice.adapt_percent(), hunter.frost.tuning.frozen_hit_scale, landed, expected], profiled and froze and frozen_now and absf(landed - expected) < 0.5 and pick_hunter, "profiled %s froze %s frozen %s pick %s" % [profiled, froze, frozen_now, pick_hunter])
	var hunters_before: int = ice.hunters_made
	while is_instance_valid(hunter) and not hunter.broken:
		hunter.hit(1000.0, hunter.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail")
		await process_frame
	await _frames(int(Engine.physics_ticks_per_second * (ice.tuning.hunter_respawn_s * 0.2 + 2.0)))
	ice.hunter_wait = 0.0  # the arena's whole wait (hunter_respawn_s) over, as if it had all passed: still none
	await _frames(3)
	_check("the hunter broken: the beat done, the third rule engaged, and no hunter comes back on its own, the arena's wait over (finite: %d made)" % ice.hunters_made, runner.index >= 4 and (ice.hunter == null or not is_instance_valid(ice.hunter) or ice.hunter.broken) and ice.hunters_made == hunters_before and _fired_has("deny rule 3 of 3 engaged"))
	# The last rule and the deck: the second brute pickup, the vault door broken, the deck reached; the hold: its second hunter and nodes come.
	player.global_position = world.point("pickup_2") + Vector3(0, RuinsLayout.STAND_Y, 0)
	await _until(func(): return breakers.mine.count(Breakers.kind_of("brute")) >= 1)
	var wall3: IceBarrier = ice.walls[2]
	player.global_position = world.point("vault_door") + Vector3(0, RuinsLayout.STAND_Y, 1.7)
	player.rotation.y = 0.0
	await _frames(3)
	breakers.press_run()
	var broken3 := await _until(func(): return wall3.broken)
	player.global_position = world.point("vault")
	await _until(func(): return runner.index >= 5)
	var second := await _until(func(): return ice.hunters_made == hunters_before + 1 and ice.nodes.size() == 4)
	var record_hidden: bool = runner.pickup("owner") == null
	_check("acceptance (the last rule and the deck): the vault door broken with the second brute, the deck reached, the hold begun with its second hunter and two more nodes, the record not yet standing (it decrypts)", broken3 and runner.index == 5 and second and record_hidden and _fired_has("second hunter dispatched"), "broken %s index %d second %s hidden %s" % [broken3, runner.index, second, record_hidden])
	await _until(func(): return runner.index >= 6)
	var decrypted := await _until(func(): return runner.pickup("owner") != null)
	_check("the hold held (%d s of play): the record stands on the console once decrypted" % int(m4.objectives[5]["seconds"]), runner.index == 6 and decrypted and _fired_has("Decrypted"))
	# The record read: the records screen lights with its redaction bar; your AI's line; the escalation; the lights stutter once.
	var power_before: float = world.vault_power()
	player.global_position = runner.log_place("owner")
	await _until(func(): return runner.logs_found.has("owner"))
	var read_at := Engine.get_process_frames()
	var lit := await _until(func(): return world.vault_power() >= 1.0)
	await _until(func(): return _fired.has(SESSION))
	var session_s: float = float(int(_said_at.get(SESSION, read_at)) - read_at) / Engine.physics_ticks_per_second
	var mesh: ArrayMesh = world.get("_built")["vault"]["mesh"]
	_check("acceptance (STORY.md): the record read: the records screen lights over the deck (dark before: %.2f), its session line a redaction bar (its mesh's own mark surface), the Auditor's read line, and after a moment (%.1f s) your AI: \"%s\"" % [power_before, session_s, SESSION], power_before == 0.0 and lit and world.has_vault() and mesh.get_surface_count() == 3 and _fired_has("pid: redacted") and _fired.has(SESSION) and session_s >= 2.0)
	await _until(func(): return runner.state == MissionRunner.State.COMPLETE)
	var escalated := await _until(func(): return _fired.has(ESCALATING))
	var stuttering := await _until(func(): return blackout != null and blackout.stuttering())
	var dark := false
	frames = 0
	while frames < 60 and blackout != null and blackout.stuttering():
		dark = dark or ArenaArt.light_level < 0.5
		await process_frame
		frames += 1
	var lit_again := await _until(func(): return ArenaArt.light_level >= 0.999 and blackout != null and not blackout.stuttering())
	_check("acceptance (STORY.md's end beat): \"%s\", and the sector's lights stutter once (down to Black ICE's low and back, twice in a blink), then stay lit; Black ICE itself never came" % ESCALATING, escalated and stuttering and dark and lit_again and blackout != null and blackout.stutters() == 1 and ice.black == null, "escalated %s blackout %s (the stage's own %s) stutters %d stuttering %s dark %s lit %s" % [escalated, blackout != null, Blackout.of(stage) != null, blackout.stutters() if blackout != null else -1, stuttering, dark, lit_again])
	_check("acceptance: the objective chain completed in order with a scripted run: %s" % " > ".join(_began), runner.state == MissionRunner.State.COMPLETE and _began == PackedStringArray(CHAIN))
	var end := mh.end_screen()
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, your AI's last line read first, chmod 000 and the ICEbreakers listed", not end.is_up() and await _until(func(): return end.is_up()) and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and _text_has(end.shown_text(), "chmod") and _text_has(end.shown_text(), "ICEbreakers  [U]") and _fired_has("I know what comes after escalating"))
	await _frames(int(Engine.physics_ticks_per_second * 2.0))
	var standing_pieces := stage.pieces().filter(func(p): return not p.broken).size()
	_check("acceptance: its ICE was finite and its own: %d pieces made of its waves' %d, each stood once and none ever back once broken (%d broken, %d standing), two hunters in all, the director's own none" % [_names.size(), m4.daemons_total(), _broke, standing_pieces], _names.size() == m4.daemons_total() and _broke + standing_pieces == _names.size() and ice.hunters_made == 2 and ice.staged)
	_check("acceptance: its weapon kept and mission 4 recorded done", MissionProgress.current().is_done("permission_denied") and Progress.current().has_weapon("chmod_000"))
	await _drop(main)


func _watch(d: Node3D) -> void:
	var key := String(d.name)
	if _names.has(key):
		return
	_names.append(key)
	_stood[key] = d.global_position
	if d.has_signal("broke"):
		d.broke.connect(func(_x): _broke += 1)
	elif d.has_signal("downed"):
		d.downed.connect(func(_x): _broke += 1)


## True when a ray of the level's straight through `wall`'s middle (from a metre one side to a metre the other) meets it.
func _ray_hits(main: Node, wall: Node3D) -> bool:
	var space: PhysicsDirectSpaceState3D = main.get_viewport().world_3d.direct_space_state
	var across: Vector3 = wall.global_transform.basis.z.normalized()
	var mid := wall.global_position + Vector3.UP * 1.2
	var q := PhysicsRayQueryParameters3D.create(mid - across, mid + across, 1)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and wall.is_ancestor_of(hit["collider"])


## Frames until `condition` holds (at most `most`), shooting down as a sure shot would the pieces the objective running
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


# --- The fail card. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(4))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	_fired.clear()
	runner.line_said.connect(func(_who: String, text: String) -> void: _fired.append(text))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	var wall: Node3D = runner.stage.wave_daemons("wall_1")[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, wall, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	var card_up := await _until(func(): return end.is_up())
	var again := await _until(func(): return _fired_has("Again."))
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it (\"Denied. It's a records vault; it has all night. Again.\")", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and card_up and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry" and again and mh.shown_text().size() > 0, "state %d reason '%s' up %s kind %s again %s" % [runner.state, runner.reason, card_up, end.kind(), again])
	_check("its ICE stops coming once it has failed", runner.stage.stopped)
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

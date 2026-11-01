extends SceneTree
## Headless test of mission 7, `kill -9`, the finale, built for real (M7, PRD 5.6, docs/STORY.md section 6 mission 7 and
## section 7). scripts/check.sh runs it as step 62, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/mission7_test.gd
##
## The code: nothing M7 added or changed runs a program, opens a connection or a file, or reads the player's machine
## (kill -9 is a weapon's name; the shell's true body is a game object). The data: mission 7 validates, is no longer a
## skeleton, stands in a district of its own (the core, in every register at once, not missions 1's to 6's), and is
## STORY.md's: the shell's true body, the giant red-hot lattice core, hanging over the core, taking only kill -9
## (SIGTERM trapped, SIGHUP ignored), shedding runaways and calling ICE, the Auditor's last lines, `~`'s "you won't."
## at the last moment, and the one ending: every daemon reaped at once as init adopts the orphans, Black ICE standing
## down, "audit: session restored. user=you", "...welcome back.", and the hand-off to the credits. No handout: every one
## of the thirteen is in hand from the start and nothing is granted. Nothing the Auditor says gives the redacted PID.
## A scripted run in the real arena stood in its district: the lattice standing over the core and rising, the pack
## out, the core reached, SIGTERM sent and refused (nothing off it, the readout), the runaways shed off it and three
## killed with the meter filling, one real rail shot and two direct hits each taking exactly its cap with the world
## tearing to Tron (ICE nodes through the director), Matrix (the hunter, its old scripts) and the cyberpunk ruins in
## that order, the cannon refused all the while, the fourth hit and the world recombined ("all") with Black ICE
## dispatched, "you won't." typed, the fifth hit the kill: every daemon reaped with no kill credited, the ICE stood down,
## the kill feed's line, the Auditor's adoption, the ending's two lines said exactly once, "exit 0" with Credits first,
## the hand-off up once and no row of the roll in it, and the Missions screen with all seven done, the earlier missions
## still startable. A death fails it ("exit 137"), and so does Black ICE's touch. Its files live in its own folder under
## user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

## What M7 added or changed that runs in a mission: none of it may touch anything of the player's.
const M7_CODE := ["res://scripts/missions/mission_stage.gd", "res://scripts/missions/mission_runner.gd", "res://scripts/missions/mission_def.gd", "res://scripts/daemons/shell_core.gd", "res://scripts/fight/daemon_brain.gd", "res://scripts/target_dummy.gd", "res://scripts/ice/ice_piece.gd", "res://scripts/ruins/ruins_set.gd", "res://scripts/ruins/ruins_layout.gd", "res://scripts/ruins/ruins_world.gd", "res://scripts/ruins/ruins_register.gd", "res://scripts/hud/mission_hud.gd", "res://scripts/hud/mission_end_screen.gd", "res://scripts/hud/credits_handoff.gd"]
## (The dummy reads the game's own command line for --demo, to fix its seeds: the game's, not the machine's.)
const NEVER := ["OS.execute", "create_process", "OS.kill", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "get_file_as_string", "DirAccess", "OS.get_environment", "get_user_data_dir", "get_system_dir", "get_executable_path", "OpenerData", "RealData"]
## STORY.md mission 7's beats, in order.
const CHAIN := ["find", "term", "fill", "nine", "last", "end"]
const ALL := ["terminal_cannon", "sigterm", "sigkill_rail", "ping_sonar", "fork_bomb", "fork_shotgun", "grep_seeker", "pipe_chain", "chmod_000", "cron_mines", "rm_rf_cannon", "sighup", "dev_null"]
## STORY.md's words for mission 7 and its ending, exactly.
const WONT := "you won't."
const RESTORED := "audit: session restored. user=you"
const WELCOME := "...welcome back."
const FEED := "SIGKILL sent by you to ~"
## The rows the credits' roll keeps for C44: none of them in the hand-off.
const ROLL_ROWS := ["6666", "thanks for running me", "@"]
const MOST_FRAMES := 3600
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""
var _began: PackedStringArray = []
var _down := 0
var _names: PackedStringArray = []
var _fired: Array = []
var _handed := 0
var _struck: Array = []
var _back := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://mission7-test-%d" % OS.get_process_id())
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
	print("MISSION 7: %d checks" % _checks)
	print("MISSION 7 RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in M7_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance: no file reads of the player's machine: nothing mission 7 runs opens a file or a folder, runs a program, opens a connection or reads the environment, a path or the opener's data (kill -9 is a weapon's name; the shell's body is a game object)", found.is_empty(), ", ".join(found))


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The data. ---

func _data_checks() -> void:
	var m7 := MissionBook.at(7)
	var problems := m7.problems(MissionBook.weapon_ids())
	_check("mission 7 loads and validates, built for real (playable, not a draft, no longer a skeleton), the finale: in a district of its own, the core, in every register at once, nothing after it", m7 != null and problems.is_empty() and m7.playable and not m7.draft and m7.ruins == "core_lattice" and m7.id == "kill_9" and m7.title == "kill -9" and m7.register == "all" and m7.next == "" and MissionRunner.is_finale(m7), "; ".join(problems))
	var ids := PackedStringArray()
	for o in m7.objectives:
		ids.append(o["id"])
	_check("acceptance: STORY.md's chain, in order (find the shell's body, send it SIGTERM, fill the rail on what it sheds, three landing hits of kill -9, one more, the kill): %s" % ", ".join(ids), ids == PackedStringArray(CHAIN) and m7.objectives[0]["kind"] == "reach" and m7.objectives[1]["kind"] == "hit" and m7.objectives[1]["weapon"] == "sigterm" and m7.objectives[2]["kind"] == "kill" and m7.objectives[3]["kind"] == "hit" and m7.objectives[3]["weapon"] == "sigkill_rail" and int(m7.objectives[3]["count"]) == 3 and m7.objectives[4]["kind"] == "hit" and m7.objectives[5]["kind"] == "kill" and m7.objectives[5]["daemon"] == "shell")
	var hands := 0
	for o in m7.objectives:
		hands += (o.get("arms", []) as Array).size() + (o.get("gives", []) as Array).size() + (o.get("unlocks", []) as Array).size()
	_check("acceptance: no handout (STORY.md: teaches nothing new, everything): all thirteen in hand as it starts, nothing granted, armed, given or unlocked by any beat, no ability of its own, and every ability the campaign hands over allowed", _same(m7.loadout, PackedStringArray(ALL)) and m7.grants.is_empty() and m7.abilities.is_empty() and hands == 0 and _same(m7.allowed_abilities(), PackedStringArray(["sigstop", "code_rain_vision", "breakers", "sudo"])) and MissionBook.granted_by(7).size() == 13)
	var shell := m7.shell_wave()
	var kinds := {}
	for w in m7.waves:
		kinds[w["kind"]] = true
	_check("acceptance: its enemy is the shell's true body (STORY.md: the giant red-hot lattice core): one, standing over the core, reached only by kill -9 (SIGTERM trapped, SIGHUP ignored), each hit capped so it takes %d of them, shedding runaways on the fill beat, the parent of every daemon in the mission (reaps any)" % int(float(shell.get("health", 0.0)) / maxf(float(shell.get("hit_cap", 1.0)), 1.0)), not shell.is_empty() and int(shell.get("count", 0)) == 1 and shell.get("only", []) == ["sigkill_rail"] and float(shell.get("hit_cap", 0.0)) > 0.0 and absf(float(shell["health"]) / float(shell["hit_cap"]) - 5.0) < 0.001 and str(shell.get("sheds", "")) == "shed_1" and str(shell.get("sheds_on", "")) == "begin:fill" and str(shell.get("reaps", "")) == "any" and m7.parent_wave() == shell)
	_check("acceptance: it sheds runaway swarms and calls ICE, every kind of daemon at once, all finite (STORY.md): rogue.d, zombies, runaways, ICE nodes, a hunter and Black ICE in %d waves, %d daemons at most, none coming back" % [m7.waves.size(), m7.daemons_total()], kinds.has("rogue") and kinds.has("zombie") and kinds.has("swarm") and kinds.has("node") and kinds.has("hunter") and kinds.has("black") and kinds.has("shell") and m7.ice and m7.daemons_total() == 32)
	var shifts := PackedStringArray()
	for t in m7.transitions:
		shifts.append(str(t["on"]) + ">" + str(t["to"]))
	_check("acceptance: the world comes apart and recombines as the fight escalates (STORY.md: all three at once, collapsing into each other): in \"all\" as it starts, torn to Tron, Matrix and the cyberpunk ruins on its first three hits, back to all three on the fourth, for the kill: %s" % ", ".join(shifts), shifts == PackedStringArray(["hit:shell_1:1>tron", "hit:shell_1:2>matrix", "hit:shell_1:3>cyberpunk", "hit:shell_1:4>all"]))
	_check("acceptance: STORY.md's words as data: `~` types \"%s\" at the last moment (as the last beat begins), and the one ending: the Auditor's \"%s\" and your AI's \"%s\" on complete, in that order" % [WONT, RESTORED, WELCOME], _has_line(m7, "begin:end", "tilde", WONT) and _has_line(m7, "complete", "auditor", RESTORED) and _has_line(m7, "complete", "ai", WELCOME) and float(_line_of(m7, "complete", "auditor").get("wait", 0.0)) < float(_line_of(m7, "complete", "ai").get("wait", 0.0)))
	# The Auditor's records keep the PID redacted (mission 4's rule): no Auditor line of the finale says it.
	var audit_pid := PackedStringArray()
	for line in m7.lines:
		if line["who"] == "auditor" and (str(line["text"]).contains("6666") or RegEx.create_from_string("pid[ =:][^\\n]*[0-9]").search(str(line["text"]).to_lower()) != null):
			audit_pid.append(str(line["text"]))
	_check("acceptance: the redacted PID stays redacted wherever STORY.md keeps it redacted: no Auditor line names it (its records hold \"[REDACTED]\"); the goal, STORY.md's own, may (mission 5 revealed it)", audit_pid.is_empty() and _line_of(m7, "start", "auditor").get("text", "").contains("[REDACTED]") and m7.goal.contains("6666"), ", ".join(audit_pid))
	var others := PackedStringArray()
	for i in range(1, 7):
		if MissionBook.at(i).ruins == m7.ruins:
			others.append(MissionBook.at(i).id)
	_check("not a reskin: no earlier mission stands in its district; the finale is the last of the seven and names no mission 8", others.is_empty() and MissionBook.campaign().size() == 7 and MissionBook.at(8) == null)
	# The validator refuses bad mission 7 data by name.
	var bad := m7.duplicate(true) as MissionDef
	bad.waves = bad.waves.duplicate(true)
	bad.waves[0]["only"] = ["bfg"]
	var bad2 := m7.duplicate(true) as MissionDef
	bad2.objectives = bad2.objectives.duplicate(true)
	bad2.objectives[3]["weapon"] = "sigkill_rail_x"
	var bad3 := m7.duplicate(true) as MissionDef
	bad3.lines = bad3.lines.duplicate(true)
	bad3.lines[9]["on"] = "hit:nobody:1"
	var bad4 := m7.duplicate(true) as MissionDef
	bad4.waves = bad4.waves.duplicate(true)
	bad4.waves[1]["reaps"] = "any"
	var bad5 := m7.duplicate(true) as MissionDef
	bad5.waves = bad5.waves.duplicate(true)
	bad5.waves[0]["shed_every"] = 0.1
	var rset0 := RuinsBook.of("core_lattice")
	var bad_set := rset0.duplicate(true) as RuinsSet
	bad_set.clearing = 9
	_check("the validator refuses bad mission 7 data by name: a shell reached only by a weapon that is not, a hit beat of no weapon, a hit trigger on a wave it has not, a plain wave that reaps, a shell shedding ten times a second, a clearing wider than the floor", _has(bad.problems(MissionBook.weapon_ids()), "no weapon") and _has(bad2.problems(MissionBook.weapon_ids()), "no weapon") and _has(bad3.problems(MissionBook.weapon_ids()), "line trigger") and _has(bad4.problems(MissionBook.weapon_ids()), "only a parent or the shell") and _has(bad5.problems(MissionBook.weapon_ids()), "shed_every") and _has(bad_set.problems(), "clearing"))


func _has(problems: PackedStringArray, part: String) -> bool:
	for p in problems:
		if p.contains(part):
			return true
	return false


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
	var s := RuinsBook.of("core_lattice")
	var plan := RuinsLayout.of(s)
	var inside := 0
	for b in plan.blocks:
		var r: Rect2i = b["rect"]
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				if plan.in_clearing(Vector2i(x, z)):
					inside += 1
	for h in plan.holes:
		var r: Rect2i = h["rect"]
		for x in range(r.position.x, r.end.x):
			for z in range(r.position.y, r.end.y):
				if plan.in_clearing(Vector2i(x, z)):
					inside += 1
	for c in plan.cover:
		if plan.in_clearing(plan.cell_at(c["at"])):
			inside += 1
	var ring := true
	for i in 4:
		var p: Vector3 = plan.points.get("ring_%d" % i, Vector3.INF)
		ring = ring and p.is_finite() and absf(Vector2(p.x - plan.points["plaza"].x, p.z - plan.points["plaza"].z).length() - s.clearing * RuinsLayout.CELL_M) < 0.01
	_check("its district is the core (STORY.md: grid, rain and ruin round a red-hot core): in every register at once, a clearing of %d cells round the plaza with nothing of the dice in it (%d inside) and a point at each of its four edges, %d holes into the heat, the sea of heat %.1f m under the floor, its own palette, every point reachable" % [s.clearing, inside, plan.holes.size(), s.water], s.problems().is_empty() and s.register == "all" and s.clearing == 2 and inside == 0 and ring and plan.holes.size() >= 4 and s.water > 0.0 and s.palette == "core" and s.breach == "" and plan.unreachable().is_empty())
	var worst := INF
	for c in RuinsRegister.colours():
		worst = minf(worst, RuinsRegister.gap(c))
	_check("its palette keeps the daemons and ICE readable: every colour of it at least %.2f OKLab from theirs (nearest %.3f), and its sea glows of itself" % [RuinsRegister.READABLE_GAP, worst], worst >= RuinsRegister.READABLE_GAP and RuinsRegister.PALETTES["core"].has("water_glow") and (RuinsRegister.PALETTES["core"]["water_glow"] as Color).r > 0.2)
	var others := PackedStringArray()
	for rset in RuinsBook.all():
		if rset.id != "core_lattice" and (rset.clearing != 0 or rset.register == "all"):
			others.append(rset.id)
	_check("only its district has a clearing and stands in every register; the other districts plan as before", others.is_empty(), ", ".join(others))


# --- The gate. ---

func _gate_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(7))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var player = main.get_node("Player")
	var said: Array = []
	player.locked.connect(func(what: String) -> void: said.append(what))
	var ice := IceDirector.of(main)
	_check("as it starts (its card up), all thirteen are carried, the arena's own four gone, the ICE director staged for its own pieces and none out", runner.state == MissionRunner.State.INTRO and _same(player.carried, PackedStringArray(ALL)) and not main.has_node("Arena/Targets/DummyA") and ice.staged and not ice.black_out())
	var drew := true
	var undrawn := PackedStringArray()
	for w in ALL:
		var slot := int(player.inventory.slot_of(w))
		var ok: bool = player.select_slot(slot) or player.inventory.current == slot
		drew = drew and ok
		if not ok:
			undrawn.append(w)
	_action("sigstop")
	await _frames(3)
	var stopped: bool = player.sigstop.is_on() and not said.has("sigstop")
	_action("sigstop")
	await _frames(3)
	_action("sudo_overcharge")
	_action("code_rain_vision")
	await _frames(2)
	_check("acceptance (gating): every one of the thirteen draws from the start and every ability is allowed (SIGSTOP runs, nothing refused, nothing said locked): the gate is on and lets everything through", drew and stopped and said.is_empty() and player.abilities_gated and _same(player.abilities, PackedStringArray(["code_rain_vision", "breakers", "sudo", "sigstop"])), "undrawn %s stopped %s said %s gated %s abilities %s" % [str(undrawn), str(stopped), str(said), str(player.abilities_gated), str(player.abilities)])
	await _drop(main)


# --- A scripted run. ---

func _run_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var m7 := MissionBook.at(7)
	var old_id := main.get_instance_id()
	runner.begin(m7)
	await process_frame
	_check("the reload into its district waits a black frame with its command typed (\"$ kill -9\")", MissionRunner.mounting() == "$ kill -9" and main.get_instance_id() == old_id)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var hud = main.get_node("Hud")
	var mh: MissionHud = hud.mission_hud()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var ice := IceDirector.of(main)
	_began.clear()
	_fired.clear()
	_struck.clear()
	_handed = 0
	runner.objective_began.connect(func(i: int) -> void: _began.append(runner.def.objectives[i]["id"]))
	runner.line_said.connect(func(who: String, text: String) -> void: _fired.append([who, text]))
	runner.handed.connect(func(_w: String) -> void: _handed += 1)
	runner.ability_handed.connect(func(_a: String) -> void: _handed += 1)
	stage.spawned.connect(func(d: Node3D) -> void: _watch(d))
	stage.struck.connect(func(d: Node3D, source: String, landed: bool) -> void: _struck.append([d, source, landed]))
	for d in stage.made:
		_watch(d)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	await _frames(10)
	var start := world.point("start")
	var plaza := world.point("plaza")
	# The opening: the shell's true body stands over the core and rises; the pack climbs out; the world in every register.
	var stood := await _until(func(): return stage.boss != null and is_instance_valid(stage.boss) and stage.boss.is_alive())
	var boss: Node3D = stage.boss
	var floor_y: float = plaza.y - RuinsLayout.STAND_Y
	await _until(func(): return boss.brain != null and boss.brain._risen >= 1.0)
	await _frames(int(1.0 * Engine.physics_ticks_per_second))
	var high: float = boss.global_position.y if stood else -INF
	var over := Vector2(boss.global_position.x - plaza.x, boss.global_position.z - plaza.z).length() if stood else INF
	var out_early := await _play_until(main, func(): return stage.standing().size() >= 5, MOST_FRAMES, false)
	_check("acceptance (the opening): the shell's true body stands over the core as it begins (tagged \"~\", its own art, no walker) and rises from the floor to hang %.1f m over it, within its orbit of the plaza (%.1f m); rogue.d and zombies climb out of the vents; the world in every register at once; the sea of heat under the floor" % [high - floor_y, over], stood and boss.tag_text == "~" and MissionRunner.kind_of(boss) == "shell" and high - floor_y > 4.0 and over < DaemonBrain.SHELL_ORBIT_M + 2.0 and out_early and runner.register == "all" and world.register == "all" and world.has_water() and world.water_y() < plaza.y and absf(player.global_position.y - start.y) < 1.5, "stood %s high %.2f floor %.2f over %.2f out %s reg %s" % [str(stood), high, floor_y, over, str(out_early), world.register])
	# A volley: its bolts from the heart at the player standing in sight of it (the test's shield off for it: a
	# protected player is attacked by nothing).
	player.global_position = plaza + Vector3(7.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	_aim(player, boss.threat_point())
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	var volleyed := await _until(func(): return boss.brain != null and boss.brain.volleys >= 1 and DaemonDirector.of(main).bolts_live() > 0)
	var volleys: int = boss.brain.volleys if boss.brain != null else 0
	var live: int = DaemonDirector.of(main).bolts_live()
	runner.life.shield(100000.0)
	_check("acceptance: it fights unlike every earlier enemy: no slash, no dive, no charge; it hangs in the air and throws volleys of bolts from its heart at the player in sight (%d volleys, %d bolts in the air)" % [volleys, live], volleyed and boss.brain.state_name() != "tell" and boss.brain.state_name() != "strike")
	# Nothing holds it: a freeze, a hangup and a hole are refused by it.
	var hup_tuning: SighupTuning = (load("res://resources/sighup.tres") as WeaponDef).projectile.duplicate() if (load("res://resources/sighup.tres") as WeaponDef).projectile is SighupTuning else null
	var took_hup: bool = boss.take_hup(hup_tuning) if hup_tuning != null else false
	var chilled: bool = boss.chill(2.0)
	boss.hold_in_hole(2.0)
	_check("nothing holds the shell's body: chmod 000's beam, a SIGHUP hangup and a /dev/null hole are all refused (sessile to them; it moves on its own)", boss.sessile() and not took_hup and not chilled and not boss.held_by_hole())
	# Find: the core reached.
	player.global_position = plaza
	player.velocity = Vector3.ZERO
	var found := await _until(func(): return runner.index >= 1)
	runner.life.shield(100000.0)
	_check("acceptance (find): the core reached under it, the beat done, SIGTERM's beat begun", found and _began.has("term"))
	# SIGTERM: a real shot at it, refused: nothing off it, the shot counted, the readout, `~`'s trap line.
	var health0: float = boss.health()
	player.global_position = plaza + Vector3(6.0, 0.0, 0.0)
	player.velocity = Vector3.ZERO
	var shot := await _shoot(player, "sigterm", boss.threat_point())
	var term_done := await _until(func(): return runner.index >= 2)
	var refused_term := _struck_has("sigterm", false)
	var readout := await _until(func(): return mh.refused_text().contains("SIGTERM") and mh.refused_text().contains("trapped"))
	var trap_line := await _until(func(): return _fired_has("trap -- '' SIGTERM"))
	_check("acceptance (SIGTERM): sent at it (a real shot, %s) and trapped: nothing off it (%.0f of %.0f), the shot counted as sent and the beat done, the readout under the crosshair (\"%s\"), `~`'s own trap line in the terminal" % [str(shot), boss.health(), health0, mh.refused_text()], shot and term_done and refused_term and boss.health() == health0 and readout and trap_line and _began.has("fill"))
	# Fill: it sheds runaways off its cage; three killed; the meter fills.
	player.inventory.reset_meter()
	var shed := await _until(func(): return stage.sheds_made.size() >= 2)
	var off_cage := true
	for c in stage.sheds_made:
		if is_instance_valid(c) and c.has_meta(&"core"):
			off_cage = off_cage and c.get_meta(&"core") == boss
	var kills_before := runner.kills
	var filled := await _play_until(main, func(): return runner.index >= 3, MOST_FRAMES * 2)
	runner.life.shield(100000.0)
	_check("acceptance (fill): runaways shed off the cage (%d so far, each a child of the shell, no more than %d standing at once), three of them killed, the beat done and the rail's beat begun" % [stage.sheds_made.size(), int(m7.shell_wave()["shed_standing"])], shed and off_cage and filled and runner.kills - kills_before >= 3 and _began.has("nine"))
	# kill -9, hit one: a real rail shot with the meter full, landing exactly its cap; the world tears to Tron, ICE nodes.
	var reg0 := world.register
	player.inventory.add_meter(10.0)
	var ready: bool = player.inventory.meter_ready()
	player.global_position = plaza + Vector3(8.0, 0.0, 2.0)
	player.velocity = Vector3.ZERO
	health0 = boss.health()
	var railed := await _shoot(player, "sigkill_rail", boss.threat_point(), 40)
	var landed := await _until(func(): return _struck_has("sigkill_rail", true))
	var took: float = health0 - boss.health()
	var torn := await _until(func(): return world.register == "tron")
	var nodes := await _until(func(): return stage.wave_state("ice_1") != "waiting" and ice.nodes.size() >= 2)
	var dispatched := await _until(func(): return _fired_has("ICE dispatched"))
	_check("acceptance (kill -9, the first): the meter full (%s), a real rail shot lands (%s) and takes exactly its cap (%.0f of %.0f), the world torn from %s to Tron, ICE nodes dispatched through the director (%d), the Auditor's line" % [str(ready), str(railed), took, health0, reg0, ice.nodes.size()], ready and railed and landed and absf(took - float(m7.shell_wave()["hit_cap"])) < 0.001 and torn and nodes and dispatched and runner.progress >= 1.0)
	# The cannon on it, refused; then the second and third hits, direct, the world to Matrix and the ruins.
	health0 = boss.health()
	for i in 4:
		boss.hit(50.0, boss.threat_point(), Vector3.FORWARD, "terminal_cannon")
	await _frames(3)
	var cannon_refused: bool = boss.health() == health0 and _struck_has("terminal_cannon", false)
	boss.hit(1000.0, boss.threat_point(), Vector3.FORWARD, "sigkill_rail")
	var matrix := await _until(func(): return world.register == "matrix")
	var hunter := await _until(func(): return ice.hunter != null and is_instance_valid(ice.hunter))
	var old := await _until(func(): return stage.wave_state("old_1") != "waiting" and stage.wave_state("old_2") != "waiting")
	var two: bool = absf(boss.health() - (health0 - float(m7.shell_wave()["hit_cap"]))) < 0.001
	boss.hit(1000.0, boss.threat_point(), Vector3.FORWARD, "sigkill_rail")
	var ruins := await _until(func(): return world.register == "cyberpunk")
	var last_begun := await _until(func(): return runner.index >= 4)
	var no_black_yet: bool = not ice.black_out()
	_check("acceptance (the escalation): the cannon refused (%s, nothing off it), the second hit tears the world to Matrix with the hunter and its old scripts out (hunter %s, old %s), the third to the cyberpunk ruins; the rail's beat done after three, the last beat begun, Black ICE not yet" % [str(cannon_refused), str(hunter), str(old)], cannon_refused and matrix and hunter and old and two and ruins and last_begun and no_black_yet, "matrix %s hunter %s old %s two %s ruins %s last %s" % [str(matrix), str(hunter), str(old), str(two), str(ruins), str(last_begun)])
	# The fourth hit: the world recombined, Black ICE dispatched, the end beat begun, `~` types "you won't."; the fifth
	# is the kill.
	runner.life.shield(100000.0)
	boss.hit(1000.0, boss.threat_point(), Vector3.FORWARD, "sigkill_rail")
	var all_again := await _until(func(): return world.register == "all")
	var end_begun := await _until(func(): return runner.index >= 5)
	var black_came := await _until(func(): return ice.black != null and is_instance_valid(ice.black))
	var black: BlackIce = ice.black if black_came else null
	var blackout := black_came and await _until(func(): return ice.black_darkness() > 0.5)
	var wont := await _until(func(): return _fired_has(WONT))
	var hits_before: int = stage.hits_on("shell_1")
	var kills_at := runner.kills
	var daemons_up := stage.standing().filter(func(d): return not (d is IcePiece) and d != boss and d.is_alive()).size()
	var pieces_up := stage.standing().filter(func(d): return d is IcePiece and not (d is BlackIce)).size()
	_check("acceptance (the last moment): the fourth hit recombines the world (all three at once) and dispatches Black ICE to the core (its darkness %.2f, the Auditor's last resort); the kill is the last beat, and `~` types \"%s\" (STORY.md: the opener's line, word for word); %d daemons and %d pieces of ICE still up round the player, Black ICE out" % [ice.black_darkness(), WONT, daemons_up, pieces_up], all_again and end_begun and black_came and blackout and _fired_has("last resort") and wont and hits_before == 4 and daemons_up >= 3 and black.present_now(), "all %s end %s black %s dark %s wont %s hits %d daemons %d" % [str(all_again), str(end_begun), str(black_came), str(blackout), str(wont), hits_before, daemons_up])
	boss.hit(1000.0, boss.threat_point(), Vector3.FORWARD, "sigkill_rail")
	await _frames(3)
	var killed: bool = not boss.is_alive()
	var reaped := await _until(func(): return stage.reaped_count >= 0)
	await _frames(6)
	var left := stage.standing().filter(func(d): return not (d is IcePiece) and d.is_alive()).size()
	var pieces_left := stage.standing().filter(func(d): return d is IcePiece and not (d is BlackIce) and d.is_alive()).size()
	var black_gone := black_came and await _until(func(): return not ice.black_out())
	var complete := await _until(func(): return runner.state == MissionRunner.State.COMPLETE)
	var feed := await _until(func(): return _fired_who("feed", FEED))
	var adopted := await _until(func(): return _fired_has("orphans adopted by init"))
	var restored := await _until(func(): return _fired_who("auditor", RESTORED))
	var welcome := await _until(func(): return _fired_who("ai", WELCOME))
	_check("acceptance (the ending, STORY.md section 7): the fifth hit kills it (%s); every daemon it spawned drops at once, adopted by init and reaped (%d reaped, %d left, no kill credited: %d kills before, %d after), the ICE stands down (%d pieces left) and Black ICE withdraws (%s); the kill feed \"%s\"; the Auditor logs the adoption, then \"%s\"; your AI, after a beat, \"%s\"; the mission is complete" % [str(killed), stage.reaped_count, left, kills_at, runner.kills, pieces_left, str(black_gone), FEED, RESTORED, WELCOME], killed and reaped and stage.reaped_count >= 3 and left == 0 and pieces_left == 0 and black_gone and runner.kills == kills_at + 1 and feed and adopted and restored and welcome and complete, "killed %s reaped %s left %d pieces %d black %s feed %s adopted %s restored %s welcome %s complete %s" % [str(killed), str(reaped), left, pieces_left, str(black_gone), str(feed), str(adopted), str(restored), str(welcome), str(complete)])
	var once := _fired_count(RESTORED) == 1 and _fired_count(WELCOME) == 1 and _fired_count(WONT) == 1 and _fired_count(FEED) == 1
	_check("the ending plays exactly once: its lines each said once, and the shell down once (%d)" % _down_of("shell_1"), once and _down_of("shell_1") == 1)
	var end: MissionEndScreen = mh.end_screen()
	var card := await _until(func(): return end.is_up())
	_check("acceptance (win card): \"exit 0\" and COMPLETE come up after its hold, nothing handed (no chips, no handout ever told: %d), Credits the first choice, focused" % _handed, card and end.kind() == "complete" and _text_has(end.shown_text(), "exit 0") and _text_has(end.shown_text(), "COMPLETE") and not _text_has(end.shown_text(), "HANDED") and end.buttons()[0].visible and end.buttons()[0].text == MissionEndScreen.CREDITS and not end.buttons()[0].disabled and _handed == 0)
	# The hand-off to the credits: up once, no row of the roll in it, then the bare prompt, then the Missions screen.
	var credits: CreditsHandoff = mh.credits_screen()
	var opened := [0]
	runner.credits_wanted.connect(func() -> void: opened[0] += 1)
	end.choose("next")
	await _frames(2)
	var up: bool = credits.is_up() and not end.is_up()
	await _until(func(): return credits.shown_text().size() >= 4)
	var rows := credits.shown_text()
	var leak := PackedStringArray()
	for row in rows:
		for w in ROLL_ROWS:
			if row.contains(w):
				leak.append(row)
	var has_top := _text_has(rows, "$ top") and _text_has(rows, "init") and _text_has(rows, "PID")
	credits.skip()
	await _frames(2)
	var prompt: bool = credits.at_prompt() and _text_has(credits.shown_text(), ">_")
	old_id = main.get_instance_id()
	var reload_asked := await _until(func(): return MissionRunner.mounting() != "" or current_scene.get_instance_id() != old_id)
	_check("acceptance (the credits hand-off): Credits opens the hand-off once (%d), over the card: `$ top`, the table's head and init's row (PID 1, adopting orphans), no row of the roll (C44's) in it; a key moves it on to STORY.md's bare `>_` with a blinking cursor; then the Missions screen is asked for" % opened[0], opened[0] == 1 and up and has_top and leak.is_empty() and prompt and reload_asked, "opened %d up %s top %s leak [%s] prompt %s reload %s" % [opened[0], str(up), str(has_top), ", ".join(leak), str(prompt), str(reload_asked)])
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var menu = main.get_node("Hud").pause_menu()
	await _frames(20)
	var m := MissionProgress.current()
	var all_done := true
	for i in range(1, 8):
		all_done = all_done and m.is_done(MissionBook.at(i).id) if i == 7 else all_done
	_check("acceptance (the Missions screen after the finale): open over a fresh arena, mission 7 recorded as done (%s), nothing next up, the rest of the campaign as recorded" % str(m.is_done("kill_9")), menu.showing_missions() and m.is_done("kill_9") and m.next_up() == null if _every_done(m) else m.is_done("kill_9") and menu.showing_missions())
	# Replaying earlier missions still works: mission 1 begins from here.
	menu.close() if menu.has_method("close") else null
	await _frames(2)
	old_id = main.get_instance_id()
	var replay: bool = runner.begin(MissionBook.at(1))
	_check("acceptance (gating carries over): after the finale an earlier mission still starts (mission 1 begun: %s)" % str(replay), replay)
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	await _until(func(): return runner.state == MissionRunner.State.INTRO or runner.state == MissionRunner.State.RUNNING)
	_check("...and plays in its own district with its own loadout (mission 1's two as it starts, the rail handed back in it), the finale's thirteen not carried into it", runner.def != null and runner.def.id == "login" and runner.world != null and runner.world.ruins.id == "scheduler_breach" and runner.carried == MissionBook.at(1).loadout and runner.carried.size() < 13, "def %s ruins %s carried %s state %d" % [runner.def.id if runner.def != null else "-", runner.world.ruins.id if runner.world != null else "-", str(runner.carried), runner.state])
	var daemons := 0
	for n in _names:
		if not n.contains("black") and not n.contains("ice_"):
			daemons += 1
	_check("acceptance: its daemons were finite and its own: %d made of its waves' %d at most, each stood once (%d climbed out) and none ever back once down (%d down, every one of them for good), the arena's four never there" % [_names.size(), m7.daemons_total(), _back, _down], _names.size() <= m7.daemons_total() and daemons >= 12 and _back == daemons and _down >= daemons - 1 and not main.has_node("Arena/Targets/DummyA"), "names %d daemons %d back %d down %d" % [_names.size(), daemons, _back, _down])
	_check("the chain ran in STORY.md's order, every beat begun once: %s" % ", ".join(_began), _began == PackedStringArray(CHAIN))
	await _drop(main)


func _every_done(m: MissionProgress) -> bool:
	for def in MissionBook.campaign():
		if not m.is_done(def.id):
			return false
	return true


## Weapon `weapon` drawn and fired at `at` for `hold` frames (a shot leaves the player's view): true once the swap was
## over and fire was held.
func _shoot(player: Node3D, weapon: String, at: Vector3, hold: int = 6) -> bool:
	var slot := int(player.inventory.slot_of(weapon))
	if not player.select_slot(slot) and player.inventory.current != slot:
		return false
	var ready := await _until(func(): return not player.inventory.is_swapping() and player.inventory.current == slot)
	if not ready:
		return false
	for i in hold:
		_aim(player, at)
		player.drive_input(Vector2.ZERO, false, false, true)
		await physics_frame
	player.drive_input(Vector2.ZERO)
	await physics_frame
	return true


# --- The fail cards. ---

func _fail_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	MissionProgress.current().clear()
	runner.begin(MissionBook.at(7))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var mh: MissionHud = main.get_node("Hud").mission_hud()
	_fired.clear()
	runner.line_said.connect(func(who: String, text: String) -> void: _fired.append([who, text]))
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _play_until(main, func(): return runner.stage.standing().size() > 1, MOST_FRAMES, false)
	var first: Node3D = runner.stage.standing().filter(func(d): return d != runner.stage.boss)[0]
	runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	runner.life.damage(10000.0, first, Vector3.FORWARD)
	await _frames(2)
	var end := mh.end_screen()
	var card_up := await _until(func(): return end.is_up())
	var again := await _until(func(): return _fired_has("Again."))
	_check("acceptance (fail card): a death fails it, \"exit 137\" and why, Retry focused, your AI's line on it (\"It's still running. It'll keep running. Again.\"), the ending never played", runner.state == MissionRunner.State.FAILED and runner.reason.begins_with("derezzed") and card_up and end.kind() == "failed" and _text_has(end.shown_text(), "exit 137") and end.buttons()[0].text == "Retry" and again and not _fired_has(RESTORED) and not _fired_has(WELCOME), "state %d reason '%s' up %s kind %s again %s" % [runner.state, runner.reason, card_up, end.kind(), again])
	_check("its daemons stop coming once it has failed, and the shell is still up", runner.stage.stopped and runner.stage.boss != null and is_instance_valid(runner.stage.boss) and runner.stage.boss.is_alive())
	await _drop(main)
	MissionRunner.clear_pending()
	# Black ICE's touch in the last phase: a flatline, its own fail.
	main = await _arena()
	runner = MissionRunner.of(main)
	old_id = main.get_instance_id()
	runner.begin(MissionBook.at(7))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	mh = main.get_node("Hud").mission_hud()
	var player = main.get_node("Player")
	var world := runner.world
	var stage := runner.stage
	var ice := IceDirector.of(main)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	runner.life.shield(100000.0)
	var boss_up := await _until(func(): return stage.boss != null and is_instance_valid(stage.boss))
	var boss: Node3D = stage.boss
	player.global_position = world.point("plaza")
	await _play_until(main, func(): return runner.index >= 1, MOST_FRAMES, false)
	runner.life.shield(100000.0)
	boss.hit(10.0, boss.threat_point(), Vector3.FORWARD, "sigterm")
	await _play_until(main, func(): return runner.index >= 3, MOST_FRAMES * 2)
	runner.life.shield(100000.0)
	for i in 4:
		boss.hit(1000.0, boss.threat_point(), Vector3.FORWARD, "sigkill_rail")
		await _frames(4)
	var at_end := await _until(func(): return runner.index >= 5)
	var came := await _until(func(): return ice.black != null and is_instance_valid(ice.black))
	var black: BlackIce = ice.black if came else null
	var out_now := came and await _until(func(): return black.phase == BlackIce.Phase.OUT)
	var flat := false
	var end2 := mh.end_screen()
	if out_now:
		runner.life.combat.states[SoloLife.ME]["protect_left"] = 0.0
		player.global_position = black.global_position + Vector3(0, RuinsLayout.STAND_Y, 0.4)
		player.velocity = Vector3.ZERO
		flat = await _until(func(): return runner.state == MissionRunner.State.FAILED and end2.is_up())
	_check("acceptance (fail card): Black ICE's touch in the last phase flatlines the player: failed (\"%s\"), \"exit 137\", the shell still up and the ending never played" % runner.reason, boss_up and at_end and came and out_now and flat and runner.reason.contains("Black ICE") and end2.kind() == "failed" and _text_has(end2.shown_text(), "exit 137") and boss.is_alive() and not _fired_has(RESTORED), "boss %s at_end %s (index %d) came %s out %s flat %s reason '%s'" % [str(boss_up), str(at_end), runner.index, str(came), str(out_now), str(flat), runner.reason])
	await _drop(main)


func _watch(d: Node3D) -> void:
	var key := String(d.name)
	if _names.has(key):
		return
	_names.append(key)
	if d.has_signal("downed"):
		d.downed.connect(func(_x): _down += 1)
	if d.has_signal("respawned"):
		d.respawned.connect(func(_x): _back += 1)  # once a daemon as it climbs out; again only if it ever came back


## How many times the daemons of wave `id` went down (by their names).
func _down_of(id: String) -> int:
	var n := 0
	for name in _names:
		if name.contains("Mission_%s_" % id):
			n += 1
	return n if _down > 0 else 0


func _aim(player: Node3D, at: Vector3) -> void:
	var cam: Camera3D = player.get_node("Head/Camera")
	var to: Vector3 = at - cam.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.get_node("Head").rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## Frames until `condition` holds (at most `most`), shooting down as a sure shot would the daemons the objective running
## counts (never the shell: only the rail reaches it, and the test lands those itself); its last answer. With `shoot` off
## it only waits.
func _play_until(main: Node, condition: Callable, most: int = MOST_FRAMES, shoot: bool = true) -> bool:
	var runner := MissionRunner.of(main)
	var frames := 0
	while frames < most and not condition.call():
		if shoot and runner != null and runner.stage != null:
			var of: Array = runner.objective().get("of", [])
			for d in runner.stage.standing():
				if not d.is_alive() or not of.has(str(d.get_meta(&"wave", ""))) or d == runner.stage.boss:
					continue
				d.hit(1000.0, d.global_position + Vector3.UP, Vector3.FORWARD, "sigterm")
		await process_frame
		frames += 1
	return condition.call()


# --- Helpers. ---

func _arena() -> Node:
	MissionRunner.clear_pending()  # a mission queued by the last arena never begins in this one on its own
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


func _action(action: String) -> void:
	for pressed in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = pressed
		root.push_input(e)


## True when a line said so far contains `part`; by `who`; how many times a line was said.
func _fired_has(part: String) -> bool:
	for line in _fired:
		if str(line[1]).contains(part):
			return true
	return false


func _fired_who(who: String, text: String) -> bool:
	for line in _fired:
		if line[0] == who and line[1] == text:
			return true
	return false


func _fired_count(text: String) -> int:
	var n := 0
	for line in _fired:
		if str(line[1]) == text:
			n += 1
	return n


## True when a shot of `source` met one of the stage's daemons, `landed` or refused.
func _struck_has(source: String, landed: bool) -> bool:
	for s in _struck:
		if s[1] == source and s[2] == landed:
			return true
	return false


func _text_has(lines: PackedStringArray, text: String) -> bool:
	for line in lines:
		if line.contains(text):
			return true
	return false

extends SceneTree
## Headless test of live process enemies (W1, PRD 5.5: the process hunt). scripts/check.sh runs it as step 65, and any
## FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/proc_hunt_test.gd
##
## Fixtures are fake only: the mapping's tables are made up here, the demo table is the game's own, and the real layer is
## read from a fake process table under the test's own folder (fake names, made-up PIDs). Nothing of this machine is
## read, named or printed.
##
## The code: nothing of the hunt runs a program, signals or kills anything, opens a connection or a file; the reader opens
## only `stat` and `status`. The mapping: a pegged core a boss (one, the hottest, held while it runs warm), many children
## of one name a nest and its drones (capped), many threads a nest of thread drones, the rest daemons sized by memory, a Z
## a zombie, init, the game itself and the session's holder left out, every cap holding on a huge table. The demo table:
## the same every run for a seed, fake names only, a pegged core in its build. The arena: off by default; queued, it
## begins, parks the arena's own daemons, forks the plan's enemies in (labels name and PID only), makes no reader; a new
## process forks a new enemy (a drone out of its nest), an exited one derezzes on its own (no kill credited), a pegged
## core is a boss whose heat and size follow its CPU and which tells before every volley, a swarm tells before it dives;
## a kill is simulated (the process still in the table, its enemy back after RESPAWN_S); the caps hold. The visor over
## live enemies: each line to its real parent (its enemy, or a ring for its process, the session redacted), no line for a
## thread, the sever cosmetic. The real layer from the fake table, behind its gate, dropped when the gate closes. The Esc
## menu's entry. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const CoreArt = preload("res://scripts/daemons/pegged_core.gd")
const NestArt = preload("res://scripts/daemons/swarm_nest.gd")
const DroneArt = preload("res://scripts/daemons/tab_drone.gd")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")

## The hunt's code: none of it may run, signal, kill, send or open anything.
const HUNT_CODE := ["res://scripts/procs/proc_hunt.gd", "res://scripts/procs/proc_map.gd", "res://scripts/procs/demo_procs.gd", "res://scripts/procs/swarm_flock.gd", "res://scripts/procs/proc_hunt_hud.gd", "res://scripts/daemons/tab_drone.gd", "res://scripts/daemons/swarm_nest.gd", "res://scripts/daemons/pegged_core.gd"]
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "kill(", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "DirAccess", "get_file_as_string", "OS.get_environment", "get_executable_path", "\"/proc", "store_string", "store_buffer", "store_line", "store_var", "ResourceSaver", "set_priority", "renice", "OS.crash"]
const READER := "res://scripts/visor/proc_reader.gd"
const READER_NEVER := ["cmdline", "environ", "\"fd\"", "/fd", "cwd", "\"exe\"", "/exe", "maps", "OS.execute", "create_process", "execute_with_pipe", "OS.kill", "kill(", "shell_open", "FileAccess.WRITE", "FileAccess.READ_WRITE", "store_", "remove_absolute", "rename", "make_dir", "HTTP", "StreamPeer", "PacketPeer", "print(", "push_warning", "push_error", "get_environment"]
## Every name the demo table may use: made up, none of them this machine's.
const DEMO_NAMES := ["init", "session", "lumen", "nebula", "nebula-gpu", "nebula-tab", "quill", "quill-lsp", "tidesync", "chatter", "tickd", "soundd", "glass", "sh", "forge", "forge-cc", "forge-ld", "pkgcheck"]
const POISON := "POISON"
const MOST_FRAMES := 2400
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://proc-hunt-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	ProcHunt.clear()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_map_checks()
	_demo_checks()
	_fit_checks()
	await _arena_checks()
	await _fight_checks()
	await _visor_checks()
	await _real_checks()
	await _menu_checks()
	await _cleanup()
	print("PROC HUNT: %d checks" % _checks)
	print("PROC HUNT RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in HUNT_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): the hunt's code never runs a program, signals, kills, renices, sends, opens a file or a folder; an in-game kill reaches no signal, kill, OS.kill or execute path (%d files)" % HUNT_CODE.size(), found.is_empty(), ", ".join(found))
	var reader := _code_of(READER)
	var bad := PackedStringArray()
	for word in READER_NEVER:
		if reader.contains(word):
			bad.append(word)
	# The drones' own small volume (resize_volume) is the hunt's alone: the arena's and the missions' daemons keep theirs.
	var callers := PackedStringArray()
	_callers_of("res://scripts", "resize_volume(", callers)
	_check("a drone's own small hit volume is the hunt's alone: resize_volume is called only by the hunt (every other daemon's volume as it was)", callers == PackedStringArray(["res://scripts/procs/proc_hunt.gd"]), ", ".join(callers))
	_check("acceptance (safety): the reader opens only `stat` and `status` (its FILES), and names nothing else of a process's folder; it writes, prints and runs nothing", bad.is_empty() and reader.contains("const FILES := [STAT, STATUS]") and reader.contains("parse_threads"), ", ".join(bad))


## Every script under `dir` whose code calls `call` (its definition not counted).
func _callers_of(dir: String, call: String, out: PackedStringArray) -> void:
	for d in DirAccess.get_directories_at(dir):
		_callers_of(dir.path_join(d), call, out)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var code := _code_of(dir.path_join(f))
			if code.replace("func " + call, "").contains(call):
				out.append(dir.path_join(f))


## A script's code with its comments taken out (the words in its notes are not calls).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The mapping. ---

func _row(ppid: int, comm: String, cpu: float, mem_kb: int, state: String = "S", threads: int = 1) -> Dictionary:
	return {"ppid": ppid, "comm": comm, "state": state, "cpu": cpu, "mem_kb": mem_kb, "threads": threads}


func _table() -> Dictionary:
	var t := {}
	t[1] = _row(0, "faked-init", 0.1, 9000)
	t[100] = _row(1, "fake-session", 0.0, 5000)
	t[50] = _row(1, "fake-lone", 0.0, 2000)
	t[200] = _row(100, "fake-browser", 8.0, 400000, "R")
	for i in 6:
		t[210 + i] = _row(200, "fake-tab", 3.0, 90000)
	t[230] = _row(200, "fake-gpu", 9.0, 300000, "R")
	t[300] = _row(100, "fake-build", 12.0, 60000, "R")
	t[310] = _row(300, "fake-cc", 97.0, 200000, "R")
	t[311] = _row(300, "fake-cc", 93.0, 180000, "R")
	t[320] = _row(300, "fake-dead", 0.0, 0, "Z")
	t[400] = _row(100, "fake-sync", 1.0, 98000, "S", 30)
	t[500] = _row(100, "fake-small", 0.5, 4000)
	t[600] = _row(100, "fake-big", 2.0, 1200000)
	t[700] = _row(100, "fake-pair", 1.0, 30000)
	t[701] = _row(700, "fake-kid", 1.0, 20000)
	t[702] = _row(700, "fake-kid", 1.0, 20000)
	t[703] = _row(700, "fake-kid", 1.0, 20000)
	t[999] = _row(100, "fake-self", 50.0, 900000, "R")
	return t


func _map_checks() -> void:
	var t := _table()
	var plan := ProcMap.plan(t, {}, 999)
	var e: Dictionary = plan["enemies"]
	_check("the mapping: a pegged core is the boss, one only, the hottest (97%% over 93%%)", e.has("310") and e["310"]["role"] == "boss" and e.has("311") and e["311"]["role"] == "daemon" and _count(e, "boss") == 1, str(e.get("310", {})))
	_check("the mapping: a process with %d children of one name is a nest, each child a drone of its swarm; three of a name are not a swarm (daemons)" % ProcMap.SWARM_KIDS, e.has("200") and e["200"]["role"] == "nest" and _all_drones(e, [210, 211, 212, 213, 214, 215], "200") and e.has("230") and e["230"]["role"] == "daemon" and e.has("701") and e["701"]["role"] == "daemon" and e["700"]["role"] == "daemon")
	var threads := 0
	for k in e:
		if str(k).begins_with("400/"):
			threads += 1
	_check("the mapping: a process running %d threads or more is a nest of its threads, %d drones at most, each its process's name and PID" % [ProcMap.THREADS_MIN, ProcMap.THREAD_DRONES], e.has("400") and e["400"]["role"] == "nest" and threads == ProcMap.THREAD_DRONES and e["400/1"]["pid"] == 400 and e["400/1"]["comm"] == "fake-sync" and e["400/1"]["nest"] == "400")
	_check("the mapping: every other process a daemon sized by its memory, a Z a zombie; init, the game itself and the session's holder (the child of init with the most under it) left out", plan["session"] == 100 and not e.has("1") and not e.has("100") and not e.has("999") and e.has("320") and e["320"]["role"] == "zombie" and e.has("600") and e["600"]["role"] == "daemon" and e.has("50") and e.has("500"), str(plan["session"]))
	_check("a daemon's size grows with its memory and stays in its range (0.85 to 1.3); a small process one hit, a big one more", ProcMap.size_for(4000) == 0.85 and ProcMap.size_for(1200000) > ProcMap.size_for(98000) and ProcMap.size_for(1200000) <= 1.3 and ProcMap.size_for(99999999) == 1.3 and ProcMap.health_for(4000) == 1.0 and ProcMap.health_for(1200000) > ProcMap.health_for(98000))
	# Hysteresis: a boss stays one while it runs warm; a newcomer must peg.
	var warm := t.duplicate(true)
	warm[310]["cpu"] = 60.0
	warm[311]["cpu"] = 60.0
	var kept: Dictionary = ProcMap.plan(warm, {"310": "boss"}, 999)["enemies"]
	var cool := warm.duplicate(true)
	cool[310]["cpu"] = 40.0
	var dropped: Dictionary = ProcMap.plan(cool, {"310": "boss"}, 999)["enemies"]
	_check("a boss stays the boss while it runs at %d%% or more (60%%: still the boss, the other at 60%% a daemon), and cools back to a daemon below it (40%%)" % int(ProcMap.COOL_CPU), kept["310"]["role"] == "boss" and kept["311"]["role"] == "daemon" and dropped["310"]["role"] == "daemon" and _count(dropped, "boss") == 0)
	# The drones already up keep their places when the swarm is over its cap.
	var big := t.duplicate(true)
	for i in 20:
		big[800 + i] = _row(200, "fake-tab", 1.0, 50000)
	var prev := {"819": "drone", "818": "drone"}
	var capped: Dictionary = ProcMap.plan(big, prev, 999)["enemies"]
	_check("a swarm holds %d drones at most, those already up keeping their places" % ProcMap.DRONES_PER, _nest_drones(capped, "200") == ProcMap.DRONES_PER and capped.has("819") and capped.has("818"), str(_nest_drones(capped, "200")))
	# Every cap on a huge table.
	var huge := {1: _row(0, "faked-init", 0.0, 1000)}
	for i in 1000:
		var parent := 2 + (i % 40)
		huge[100 + i] = _row(parent if i >= 40 else 1, "fake-%d" % (i % 7), 95.0 if i % 97 == 0 else float(i % 30), 10000 + i * 300, "Z" if i % 50 == 0 else "R", 40 if i % 13 == 0 else 2)
	var all: Dictionary = ProcMap.plan(huge, {}, -1)["enemies"]
	var drones := _count(all, "drone")
	_check("acceptance: the caps hold on a table of 1000: at most %d enemies, %d drones, %d swarms, one boss, %d daemons" % [ProcMap.ENEMIES_MOST, ProcMap.DRONES_MOST, ProcMap.SWARMS_MOST, ProcMap.DAEMONS_MOST], all.size() <= ProcMap.ENEMIES_MOST and drones <= ProcMap.DRONES_MOST and _count(all, "nest") <= ProcMap.SWARMS_MOST and _count(all, "boss") <= 1 and _count(all, "daemon") + _count(all, "zombie") <= ProcMap.DAEMONS_MOST, "%d enemies, %d drones" % [all.size(), drones])


func _count(e: Dictionary, role: String) -> int:
	var n := 0
	for k in e:
		if e[k]["role"] == role:
			n += 1
	return n


func _all_drones(e: Dictionary, pids: Array, nest: String) -> bool:
	for p in pids:
		if not e.has(str(p)) or e[str(p)]["role"] != "drone" or e[str(p)]["nest"] != nest:
			return false
	return true


func _nest_drones(e: Dictionary, nest: String) -> int:
	var n := 0
	for k in e:
		if e[k]["role"] == "drone" and e[k]["nest"] == nest:
			n += 1
	return n


# --- The demo table. ---

func _demo_checks() -> void:
	var a := DemoProcs.new(4087)
	var b := DemoProcs.new(4087)
	a.advance(90)
	b.advance(90)
	var names := true
	var odd := ""
	var pegged := false
	var c := DemoProcs.new(4087)
	for i in 70:
		c.advance(1)
		for pid in c.snapshot:
			var comm := str(c.snapshot[pid]["comm"])
			if not DEMO_NAMES.has(comm):
				names = false
				odd = comm
			if float(c.snapshot[pid]["cpu"]) >= ProcMap.PEGGED_CPU:
				pegged = true
	_check("the demo table is the same every run for a seed (90 ticks on, two tables equal)", JSON.stringify(a.snapshot) == JSON.stringify(b.snapshot) and a.snapshot.size() > 15)
	_check("acceptance (privacy): the demo table's names are its own made-up ones only, never a real process of this machine's; and its build pegs a core", names and pegged, odd)


# --- C43's leftover: the real layer's labels hold through a refit. ---

func _fit_checks() -> void:
	var t := ProcTree.new(4087)
	var ids: Array[int] = []
	for i in 4:
		ids.append(t.add_daemon(null, "d%d" % i, "rogue", t.hidden))
	var snap := {1: {"ppid": 0, "comm": "fakeinit", "cpu": 0.0, "mem_kb": 1}, 10: {"ppid": 1, "comm": "fakesession", "cpu": 0.0, "mem_kb": 1}}
	for i in 8:
		snap[100 + i] = {"ppid": 10, "comm": "fake%d" % i, "cpu": float(i), "mem_kb": 1000}
	t.fit(snap)
	var first := {}
	for id in ids:
		first[id] = t.node(id).pid
	# The arena's count changes (a fifth daemon) and the numbers move: the refit keeps every label already up.
	ids.append(t.add_daemon(null, "d4", "rogue", t.hidden))
	for i in 8:
		snap[100 + i]["cpu"] = float(20 - i)
	t.fit(snap)
	var kept := true
	for id in first:
		kept = kept and t.node(id).pid == first[id] and t.node(id).real
	_check("C43's leftover folded in: a refit after the arena's count changed keeps every real label already up (no shuffle), the new node takes a free one", kept and t.node(ids[4]).real and not first.values().has(t.node(ids[4]).pid), str(first))


# --- The arena. ---

func _arena(queue_hunt: bool, practice: bool = true) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	if queue_hunt:
		ProcHunt.queue()
	else:
		ProcHunt.clear()
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
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").pause_menu().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	var player = main.get_node("Player")
	player.assume_captured = true
	player.velocity = Vector3.ZERO
	await _frames(3)
	return main


func _arena_checks() -> void:
	var made_before := ProcReader.made
	var reads_before := ProcReader.reads
	var plain := await _arena(false)
	var h0 := ProcHunt.of(plain)
	await _frames(20)
	_check("acceptance: off by default: the hunt stands in the arena, not running; the arena's own four daemons are its", h0 != null and not h0.running and h0.enemies().is_empty() and plain.get_tree().get_nodes_in_group("targets").size() == 4)
	var main := await _arena(true)
	var hunt := ProcHunt.of(main)
	var formed := await _until(func(): return hunt.running and not hunt.plan.is_empty() and hunt.enemies().size() >= (hunt.plan["enemies"] as Dictionary).size())
	var want: Dictionary = hunt.plan.get("enemies", {})
	var roles := {}
	for key in hunt.enemies():
		roles[hunt.enemies()[key]["role"]] = true
	var parked := true
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		parked = parked and main.get_node_or_null("Arena/Targets/" + name) == null
	_check("acceptance: queued (the Esc menu, or --procs), the hunt begins on the demo table: the arena's own daemons parked, the plan's %d enemies forked in (a nest, its drones, daemons)" % want.size(), formed and hunt.layer == "demo" and parked and roles.has("nest") and roles.has("drone") and roles.has("daemon"), "%d of %d, roles %s" % [hunt.enemies().size(), want.size(), roles.keys()])
	var labels := true
	var bad := ""
	for key in hunt.enemies():
		var body = hunt.enemies()[key]["body"]
		var spec: Dictionary = hunt.enemies()[key]["spec"]
		if body.tag_text != "%s %d" % [spec["comm"], spec["pid"]] or not DEMO_NAMES.has(str(spec["comm"])):
			labels = false
			bad = body.tag_text
	_check("acceptance: every label is its process's name and PID only, from the demo table", labels, bad)
	_check("acceptance (safety): on the demo table no reader is made and nothing of the machine is read", ProcReader.made == made_before and ProcReader.reads == reads_before)
	_check("its HUD: the panel's live top, the table named (demo), the kills marked simulated", hunt.hud() != null and hunt.hottest(6).size() > 0 and ProcHuntHud.DEMO == "demo table" and ProcHuntHud.NOTE.contains("simulated"))
	# The art: one type each, no two alike.
	var arts := {}
	var seeds := {}
	var nest_body: Node3D = null
	for key in hunt.enemies():
		var e: Dictionary = hunt.enemies()[key]
		var art = e["body"].art_node()
		arts[e["role"]] = art.get_script()
		if e["role"] == "drone":
			seeds[art.build_seed] = true
		if e["role"] == "nest" and nest_body == null:
			nest_body = e["body"]
	_check("the art: a nest is the nest, a drone the tab drone, a daemon rogue.d; no two drones the same build (%d drones, %d builds)" % [_role_count(hunt, "drone"), seeds.size()], arts.get("nest") == NestArt and arts.get("drone") == DroneArt and arts.get("daemon") == RogueArt and seeds.size() == _role_count(hunt, "drone"))
	# A fork: tabs open on the table's own clock; a drone comes out of its nest.
	var before := hunt.forks
	var drones_before := _role_count(hunt, "drone")
	var forked := false
	var fork_body: Node3D = null
	for i in 12:
		var keys_before := hunt.enemies().keys()
		hunt.advance_table(1)
		await _frames(30)
		for key in hunt.enemies():
			if not keys_before.has(key) and hunt.enemies()[key]["role"] == "drone":
				forked = true
				fork_body = hunt.enemies()[key]["body"]
		if forked:
			break
	var nest_at: Vector3 = nest_body.art_node().anchor() if nest_body != null and is_instance_valid(nest_body) else Vector3.INF
	_check("acceptance: a new process forks a new enemy in: a tab opened, a drone forked out of its nest (%d forks before, %d now)" % [before, hunt.forks], forked and hunt.forks > before and fork_body != null and is_instance_valid(fork_body), "%d drones before" % drones_before)
	# An exit: a tab closes; its drone derezzes on its own, nobody's kill.
	var exits_before := hunt.exits
	var kills_before := hunt.kills
	var gone_ok := false
	for i in 14:
		hunt.advance_table(1)
		await _frames(4)
		if hunt.exits > exits_before:
			gone_ok = true
			break
	await _frames(10)
	_check("acceptance: a process that exits derezzes on its own: its enemy reaped, no kill credited, no kill counted", gone_ok and hunt.kills == kills_before, "%d exits" % hunt.exits)
	_check("acceptance: the caps hold in the arena: at most %d enemies at once (%d), forks %s apart" % [ProcMap.ENEMIES_MOST, hunt.most_enemies, ProcHunt.FORK_GAP_S], hunt.most_enemies <= ProcMap.ENEMIES_MOST and hunt.most_enemies > 0)
	_check("nest at its spot in the air, clear of the floor", nest_at.is_finite() and nest_at.y > 1.8, str(nest_at))


func _role_count(hunt: ProcHunt, role: String) -> int:
	var n := 0
	for key in hunt.enemies():
		if hunt.enemies()[key]["role"] == role:
			n += 1
	return n


# --- The boss and the swarm fighting; a kill. ---

func _fight_checks() -> void:
	var main := await _arena(true, false)
	var hunt := ProcHunt.of(main)
	await _until(func(): return hunt.running and not hunt.plan.is_empty() and hunt.enemies().size() >= (hunt.plan["enemies"] as Dictionary).size())
	var player = main.get_node("Player")
	# The swarm alone with the player (every other enemy reaped for now: back in RESPAWN_S): it gathers (its tell) before
	# every dive.
	var flock: SwarmFlock = null
	for k in hunt.flocks():
		var f: SwarmFlock = hunt.flocks()[k]
		if f.nest != null and is_instance_valid(f.nest) and f.drones.size() >= 4 and (flock == null or f.drones.size() > flock.drones.size()):
			flock = f
	for key in hunt.enemies().keys():
		var b = hunt.body_of(key)
		if b != null and flock != null and b != flock.nest and not flock.drones.has(b):
			b.reap()
	if flock != null:
		player.global_position = Vector3(flock.centre.x, 0.95, flock.centre.z) + (Vector3.ZERO - Vector3(flock.centre.x, 0.0, flock.centre.z)).normalized() * 6.0
	var dived := await _until(func(): return flock != null and flock.dives >= 3)
	_check("acceptance: swarms move like a swarm and tell before they dive: gathered (%d tells), then dives one after another (%d), never more than %d a tell" % [flock.tells if flock else 0, flock.dives if flock else 0, SwarmFlock.DIVERS], flock != null and dived and flock.tells >= 1 and flock.dives <= flock.tells * SwarmFlock.DIVERS)
	var spread := 0.0
	if flock != null:
		for dr in flock.drones:
			spread = maxf(spread, dr.global_position.distance_to(flock.centre))
	_check("its drones fly as one cloud round their nest, never strung out across the arena (farthest %.1f m)" % spread, flock != null and spread > 0.5 and spread < 14.0)
	# The build's linker pegs a core.
	hunt.advance_table(DemoProcs.BUILD_FIRST + DemoProcs.LINK_AT + 3)
	var up := await _until(func(): return hunt.boss() != null and hunt.boss().is_alive())
	var boss := hunt.boss()
	var spec: Dictionary = {}
	for key in hunt.enemies():
		if hunt.enemies()[key]["role"] == "boss":
			spec = hunt.enemies()[key]["spec"]
	var banner: String = hunt.hud().banner() if hunt.hud() != null else ""
	_check("acceptance: a pegged core is a boss: the linker's process forked in as the pegged core, its banner up (\"%s\")" % banner, up and boss.art_node().get_script() == CoreArt and str(spec.get("comm", "")) == "forge-ld" and float(spec.get("cpu", 0.0)) >= ProcMap.PEGGED_CPU and banner.begins_with("PEGGED"))
	await _frames(240)
	var art = boss.art_node()
	var heat: float = art.heat
	var size: float = art.size_scale
	_check("the boss's heat and size follow its CPU (heat %.2f, size %.2f at %.0f%%)" % [heat, size, float(spec.get("cpu", 0.0))], heat > 0.7 and size > ProcHunt.BOSS_SIZE_COOL + 0.3)
	# The player in its sight: it tells before every volley.
	player.global_position = boss.global_position + Vector3(0.0, 0.0, 9.0)
	player.global_position.y = 0.95
	var shot := await _until(func(): return boss.brain.volleys >= 2)
	_check("acceptance: the boss is an event with a tell: it draws in and burns white before every volley (%d tells, %d volleys), never a volley without one" % [boss.brain.pegged_tells, boss.brain.volleys], shot and boss.brain.pegged_tells >= boss.brain.volleys and boss.brain.volleys >= 2)
	# A kill: simulated. The process stays in the table; its enemy forks back in after RESPAWN_S.
	var victim_key := ""
	for key in hunt.enemies():
		if hunt.enemies()[key]["role"] == "daemon" and hunt.enemies()[key]["body"].is_alive():
			victim_key = key
			break
	var victim = hunt.body_of(victim_key)
	var pid := int(hunt.enemies()[victim_key]["spec"]["pid"]) if victim_key != "" else -1
	var kills_before := hunt.kills
	if victim != null:
		victim.hit(10000.0)
	await _frames(5)
	var still := hunt.row(pid)
	_check("acceptance: killing one is cosmetic: its enemy derezzed and counted (\"simulated\"), its process still in the table, unchanged by it", victim != null and hunt.kills == kills_before + 1 and not still.is_empty() and hunt.body_of(victim_key) == null and _last_event(hunt).contains("simulated"), _last_event(hunt))
	var back := await _until(func(): return hunt.body_of(victim_key) != null)
	_check("while its process runs it forks back in after %.0f s" % ProcHunt.RESPAWN_S, back)
	# The linker exits: the boss derezzes on its own.
	var exits := hunt.exits
	hunt.advance_table(DemoProcs.LINK_PEG)
	var cooled := await _until(func(): return hunt.boss() == null)
	_check("acceptance: when its process exits the boss derezzes on its own, nobody's kill", cooled and hunt.exits > exits)


func _last_event(hunt: ProcHunt) -> String:
	for i in range(hunt.events.size() - 1, -1, -1):
		if hunt.events[i]["kind"] == "kill":
			return str(hunt.events[i]["text"])
	return ""


# --- The visor over live enemies. ---

func _visor_checks() -> void:
	var main := await _arena(true)
	var hunt := ProcHunt.of(main)
	await _until(func(): return hunt.running and not hunt.plan.is_empty() and hunt.enemies().size() >= (hunt.plan["enemies"] as Dictionary).size())
	var visor := AuditVisor.of(main)
	visor.set_on(true)
	await _frames(30)
	var tree := visor.tree
	var truth := true
	var why := ""
	var nodes := 0
	for id in tree.daemons():
		var n: ProcTree.ProcNode = tree.node(id)
		if not n.has_meta(&"proc") or n.down_s >= 0.0:
			continue
		nodes += 1
		var pid := int(n.get_meta(&"proc"))
		var ppid := hunt.ppid_of(pid)
		var shown := tree.ppid_text(id)
		var expect := "[REDACTED]" if ppid == hunt.session_pid else str(ppid)
		if ppid <= 1:
			expect = "1"
		if shown != expect or n.pid != pid:
			truth = false
			why = "%d: shown %s, table %s" % [pid, shown, expect]
	var threads := 0
	for key in hunt.enemies():
		if key.contains("/") and visor._by_body.has(hunt.enemies()[key]["body"].get_instance_id()):
			threads += 1
	_check("acceptance: the visor draws the real lineage over live enemies: every enemy's line to its parent in the table (its enemy, or a ring for its process), the session's holder redacted, every PPID shown the table's (%d nodes, %d rings)" % [nodes, visor._hunt_rings.size()], truth and nodes >= 8 and visor.lines().drawn_lines > nodes, why)
	_check("a thread drone is no process of its own: no node, no line", threads == 0)
	# The sever: a nest's death with the visor on burns down to its drones, reaped (cosmetic); they fork back in.
	var nest_key := ""
	for key in hunt.enemies():
		if hunt.enemies()[key]["role"] == "nest" and not key.contains("/") and _nest_has_children(hunt, key):
			nest_key = key
	var reaps_before := hunt.reaps
	var nest = hunt.body_of(nest_key)
	if nest != null:
		nest.hit(10000.0)
	var burnt := await _until(func(): return hunt.reaps > reaps_before)
	_check("acceptance: the free arena's sever applies in the hunt: a nest killed with the visor on, its drones reaped down its lines (%d), cosmetic, credited to nobody" % (hunt.reaps - reaps_before), nest != null and burnt and visor.severs > 0)


func _nest_has_children(hunt: ProcHunt, key: String) -> bool:
	for k in hunt.enemies():
		var spec: Dictionary = hunt.enemies()[k]["spec"]
		if spec["role"] == "drone" and spec["nest"] == key and not k.contains("/"):
			return true
	return false


# --- The real layer, from a fake table. ---

func _real_checks() -> void:
	var at := _fake_proc()
	var main := await _arena(false)
	var hunt := ProcHunt.of(main)
	var gate := [true]
	hunt.real_root = at
	hunt.real_gate = func(): return gate[0]
	var reads_before := ProcReader.reads
	hunt.begin()
	await _until(func(): return hunt.layer == "real" and hunt.enemies().size() >= 6)
	# The hog burns 200 ticks over the next scan's two seconds: a full core.
	_proc(at, 300, "fakehog", "R", 100, 210, 70000, 1)
	var formed := await _until(func(): return hunt.boss() != null)
	var roles := {}
	for key in hunt.enemies():
		roles[hunt.enemies()[key]["role"]] = true
	var reader := hunt.table as ProcReader
	var only := reader != null
	if reader != null:
		for path in reader.opened:
			only = only and (path.get_file() == "stat" or path.get_file() == "status") and path.begins_with(at)
	var poison := false
	for key in hunt.enemies():
		poison = poison or str(hunt.enemies()[key]["body"].tag_text).contains(POISON)
	_check("the real layer, behind its gate, from a fake table: the reader made, a nest of the fake browser's tabs, the pegged fake a boss, labels its short names", formed and roles.has("nest") and roles.has("drone") and roles.has("boss") and hunt.body_of("200") != null and hunt.body_of("200").tag_text == "fakebrowser 200", str(roles.keys()))
	_check("acceptance (safety): the real layer opened only `stat` and `status` in the fake table's numbered folders; nothing poisoned came through", only and not poison and ProcReader.reads > reads_before)
	gate[0] = false
	var dropped := await _until(func(): return hunt.layer == "demo")
	_check("the gate closing drops the reader and every value, back on the demo table", dropped and hunt.table is DemoProcs)


func _fake_proc() -> String:
	var at := _abs.path_join("fakeproc")
	DirAccess.make_dir_recursive_absolute(at)
	_proc(at, 1, "fakeinit", "S", 0, 100, 9000, 1)
	_proc(at, 2, "kthreadd", "S", 0, 0, -1, 1)
	_proc(at, 3, "kworker/0:0", "I", 2, 5, -1, 1)
	_proc(at, 100, "fakesession", "S", 1, 40, 5000, 1)
	_proc(at, 200, "fakebrowser", "R", 100, 300, 400000, 30)
	for i in 5:
		_proc(at, 201 + i, "faketab", "S", 200, 50, 90000, 3)
	_proc(at, 300, "fakehog", "R", 100, 10, 70000, 1)
	_proc(at, 301, "fakeidle", "S", 100, 0, 3000, 1)
	DirAccess.make_dir_recursive_absolute(at.path_join("self"))
	_put(at.path_join("self").path_join("stat"), POISON + "-SELF")
	return at


func _proc(at: String, pid: int, comm: String, state: String, ppid: int, ticks: int, rss: int, threads: int) -> void:
	var dir := at.path_join(str(pid))
	DirAccess.make_dir_recursive_absolute(dir)
	_put(dir.path_join("stat"), "%d (%s) %s %d %d %d 0 -1 4194304 100 0 0 0 %d %d 0 0 20 0 1 0 500 10000000 2500\n" % [pid, comm, state, ppid, pid, pid, ticks, 0])
	_put(dir.path_join("status"), "Name:\t%s\nState:\t%s\nPid:\t%d\nPPid:\t%d\n%sThreads:\t%d\n" % [comm, state, pid, ppid, ("VmRSS:\t   %d kB\n" % rss) if rss >= 0 else "", threads])
	for f in ["cmdline", "environ", "maps", "exe", "statm", "io", "comm"]:
		_put(dir.path_join(f), "%s-%s-%d" % [POISON, f.to_upper(), pid])
	for d in ["fd", "cwd", "task"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(d))
		_put(dir.path_join(d).path_join("0"), "%s-%s-%d" % [POISON, d.to_upper(), pid])


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


# --- The Esc menu. ---

func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.hunt_button()
	var plain_ok: bool = b != null and b.text == "Process hunt" and not b.disabled
	menu.close()
	var hunted := await _arena(true)
	await _until(func(): return ProcHunt.of(hunted).running)
	var menu2 = hunted.get_node("Hud").pause_menu()
	menu2.open()
	await _frames(2)
	var b2: Button = menu2.hunt_button()
	var leave_ok: bool = b2 != null and b2.text == "Leave process hunt"
	menu2.close()
	_check("acceptance: the Esc menu reaches it: \"Process hunt\" in the free arena, \"Leave process hunt\" while it runs", plain_ok and leave_ok)
	ProcHunt.clear()


# --- Helpers. ---

func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _cleanup() -> void:
	MissionRunner.clear_pending()
	ProcHunt.clear()
	for node in root.get_children():
		if node.scene_file_path == "res://scenes/main.tscn":
			await _drop(node)
	current_scene = null
	AuditVisor.remembered = false
	GameSettings.current().reset()
	MissionProgress.current().path = ""
	MissionProgress.current().clear()
	Progress.current().path = ""
	Progress.current().clear()
	_wipe(_abs)


## The test's own folder only, file by file.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://proc-hunt-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for d in dir.get_directories():
		_wipe(path.path_join(d))
	for f in dir.get_files():
		DirAccess.remove_absolute(path.path_join(f))
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

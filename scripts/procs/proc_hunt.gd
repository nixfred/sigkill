class_name ProcHunt
extends Node3D
## Live process enemies (W1, PRD 5.5; the first of M5's world features): the process hunt, a mode of the free arena where
## the arena's daemons are processes. Reached from the Esc menu ("Process hunt"; "Leave process hunt" ends it), or with
## --procs on a demo or test run. Made by the arena (scripts/main.gd) beside the directors; it begins when queued.
##
## Where its table comes from, two layers as the visor's (C43):
##   demo  the default, and the only layer the tests and captures use: a table the game makes up (scripts/procs/
##         demo_procs.gd), fake but believable, its numbers moving every second. Nothing of the machine is read.
##   real  opt-in, behind the same answer as the opener's real data and the visor's real layer (Settings, Privacy and AI,
##         "opener data", with real-machine data on, never on a demo run): the read-only reader (scripts/visor/
##         proc_reader.gd), which opens only each process's `stat` and `status` and reads only its PID, its parent's PID,
##         its short name, its state, its CPU ticks, its resident memory and its thread count, a slice a frame within the
##         budget C43 set. Kernel threads are left out. Off, no reader is made and nothing is read.
##
## The mapping is scripts/procs/proc_map.gd's: a pegged core a boss (scripts/daemons/pegged_core.gd, its size and heat its
## live CPU), a process with many children of one name (a browser's tabs) or many threads a nest (scripts/daemons/
## swarm_nest.gd) with a swarm of drones (scripts/daemons/tab_drone.gd), one a child or thread, flown as one by its flock
## (scripts/procs/swarm_flock.gd), every other process a daemon (rogue.d, a zombie for Z) sized by its memory, asleep
## while its process is idle. The arena follows the table: a new process forks a new enemy in (out of its parent where its
## parent stands, out of its nest for a drone), a process that exits derezzes on its own, one whose role changes (a core
## pegged, a boss cooled) is remade. Labels are name and PID only (the kernel's short name in the real layer, the made-up
## one in demo).
##
## Killing one is cosmetic: the enemy derezzes, and nothing real is ever signaled, stopped, reniced or touched; while its
## process still runs it forks back in after RESPAWN_S. The Audit Trail visor (I) draws the real lineage over the live
## enemies (scripts/visor/audit_visor.gd asks lineage_of()), and its free-arena sever applies here too (cosmetic).
##
## Caps: ProcMap's (at most 40 enemies, 24 drones, 12 daemons, one boss), and forks come in FORK_GAP_S apart. Alone only:
## never in a match, never in a mission. It writes, saves, logs, sends and runs nothing.

const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const DroneArt = preload("res://scripts/daemons/tab_drone.gd")
const NestArt = preload("res://scripts/daemons/swarm_nest.gd")
const CoreArt = preload("res://scripts/daemons/pegged_core.gd")

const GROUP := &"proc_hunt"
const NODE_NAME := "ProcHunt"
## The dev and test flag that begins it as the arena loads (with --demo, or under --script).
const FLAG := "--procs"
const LEVEL_MASK := 1
## A process killed in-game forks back in this long after, while it still runs.
const RESPAWN_S := 10.0
const FORK_GAP_S := 0.12
const GATE_EVERY_S := 2.0
## The spots: a grid this far apart over the floor, clear of the level by SPOT_CLEAR_M, never within PLAYER_CLEAR_M of
## the player's start; nests want NEST_CLEAR_M of air round them at NEST_LIFT_M over the floor.
const GRID_M := 3.5
const GRID_HALF := 5
const SPOT_CLEAR_M := 0.9
const PLAYER_CLEAR_M := 8.0
const NEST_CLEAR_M := 3.0
const NEST_LIFT_M := 2.3
## Nests hang no farther than this from the arena's middle (out of the corners, where walls hide them).
const NEST_REACH_M := 13.0
## A daemon forks in this far from its parent.
const FORK_OFF_M := 2.2
## Sizes and health: a drone's hit volume; a nest's and a boss's health; a boss's size cool and at a full core.
const DRONE_RADIUS := 0.5
const DRONE_HEIGHT := 1.0
## A drone's label shows within this many metres only.
const DRONE_TAG_M := 6.0
const NEST_HEALTH := 40.0
const BOSS_HEALTH := 400.0
const BOSS_SIZE_COOL := 1.35
const BOSS_SIZE_HOT := 2.1
## A sleeping daemon wakes when its process gets busy (CPU this or more) or the player comes this near.
const BUSY_CPU := 1.0
const WAKE_M := 7.0
## Climbs: a walker's out of the floor, a drone's and a nest's grown where they are, the boss's.
const CLIMB_S := 1.1
const DRONE_S := 0.45
const NEST_S := 1.0
const BOSS_S := 2.4
const EVENTS_KEPT := 6

## Queued for the next arena (the Esc menu, the flag); kept while it runs, so an R reload stays in it.
static var queued := false
static var _flag_taken := false

signal began
## It ended where it stood (a match starting).
signal ended
## An enemy forked in (the arena counts it as its own: a kill toward sudo, the top table).
signal spawned(dummy: Node3D)
## A line for its HUD: "fork", "exit", "kill", "reaped", "pegged".
signal event(kind: String, text: String)

var running := false
## Set by the arena.
var player: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
## The demo table's seed; the real table's root (a test hands in a fake one) and a gate the tests may set.
var demo_seed := 4087
var real_root := ProcReader.ROOT
var real_gate: Callable
## Its table now: a DemoProcs or a ProcReader, and which.
var table: RefCounted = null
var layer := "demo"
var snapshot := {}
var plan := {}
var session_pid := 0
## For the checks and the HUD.
var forks := 0
var exits := 0
var kills := 0
var reaps := 0
var remakes := 0
var tables := 0
var most_enemies := 0
var events: Array = []

var _enemies := {}
var _cooldown := {}
var _exiting := {}
var _queue: Array = []
var _queue_wait := 0.0
var _flocks := {}
var _nest_at := {}
var _spots: Array = []
var _nest_spots: Array = []
var _boss_home := Vector3.INF
var _spots_ready := false
var _clock := 0.0
var _gate_wait := 0.0
var _parked: Array = []
var _hud: CanvasLayer = null


static func of(node: Node) -> ProcHunt:
	if node == null or not node.is_inside_tree():
		return null
	for h in node.get_tree().get_nodes_in_group(GROUP):
		return h as ProcHunt
	return null


## The hunt as the next arena loads (the Esc menu reloads it).
static func queue() -> void:
	queued = true


static func clear() -> void:
	queued = false


## --procs (with --demo, or under --script): queued once a run.
static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queued = true


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


func _exit_tree() -> void:
	_drop_table()


## Begins the hunt: the arena's own daemons parked, ICE stood down, the rounds held, its table made. False online or in
## a mission.
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	running = true
	queued = true
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	_make_table(real_allowed())
	_hud = ProcHuntHud.new()
	_hud.hunt = self
	add_child(_hud)
	began.emit()
	return true


## True when the real layer is allowed: the visor's own gate (the opener's answer, real-machine data on, not a demo run).
func real_allowed() -> bool:
	if real_gate.is_valid():
		return bool(real_gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return AuditVisor.real_gate_for(link)


## Ends the hunt where it stands (a match starting): its enemies gone, its table dropped, the arena's own daemons back,
## ICE and the rounds as they were; not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	queued = false
	for key in _enemies.keys():
		var body = _enemies[key]["body"]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.queue_free()
	_enemies.clear()
	_queue.clear()
	_cooldown.clear()
	_flocks.clear()
	_drop_table()
	for entry in _parked:
		var dummy: Node3D = entry[0]
		if not is_instance_valid(dummy) or not is_instance_valid(entry[1]):
			continue
		dummy.reparent(entry[1])
		dummy.collision_layer = entry[2]
		dummy.visible = true
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		dummy.add_to_group("targets")
	_parked.clear()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	ended.emit()


func _make_table(real: bool) -> void:
	_drop_table()
	if real:
		table = ProcReader.new(real_root)
		layer = "real"
	else:
		table = DemoProcs.new(demo_seed)
		layer = "demo"
		snapshot = (table as DemoProcs).snapshot
		_apply()


func _drop_table() -> void:
	if table != null and table.has_method("drop"):
		table.drop()
	table = null
	snapshot = {}


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-hunt: the match's rules, the arena's own daemons back
		return
	_clock += delta
	if not _spots_ready:
		_find_spots()
	_gate_wait -= delta
	if _gate_wait <= 0.0:
		_gate_wait = GATE_EVERY_S
		var want := real_allowed()
		if want != (layer == "real"):
			_clear_enemies()
			_make_table(want)
	if table != null and table.step(delta):
		snapshot = table.snapshot
		_apply()
	_step_queue(delta)
	_step_live(delta)
	for key in _flocks:
		(_flocks[key] as SwarmFlock).step(delta, director)


# --- The table to the arena. ---

func _apply() -> void:
	tables += 1
	var prev := {}
	for key in _enemies:
		prev[key] = _enemies[key]["role"]
	plan = ProcMap.plan(snapshot, prev, OS.get_process_id())
	session_pid = int(plan.get("session", 0))
	var want: Dictionary = plan["enemies"]
	# Gone from the table, or its role changed: derezzed on its own (a role change forks it back in as its new self).
	for key in _enemies.keys():
		var e: Dictionary = _enemies[key]
		if not want.has(key):
			_exit(key, "exit")
		elif want[key]["role"] != e["role"]:
			remakes += 1
			_exit(key, "remake")
	for key in _cooldown.keys():
		if not want.has(key):
			_cooldown.erase(key)  # its process is gone: nothing to come back
	# Up already: their numbers.
	for key in _enemies:
		_enemies[key]["spec"] = want[key]
	# New: queued to fork in, the boss first, then nests, their drones, the daemons.
	var order := {"boss": 0, "nest": 1, "drone": 2, "daemon": 3, "zombie": 3}
	var fresh: Array = []
	for key in want:
		if not _enemies.has(key) and not _queued(key) and _clock >= float(_cooldown.get(key, -1.0)):
			fresh.append(key)
	fresh.sort_custom(func(a, b): return [order[want[a]["role"]], want[a]["pid"], a] < [order[want[b]["role"]], want[b]["pid"], b])
	for key in fresh:
		_queue.append(key)


func _queued(key: String) -> bool:
	return _queue.has(key)


func _step_queue(delta: float) -> void:
	_queue_wait -= delta
	while not _queue.is_empty() and _queue_wait <= 0.0 and _spots_ready:
		var key: String = _queue.pop_front()
		var want: Dictionary = plan.get("enemies", {})
		if not want.has(key) or _enemies.has(key):
			continue
		if _fork(key, want[key]) != null:
			_queue_wait = FORK_GAP_S


## Enemy `key` forks in as `spec` says. The new body, or null.
func _fork(key: String, spec: Dictionary) -> Node3D:
	var targets := _targets()
	if targets == null:
		return null
	var role: String = spec["role"]
	var dummy = DummyScene.instantiate()
	dummy.name = "Proc_%s" % key.replace("/", "_t")
	dummy.tag_text = "%s %d" % [spec["comm"], spec["pid"]]
	dummy.respawns = false
	match role:
		"boss":
			dummy.art = CoreArt
			dummy.max_health = BOSS_HEALTH
		"nest":
			dummy.art = NestArt
			dummy.max_health = NEST_HEALTH
		"drone":
			dummy.art = DroneArt
			dummy.max_health = 1.0
		"zombie":
			dummy.art = ZombieArt
			dummy.max_health = ProcMap.health_for(maxi(int(spec["mem_kb"]), 1))
		_:
			dummy.art = RogueArt
			dummy.max_health = ProcMap.health_for(int(spec["mem_kb"]))
	dummy.seed_wanted = _seed_for(key, role)
	dummy.set_meta(&"proc", key)
	dummy.set_meta(&"proc_pid", int(spec["pid"]))
	targets.add_child(dummy)
	var at := _place_for(key, spec)
	dummy.global_position = at
	if player != null and is_instance_valid(player):
		var to: Vector3 = player.global_position - at
		dummy.rotation.y = atan2(-to.x, -to.z)
	match role:
		"drone":
			dummy.resize_volume(DRONE_RADIUS, DRONE_HEIGHT)
			dummy.climb_depth_m = 0.0
			dummy.spawn_in(DRONE_S)
			# A swarm's labels never a wall of text: small, near only; a thread's none (its nest carries its name and PID).
			var tag := dummy.get_node("Tag") as Label3D
			tag.font_size = 30
			tag.visibility_range_end = DRONE_TAG_M
			if int(spec.get("thread", 0)) > 0:
				dummy.hide_tag(true)
			var flock := _flock_for(spec["nest"])
			flock.add(dummy)
			var nest = _body(spec["nest"])
			if nest != null and nest.art_node() != null and nest.art_node().has_method("fork_flash"):
				nest.art_node().fork_flash()
		"nest":
			dummy.climb_depth_m = 0.0
			dummy.spawn_in(NEST_S)
			_flock_for(key).nest = dummy
		"boss":
			dummy.resize_art(BOSS_SIZE_COOL)
			dummy.spawn_in(BOSS_S)
			_note("pegged", "PEGGED  %s %d  %.0f%% CPU" % [spec["comm"], spec["pid"], float(spec["cpu"])])
		_:
			dummy.resize_art(ProcMap.size_for(int(spec["mem_kb"])))
			dummy.spawn_in(CLIMB_S)
			if dummy.brain != null:
				dummy.brain.dormant = role == "daemon" and _idle(spec)
	dummy.downed.connect(_on_downed)
	dummy.gone.connect(_on_gone)
	_enemies[key] = {"body": dummy, "role": role, "spec": spec, "heat": 0.0}
	forks += 1
	most_enemies = maxi(most_enemies, _enemies.size())
	if role != "boss":
		_note("fork", "+ fork %d %s" % [spec["pid"], spec["comm"]])
	if director != null and is_instance_valid(director):
		director.forget_brains()
	spawned.emit(dummy)
	return dummy


## A build seed for enemy `key`: fixed by its key on demo and test runs (the same arena every run), else rolled; a drone,
## a nest and a boss never an elite (a drone stays one hit, the others are already what they are).
func _seed_for(key: String, role: String) -> int:
	var seed := (DaemonArt.seed_of("proc:" + key) if _fixed_seeds() else randi()) & DaemonArt.SEED_LAST
	if role == "drone" or role == "nest" or role == "boss":
		var guard := 0
		while DaemonArt.elite_of(seed) and guard < 64:
			seed = (seed + 7919) & DaemonArt.SEED_LAST
			guard += 1
	return seed


static func _fixed_seeds() -> bool:
	return OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script")


## Where enemy `key` forks in: a drone out of its nest, a nest at its spot in the air, the boss over the middle, a daemon
## beside its parent where its parent stands, else at a free spot.
func _place_for(key: String, spec: Dictionary) -> Vector3:
	match str(spec["role"]):
		"drone":
			var nest = _body(spec["nest"])
			if nest != null and nest.art_node() != null and nest.art_node().has_method("hub"):
				return nest.art_node().hub() - Vector3.UP * DRONE_HEIGHT * 0.5
			return _nest_point(spec["nest"]) + Vector3.UP * 0.9 - Vector3.UP * DRONE_HEIGHT * 0.5
		"nest":
			return _nest_point(key)
		"boss":
			return _boss_home
	var parent = _body(str(spec["ppid"]))
	if parent != null and is_instance_valid(parent) and parent.is_alive():
		var a := float(hash(key) % 628) / 100.0
		var at: Vector3 = _floor_at(Vector3(parent.global_position.x, 0.0, parent.global_position.z) + Vector3(cos(a), 0.0, sin(a)) * FORK_OFF_M)
		if _clear_at(at, SPOT_CLEAR_M):
			return at
	return _free_spot(key)


func _nest_point(key: String) -> Vector3:
	if _nest_at.has(key):
		return _nest_at[key]
	var used := _nest_at.values()
	var at: Vector3 = _nest_spots[0] if not _nest_spots.is_empty() else _boss_home
	for s in _nest_spots:
		if not used.has(s):
			at = s
			break
	_nest_at[key] = at
	return at


## A free spot for `key`: its own (by its key) if free, else the nearest free one to that.
func _free_spot(key: String) -> Vector3:
	if _spots.is_empty():
		return _boss_home
	var mine: Vector3 = _spots[hash(key) % _spots.size()]
	var best := mine
	var best_d := INF
	for s in _spots:
		if _taken(s):
			continue
		var d: float = s.distance_to(mine)
		if d < best_d:
			best_d = d
			best = s
	return best


func _taken(at: Vector3) -> bool:
	for key in _enemies:
		var b = _enemies[key]["body"]
		if is_instance_valid(b) and Vector2(b.global_position.x, b.global_position.z).distance_to(Vector2(at.x, at.z)) < 1.6:
			return true
	return false


## Enemy `key` goes: its process exited (or its role changed): it derezzes on its own, nobody's kill.
func _exit(key: String, why: String) -> void:
	var e: Dictionary = _enemies[key]
	var body = e["body"]
	_enemies.erase(key)
	_cooldown.erase(key)
	_forget_from_flocks(body)
	if is_instance_valid(body) and not body.is_queued_for_deletion():
		_exiting[body.get_instance_id()] = why
		if not body.reap():
			_exiting.erase(body.get_instance_id())
			body.queue_free()  # still climbing out: gone before it was whole
	if why == "exit":
		exits += 1
		var spec: Dictionary = e["spec"]
		_note("exit", "- exit %d %s" % [spec["pid"], spec["comm"]])
	if e["role"] == "nest" and _flocks.has(key):
		(_flocks[key] as SwarmFlock).nest = null


func _on_downed(body: Node3D) -> void:
	var iid := body.get_instance_id()
	var key := str(body.get_meta(&"proc", ""))
	_forget_from_flocks(body)
	if _exiting.has(iid):
		_exiting.erase(iid)
		return
	if not _enemies.has(key) or _enemies[key]["body"] != body:
		return
	var spec: Dictionary = _enemies[key]["spec"]
	_enemies.erase(key)
	_cooldown[key] = _clock + RESPAWN_S
	if body.get("credited") == false:
		reaps += 1
		_note("reaped", "~ reaped %d %s  (simulated)" % [spec["pid"], spec["comm"]])
	else:
		kills += 1
		_note("kill", "x kill -9 %d %s  (simulated)" % [spec["pid"], spec["comm"]])
	if spec["role"] == "nest" and _flocks.has(key):
		(_flocks[key] as SwarmFlock).nest = null


func _on_gone(body: Node3D) -> void:
	_exiting.erase(body.get_instance_id())
	_forget_from_flocks(body)


func _forget_from_flocks(body) -> void:
	if not is_instance_valid(body):
		return
	for k in _flocks:
		(_flocks[k] as SwarmFlock).remove(body)


func _flock_for(nest_key: String) -> SwarmFlock:
	if not _flocks.has(nest_key):
		var f := SwarmFlock.new(hash(nest_key) + demo_seed)
		f.centre = _nest_point(nest_key) + Vector3.UP * 0.9
		f.floor_y = _floor_y()
		_flocks[nest_key] = f
	return _flocks[nest_key]


# --- Every frame: the boss's heat and size, the nests' lights, the sleepers. ---

func _step_live(delta: float) -> void:
	var lit := {}
	for key in _enemies:
		var e: Dictionary = _enemies[key]
		var body = e["body"]
		if not is_instance_valid(body):
			continue
		var spec: Dictionary = e["spec"]
		match str(e["role"]):
			"boss":
				var goal := ProcMap.heat_for(float(spec["cpu"]))
				e["heat"] = move_toward(float(e["heat"]), goal, delta * 0.6)
				var art = body.art_node()
				if art != null:
					art.set("heat", e["heat"])
				body.resize_art(snappedf(lerpf(BOSS_SIZE_COOL, BOSS_SIZE_HOT, e["heat"]), 0.02))
			"drone":
				if body.is_alive():
					lit[spec["nest"]] = int(lit.get(spec["nest"], 0)) + 1
			"daemon":
				if body.brain != null and body.brain.dormant and body.is_alive():
					var near: bool = player != null and is_instance_valid(player) and player.global_position.distance_to(body.global_position) < WAKE_M
					if near or not _idle(spec):
						body.brain.dormant = false
	for key in _enemies:
		if _enemies[key]["role"] == "nest":
			var art = _enemies[key]["body"].art_node() if is_instance_valid(_enemies[key]["body"]) else null
			if art != null:
				art.set("lit", int(lit.get(key, 0)))


static func _idle(spec: Dictionary) -> bool:
	return float(spec.get("cpu", 0.0)) < BUSY_CPU and str(spec.get("state", "S")) != "R"


# --- Asked by the visor, the HUD and the checks. ---

## Every enemy up now: {key: {"body", "role", "spec"}}.
func enemies() -> Dictionary:
	return _enemies


func body_of(key: String) -> Node3D:
	return _body(key)


func _body(key: String):
	if not _enemies.has(key):
		return null
	var b = _enemies[key]["body"]
	return b if is_instance_valid(b) and not b.is_queued_for_deletion() else null


func flocks() -> Dictionary:
	return _flocks


func boss() -> Node3D:
	for key in _enemies:
		if _enemies[key]["role"] == "boss":
			return _body(key)
	return null


## A process's row in the table now ({} when it is not in it).
func row(pid: int) -> Dictionary:
	return snapshot.get(pid, {})


## The visor's question (C43 over W1): process `pid`'s parent's PID in the table, or -1 when it is not in it.
func ppid_of(pid: int) -> int:
	var p: Dictionary = snapshot.get(pid, {})
	return int(p["ppid"]) if not p.is_empty() else -1


## The enemy standing for process `pid` now (a thread drone stands for its process only through its nest), or null.
func enemy_for_pid(pid: int) -> Node3D:
	return _body(str(pid))


## How many processes the table holds.
func process_count() -> int:
	return snapshot.size()


## The hottest enemies now, for the HUD: [[pid, comm, cpu, role], ...], at most `most`.
func hottest(most: int) -> Array:
	var rows: Array = []
	var seen := {}
	for key in _enemies:
		var spec: Dictionary = _enemies[key]["spec"]
		if seen.has(spec["pid"]):
			continue
		seen[spec["pid"]] = true
		rows.append([int(spec["pid"]), str(spec["comm"]), float(spec["cpu"]), str(_enemies[key]["role"])])
	rows.sort_custom(func(a, b): return a[2] > b[2] or (a[2] == b[2] and a[0] < b[0]))
	return rows.slice(0, most)


## The demo table `ticks` on at once and the arena told (the checks and the captures jump to a moment of it).
func advance_table(ticks: int) -> void:
	if table is DemoProcs:
		(table as DemoProcs).advance(ticks)
		snapshot = table.snapshot
		_apply()


func hud() -> ProcHuntHud:
	return _hud as ProcHuntHud


func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > EVENTS_KEPT:
		events.pop_front()
	event.emit(kind, text)


func clock() -> float:
	return _clock


# --- The arena. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


## The arena's own daemons parked under the hunt (out of the targets, still, hidden, nothing colliding), as a mission does.
func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"proc"):
			dummy.remove_from_group("targets")
			_parked.append([dummy, dummy.get_parent(), dummy.collision_layer])
			dummy.process_mode = Node.PROCESS_MODE_DISABLED
			dummy.visible = false
			dummy.collision_layer = 0
			dummy.reparent(self)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	for driver in get_tree().get_nodes_in_group(&"code_rain_driver"):
		if driver.has_method("invalidate"):
			driver.invalidate()


func _clear_enemies() -> void:
	for key in _enemies.keys():
		_exit(key, "remake")
	_queue.clear()
	_cooldown.clear()


## The floor's spots, found once the level's bodies are in the physics world: a grid over the floor, each clear of the
## level, none near the player's start; the nests' spots with air round them; the boss's home nearest the middle.
func _find_spots() -> void:
	var host := get_parent() as Node3D
	var arena := host.get_node_or_null("Arena") as Node3D if host != null else null
	var middle: Vector3 = arena.global_position if arena != null else Vector3.ZERO
	var start: Vector3 = player.global_position if player != null and is_instance_valid(player) else Vector3.INF
	_spots.clear()
	_nest_spots.clear()
	for ix in range(-GRID_HALF, GRID_HALF + 1):
		for iz in range(-GRID_HALF, GRID_HALF + 1):
			var at := _floor_at(middle + Vector3(ix * GRID_M, 0.0, iz * GRID_M))
			if not at.is_finite() or (start.is_finite() and Vector2(at.x, at.z).distance_to(Vector2(start.x, start.z)) < PLAYER_CLEAR_M):
				continue
			if _clear_at(at, SPOT_CLEAR_M):
				_spots.append(at)
	if _spots.is_empty():
		return  # the level not in the physics world yet: look again next frame
	# The boss: the clear spot nearest the middle, with air for it.
	var best := INF
	for s in _spots:
		var d: float = Vector2(s.x - middle.x, s.z - middle.z).length()
		if d < best and _clear_at(s + Vector3.UP * 3.0, 2.5):
			best = d
			_boss_home = s
	if not _boss_home.is_finite():
		_boss_home = _spots[0]
	# Nests: spots with air round them, spread out (each the farthest from those already taken and the boss).
	var air: Array = []
	for s in _spots:
		if _clear_at(s + Vector3.UP * (NEST_LIFT_M + 0.9), NEST_CLEAR_M) and s.distance_to(_boss_home) > 7.0 and Vector2(s.x - middle.x, s.z - middle.z).length() <= NEST_REACH_M:
			air.append(s + Vector3.UP * NEST_LIFT_M)
	var picked: Array = [_boss_home]
	for i in ProcMap.SWARMS_MOST + 1:
		var far := -1.0
		var pick := Vector3.INF
		for a in air:
			var near := INF
			for p in picked:
				near = minf(near, Vector2(a.x - p.x, a.z - p.z).length())
			if near > far:
				far = near
				pick = a
		if not pick.is_finite():
			break
		_nest_spots.append(pick)
		picked.append(pick)
		air.erase(pick)
	_spots_ready = true


func _floor_at(at: Vector3) -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var from := Vector3(at.x, at.y + 6.0, at.z)
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 14.0, LEVEL_MASK))
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7 or (hit["position"] as Vector3).y > at.y + 1.0:
		return Vector3.INF
	return hit["position"]


func _floor_y() -> float:
	return _boss_home.y if _boss_home.is_finite() else 0.0


## True when a ball of `radius` at `at` (lifted to sit on the floor there) meets nothing of the level.
func _clear_at(at: Vector3, radius: float) -> bool:
	if not is_inside_tree() or not at.is_finite():
		return false
	var ball := SphereShape3D.new()
	ball.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = ball
	q.collision_mask = LEVEL_MASK
	q.transform = Transform3D(Basis.IDENTITY, at + Vector3.UP * (radius + 0.15))
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

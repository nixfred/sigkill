class_name AuditVisor
extends Node3D
## The Audit Trail visor (C43, PRD 5.5; a community prompt by Albert, @QuantaCortex, credited on its HUD): I (rebindable
## as "audit visor") turns it on and off. On, every daemon, zombie, runaway and boss in the arena carries its process
## (scripts/visor/proc_tree.gd: PID, parent's PID, name, state, CPU and memory), and a glowing line runs from each to its
## parent, up the tree to init (scripts/visor/visor_lines.gd), with small tags over them (scripts/hud/visor_hud.gd).
## Made by the arena (scripts/main.gd) beside the directors; it watches the arena's targets and its mission.
##
## Its lineage: in the free arena rogue.d is a daemon (its parent the hidden process that holds the session, PPID
## redacted), a zombie or <defunct> the unreaped child of the nearest rogue.d, a runaway forked by the nearest older
## runaway (a fork bomb's chain) or else by a rogue.d. In a mission a daemon the mission gives a parent (mission 2's,
## mission 3's cores, the finale's) hangs from it, and the rest from their wave's job. A daemon is forked once: its
## parent is fixed as it climbs out or comes back; one whose parent dies and is not severed is adopted by init. A sleeper
## is in the table too, state S (mission 2's own threads lead to its sleepers already; the visor's lines do no more).
##
## Severing (PRD 5.5): with the visor on, alone, in the free arena, a parent's death burns down its lines like a fuse,
## one line a FUSE_S, and each child the fuse reaches is reaped (no kill credited), its own children next, and the
## arena reshapes where each stood (scripts/visor/visor_collapse.gd). A protected node stops it, and it and everything
## under it hold, adopted by init: a sealed daemon, a rooted or flying boss. In a mission every daemon is protected
## from the visor's own sever (a sever would take daemons a kill objective counts, credited to nobody, and could starve
## a finite mission): a mission's severs are its own reaps (mission 2's parent, mission 3's cores and its loop, the
## finale's), each drawn as the same chain reaction. In a match the visor draws and never severs (the host's rules are
## the match's). Cosmetic and in-game only: nothing real is ever signaled, stopped or touched.
##
## Its real layer (opt-in, the opener's real-data answer, off by default): ProcReader (scripts/visor/proc_reader.gd)
## reads a sample of the machine's processes while the visor is on and the player has said yes, and ProcTree.fit() lays
## their labels over the same tree. Off, no reader is made and nothing is read.
##
## The process hunt (W1, scripts/procs/proc_hunt.gd): its enemies are processes already, so the visor draws their own
## lineage from the hunt's table (the demo's, or the real reader's under the same yes; the visor makes no reader of its
## own then): each enemy hangs from its real parent, that parent's enemy where one stands, else a ring for the parent
## process itself (a JOB node, its true PID and short name), and so up to the session's holder (redacted, as ever) and
## init. Parents are looked up again every frame, so every PPID shown is the table's; a thread drone is no process of its
## own and draws no line. Its numbers are the table's. The free arena's sever applies (cosmetic): a hunt's enemy
## reaped by a sever forks back in while its process runs.

const Privacy = preload("res://scripts/boot/guide_settings.gd")
const Dummy = preload("res://scripts/target_dummy.gd")

const GROUP := &"audit_visor"
const NODE_NAME := "AuditVisor"
## The dev and test flag that starts it on as every arena loads (with --demo, or under --script).
const FLAG := "--visor"
const CREDIT := "visor design: @QuantaCortex"
## The visor's colour in each register: amber over Tron's teal, ice white over the rain's violet, hot pink over the
## Matrix's green.
const HUE_TRON := Color(1.0, 0.52, 0.12)
const HUE_CYBER := Color(0.35, 0.9, 1.0)
const HUE_MATRIX := Color(1.0, 0.34, 0.74)
## Heights over the arena's middle (init's and the hidden parent's) and over a wave's first spawn (its job's), metres;
## how far apart two jobs stand at least.
const ROOT_LIFT_M := 16.0
const HIDDEN_LIFT_M := 11.0
const JOB_LIFT_M := 5.5
const JOB_APART_M := 4.0
## Half a line's width: the trunk (to init and the hidden parent), a job's, a daemon's.
const TRUNK_W := 0.1
const JOB_W := 0.075
const DAEMON_W := 0.055
## A fork's line growing in, a fuse along one line, its embers, a flash.
const FORK_S := 0.5
const FUSE_S := 0.42
const EMBER_S := 0.75
const FLASH_S := 0.6
## A runaway forks from an older one this near (a fork bomb's chain).
const SWARM_FORK_M := 8.0
## How far down a sever looks for the floor under what it took.
const FLOOR_LOOK_M := 40.0
const LEVEL_MASK := 1

## Every arena of a run starts as the last was left (an R reload keeps it), and on under the flag.
static var flag_on: bool = OS.get_cmdline_user_args().has(FLAG) and (OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script"))
static var remembered := false

signal toggled(on: bool)
## A sever began at a dead parent (its node in the tree): the children its fuse will reach.
signal severed(parent: int, count: int)

var on := false
## Set by the arena.
var player: Node3D = null
var runner: MissionRunner = null
var director: DaemonDirector = null
## The guide's HUD, for the real-data answer (its session link).
var guide: Node = null
## The table the real layer reads (a test hands in a fake one), and a gate the tests may set in place of the answer.
var real_root := ProcReader.ROOT
var real_gate: Callable
var tree: ProcTree
var real_reader: ProcReader = null
## For the checks.
var severs := 0
var reaped_by_sever := 0
var held := 0
var adopted := 0
var mission_reaps_drawn := 0
var most_lines := 0

var _by_body := {}
var _jobs := {}
var _fuses: Array = []
var _burn := {}
var _flash := {}
var _tags_off := {}
var _lines: VisorLines
var _collapse: VisorCollapse
var _clock := 0.0
var _fit_size := -1
## The process hunt's ancestor rings (W1): {pid: node id}.
var _hunt_rings := {}


static func of(node: Node) -> AuditVisor:
	if node == null or not node.is_inside_tree():
		return null
	for v in node.get_tree().get_nodes_in_group(GROUP):
		return v as AuditVisor
	return null


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)
	tree = ProcTree.new(_seed())
	_lines = VisorLines.new()
	add_child(_lines)
	_lines.set_hues(HUE_TRON, HUE_CYBER, HUE_MATRIX)
	_collapse = VisorCollapse.new()
	add_child(_collapse)
	_collapse.set_hues(HUE_TRON, HUE_CYBER, HUE_MATRIX)
	if flag_on or remembered:
		set_on(true)


func _exit_tree() -> void:
	if flag_on:
		print("audit visor: on (--visor): most lines %d, severs %d, reaped by sever %d, held %d, mission reaps drawn %d" % [most_lines, severs, reaped_by_sever, held, mission_reaps_drawn])
	if real_reader != null:
		real_reader.drop()
		real_reader = null


func _seed() -> int:
	return 4087 if Dummy.fixed_seeds else randi()


func toggle() -> void:
	set_on(not on)


func set_on(v: bool) -> void:
	if v == on:
		return
	on = v
	remembered = v
	if not on:
		_restore_tags()
		_lines.draw([], [])
		_drop_real()
	_threads_shown(not on)
	toggled.emit(on)


func lines() -> VisorLines:
	return _lines


func collapse() -> VisorCollapse:
	return _collapse


func _process(delta: float) -> void:
	_clock += delta
	tree.clock = _clock
	_sync()
	_step_fuses()
	_forget_done()
	_sync_hunt()
	_simulate()
	_step_real(delta)
	if on:
		_hide_tags()
		_threads_shown(false)
		_draw_world()


# --- The tree, kept in step with the arena. ---

func _sync() -> void:
	var stage := _stage()
	var fresh: Array = []
	for body in get_tree().get_nodes_in_group("targets"):
		if _is_daemon(body) and (body.is_alive() or body.climbing()) and not _by_body.has(body.get_instance_id()) and not _thread_drone(body):
			fresh.append(body)
	# Parents before children: the rooted and the flying first, then rogue.d, then the runaways, then the rest.
	fresh.sort_custom(func(a, b): return _rank(a) < _rank(b))
	for body in fresh:
		if not _by_body.has(body.get_instance_id()):
			_register(body, stage)
	for id in tree.daemons():
		var n: ProcTree.ProcNode = tree.node(id)
		if n.down_s >= 0.0:
			continue
		if n.body == null or not is_instance_valid(n.body) or n.body.is_queued_for_deletion() or not n.body.is_in_group("targets"):
			_by_body.erase(n.body_id)
			tree.remove(id)  # parked or freed without dying: gone from the table, its children adopted
	# The finale's threat is the hidden parent itself, once it stands.
	var h: ProcTree.ProcNode = tree.node(tree.hidden)
	if h.body != null and (not is_instance_valid(h.body) or h.body.is_queued_for_deletion()):
		h.body = null


static func _rank(body: Node) -> int:
	var kind := MissionRunner.kind_of(body)
	if kind == "shell" or kind == "parent" or kind == "core":
		return 0
	return 1 if kind == "rogue" else (2 if kind == "swarm" else 3)


## Node of a daemon the mission names as a parent, registered first if it stands and is not yet: -1 for none.
func _ensure(body: Node3D, stage: MissionStage) -> int:
	var iid := body.get_instance_id()
	if not _by_body.has(iid) and _is_daemon(body) and (body.is_alive() or body.climbing()):
		_register(body, stage)
	return _by_body.get(iid, -1)


static func _is_daemon(body: Node) -> bool:
	return body is StaticBody3D and not (body is IcePiece) and body.get_script() == Dummy


func _register(body: Node3D, stage: MissionStage) -> void:
	if stage != null and body == stage.boss:
		var h: ProcTree.ProcNode = tree.node(tree.hidden)
		h.body = body
		_by_body[body.get_instance_id()] = tree.hidden
		_listen(body)
		return
	var kind := MissionRunner.kind_of(body)
	var hunt := _hunt()
	var id := tree.add_daemon(body, str(body.tag_text), kind, _hunt_parent(hunt.ppid_of(int(body.get_meta(&"proc_pid", 0))), hunt, 0) if hunt != null and body.has_meta(&"proc") else _parent_for(body, kind, stage))
	var n: ProcTree.ProcNode = tree.node(id)
	if hunt != null and body.has_meta(&"proc"):
		_hunt_label(n, int(body.get_meta(&"proc_pid", 0)), hunt)
	var art = body.art_node()
	n.elite = art != null and art.elite
	n.protected = stage != null or body.sealed or body.sessile()
	n.at = _point_of(body)
	_by_body[body.get_instance_id()] = id
	_listen(body)


func _listen(body: Node3D) -> void:
	if not body.downed.is_connected(_on_down):
		body.downed.connect(_on_down)


func _parent_for(body: Node3D, kind: String, stage: MissionStage) -> int:
	if stage != null:
		var core = body.get_meta(&"core") if body.has_meta(&"core") else null
		if core != null and is_instance_valid(core) and core != body:
			if core == stage.boss:
				return tree.hidden
			var cid := _ensure(core, stage)
			if cid >= 0:
				return cid
		var p := stage.parent
		if p != null and is_instance_valid(p) and p != body and stage.children().has(body):
			if p == stage.boss:
				return tree.hidden
			var pid := _ensure(p, stage)
			if pid >= 0:
				return pid
		return _job_for(body)
	match kind:
		"rogue":
			return tree.hidden
		"swarm":
			var fork := _nearest(body, "swarm", SWARM_FORK_M)
			if fork >= 0:
				return fork
	var rogue := _nearest(body, "rogue", INF)
	return rogue if rogue >= 0 else tree.hidden


## The nearest living daemon node of `kind` within `reach` metres, forked before now; -1 for none.
func _nearest(body: Node3D, kind: String, reach: float) -> int:
	var best := -1
	var best_d := reach
	for id in tree.daemons():
		var n: ProcTree.ProcNode = tree.node(id)
		if n.daemon_kind != kind or n.down_s >= 0.0 or n.body == null or not is_instance_valid(n.body) or n.body == body:
			continue
		var d: float = n.body.global_position.distance_to(body.global_position)
		if d < best_d:
			best_d = d
			best = id
	return best


func _job_for(body: Node3D) -> int:
	var wave := str(body.get_meta(&"wave", ""))
	if _jobs.has(wave) and tree.has(_jobs[wave]):
		return _jobs[wave]
	var at := _floor_point(body.global_position + Vector3.UP * 0.5) + Vector3.UP * JOB_LIFT_M
	for turn in 12:
		var crowded := false
		for j in _jobs.values():
			if tree.has(j) and (tree.node(j).at as Vector3).distance_to(at) < JOB_APART_M:
				crowded = true
				break
		if not crowded:
			break
		at += Vector3(cos(turn * 2.4), 0.35, sin(turn * 2.4)) * JOB_APART_M * 0.6
	var id := tree.add_virtual(ProcTree.Kind.JOB, ProcTree.JOB_NAME, tree.hidden, at)
	_jobs[wave] = id
	return id


# --- Deaths: severs, adoptions, a mission's reaps. ---

func _on_down(body: Node3D) -> void:
	var iid := body.get_instance_id()
	if not _by_body.has(iid):
		return
	var id: int = _by_body[iid]
	_by_body.erase(iid)
	var n: ProcTree.ProcNode = tree.node(id)
	if n == null:
		return
	n.at = _point_of(body)
	n.set_meta(&"floor", _floor_point(body.global_position + Vector3.UP * 0.5))
	n.body = null
	n.down_s = _clock
	n.state = "X"
	n.cpu = 0.0
	if not _burn.has(id) and id != tree.hidden:
		_burn[id] = _clock
	if _stage() != null:
		_mission_cascade(id)
	elif n.get_meta(&"cascading", false) or _severs_now():
		_sever_from(id)
	elif n.has_meta(&"proc"):
		pass  # the hunt's (W1): its children hang from its process's ring now, looked up next frame
	else:
		_adopt_children(id)


## The visor's own sever (the free arena, on, alone): a fuse down every line to a child; each it reaches is reaped.
func _sever_from(id: int) -> void:
	var kids := tree.children_of(id)
	var count := 0
	for c in kids:
		var cn: ProcTree.ProcNode = tree.node(c)
		if cn.down_s >= 0.0:
			continue
		if cn.protected:
			_hold(c)
			continue
		_burn[c] = _clock
		_fuses.append({"node": c, "arrive": _clock + FUSE_S, "act": true})
		count += 1
	if count > 0:
		severs += 1
		var n: ProcTree.ProcNode = tree.node(id)
		_collapse.burst(n.get_meta(&"floor", n.at), 1.5, n.pid)
		severed.emit(id, count)


## A mission's own reap drawn: down its subtree, a job's line and a reaped daemon's burn a hop apart; a child still
## standing is adopted by init.
func _mission_cascade(id: int) -> void:
	var queue: Array = []
	for c in tree.children_of(id):
		queue.append([c, 1])
	var reaped := 0
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var c: int = item[0]
		var hop: int = item[1]
		var cn: ProcTree.ProcNode = tree.node(c)
		if cn == null:
			continue
		if cn.kind == ProcTree.Kind.DAEMON and cn.down_s < 0.0:
			_adopt(c)
			continue
		if cn.kind == ProcTree.Kind.DAEMON and cn.down_s < _clock:
			continue  # down before this reap: its own line burnt already
		var start := _clock + float(hop - 1) * FUSE_S
		_burn[c] = start
		if cn.kind == ProcTree.Kind.DAEMON:
			_fuses.append({"node": c, "arrive": start + FUSE_S, "act": false})
			reaped += 1
		for g in tree.children_of(c):
			queue.append([g, hop + 1])
	if reaped > 0 and on:  # off, a mission's reap is the mission's alone: nothing of the visor's is drawn
		mission_reaps_drawn += reaped
		var n: ProcTree.ProcNode = tree.node(id)
		_collapse.burst(n.get_meta(&"floor", n.at), 1.5, n.pid)


func _adopt_children(id: int) -> void:
	for c in tree.children_of(id):
		var cn: ProcTree.ProcNode = tree.node(c)
		if cn.down_s < 0.0 or cn.kind == ProcTree.Kind.JOB:
			_adopt(c)


func _adopt(id: int) -> void:
	tree.reparent(id, tree.root)
	tree.node(id).born_s = _clock - FORK_S  # the line is whole at once, swung to init
	_flash[id] = _clock
	adopted += 1


func _hold(id: int) -> void:
	_adopt(id)
	adopted -= 1
	held += 1


func _step_fuses() -> void:
	var keep: Array = []
	for f in _fuses:
		if f["arrive"] > _clock:
			keep.append(f)
			continue
		var cn: ProcTree.ProcNode = tree.node(f["node"])
		if cn == null:
			continue
		if on or f["act"]:  # a sever already running ends as it began; a mission's reap shows only with the visor on
			_collapse.burst(_floor_of(cn), 1.0, cn.pid)
			_spark(cn.at)
		if f["act"] and cn.body != null and is_instance_valid(cn.body) and cn.body.is_alive():
			cn.set_meta(&"cascading", true)
			if cn.body.reap():
				reaped_by_sever += 1
	_fuses = keep


## The floor under a node: where it fell, or under where it stands.
func _floor_of(n: ProcTree.ProcNode) -> Vector3:
	if n.has_meta(&"floor"):
		return n.get_meta(&"floor")
	if n.body != null and is_instance_valid(n.body):
		return _floor_point(n.body.global_position + Vector3.UP * 0.5)
	return _floor_point(n.at)


## Down nodes whose lines have burnt out leave the table (anything still under one is adopted by init).
func _forget_done() -> void:
	for id in tree.nodes.keys():
		var n: ProcTree.ProcNode = tree.node(id)
		if n == null or n.down_s < 0.0 or n.kind != ProcTree.Kind.DAEMON:
			continue
		var from: float = maxf(n.down_s, float(_burn.get(id, n.down_s)))
		if _clock - from > FUSE_S + EMBER_S + 0.1 and not _fuse_due(id):
			tree.remove(id)
			_burn.erase(id)
			_flash.erase(id)


func _fuse_due(id: int) -> bool:
	for f in _fuses:
		if f["node"] == id:
			return true
	return false


func _spark(at: Vector3) -> void:
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.blast(at, hue(), 2.2)


# --- Rules. ---

func _stage() -> MissionStage:
	if runner == null or not is_instance_valid(runner):
		return null
	var s = runner.stage
	return s if s != null and is_instance_valid(s) and not s.is_queued_for_deletion() else null


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


## True when a parent's death severs its subtree now: the visor on, alone, in the free arena.
func severs_now() -> bool:
	return _severs_now()


func _severs_now() -> bool:
	return on and _stage() == null and not _online()


# --- Its numbers (the demo layer). ---

func _simulate() -> void:
	for id in tree.nodes:
		var n: ProcTree.ProcNode = tree.node(id)
		if n.real or n.down_s >= 0.0 or n.has_meta(&"proc"):
			continue  # the hunt's nodes (W1) carry the table's own numbers
		var wave := 0.5 + 0.5 * sin(_clock * 0.9 + float(id) * 1.7)
		match n.kind:
			ProcTree.Kind.ROOT:
				n.state = "S"
				n.cpu = 0.1
				n.mem_kb = 11816
			ProcTree.Kind.HIDDEN:
				n.state = "S"
				n.cpu = 0.0
				n.mem_kb = 0
			ProcTree.Kind.JOB:
				n.state = "S"
				n.cpu = 0.0
				n.mem_kb = 3584 + (n.pid % 7) * 128
			_:
				_simulate_daemon(n, wave)


func _simulate_daemon(n: ProcTree.ProcNode, wave: float) -> void:
	var body = n.body
	var busy := 0.0
	if body != null and is_instance_valid(body) and body.brain != null:
		var s: int = body.brain.state
		busy = 1.0 if s == DaemonBrain.State.TELL or s == DaemonBrain.State.STRIKE else (0.5 if s == DaemonBrain.State.HUNT else 0.0)
	var big := 2.0 if n.elite else 1.0
	if body != null and is_instance_valid(body) and body.brain != null and body.brain.dormant and n.daemon_kind != "zombie":
		n.state = "S"  # asleep (mission 2's sleepers): in the table, doing nothing
		n.cpu = 0.0
		n.mem_kb = int(18432 * big)
		return
	match n.daemon_kind:
		"zombie":
			n.state = "Z"
			n.cpu = 0.0
			n.mem_kb = 0
			return
		"swarm":
			n.cpu = 71.0 + 27.0 * wave
			n.mem_kb = int((2048 + 3072 * wave) * big)
		"parent":
			n.cpu = 1.2 + 2.0 * wave
			n.mem_kb = 86016 + int(8192 * wave)
		"core":
			n.cpu = 99.0 + 0.9 * wave
			n.mem_kb = 1024
		"shell":
			n.cpu = 0.1
			n.mem_kb = 4096
		_:
			n.cpu = (9.0 + 16.0 * wave + 28.0 * busy) * (1.25 if n.elite else 1.0)
			n.mem_kb = int((18432 + 16384 * wave) * big)
	n.state = "R" if busy > 0.0 or n.daemon_kind == "core" or n.daemon_kind == "swarm" else "S"
	if body != null and is_instance_valid(body) and body.chmod_frozen():
		n.state = "T"  # stopped: chmod 000 holds it
		n.cpu = 0.0


# --- The real layer (opt-in). ---

## The real layer is on only with the player's yes: a session link that is not a demo run, real-machine data on and the
## opener's real data on (the same answer as the opener's, C39); off for no link at all.
static func real_gate_for(link) -> bool:
	if link == null or not is_instance_valid(link) or link.get("demo") != false:
		return false
	var path := str(link.get("settings_path"))
	return Privacy.real_data_on(path) and Privacy.opener_real_on(path)


func real_allowed() -> bool:
	if real_gate.is_valid():
		return bool(real_gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return real_gate_for(link)


func _step_real(delta: float) -> void:
	if not on or not real_allowed() or _hunt() != null:  # the hunt (W1) reads for both: one reader, C43's budget
		_drop_real()
		return
	if real_reader == null:
		real_reader = ProcReader.new(real_root)
	if real_reader.step(delta):
		if tree.nodes.size() != _fit_size:
			tree.fit(real_reader.snapshot)
			_fit_size = tree.nodes.size()
		else:
			tree.refresh_real(real_reader.snapshot)


func _drop_real() -> void:
	if real_reader == null:
		return
	real_reader.drop()
	real_reader = null
	tree.fit({})
	_fit_size = -1


## True when any label on the tree is the machine's own.
func showing_real() -> bool:
	for id in tree.nodes:
		if tree.node(id).real:
			return true
	return false


# --- Where things are. ---

func _center() -> Vector3:
	var world = runner.world if runner != null and is_instance_valid(runner) else null
	if world != null and is_instance_valid(world):
		return world.point("plaza") if world.has_point("plaza") else world.global_position
	var host := get_parent() as Node3D
	return host.global_position if host != null else Vector3.ZERO


func _point_of(body: Node3D) -> Vector3:
	var art = body.art_node()
	if art != null and art.has_method("anchor"):
		return art.anchor()
	var tag := body.get_node_or_null("Tag") as Node3D
	if tag != null:
		return tag.global_position + Vector3.DOWN * 0.3
	return body.global_position + Vector3.UP * 2.0


func _floor_point(from: Vector3) -> Vector3:
	if not is_inside_tree() or not from.is_finite():
		return from
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * FLOOR_LOOK_M, LEVEL_MASK))
	return hit["position"] if not hit.is_empty() else Vector3(from.x, _center().y, from.z)


## Where node `id` is drawn now.
func place(id: int) -> Vector3:
	var n: ProcTree.ProcNode = tree.node(id)
	if n == null:
		return Vector3.INF
	var mid := _center()
	match n.kind:
		ProcTree.Kind.ROOT:
			return mid + Vector3.UP * ROOT_LIFT_M
		ProcTree.Kind.HIDDEN:
			if n.body != null and is_instance_valid(n.body) and n.down_s < 0.0:
				n.at = _point_of(n.body)
				return n.at
			if n.down_s >= 0.0:
				return n.at
			return mid + Vector3.UP * HIDDEN_LIFT_M
		ProcTree.Kind.JOB:
			return n.at
	if n.down_s < 0.0 and n.body != null and is_instance_valid(n.body):
		n.at = _point_of(n.body)
	return n.at


## The visor's colour now: the register's, mixed as the place is.
func hue() -> Color:
	var mix := Vector4(1.0, 0.0, 0.0, 0.0)
	var world = runner.world if runner != null and is_instance_valid(runner) else null
	if world != null and is_instance_valid(world):
		mix = world.mix
	var w := Vector3(mix.x, mix.y, mix.z) + Vector3.ONE * (mix.w / 3.0)
	var sum := maxf(w.x + w.y + w.z, 0.0001)
	w /= sum
	return HUE_TRON * w.x + HUE_CYBER * w.y + HUE_MATRIX * w.z


# --- Drawing. ---

## The lines drawn now, child to parent: [{"child", "parent", "burn"}], for the checks and the HUD.
func edges() -> Array:
	var out: Array = []
	for id in tree.nodes:
		var n: ProcTree.ProcNode = tree.node(id)
		if id == tree.root or n.parent == -1 or not tree.has(n.parent):
			continue
		if n.kind == ProcTree.Kind.JOB and tree.children_of(id).is_empty() and not _burn.has(id):
			continue
		if n.kind == ProcTree.Kind.HIDDEN and n.down_s >= 0.0 and _clock - n.down_s > FUSE_S + EMBER_S:
			continue
		var burn := _burn_of(id)
		if burn > 2.0:
			continue
		out.append({"child": id, "parent": n.parent, "burn": burn})
	return out


func _burn_of(id: int) -> float:
	if not _burn.has(id):
		return 0.0
	var t: float = _clock - float(_burn[id])
	if t < 0.0:
		return 0.0
	return t / FUSE_S if t < FUSE_S else 1.0 + (t - FUSE_S) / EMBER_S


func _draw_world() -> void:
	var lines: Array = []
	var marks: Array = []
	var colour := hue()
	var deepest := 1
	for id in tree.nodes:
		deepest = maxi(deepest, tree.depth(id))
	for e in edges():
		var id: int = e["child"]
		var n: ProcTree.ProcNode = tree.node(id)
		var depth := tree.depth(id)
		var width := TRUNK_W if n.kind == ProcTree.Kind.HIDDEN else (JOB_W if n.kind == ProcTree.Kind.JOB else DAEMON_W * (1.3 if n.elite else 1.0))
		var heat := clampf(n.cpu / 100.0, 0.0, 1.0) if n.kind == ProcTree.Kind.DAEMON else 0.2
		var flash := _flash_of(id)
		lines.append({"a": place(id), "b": place(n.parent), "heat": heat, "width": width, "grown": clampf((_clock - n.born_s) / FORK_S, 0.0, 1.0), "phase": fposmod(float(id) * 0.6180339, 1.0), "burn": e["burn"], "bright": 1.0 + 1.5 * flash, "depth": float(depth) / float(deepest), "lift": 0.0})
	most_lines = maxi(most_lines, lines.size())
	for id in tree.nodes:
		var n: ProcTree.ProcNode = tree.node(id)
		var at := place(id)
		if not at.is_finite():
			continue
		var flash := _flash_of(id)
		match n.kind:
			ProcTree.Kind.ROOT:
				marks.append({"at": at, "size": 2.2, "kind": 0, "flash": 0.0, "color": colour, "alpha": 1.0})
			ProcTree.Kind.HIDDEN:
				if n.down_s < 0.0:
					var over := at + (Vector3.UP * 3.4 if n.body != null else Vector3.ZERO)
					marks.append({"at": over, "size": 2.6, "kind": 1, "flash": 0.0, "color": colour, "alpha": 1.0})
			ProcTree.Kind.JOB:
				if not tree.children_of(id).is_empty():
					marks.append({"at": at, "size": 1.25, "kind": 2, "flash": 0.0, "color": colour, "alpha": 1.0})
			_:
				if n.down_s < 0.0:
					marks.append({"at": at, "size": 0.45 if not n.elite else 0.6, "kind": 3, "flash": 0.0, "color": colour, "alpha": clampf((_clock - n.born_s) / FORK_S, 0.0, 1.0)})
		if flash > 0.0:
			marks.append({"at": at, "size": 3.0, "kind": 4, "flash": 1.0 - flash, "color": colour, "alpha": 1.0})
	_lines.draw(lines, marks)


func _flash_of(id: int) -> float:
	if not _flash.has(id):
		return 0.0
	var t: float = _clock - float(_flash[id])
	return clampf(1.0 - t / FLASH_S, 0.0, 1.0)


## What the HUD tags (scripts/hud/visor_hud.gd): every node drawn now, each {"id", "at", "kind", "pid", "name",
## "ppid", "state", "cpu", "mem_kb", "real", "elite", "down", "flash"}.
func tags() -> Array:
	var out: Array = []
	if not on:
		return out
	var drawn := {}
	for e in edges():
		drawn[e["child"]] = true
	drawn[tree.root] = true
	for id in drawn:
		var n: ProcTree.ProcNode = tree.node(id)
		if n == null:
			continue
		var at := place(id)
		if n.kind == ProcTree.Kind.HIDDEN and n.body != null:
			at += Vector3.UP * 3.4
		out.append({"id": id, "at": at, "kind": n.kind, "pid": n.pid_text(), "name": n.name, "ppid": tree.ppid_text(id), "state": n.state, "cpu": n.cpu, "mem_kb": n.mem_kb, "real": n.real, "elite": n.elite, "down": n.down_s >= 0.0, "flash": _flash_of(id)})
	return out


# --- What the visor hides while it is on. ---

func _hide_tags() -> void:
	for id in tree.daemons():
		var body = tree.node(id).body
		if body == null or not is_instance_valid(body):
			continue
		var tag := body.get_node_or_null("Tag") as Node3D
		if tag != null and tag.visible:
			tag.visible = false
			_tags_off[body.get_instance_id()] = body


func _restore_tags() -> void:
	for iid in _tags_off:
		var body = _tags_off[iid]
		if is_instance_valid(body) and not body.is_queued_for_deletion():
			body.hide_tag(body.tag_hidden)
	_tags_off.clear()


## Mission 2's threads give way to the visor's own lines while it is on.
func _threads_shown(shown: bool) -> void:
	var stage := _stage()
	if stage != null and stage.threads() != null and is_instance_valid(stage.threads()):
		stage.threads().visible = shown


# --- The process hunt (W1). ---

func _hunt() -> ProcHunt:
	var h := ProcHunt.of(self)
	return h if h != null and h.running else null


## A drone of a process's threads (its key "pid/n"): no process of its own, so no node and no line.
static func _thread_drone(body: Node) -> bool:
	return body.has_meta(&"proc") and str(body.get_meta(&"proc")).contains("/")


## The tree node a hunt's process `pid` hangs from: its parent's enemy where one stands, the session's holder (redacted),
## init, or a ring for the parent process itself, made on the way up.
func _hunt_parent(ppid: int, hunt: ProcHunt, depth: int) -> int:
	if ppid <= ProcTree.INIT_PID or depth > 8:
		return tree.root
	if ppid == hunt.session_pid:
		return tree.hidden
	var body := hunt.enemy_for_pid(ppid)
	if body != null and _by_body.has(body.get_instance_id()):
		return _by_body[body.get_instance_id()]
	var row := hunt.row(ppid)
	if row.is_empty():
		return tree.root
	if _hunt_rings.has(ppid) and tree.has(_hunt_rings[ppid]):
		return _hunt_rings[ppid]
	var up := _hunt_parent(int(row.get("ppid", 0)), hunt, depth + 1)
	var id := tree.add_virtual(ProcTree.Kind.JOB, str(row.get("comm", "?")), up, place(up) + Vector3.DOWN * 3.0)
	var n: ProcTree.ProcNode = tree.node(id)
	_hunt_label(n, ppid, hunt)
	n.set_meta(&"ring", true)
	_hunt_rings[ppid] = id
	return id


## A hunt's node labelled from the table: its PID and name the table's, its numbers too.
func _hunt_label(n: ProcTree.ProcNode, pid: int, hunt: ProcHunt) -> void:
	var row := hunt.row(pid)
	n.pid = pid
	n.demo_pid = pid
	n.set_meta(&"proc", pid)
	n.real = hunt.layer == "real"
	if not row.is_empty():
		n.name = str(row.get("comm", n.name))
		n.demo_name = n.name
		n.cpu = float(row.get("cpu", 0.0))
		n.mem_kb = int(row.get("mem_kb", 0))
		n.state = str(row.get("state", "S"))


## Every frame in the hunt: each enemy's parent looked up again (the table's truth), numbers refreshed, rings placed over
## what hangs from them, rings with nothing under them or gone from the table let go.
func _sync_hunt() -> void:
	var hunt := _hunt()
	if hunt == null:
		if not _hunt_rings.is_empty():
			for pid in _hunt_rings:
				tree.remove(_hunt_rings[pid])
			_hunt_rings.clear()
		return
	for id in tree.daemons():
		var n: ProcTree.ProcNode = tree.node(id)
		if n == null or not n.has_meta(&"proc") or n.down_s >= 0.0 or _burn.has(id):
			continue
		var pid := int(n.get_meta(&"proc"))
		var want := _hunt_parent(hunt.ppid_of(pid), hunt, 0)
		if want != n.parent and tree.has(want):
			tree.reparent(id, want)
		_hunt_label(n, pid, hunt)
	for pid in _hunt_rings.keys():
		var id: int = _hunt_rings[pid]
		if not tree.has(id):
			_hunt_rings.erase(pid)
			continue
		var n: ProcTree.ProcNode = tree.node(id)
		var kids := tree.children_of(id)
		if kids.is_empty() or hunt.row(pid).is_empty() or hunt.enemy_for_pid(pid) != null:
			tree.remove(id)
			_hunt_rings.erase(pid)
			continue
		_hunt_label(n, pid, hunt)
	# The rings over what hangs from them, the deepest first so a ring above another sits over it.
	var order := _hunt_rings.values()
	order.sort_custom(func(a, b): return tree.depth(a) > tree.depth(b))
	for id in order:
		var sum := Vector3.ZERO
		var count := 0
		for c in tree.children_of(id):
			var at := place(c)
			if at.is_finite():
				sum += at
				count += 1
		if count > 0:
			var n: ProcTree.ProcNode = tree.node(id)
			var mid := sum / float(count)
			n.at = Vector3(mid.x, minf(mid.y + JOB_LIFT_M * 0.7, _center().y + HIDDEN_LIFT_M - 1.5), mid.z)

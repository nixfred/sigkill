class_name ProcTree
extends RefCounted
## The Audit Trail visor's process tree (C43, PRD 5.5; the visor's design is Albert's, @QuantaCortex): every daemon,
## zombie, runaway and boss in the arena as a process, with a PID, a parent's PID, a short name, a state letter and
## CPU and memory numbers, hung in a believable spawn tree up to init, PID 1. Pure data: nodes in, lineage out. The
## visor (scripts/visor/audit_visor.gd) keeps it in step with the arena and draws it.
##
## The demo layer (the default, and the only one the tests and captures use): every number is the game's own. PIDs
## count up from a seeded start with small seeded gaps, as forks do; a tag that carries a PID of its own (mission 2's
## parent, "<parent> 4087") keeps it. CPU and memory come from what each daemon is and does (DaemonSim below): a zombie
## holds no CPU and no memory (Z), a runaway pegs a core, a sleeper sleeps (S), a frozen one is stopped (T).
##
## The tree's shape (STORY.md): above every daemon, below init, stands the process that holds the player's session,
## and its PID is redacted: only root may read it (mission 4's beat; the Auditor's own "[REDACTED]"). The visor never
## prints who it is or its number. In a mission each wave is a job, a subshell `sh` that forked it, hung from that
## hidden parent; a daemon the mission itself gives a parent (mission 2's, mission 3's cores, the finale's) hangs from
## that parent instead.
##
## The real layer (opt-in, scripts/visor/proc_reader.gd): fit() lays a sample of the machine's own processes over the
## same shape, labels only: the tree's shape never changes, so real data never changes what a sever takes. A node is
## given a real process only where that process's real parent is the one already on its tree parent, so every PPID
## shown is true; a node the machine cannot fit keeps its demo label. The hidden parent stays redacted either way.
##
## Severing (sever_plan()): a dead parent's subtree, breadth first, each node with its hops from the parent; a
## protected node stops the sever: it and everything under it hold, adopted by init. Nothing here touches a process,
## real or simulated: it is a table of numbers.

enum Kind { ROOT, HIDDEN, JOB, DAEMON }

const INIT_PID := 1
const INIT_NAME := "init"
const REDACTED := "[REDACTED]"
const JOB_NAME := "sh"
## Where a run's PIDs start, and the most a fork skips.
const PID_FIRST := Vector2i(3100, 3900)
const PID_GAP_MOST := 9
## The PIDs a tag may carry as its own: three digits or more.
const TAG_PID := "(\\d{3,7})\\s*$"

class ProcNode:
	var id := 0
	var kind := Kind.DAEMON
	var pid := 0
	var redacted := false
	var name := ""
	var state := "R"
	var cpu := 0.0
	var mem_kb := 0
	var parent := -1
	## The daemon (a TargetDummy) for a DAEMON; null for the rest; its instance id, kept for after it is freed.
	var body: Node3D = null
	var body_id := 0
	## Where it is drawn now (world space): a virtual node's place; a daemon's last point.
	var at := Vector3.ZERO
	var protected := false
	## The tree's clock when it was forked (the line grows in), and when it went down (-1 alive).
	var born_s := 0.0
	var down_s := -1.0
	## From the real layer (fit()), and the demo label it had before.
	var real := false
	var demo_pid := 0
	var demo_name := ""
	## The kind of daemon it is ("rogue", "zombie", "swarm", "parent", "core", "shell") and whether an elite.
	var daemon_kind := ""
	var elite := false

	func pid_text() -> String:
		return REDACTED if redacted else str(pid)


var nodes := {}
var root := -1
var hidden := -1
var clock := 0.0
var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _next_pid := 0
var _tag_pid := RegEx.new()


func _init(seed: int = 0) -> void:
	_rng.seed = hash(seed) & 0x7fffffff
	_next_pid = _rng.randi_range(PID_FIRST.x, PID_FIRST.y)
	_tag_pid.compile(TAG_PID)
	root = add_virtual(Kind.ROOT, INIT_NAME, -1, Vector3.ZERO)
	nodes[root].pid = INIT_PID
	hidden = add_virtual(Kind.HIDDEN, "?", root, Vector3.ZERO)
	nodes[hidden].redacted = true


## The next PID a fork takes: up from the last by a small seeded gap.
func next_pid() -> int:
	_next_pid += _rng.randi_range(1, PID_GAP_MOST)
	return _next_pid


func add_virtual(kind: Kind, name: String, parent: int, at: Vector3) -> int:
	var n := ProcNode.new()
	n.id = _next_id
	_next_id += 1
	n.kind = kind
	n.name = name
	n.parent = parent
	n.at = at
	n.state = "S"
	n.born_s = clock
	n.protected = true  # a virtual node is never a daemon: nothing kills it
	if kind == Kind.JOB:
		n.pid = next_pid()
	n.demo_pid = n.pid
	n.demo_name = name
	nodes[n.id] = n
	return n.id


## A daemon forked under `parent`: its name from its tag (a tag's own PID kept), the next PID otherwise.
func add_daemon(body: Node3D, tag: String, daemon_kind: String, parent: int) -> int:
	var n := ProcNode.new()
	n.id = _next_id
	_next_id += 1
	n.kind = Kind.DAEMON
	n.body = body
	n.body_id = body.get_instance_id() if body != null else 0
	n.daemon_kind = daemon_kind
	n.parent = parent if nodes.has(parent) else hidden
	n.born_s = clock
	var found := _tag_pid.search(tag)
	if found != null:
		n.pid = int(found.get_string(1))
		n.name = tag.substr(0, found.get_start()).strip_edges()
	else:
		n.pid = next_pid()
		n.name = tag.strip_edges()
	if n.name == "":
		n.name = daemon_kind
	n.demo_pid = n.pid
	n.demo_name = n.name
	nodes[n.id] = n
	return n.id


func node(id: int) -> ProcNode:
	return nodes.get(id)


func has(id: int) -> bool:
	return nodes.has(id)


func remove(id: int) -> void:
	if id == root or id == hidden or not nodes.has(id):
		return
	for c in children_of(id):
		nodes[c].parent = root  # orphans: init adopts them
	nodes.erase(id)


func reparent(id: int, parent: int) -> void:
	if nodes.has(id) and nodes.has(parent) and id != parent and not is_ancestor(id, parent):
		nodes[id].parent = parent


## True when `a` is `b` or above it.
func is_ancestor(a: int, b: int) -> bool:
	var at := b
	var guard := 0
	while at != -1 and guard < 4096:
		if at == a:
			return true
		at = nodes[at].parent if nodes.has(at) else -1
		guard += 1
	return false


func children_of(id: int) -> Array[int]:
	var out: Array[int] = []
	for k in nodes:
		if nodes[k].parent == id:
			out.append(k)
	out.sort()
	return out


## Its hops from init (init 0).
func depth(id: int) -> int:
	var d := 0
	var at: int = nodes[id].parent if nodes.has(id) else -1
	while at != -1 and d < 4096:
		d += 1
		at = nodes[at].parent if nodes.has(at) else -1
	return d


## The parent's PID as a tag shows it ("" for init's).
func ppid_text(id: int) -> String:
	var n: ProcNode = nodes.get(id)
	if n == null or n.parent == -1 or not nodes.has(n.parent):
		return "0" if n != null and n.kind == Kind.ROOT else ""
	return nodes[n.parent].pid_text()


## A dead parent's sever, breadth first: {"take": [[id, hops], ...] every node it takes, "hold": [id, ...] each
## protected node it stopped at (it and its own subtree hold, adopted by init)}.
func sever_plan(id: int) -> Dictionary:
	var take: Array = []
	var hold: Array = []
	var queue: Array = []
	for c in children_of(id):
		queue.append([c, 1])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var c: int = item[0]
		if nodes[c].protected:
			hold.append(c)
			continue
		take.append(item)
		for g in children_of(c):
			queue.append([g, item[1] + 1])
	return {"take": take, "hold": hold}


## Every daemon node, in id order.
func daemons() -> Array[int]:
	var out: Array[int] = []
	for k in nodes:
		if nodes[k].kind == Kind.DAEMON:
			out.append(k)
	out.sort()
	return out


## Every node by kind.
func of_kind(kind: Kind) -> Array[int]:
	var out: Array[int] = []
	for k in nodes:
		if nodes[k].kind == kind:
			out.append(k)
	out.sort()
	return out


# --- The real layer's fit. ---

## Lays a snapshot of real processes ({pid: {"ppid", "comm", "state", "cpu", "mem_kb"}}, scripts/visor/proc_reader.gd)
## over the tree, top down: init takes PID 1; the hidden parent the real child of PID 1 with the most below it (its
## label stays redacted); every other node an unused real child of its tree parent's process, the busiest first and a
## parent with children of its own for a node with children. A node with no fit keeps its demo label, and so does
## everything under it. Labels only: the shape stays. Returns how many nodes carry a real label.
func fit(snapshot: Dictionary) -> int:
	for k in nodes:
		_demo_label(nodes[k])
	if snapshot.is_empty() or not snapshot.has(INIT_PID):
		return 0
	var kids := {}
	var below := {}
	for pid in snapshot:
		var pp := int(snapshot[pid].get("ppid", 0))
		if not kids.has(pp):
			kids[pp] = []
		kids[pp].append(pid)
	for pid in snapshot:
		below[pid] = (kids.get(pid, []) as Array).size()
	var used := {}
	var count := 0
	_real_label(nodes[root], INIT_PID, snapshot[INIT_PID])
	used[INIT_PID] = true
	count += 1
	var queue: Array = [root]
	while not queue.is_empty():
		var id: int = queue.pop_front()
		var n: ProcNode = nodes[id]
		var mine := children_of(id)
		if not n.real:
			continue  # an unfitted node's children keep their demo labels
		# The children with children of their own pick first, and take the real children with the most below them.
		mine.sort_custom(func(a, b): return children_of(a).size() > children_of(b).size())
		var options: Array = (kids.get(real_pid(n), []) as Array).filter(func(p): return not used.has(p))
		options.sort_custom(func(a, b): return [below[a], float(snapshot[a].get("cpu", 0.0))] > [below[b], float(snapshot[b].get("cpu", 0.0))])
		for c in mine:
			if options.is_empty():
				break
			var want := children_of(c).size()
			var pick: int = options[0]
			for p in options:
				if below[p] >= want:
					pick = p
					break
			options.erase(pick)
			used[pick] = true
			_real_label(nodes[c], pick, snapshot[pick])
			count += 1
			queue.append(c)
	return count


## The real PID behind a fitted node (the hidden parent's is kept, never shown); its own PID otherwise.
static func real_pid(n: ProcNode) -> int:
	return int(n.get_meta(&"real_pid", 0)) if n.redacted else n.pid


## Real numbers on the nodes already fitted (a refresh): CPU, memory and state; a process gone keeps its last.
func refresh_real(snapshot: Dictionary) -> void:
	for k in nodes:
		var n: ProcNode = nodes[k]
		var pid := real_pid(n)
		if n.real and snapshot.has(pid):
			n.cpu = float(snapshot[pid].get("cpu", n.cpu))
			n.mem_kb = int(snapshot[pid].get("mem_kb", n.mem_kb))
			n.state = str(snapshot[pid].get("state", n.state))


func _real_label(n: ProcNode, pid: int, p: Dictionary) -> void:
	n.real = true
	if n.redacted:
		n.set_meta(&"real_pid", pid)  # kept for the fit, never shown
	else:
		n.pid = pid
		n.name = str(p.get("comm", n.name))
	n.cpu = float(p.get("cpu", 0.0))
	n.mem_kb = int(p.get("mem_kb", 0))
	n.state = str(p.get("state", n.state))


func _demo_label(n: ProcNode) -> void:
	n.real = false
	n.pid = n.demo_pid
	n.name = n.demo_name
	if n.has_meta(&"real_pid"):
		n.remove_meta(&"real_pid")

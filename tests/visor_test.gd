extends SceneTree
## Headless test of the Audit Trail visor (C43, PRD 5.5; the visor's design is Albert's, @QuantaCortex). scripts/check.sh
## runs it as step 63 (with the seven mission tests run again with the visor on, --visor), and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/visor_test.gd
##
## The code: nothing of the visor runs a program, signals or kills anything, opens a connection or reads the machine,
## but its reader; and the reader opens only `stat` and `status` in a process's folder, reading only (never the command
## line, environment, open files, working folder, executable or memory map), and never signals. The tree: PIDs, the
## redacted parent, a tag's own PID, a sever's plan (the subtree breadth first, a protected node holding with what is
## under it), the real layer's fit (labels only, the shape kept, every PPID shown true). The reader against a fake
## process table under the test's own folder: what it reads, what it leaves out (kernel threads, the poison files),
## CPU from two scans. The gate: the real layer only with the opener's yes, on a run that is not a demo. The arena: off
## by default with zero reads; I turns it on and off; its lines are the simulated tree; its tags never a wall of text,
## its credit; a sever burns down exactly the subtree and nothing else, a chain a hop at a time, a protected node holds;
## off, the orphans are adopted. The real layer drawn from the fake table, dropped as the visor goes off. A mission with
## the visor on: every daemon protected, no sever of the visor's own, the mission's own reap drawn as the chain. Black
## ICE's fail card says "flatlined by Black ICE". Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const DummyScene = preload("res://scenes/target_dummy.tscn")
const SwarmArt = preload("res://scripts/daemons/runaway_swarm.gd")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")

## The visor's code that runs in the arena: none of it may read, run, signal or send anything.
const VISOR_CODE := ["res://scripts/visor/audit_visor.gd", "res://scripts/visor/proc_tree.gd", "res://scripts/visor/visor_lines.gd", "res://scripts/visor/visor_collapse.gd", "res://scripts/hud/visor_hud.gd"]
const READER := "res://scripts/visor/proc_reader.gd"
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "kill(", "shell_open", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "FileAccess", "DirAccess", "get_file_as_string", "OS.get_environment", "get_user_data_dir", "get_executable_path", "/proc", "store_string", "store_buffer", "store_line", "store_var", "ResourceSaver"]
## What the reader must never name in its code, and never open.
const READER_NEVER := ["cmdline", "environ", "\"fd\"", "/fd", "cwd", "\"exe\"", "/exe", "maps", "OS.execute", "create_process", "execute_with_pipe", "OS.kill", "kill(", "shell_open", "FileAccess.WRITE", "FileAccess.READ_WRITE", "store_", "remove_absolute", "rename", "make_dir", "HTTP", "StreamPeer", "PacketPeer", "print(", "push_warning", "push_error", "get_environment"]
const POISON := "POISON"
const MOST_FRAMES := 1800
const LONG_ROUND_S := 100000.0

var _fails := 0
var _checks := 0
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://visor-test-%d" % OS.get_process_id())
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
	AuditVisor.remembered = false
	_code_checks()
	_tree_checks()
	_reader_checks()
	_gate_checks()
	await _arena_checks()
	await _real_checks()
	await _mission_checks()
	await _card_checks()
	await _cleanup()
	print("AUDIT VISOR: %d checks" % _checks)
	print("AUDIT VISOR RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in VISOR_CODE:
		var code := _code_of(path)
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): the visor's code reads nothing, runs nothing, signals or kills nothing, sends nothing: severing is drawn, never sent; only its reader reads", found.is_empty(), ", ".join(found))
	var reader := _code_of(READER)
	var bad := PackedStringArray()
	for word in READER_NEVER:
		if reader.contains(word):
			bad.append(word)
	_check("acceptance (safety): the reader's code names only `stat` and `status` and opens them only to read: never cmdline, environ, fd, cwd, exe or maps, never a write, never a signal, never a print", bad.is_empty() and ProcReader.FILES == ["stat", "status"] and reader.count("FileAccess.open(") == 1 and reader.contains("FileAccess.READ)") and reader.count("DirAccess.open(") == 1, ", ".join(bad))
	var visor_key := Controls.default_bind("audit_visor")
	var clashes := Controls.conflicts(_default_binds())
	_check("acceptance: the visor's key is I, free (no other action, no fixed key), rebindable as \"audit visor\", never a Ctrl or Alt chord", visor_key == "key:%d" % KEY_I and not clashes.has("audit_visor") and _shown("audit_visor") == "audit visor", "%s %s" % [visor_key, clashes])
	var water := FileAccess.get_file_as_string("res://shaders/ruins_water.gdshader")
	_check("M6 leftover: the drowned city's lamp streaks sit at each lamp's mirror point (h / (h + eye) of the way from its foot), not from its foot", water.contains("far * h / (h + eye)") and not water.contains("smoothstep(0.0, 0.12, share)"))


func _default_binds() -> Dictionary:
	var out := {}
	for pair in Controls.REBINDABLE:
		out[pair[0]] = Controls.default_bind(pair[0])
	return out


func _shown(action: String) -> String:
	for pair in Controls.REBINDABLE:
		if pair[0] == action:
			return pair[1]
	return ""


## A script's code without its comments (its words may name what it never does).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The tree. ---

func _tree_checks() -> void:
	var t := ProcTree.new(4087)
	var init: ProcTree.ProcNode = t.node(t.root)
	var hidden: ProcTree.ProcNode = t.node(t.hidden)
	_check("the tree: init is PID 1 at its root; under it the process that holds the session, its PID redacted (STORY.md: only root may read it), its name never shown", init.pid == 1 and init.name == "init" and t.ppid_text(t.root) == "0" and hidden.parent == t.root and hidden.pid_text() == "[REDACTED]" and t.ppid_text(t.hidden) == "1" and not hidden.name.contains("~"))
	var a := t.add_daemon(null, "rogue.d", "rogue", t.hidden)
	var b := t.add_daemon(null, "zombie", "zombie", a)
	var c := t.add_daemon(null, "runaway", "swarm", a)
	var parent := t.add_daemon(null, "<parent> 4087", "parent", t.hidden)
	var core := t.add_daemon(null, "cpu0", "core", t.hidden)
	var pa: int = t.node(a).pid
	var pb: int = t.node(b).pid
	var pc: int = t.node(c).pid
	_check("PIDs count up from a seeded start with small gaps, as forks do; the children's PPID is their parent's PID; the hidden parent's children show it redacted", pa >= ProcTree.PID_FIRST.x and pb > pa and pb - pa <= ProcTree.PID_GAP_MOST and pc > pb and t.ppid_text(b) == str(pa) and t.ppid_text(a) == "[REDACTED]")
	_check("a tag's own PID is kept (mission 2's \"<parent> 4087\"), its name without it; a short number is a name (mission 3's cpu0)", t.node(parent).pid == 4087 and t.node(parent).name == "<parent>" and t.node(core).name == "cpu0" and t.node(core).pid > 1000)
	# A sever's plan: hidden > A > {B, C(protected) > {E}, D > {F > {G}}}; X under hidden elsewhere.
	var s := ProcTree.new(1)
	var sa := s.add_daemon(null, "rogue.d", "rogue", s.hidden)
	var sb := s.add_daemon(null, "zombie", "zombie", sa)
	var sc := s.add_daemon(null, "sealed", "zombie", sa)
	s.node(sc).protected = true
	var se := s.add_daemon(null, "runaway", "swarm", sc)
	var sd := s.add_daemon(null, "runaway", "swarm", sa)
	var sf := s.add_daemon(null, "runaway", "swarm", sd)
	var sg := s.add_daemon(null, "runaway", "swarm", sf)
	var sx := s.add_daemon(null, "rogue.d", "rogue", s.hidden)
	var plan := s.sever_plan(sa)
	var taken := {}
	for item in plan["take"]:
		taken[item[0]] = item[1]
	_check("a sever's plan is exactly the dead parent's subtree, breadth first with each node's hops (B and D one, F two, G three); a protected node stops it (C holds, and E under it), and nothing outside it is touched (X)", taken.keys().size() == 4 and taken.get(sb) == 1 and taken.get(sd) == 1 and taken.get(sf) == 2 and taken.get(sg) == 3 and not taken.has(sc) and not taken.has(se) and not taken.has(sx) and plan["hold"] == [sc], str(plan))
	s.remove(sd)
	_check("a node gone leaves its children to init: orphans are adopted, PPID 1", s.node(sf).parent == s.root and s.ppid_text(sf) == "1")
	# The real layer's fit: labels only, the shape kept, every PPID shown true.
	var r := ProcTree.new(2)
	var job := r.add_virtual(ProcTree.Kind.JOB, "sh", r.hidden, Vector3.ZERO)
	var d1 := r.add_daemon(null, "rogue.d", "rogue", job)
	var d2 := r.add_daemon(null, "zombie", "zombie", d1)
	var d3 := r.add_daemon(null, "zombie", "zombie", d1)
	var d4 := r.add_daemon(null, "runaway", "swarm", job)
	var lone := r.add_daemon(null, "rogue.d", "rogue", r.hidden)
	var shape := _shape(r)
	var snap := {1: {"ppid": 0, "comm": "fakeinit", "state": "S", "cpu": 0.1, "mem_kb": 9000}, 100: {"ppid": 1, "comm": "fakesession", "state": "S", "cpu": 0.0, "mem_kb": 5000}, 200: {"ppid": 100, "comm": "fakeshell", "state": "S", "cpu": 0.5, "mem_kb": 4000}, 300: {"ppid": 200, "comm": "fakebrowser", "state": "R", "cpu": 30.0, "mem_kb": 400000}, 301: {"ppid": 300, "comm": "faketab", "state": "S", "cpu": 3.0, "mem_kb": 90000}, 302: {"ppid": 300, "comm": "faketab", "state": "S", "cpu": 2.0, "mem_kb": 80000}, 400: {"ppid": 200, "comm": "fakeeditor", "state": "S", "cpu": 1.0, "mem_kb": 70000}}
	var fitted := r.fit(snap)
	var truthful := true
	for id in r.nodes:
		var n: ProcTree.ProcNode = r.node(id)
		if n.real and n.parent != -1 and r.node(n.parent).real:
			var real_parent := ProcTree.real_pid(r.node(n.parent))
			truthful = truthful and int(snap[ProcTree.real_pid(n)]["ppid"]) == real_parent
	_check("the real layer's fit lays real processes over the same tree (labels only, the shape kept): init takes PID 1, the hidden parent stays redacted, a parent with children takes a real parent with children, and every real PPID shown is its tree parent's real PID", fitted == 7 and _shape(r) == shape and r.node(r.root).name == "fakeinit" and r.node(r.hidden).pid_text() == "[REDACTED]" and r.node(job).name == "fakeshell" and r.node(d1).name == "fakebrowser" and r.node(d2).name == "faketab" and r.node(d3).name == "faketab" and r.node(d4).name == "fakeeditor" and truthful, "fitted %d %s" % [fitted, _names(r)])
	_check("a node the machine cannot fit keeps its demo label (the lone rogue.d: the session's process has no child left), and the fit's undoing puts every demo label back", not r.node(lone).real and r.node(lone).name == "rogue.d" and r.fit({}) == 0 and r.node(d1).name == "rogue.d" and r.node(r.root).name == "init" and r.node(d1).pid == r.node(d1).demo_pid)


func _shape(t: ProcTree) -> Dictionary:
	var out := {}
	for id in t.nodes:
		out[id] = t.node(id).parent
	return out


func _names(t: ProcTree) -> String:
	var out := PackedStringArray()
	for id in t.nodes:
		out.append("%d:%s" % [id, t.node(id).name])
	return " ".join(out)


# --- The reader, against a fake table. ---

func _fake_proc() -> String:
	var at := _abs.path_join("fakeproc")
	DirAccess.make_dir_recursive_absolute(at)
	_proc(at, 1, "fakeinit", "S", 0, 100, 9000)
	_proc(at, 2, "kthreadd", "S", 0, 0, -1)
	_proc(at, 3, "kworker/0:0", "I", 2, 5, -1)
	_proc(at, 100, "fakesession", "S", 1, 40, 5000)
	_proc(at, 200, "fakebrowser", "R", 100, 300, 400000)
	_proc(at, 201, "faketab", "S", 200, 50, 90000)
	_proc(at, 202, "faketab", "S", 200, 20, 80000)
	_proc(at, 203, "faketab", "R", 200, 10, 70000)
	_proc(at, 300, "fake(odd) name)", "S", 1, 0, 1234)
	DirAccess.make_dir_recursive_absolute(at.path_join("self"))
	_put(at.path_join("self").path_join("stat"), POISON + "-SELF")
	_put(at.path_join("uptime"), POISON + "-UPTIME")
	return at


## A fake process's folder: its stat and status as the kernel writes them, and beside them every file the reader must
## never open, each holding poison.
func _proc(at: String, pid: int, comm: String, state: String, ppid: int, ticks: int, rss: int) -> void:
	var dir := at.path_join(str(pid))
	DirAccess.make_dir_recursive_absolute(dir)
	_put(dir.path_join("stat"), "%d (%s) %s %d %d %d 0 -1 4194304 100 0 0 0 %d %d 0 0 20 0 1 0 500 10000000 2500\n" % [pid, comm, state, ppid, pid, pid, ticks, 0])
	_put(dir.path_join("status"), "Name:\t%s\nState:\t%s\nPid:\t%d\nPPid:\t%d\n%s" % [comm, state, pid, ppid, ("VmRSS:\t   %d kB\n" % rss) if rss >= 0 else ""])
	for f in ["cmdline", "environ", "maps", "exe", "statm", "io", "comm"]:
		_put(dir.path_join(f), "%s-%s-%d" % [POISON, f.to_upper(), pid])
	for d in ["fd", "cwd", "task"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(d))
		_put(dir.path_join(d).path_join("0"), "%s-%s-%d" % [POISON, d.to_upper(), pid])


func _put(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _reader_checks() -> void:
	var at := _fake_proc()
	var reads_before := ProcReader.reads
	var reader := ProcReader.new(at)
	var scanned := false
	for i in 50:
		if reader.step(1.0 / 60.0 if i > 0 else ProcReader.REFRESH_S):
			scanned = true
			break
	var snap := reader.snapshot
	_check("the reader against a fake table under the test's own folder: every process read with its PID, parent's PID, name, state and resident memory; kernel threads (no resident memory, kthreadd's children) left out; a name with brackets and spaces whole", scanned and snap.keys().size() == 7 and not snap.has(2) and not snap.has(3) and snap[200]["comm"] == "fakebrowser" and snap[200]["ppid"] == 100 and snap[200]["mem_kb"] == 400000 and snap[203]["state"] == "R" and snap[300]["comm"] == "fake(odd) name)", str(snap.keys()))
	var only := true
	var poison := false
	for path in reader.opened:
		only = only and (path.get_file() == "stat" or path.get_file() == "status") and path.begins_with(at)
		for word in ["cmdline", "environ", "maps", "/fd", "cwd", "/exe", "task", "self", "uptime"]:
			only = only and not path.contains(word)
	for pid in snap:
		for key in snap[pid]:
			poison = poison or str(snap[pid][key]).contains(POISON)
	_check("acceptance (safety): it opened only `stat` and `status` in each numbered folder (%d files), never cmdline, environ, fd, cwd, exe, maps or anything else beside them, never a folder that is not a PID; nothing poisoned came through" % reader.opened.size(), only and not poison and reader.opened.size() == 2 * 7 + 2 and ProcReader.reads - reads_before == reader.opened.size(), ", ".join(reader.opened.slice(0, 4)))
	# CPU: 100 more ticks for the browser over the next scan's two seconds is 50 per cent of a core.
	_proc(at, 200, "fakebrowser", "R", 100, 400, 400000)
	var again := false
	for i in 50:
		if reader.step(ProcReader.REFRESH_S if i == 0 else 1.0 / 60.0):
			again = true
			break
	_check("CPU from two scans: ticks over the time between them at the kernel's 100 a second (100 ticks over 2 s: 50%%); the first scan shows 0", again and absf(float(reader.snapshot[200]["cpu"]) - 50.0) < 0.5 and float(snap[200]["cpu"]) == 0.0, "%.2f" % float(reader.snapshot[200]["cpu"]) if again else "no second scan")
	reader.drop()
	_check("drop() lets every value go", reader.snapshot.is_empty())


# --- The gate. ---

func _gate_checks() -> void:
	var path := _abs.path_join("gate.cfg")
	var link := Link.new()
	link.settings_path = path
	link.demo = false
	var no_link := AuditVisor.real_gate_for(null)
	var fresh := AuditVisor.real_gate_for(link)
	Privacy.save_real_data(true, path)
	var real_only := AuditVisor.real_gate_for(link)
	Privacy.save_opener_real(true, path)
	var both := AuditVisor.real_gate_for(link)
	link.demo = true
	var on_demo := AuditVisor.real_gate_for(link)
	link.demo = false
	Privacy.save_real_data(false, path)
	var data_off := AuditVisor.real_gate_for(link)
	_check("acceptance (safety): the real layer is behind the opener's own opt-in: off with no answer, off with real-machine data alone, off on a demo run, off with real-machine data off, on only with both yeses", not no_link and not fresh and not real_only and both and not on_demo and not data_off)


# --- The free arena. ---

func _arena_checks() -> void:
	var made_before := ProcReader.made
	var reads_before := ProcReader.reads
	var main := await _arena()
	var visor := AuditVisor.of(main)
	var hud = main.get_node("Hud")
	var vh: VisorHud = hud.visor_hud()
	await _frames(10)
	_check("acceptance: off by default: the visor stands in the arena, off, nothing drawn, its HUD hidden", visor != null and not visor.on and visor.lines().drawn_lines == 0 and not vh.visible and vh.credit_text() == "")
	var a := main.get_node("Arena/Targets/DummyA")
	var b := main.get_node("Arena/Targets/DummyB")
	var c := main.get_node("Arena/Targets/DummyC")
	var d := main.get_node("Arena/Targets/DummyD")
	var player = main.get_node("Player")
	# Back from the arena's middle, every daemon and the tree's top in view.
	player.global_position = Vector3(0.0, player.global_position.y, 28.0)
	_face(player, Vector3(0.0, 0.0, 0.0))
	_action("audit_visor")
	await _frames(40)
	_check("acceptance: I turns it on: lines drawn, its HUD up with \"AUDIT TRAIL\", demo data and the credit \"visor design: @QuantaCortex\"", visor.on and visor.lines().drawn_lines > 0 and vh.visible and vh.credit_text() == "visor design: @QuantaCortex" and vh.drawn_header.size() == 2 and vh.drawn_header[0].begins_with("AUDIT TRAIL") and vh.drawn_header[0].contains("demo data") and vh.drawn_header[1] == AuditVisor.CREDIT, str(vh.drawn_header))
	var tree := visor.tree
	var na := _node_of(visor, a)
	var expect := {na: tree.hidden, _node_of(visor, b): na, _node_of(visor, c): na, _node_of(visor, d): na, tree.hidden: tree.root}
	var edges := {}
	for e in visor.edges():
		edges[e["child"]] = e["parent"]
	_check("acceptance: the lines are the simulated tree: rogue.d a daemon under the session's redacted parent, the zombie, <defunct> and the runaway its children, the redacted parent under init; one line each, %d drawn" % visor.lines().drawn_lines, na > 0 and edges == expect and visor.lines().drawn_lines == expect.size() and tree.ppid_text(na) == "[REDACTED]" and tree.ppid_text(_node_of(visor, b)) == str(tree.node(na).pid), "%s vs %s" % [edges, expect])
	_check("the processes' own numbers: a zombie holds no CPU and no memory (Z), the runaway pegs a core (R), rogue.d its CPU and memory; init PID 1", tree.node(_node_of(visor, b)).state == "Z" and tree.node(_node_of(visor, b)).cpu == 0.0 and tree.node(_node_of(visor, b)).mem_kb == 0 and tree.node(_node_of(visor, d)).cpu > 70.0 and tree.node(na).mem_kb > 0 and tree.node(tree.root).pid == 1)
	var full := 0
	var longest := 0
	for tag in vh.drawn_tags:
		if tag.contains(" / "):
			full += 1
		longest = maxi(longest, tag.length())
	var rogue_tag := ""
	for tag in vh.drawn_tags:
		if tag.contains("rogue.d"):
			rogue_tag = tag
	_check("acceptance: its tags read, never a wall of text: the process at the crosshair in full (PID, name, state; PPID, CPU, memory), the rest a line or a PID, init and the redacted parent by name, at most one in full, none long", vh.drawn_tags.size() >= 6 and vh.drawn_tags.has("1  init") and _has_part(vh.drawn_tags, "[REDACTED]") and full <= 1 and longest <= 72 and rogue_tag.contains(str(tree.node(na).pid)) and rogue_tag.contains("ppid [REDACTED]") and rogue_tag.contains("cpu ") and rogue_tag.contains("mem "), "%s" % [vh.drawn_tags])
	_check("while it is on, the daemons' own name tags give way to its tags", not (a.get_node("Tag") as Node3D).visible and not (b.get_node("Tag") as Node3D).visible)
	_check("acceptance (safety): on, with the settings as shipped (no yes to real data), no reader is made and nothing is read", ProcReader.made == made_before and ProcReader.reads == reads_before and visor.real_reader == null and not visor.showing_real())
	_action("audit_visor")
	await _frames(3)
	_check("acceptance: I again turns it off: nothing drawn, its HUD gone, the name tags back", not visor.on and visor.lines().drawn_lines == 0 and not vh.visible and (a.get_node("Tag") as Node3D).visible and (d.get_node("Tag") as Node3D).visible)
	# A sever: two more runaways forked down the chain (a fork bomb's), and a sealed zombie under rogue.d.
	var r1 := _add(main, SwarmArt, "runaway", d.global_position + Vector3(2.5, 0.0, 0.0))
	await _frames(2)
	var r2 := _add(main, SwarmArt, "runaway", d.global_position + Vector3(5.0, 0.0, 0.0))
	await _frames(2)
	var sealed := _add(main, ZombieArt, "zombie", a.global_position + Vector3(2.0, 0.0, 0.0))
	sealed.sealed = true
	# Another family elsewhere, which a sever of rogue.d's must never touch.
	var x := _add(main, RogueArt, "rogue.d", Vector3(26.0, 0.0, 26.0))
	await _frames(2)
	var xz := _add(main, ZombieArt, "zombie", Vector3(28.0, 0.0, 26.0))
	_action("audit_visor")
	await _frames(6)
	var n1 := _node_of(visor, r1)
	var n2 := _node_of(visor, r2)
	var ns := _node_of(visor, sealed)
	_check("a runaway is forked by the nearest older runaway (a fork bomb's chain): rogue.d > runaway > runaway > runaway; the sealed zombie rogue.d's child, protected", tree.node(n1).parent == _node_of(visor, d) and tree.node(n2).parent == n1 and tree.node(ns).parent == na and tree.node(ns).protected and not tree.node(n1).protected and tree.node(_node_of(visor, xz)).parent == _node_of(visor, x))
	var others := _others(main, [a, b, c, d, r1, r2, sealed])
	var fuse := ceili(AuditVisor.FUSE_S * 60.0)
	var counted: Array = [0]
	visor.severed.connect(func(_p: int, n: int) -> void: counted[0] = n)
	var collapses := visor.collapse().made
	a.hit(100000.0, a.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail")
	await _frames(int(AuditVisor.FUSE_S * 60.0 * 0.5))
	var mid_burn := false
	for e in visor.edges():
		mid_burn = mid_burn or (e["burn"] > 0.0 and e["burn"] < 1.0)
	var standing_mid: bool = b.is_alive() and c.is_alive() and d.is_alive()
	_check("acceptance: rogue.d killed with the visor on severs its chain: its lines burn down from it like fuses (mid-burn), its children still standing until the fuse reaches them", counted[0] == 3 and mid_burn and standing_mid, "count %d" % counted[0])
	await _frames(fuse - int(AuditVisor.FUSE_S * 60.0 * 0.5) + 5)
	var first: bool = not b.is_alive() and not c.is_alive() and not d.is_alive() and r1.is_alive() and r2.is_alive()
	await _frames(fuse)
	var second: bool = not r1.is_alive() and r2.is_alive()
	await _frames(fuse)
	var third: bool = not r2.is_alive()
	_check("acceptance: a chain reaction a hop at a time: the zombie, <defunct> and the runaway at the first fuse's end, the next runaway one fuse later, the last one more", first and second and third, "first %s second %s third %s" % [first, second, third])
	var untouched := others.size() >= 2 and others.all(func(o): return is_instance_valid(o) and o.is_alive()) and others.has(x) and others.has(xz)
	_check("acceptance: the sever took exactly the subtree and nothing else: the other family (another rogue.d and its zombie) still stands, and the sealed zombie (protected) holds, adopted by init (PPID 1)", untouched and sealed.is_alive() and tree.node(ns).parent == tree.root and tree.ppid_text(ns) == "1" and visor.held == 1 and visor.reaped_by_sever == 5, "others %d held %d reaped %d" % [others.size(), visor.held, visor.reaped_by_sever])
	_check("a sever's children are reaped, never a kill: no kill credited to anyone, and the arena reshapes where each stood (its columns thrust up)", not b.credited and not d.credited and not r2.credited and visor.collapse().made - collapses >= 6 and visor.collapse().live() > 0)
	# Off: a parent's death severs nothing; its children are adopted.
	await _until(func(): return a.is_alive() and b.is_alive() and c.is_alive() and d.is_alive())
	await _frames(5)
	_action("audit_visor")
	await _frames(3)
	var kids_of_a: Array = tree.children_of(_node_of(visor, a)).map(func(id): return tree.node(id).body)
	var columns_before := visor.collapse().made
	a.hit(100000.0, a.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail")
	await _frames(fuse * 3)
	var all_up := kids_of_a.all(func(k): return k != null and is_instance_valid(k) and k.is_alive() and tree.node(_node_of(visor, k)).parent == tree.root)
	_check("off, a parent's death severs nothing and draws nothing (no columns): its children (%d) stand, adopted by init" % kids_of_a.size(), not visor.on and kids_of_a.size() >= 3 and all_up and visor.reaped_by_sever == 5 and visor.collapse().made == columns_before)
	await _drop(main)


func _has_part(tags: PackedStringArray, part: String) -> bool:
	for t in tags:
		if t.contains(part):
			return true
	return false


func _node_of(visor: AuditVisor, body: Node) -> int:
	return visor._by_body.get(body.get_instance_id(), -1)


func _add(main: Node, art: Script, tag: String, at: Vector3) -> Node3D:
	var dummy = DummyScene.instantiate()
	dummy.tag_text = tag
	dummy.art = art
	main.get_node("Arena/Targets").add_child(dummy)
	dummy.global_position = at
	var director := DaemonDirector.of(main)
	if director != null:
		director.forget_brains()
	return dummy


func _others(main: Node, mine: Array) -> Array:
	var out: Array = []
	for t in main.get_tree().get_nodes_in_group("targets"):
		if not mine.has(t) and (t as Node).is_inside_tree() and t.has_method("is_alive") and t.is_alive():
			out.append(t)
	return out


# --- The real layer, from the fake table. ---

func _real_checks() -> void:
	var at := _abs.path_join("fakeproc")
	var main := await _arena()
	var visor := AuditVisor.of(main)
	visor.real_root = at
	visor.real_gate = func() -> bool: return true
	_face(main.get_node("Player"), main.get_node("Arena/Targets/DummyA").global_position)
	var reads_before := ProcReader.reads
	await _frames(5)
	_check("acceptance (safety): with the yes but the visor off, nothing is read", ProcReader.reads == reads_before and visor.real_reader == null)
	visor.set_on(true)
	await _until(func(): return visor.showing_real())
	await _frames(3)
	var vh: VisorHud = main.get_node("Hud").visor_hud()
	var real_names := PackedStringArray()
	for id in visor.tree.nodes:
		if visor.tree.node(id).real:
			real_names.append(visor.tree.node(id).name)
	_check("with the yes, on: the fake table's processes label the arena's (labels only: the same lines), the header says it is this machine's, read-only", visor.showing_real() and real_names.has("fakeinit") and vh.drawn_header.size() > 0 and vh.drawn_header[0].contains(VisorHud.REAL_WORD) and visor.edges().size() == 5, str(real_names))
	var opened_ok := true
	for path in visor.real_reader.opened:
		opened_ok = opened_ok and (path.get_file() == "stat" or path.get_file() == "status")
	visor.set_on(false)
	await _frames(3)
	var after := ProcReader.reads
	await _frames(int(ProcReader.REFRESH_S * 60.0) + 10)
	_check("acceptance (safety): it read only stat and status; off, the reader is dropped, every label is the demo's again, and nothing more is read", opened_ok and visor.real_reader == null and not visor.showing_real() and ProcReader.reads == after)
	await _drop(main)


# --- A mission with the visor on. ---

func _mission_checks() -> void:
	var main := await _arena()
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(2))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	var visor := AuditVisor.of(main)
	visor.set_on(true)
	var stage := runner.stage
	await _until(func(): return runner.state == MissionRunner.State.RUNNING and stage.parent != null)
	await _frames(20)
	var parent := stage.parent
	var tree := visor.tree
	var np := _node_of(visor, parent)
	var kids := stage.children()
	var all_protected := true
	var under := 0
	for id in tree.daemons():
		all_protected = all_protected and tree.node(id).protected
	for k in kids:
		if tree.node(_node_of(visor, k)) != null and tree.node(_node_of(visor, k)).parent == np:
			under += 1
	_check("mission 2 with the visor on: its parent keeps its own PID (4087), every zombie it never reaped hangs from it (sleepers too, state S, as its own threads lead to them), its threads give way to the visor's lines, and every daemon of the mission is protected from the visor's own sever", np > 0 and tree.node(np).pid == 4087 and under == kids.size() and kids.size() > 0 and all_protected and stage.threads() != null and not stage.threads().visible, "under %d of %d" % [under, kids.size()])
	var some_daemon: Node3D = null
	for d in stage.made:
		if is_instance_valid(d) and d != parent and not (d is IcePiece) and d.is_alive():
			some_daemon = d
			break
	if some_daemon != null:
		some_daemon.hit(100000.0, some_daemon.global_position + Vector3.UP, Vector3.FORWARD, "sigkill_rail")
	await _frames(10)
	_check("a mission's daemon killed with the visor on severs nothing of the visor's own", visor.severs == 0 and visor.reaped_by_sever == 0)
	parent.sealed = false
	var standing := stage.children().size()
	for i in 12:
		if not parent.is_alive():
			break
		parent.hit(1000.0, parent.global_position + Vector3.UP * 2.0, Vector3.FORWARD, "sigkill_rail")
		await _frames(2)
	await _frames(int(AuditVisor.FUSE_S * 60.0 * 3.0))
	_check("acceptance: the parent killed, the mission's own reap is drawn as the chain reaction (each reaped child's line burnt from the parent), the visor taking nothing of its own and the mission still running", not parent.is_alive() and stage.reaped_count == standing and visor.mission_reaps_drawn == standing and visor.severs == 0 and visor.reaped_by_sever == 0 and runner.running(), "reaped %d drawn %d standing %d" % [stage.reaped_count, visor.mission_reaps_drawn, standing])
	await _drop(main)


# --- Black ICE's fail card (an M6 leftover). ---

func _card_checks() -> void:
	var main := await _arena(false)
	var runner := MissionRunner.of(main)
	var old_id := main.get_instance_id()
	runner.begin(MissionBook.at(1))
	main = await _after_reload(old_id)
	runner = MissionRunner.of(main)
	await _until(func(): return runner.state == MissionRunner.State.RUNNING)
	await _frames(5)
	var life = runner.life
	life.combat.states[SoloLife.ME]["protect_left"] = 0.0
	var took: bool = life.flatline("Black ICE", null, Vector3.FORWARD)
	await _frames(3)
	_check("M6 leftover: Black ICE's touch fails a mission as \"flatlined by Black ICE\" (I3's word, the other cards' voice), never \"derezzed by Black ICE\"", took and runner.state == MissionRunner.State.FAILED and runner.reason == "flatlined by Black ICE", runner.reason)
	await _drop(main)


# --- The arena. ---

func _arena(practice: bool = true) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
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


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	return main


func _face(player: Node3D, at: Vector3) -> void:
	var to := at - player.global_position
	player.rotation.y = atan2(-to.x, -to.z)


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
	AuditVisor.remembered = false
	GameSettings.current().reset()
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

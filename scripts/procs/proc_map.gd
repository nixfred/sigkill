class_name ProcMap
extends RefCounted
## W1's mapping (PRD 5.5): which processes of a table become which enemies. Pure data: a table in (the demo layer's,
## scripts/procs/demo_procs.gd, or the opt-in real reader's, scripts/visor/proc_reader.gd), a plan out; the hunt
## (scripts/procs/proc_hunt.gd) makes the arena match it. Nothing here touches a process: it is arithmetic on numbers.
##
## The rules, in this order, every table:
##   boss    a process pegging a core (PEGGED_CPU or more) is a boss, the giant red-hot lattice core; one at most (the
##           hottest). A boss stays one while it runs at COOL_CPU or more, so a core that flickers never flickers the boss.
##   swarm   a process with SWARM_KIDS or more children sharing one name (a browser's tabs) is a nest, and each of those
##           children a drone of its swarm, DRONES_PER at most. A process running THREADS_MIN threads or more is a nest
##           of its threads, THREAD_DRONES drones at most, each carrying its process's name and PID (a thread shares
##           its process's). SWARMS_MOST swarms at most, children first, the biggest first; DRONES_MOST drones in all.
##   daemon  every other process is a daemon sized by its memory, DAEMONS_MOST at most: the ones already up first (an
##           enemy never blinks out for a busier newcomer), then the busiest by CPU and memory. A zombie (Z) is a zombie.
## Left out: init (PID 1, the visor's root), the game itself (its own PID) and the session's holder (the child of init
## with the most processes under it: the visor redacts it, as the story has it). ENEMIES_MOST caps the whole arena.
##
## A plan: {"session": the holder's PID (0 for none), "enemies": {key: spec}}, a key the PID as text ("4211") or a
## thread drone's PID and index ("1411/3"), a spec {"pid", "ppid", "role" (boss, nest, drone, daemon, zombie), "nest"
## (a drone's nest's key, else ""), "comm", "state", "cpu", "mem_kb", "threads"}.

const PEGGED_CPU := 90.0
const COOL_CPU := 50.0
const BOSSES_MOST := 1
const SWARM_KIDS := 4
const DRONES_PER := 12
const THREADS_MIN := 24
const THREAD_DRONES := 8
const SWARMS_MOST := 3
const DRONES_MOST := 24
const DAEMONS_MOST := 12
const ENEMIES_MOST := 40
const INIT_PID := 1
const ROLES := ["boss", "nest", "drone", "daemon", "zombie"]


## The plan for `snapshot`, given the roles already up (`prev`: {key: role}) and the game's own PID.
static func plan(snapshot: Dictionary, prev: Dictionary = {}, own_pid: int = -1) -> Dictionary:
	var session := session_of(snapshot)
	var out := {}
	var taken := {}
	var kids := children(snapshot)
	var eligible := func(pid: int) -> bool:
		return snapshot.has(pid) and pid != INIT_PID and pid != own_pid and pid != session and not taken.has(pid)
	# The boss: the hottest pegged process; one already up stays while it runs warm.
	var hottest := -1
	var hottest_cpu := -1.0
	for pid in snapshot:
		if not eligible.call(pid) or str(snapshot[pid].get("state", "")) == "Z":
			continue
		var cpu := float(snapshot[pid].get("cpu", 0.0))
		var line := COOL_CPU if prev.get(str(pid), "") == "boss" else PEGGED_CPU
		if cpu >= line and (cpu > hottest_cpu or (cpu == hottest_cpu and pid < hottest)):
			hottest = pid
			hottest_cpu = cpu
	if hottest > 0 and BOSSES_MOST > 0:
		out[str(hottest)] = _spec(hottest, snapshot, "boss", "")
		taken[hottest] = true
	# The swarms: children of one name first (the biggest group first), then threads.
	var groups: Array = []
	for pid in kids:
		if not eligible.call(pid):
			continue
		var by_name := {}
		for c in kids[pid]:
			if eligible.call(c) and str(snapshot[c].get("state", "")) != "Z" and not kids.has(c):
				var name := str(snapshot[c].get("comm", ""))
				if not by_name.has(name):
					by_name[name] = []
				by_name[name].append(c)
		var best: Array = []
		for name in by_name:
			if by_name[name].size() > best.size() or (by_name[name].size() == best.size() and not best.is_empty() and name < str(snapshot[best[0]]["comm"])):
				best = by_name[name]
		if best.size() >= SWARM_KIDS:
			groups.append([pid, best])
	groups.sort_custom(func(a, b): return a[1].size() > b[1].size() or (a[1].size() == b[1].size() and a[0] < b[0]))
	var swarms := 0
	var drones := 0
	for g in groups:
		if swarms >= SWARMS_MOST or drones >= DRONES_MOST:
			break
		var nest: int = g[0]
		var members: Array = g[1].duplicate()
		# The drones already up keep their places, then the oldest (lowest PID) first.
		members.sort_custom(func(a, b): return [0 if prev.has(str(a)) else 1, a] < [0 if prev.has(str(b)) else 1, b])
		out[str(nest)] = _spec(nest, snapshot, "nest", "")
		taken[nest] = true
		swarms += 1
		for c in members.slice(0, mini(DRONES_PER, DRONES_MOST - drones)):
			out[str(c)] = _spec(c, snapshot, "drone", str(nest))
			taken[c] = true
			drones += 1
	var threaded: Array = []
	for pid in snapshot:
		if eligible.call(pid) and int(snapshot[pid].get("threads", 1)) >= THREADS_MIN and str(snapshot[pid].get("state", "")) != "Z":
			threaded.append(pid)
	threaded.sort_custom(func(a, b): return [-int(snapshot[a]["threads"]), a] < [-int(snapshot[b]["threads"]), b])
	for pid in threaded:
		if swarms >= SWARMS_MOST or drones >= DRONES_MOST:
			break
		out[str(pid)] = _spec(pid, snapshot, "nest", "")
		taken[pid] = true
		swarms += 1
		for i in mini(mini(int(snapshot[pid]["threads"]), THREAD_DRONES), DRONES_MOST - drones):
			var spec := _spec(pid, snapshot, "drone", str(pid))
			spec["thread"] = i + 1
			out["%d/%d" % [pid, i + 1]] = spec
			drones += 1
	# The daemons: those already up first, then the busiest.
	var rest: Array = []
	for pid in snapshot:
		if eligible.call(pid):
			rest.append(pid)
	rest.sort_custom(func(a, b): return _rank(a, snapshot, prev) > _rank(b, snapshot, prev) or (_rank(a, snapshot, prev) == _rank(b, snapshot, prev) and a < b))
	var daemons := 0
	for pid in rest:
		if daemons >= DAEMONS_MOST or out.size() >= ENEMIES_MOST:
			break
		var zombie := str(snapshot[pid].get("state", "")) == "Z"
		out[str(pid)] = _spec(pid, snapshot, "zombie" if zombie else "daemon", "")
		daemons += 1
	return {"session": session, "enemies": out}


## Every process's children: {ppid: [pid, ...]}, each list in PID order.
static func children(snapshot: Dictionary) -> Dictionary:
	var kids := {}
	for pid in snapshot:
		var pp := int(snapshot[pid].get("ppid", 0))
		if not kids.has(pp):
			kids[pp] = []
		kids[pp].append(pid)
	for pp in kids:
		kids[pp].sort()
	return kids


## The session's holder: the child of init with the most processes under it (0 for none).
static func session_of(snapshot: Dictionary) -> int:
	var kids := children(snapshot)
	var best := 0
	var most := -1
	for pid in kids.get(INIT_PID, []):
		var n := _below(pid, kids, 0)
		if n > most or (n == most and pid < best):
			most = n
			best = pid
	return best


static func _below(pid: int, kids: Dictionary, depth: int) -> int:
	if depth > 64:
		return 0
	var n := 0
	for c in kids.get(pid, []):
		n += 1 + _below(c, kids, depth + 1)
	return n


## How much a daemon wants its place: up already first, a zombie next, then CPU and memory.
static func _rank(pid: int, snapshot: Dictionary, prev: Dictionary) -> float:
	var p: Dictionary = snapshot[pid]
	var up := 1000000.0 if prev.has(str(pid)) else 0.0
	var zombie := 500000.0 if str(p.get("state", "")) == "Z" else 0.0
	return up + zombie + float(p.get("cpu", 0.0)) * 40.0 + float(p.get("mem_kb", 0)) / 1024.0


static func _spec(pid: int, snapshot: Dictionary, role: String, nest: String) -> Dictionary:
	var p: Dictionary = snapshot[pid]
	return {"pid": pid, "ppid": int(p.get("ppid", 0)), "role": role, "nest": nest, "comm": str(p.get("comm", "")), "state": str(p.get("state", "")), "cpu": float(p.get("cpu", 0.0)), "mem_kb": int(p.get("mem_kb", 0)), "threads": int(p.get("threads", 1)), "thread": 0}


## A daemon's size for its memory (W1): 0.85 for a few MB, up to 1.3 for a gigabyte and more.
static func size_for(mem_kb: int) -> float:
	var mb := maxf(float(mem_kb) / 1024.0, 1.0)
	return clampf(0.85 + 0.075 * log(mb / 16.0) / log(2.0), 0.85, 1.3)


## A daemon's health for its memory: one hit for a small process, more for a big one.
static func health_for(mem_kb: int) -> float:
	var mb := float(mem_kb) / 1024.0
	if mb < 64.0:
		return 1.0
	return snappedf(10.0 + 15.0 * log(mb / 64.0) / log(2.0), 1.0)


## The boss's heat for its CPU: 0 at COOL_CPU, 1 at a full core.
static func heat_for(cpu: float) -> float:
	return clampf((cpu - COOL_CPU) / (100.0 - COOL_CPU), 0.0, 1.0)

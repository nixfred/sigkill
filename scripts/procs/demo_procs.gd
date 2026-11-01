class_name DemoProcs
extends RefCounted
## W1's demo layer (PRD 5.5, live process enemies): a process table the game makes up, so the process hunt plays fully
## with zero reads of the player's machine. The tests and the captures use only this. It answers as the real reader does
## (scripts/visor/proc_reader.gd): step() reads on and says when a new table is out, `snapshot` is that table
## ({pid: {"ppid", "comm", "state", "cpu", "mem_kb", "threads"}}), drop() lets it go.
##
## Every name is invented and every number is the game's own, a pure function of the seed, the PID and the tick, so the
## same seed gives the same table every run. A believable desktop under one session (its holder redacted by the visor, as
## the story has it): a compositor; a browser with tabs that open and close and one heavy page now and then; its GPU
## helper; an editor and its language server, bursting as it checks; a sync daemon running many threads; a chat client
## that wakes for a message; a sound daemon; a scheduler that runs a check every 40 s; a terminal and its shell, under
## which a build runs every 64 s: three compilers forked and gone (the last one a zombie until the build reaps it), then
## the linker pegging a core for 26 s before it exits, then the build itself.
##
## Fiction only: nothing here reads, runs or signals anything.

## A new table every tick (s): faster than the real reader's 2 s, so the arena stays lively.
const TICK_S := 1.0
## The most ticks one step may make up (a long frame never floods the arena).
const CATCH_UP := 4
## The build's period and when the first starts (ticks), the linker's peg (from its fork, ticks), the zombie's wait.
const BUILD_EVERY := 64
const BUILD_FIRST := 6
const LINK_AT := 20
const LINK_PEG := 26
const ZOMBIE_TICKS := 12
## The tabs: how many at most and least, how often one opens and closes, how often a page goes heavy and for how long.
const TABS_MOST := 11
const TABS_LEAST := 4
const TABS_FIRST := 7
const TAB_OPEN_EVERY := 7
const TAB_CLOSE_EVERY := 9
const HEAVY_EVERY := 23
const HEAVY_TICKS := 8
## The scheduler's check: how often and how long.
const CHECK_EVERY := 40
const CHECK_TICKS := 7

## The fixed PIDs of the standing processes.
const INIT := 1
const SESSION := 412
const LUMEN := 988
const NEBULA := 1180
const NEBULA_GPU := 1204
const QUILL := 1310
const QUILL_LSP := 1322
const TIDESYNC := 1411
const CHATTER := 1466
const TICKD := 1490
const SOUNDD := 1502
const GLASS := 1530
const SHELL := 1544

var seed := 0
var tick := 0
var snapshot := {}
var scans := 0
## The PID the session's holder has (the visor redacts it), for the hunt.
var session_pid := SESSION
var _since := 0.0
var _procs := {}
var _next_pid := 4100
var _tabs: Array[int] = []
var _build := {}


func _init(at_seed: int = 4087) -> void:
	seed = at_seed
	_stand()
	_publish()


## Reads on: a new table every TICK_S. True when one came out this step.
func step(delta: float) -> bool:
	_since += maxf(delta, 0.0)
	if _since < TICK_S:
		return false
	var made := 0
	while _since >= TICK_S and made < CATCH_UP:
		_since -= TICK_S
		_tick()
		made += 1
	_since = minf(_since, TICK_S)
	_publish()
	return true


## `ticks` more ticks at once (the captures and the tests jump ahead to a moment of the table).
func advance(ticks: int) -> void:
	for i in maxi(ticks, 0):
		_tick()
	_publish()


func drop() -> void:
	snapshot = {}


# --- The table. ---

func _stand() -> void:
	_put(INIT, 0, "init", "S", 0.1, 11816, 1)
	_put(SESSION, INIT, "session", "S", 0.0, 6144, 1)
	_put(LUMEN, SESSION, "lumen", "R", 7.0, 184320, 9)
	_put(NEBULA, SESSION, "nebula", "R", 8.0, 421888, 38)
	_put(NEBULA_GPU, NEBULA, "nebula-gpu", "R", 9.0, 309248, 12)
	_put(QUILL, SESSION, "quill", "S", 1.0, 194560, 11)
	_put(QUILL_LSP, QUILL, "quill-lsp", "S", 1.0, 655360, 7)
	_put(TIDESYNC, SESSION, "tidesync", "S", 1.0, 98304, 28)
	_put(CHATTER, SESSION, "chatter", "S", 0.4, 532480, 21)
	_put(TICKD, SESSION, "tickd", "S", 0.0, 4096, 1)
	_put(SOUNDD, SESSION, "soundd", "S", 1.5, 24576, 4)
	_put(GLASS, SESSION, "glass", "S", 0.6, 88064, 6)
	_put(SHELL, GLASS, "sh", "S", 0.0, 4608, 1)
	for i in TABS_FIRST:
		_open_tab()


func _put(pid: int, ppid: int, comm: String, state: String, cpu: float, mem_kb: int, threads: int) -> void:
	_procs[pid] = {"ppid": ppid, "comm": comm, "state": state, "cpu": cpu, "mem_kb": mem_kb, "threads": threads, "born": tick}


func _fork(ppid: int, comm: String, state: String, cpu: float, mem_kb: int, threads: int) -> int:
	_next_pid += 1 + int(_noise(_next_pid, 7) * 6.0)
	_put(_next_pid, ppid, comm, state, cpu, mem_kb, threads)
	return _next_pid


func _exit(pid: int) -> void:
	_procs.erase(pid)
	_tabs.erase(pid)


func _open_tab() -> void:
	_tabs.append(_fork(NEBULA, "nebula-tab", "S", 2.0, 98304, 14))


## One tick of the table: the tabs, the build, the scheduler's check, every number on its own wave.
func _tick() -> void:
	tick += 1
	# Tabs open and close.
	if tick % TAB_OPEN_EVERY == 3 and _tabs.size() < TABS_MOST:
		_open_tab()
	if tick % TAB_CLOSE_EVERY == 5 and _tabs.size() > TABS_LEAST:
		_exit(_tabs[1 + int(_noise(tick, 11) * float(_tabs.size() - 1)) % (_tabs.size() - 1)])
	# The build, every BUILD_EVERY ticks.
	if tick >= BUILD_FIRST:
		_step_build((tick - BUILD_FIRST) % BUILD_EVERY)
	# The scheduler's check.
	var c := tick % CHECK_EVERY
	if c == 30:
		_build["check"] = _fork(TICKD, "pkgcheck", "R", 30.0, 40960, 2)
	elif c == 30 + CHECK_TICKS and _build.has("check"):
		_exit(_build["check"])
		_build.erase("check")
	_numbers()


func _step_build(c: int) -> void:
	match c:
		0:
			_build["forge"] = _fork(SHELL, "forge", "R", 18.0, 61440, 3)
		2, 4, 6:
			if _build.has("forge"):
				var key := "cc%d" % c
				_build[key] = _fork(_build["forge"], "forge-cc", "R", 70.0, 131072 + c * 8192, 1)
				_build[key + "_end"] = c + 10 + c
		LINK_AT:
			if _build.has("forge"):
				_build["ld"] = _fork(_build["forge"], "forge-ld", "R", 60.0, 368640, 1)
		LINK_AT + LINK_PEG:
			if _build.has("ld"):
				_exit(_build["ld"])
				_build.erase("ld")
		LINK_AT + LINK_PEG + 4:
			if _build.has("forge"):
				_exit(_build["forge"])
				_build.erase("forge")
	# The compilers finish; the last one left a zombie until the build reaps it.
	for k in ["cc2", "cc4", "cc6"]:
		if _build.has(k) and c == int(_build[k + "_end"]):
			if k == "cc6":
				var z: Dictionary = _procs.get(_build[k], {})
				if not z.is_empty():
					z["state"] = "Z"
					_build["zombie"] = _build[k]
					_build["zombie_end"] = c + ZOMBIE_TICKS
			else:
				_exit(_build[k])
			_build.erase(k)
			_build.erase(k + "_end")
	if _build.has("zombie") and c >= int(_build["zombie_end"]):
		_exit(_build["zombie"])
		_build.erase("zombie")
		_build.erase("zombie_end")


## Every process's numbers this tick: a pure function of the seed, its PID and the tick.
func _numbers() -> void:
	var heavy := -1
	if not _tabs.is_empty() and tick % HEAVY_EVERY < HEAVY_TICKS:
		heavy = _tabs[int(float(tick) / HEAVY_EVERY) % _tabs.size()]
	for pid in _procs:
		var p: Dictionary = _procs[pid]
		var n := _noise(pid, tick)
		var slow := 0.5 + 0.5 * sin(float(tick) * 0.37 + float(pid) * 0.71)
		if p["state"] == "Z":
			p["cpu"] = 0.0
			p["mem_kb"] = 0
			continue
		match str(p["comm"]):
			"lumen":
				_numbers_of(p, "R", 5.0 + 6.0 * n, 184320 + int(8192 * slow))
			"nebula":
				_numbers_of(p, "R", 4.0 + 8.0 * n, 421888 + 24576 * _tabs.size())
			"nebula-gpu":
				_numbers_of(p, "R", 6.0 + 9.0 * slow, 309248 + int(16384 * n))
			"nebula-tab":
				if pid == heavy:
					_numbers_of(p, "R", 55.0 + 15.0 * n, 262144 + int(32768 * slow))
				else:
					_numbers_of(p, "S" if n < 0.6 else "R", 0.5 + 7.5 * n * n, 81920 + (pid % 9) * 18432 + int(12288 * slow))
			"quill":
				_numbers_of(p, "S", 0.5 + 2.5 * n, 194560)
			"quill-lsp":
				var burst := tick % 14 >= 3 and tick % 14 <= 8
				_numbers_of(p, "R" if burst else "S", (30.0 + 15.0 * n) if burst else (0.3 + 1.5 * n), 655360 + int(65536 * slow))
			"tidesync":
				_numbers_of(p, "S", 0.2 + 1.8 * n, 98304 + int(4096 * slow))
			"chatter":
				var ping := tick % 20 <= 2
				_numbers_of(p, "R" if ping else "S", (10.0 + 4.0 * n) if ping else 0.4, 532480)
			"soundd":
				_numbers_of(p, "S", 1.0 + 1.0 * n, 24576)
			"glass":
				_numbers_of(p, "S", 0.3 + 0.8 * n, 88064)
			"forge":
				_numbers_of(p, "R" if _build.has("ld") or _build.has("cc2") else "S", 4.0 + 14.0 * n, 61440)
			"forge-cc":
				_numbers_of(p, "R", 55.0 + 25.0 * n, int(p["mem_kb"]))
			"forge-ld":
				# Ramping into a pegged core over three ticks, then pinned at it.
				var age := tick - int(p["born"])
				_numbers_of(p, "R", minf(60.0 + 14.0 * float(age), 99.0) + 0.9 * n, 368640 + mini(age, 20) * 8192)
			"pkgcheck":
				_numbers_of(p, "R", 25.0 + 15.0 * n, 40960)
			_:
				p["cpu"] = 0.0 if pid == INIT or pid == SESSION or pid == SHELL or pid == TICKD else p["cpu"]


func _numbers_of(p: Dictionary, state: String, cpu: float, mem_kb: int) -> void:
	p["state"] = state
	p["cpu"] = snappedf(cpu, 0.1)
	p["mem_kb"] = mem_kb


## A number from 0 to 1 fixed by the seed, a PID and a tick.
func _noise(pid: int, at: int) -> float:
	return float(hash(Vector3i(seed, pid, at)) & 0xffff) / 65535.0


func _publish() -> void:
	var out := {}
	for pid in _procs:
		var p: Dictionary = _procs[pid]
		out[pid] = {"ppid": p["ppid"], "comm": p["comm"], "state": p["state"], "cpu": p["cpu"], "mem_kb": p["mem_kb"], "threads": p["threads"]}
	snapshot = out
	scans += 1

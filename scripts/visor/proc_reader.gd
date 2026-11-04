class_name ProcReader
extends RefCounted
## The Audit Trail visor's real layer (C43, PRD 5.5): a read-only reader of the machine's process table, made only when
## the player has said yes (the same opt-in as the opener's real data, C39: Settings, Privacy and AI, "opener data",
## with real-machine data on and never on a demo run; the visor asks, scripts/visor/audit_visor.gd). Off by default:
## when it is off, no reader is made at all and nothing is read.
##
## What it reads, all of it: the names of the numbered folders in the process table's root (each a PID), and for each,
## two small files, `stat` and `status`, at most SMALL bytes apiece. From `stat`: the PID, the short process name
## between its brackets (at most COMM_LONGEST printable characters), its state letter, its parent's PID and its CPU
## ticks; from `status`: its resident memory (VmRSS, kB) and how many threads it runs (Threads; W1's swarms). A process
## with no resident memory line is a kernel thread and is left out. It opens nothing else in a process's folder, ever: no command line, no environment, no open files,
## no working folder, no executable, no memory map, no path and no file's contents. It writes, saves, prints, logs and
## sends nothing, runs nothing, and never signals a process: the visor's sever is drawn, never sent.
##
## CPU: ticks between two scans over the time between them, at CLK_TCK ticks a second (Linux's USER_HZ, 100 on every
## architecture the game ships for). The table is read a slice at a time (step(): at most budget_us a frame, MOST_PIDS
## a scan), a full scan published as `snapshot` every REFRESH_S. drop() lets every value go: they live only here.

const ROOT := "/proc"
## Every file it ever opens, by name, in a process's folder.
const STAT := "stat"
const STATUS := "status"
const FILES := [STAT, STATUS]
const SMALL := 4096
const COMM_LONGEST := 15
const MOST_PIDS := 1024
const CLK_TCK := 100.0
const REFRESH_S := 2.0
const BUDGET_US := 1500
## A kernel thread's parent.
const KTHREADD := 2

## Every file opened by any reader this run, and every reader made (the tests' proof that an off visor reads nothing).
static var reads := 0
static var made := 0

## The table's root (a test hands in a fake one under its own folder).
var root := ROOT
var budget_us := BUDGET_US
## Every path this reader opened, in order, for the checks: the first OPENED_KEPT only, so a long session on the
## real layer does not grow it without end; drop() lets them go with the rest.
const OPENED_KEPT := 4096
var opened := PackedStringArray()
## The last full scan: {pid: {"ppid", "comm", "state", "cpu", "mem_kb", "threads"}}.
var snapshot := {}
var scans := 0
var _queue := PackedStringArray()
var _building := {}
var _clock := 0.0
var _scan_at := 0.0
var _last_scan_at := -1.0
var _ticks := {}
var _since := INF


func _init(at: String = ROOT) -> void:
	made += 1
	root = at


## Reads on: a slice of the table within the frame's budget, a new scan when the last is REFRESH_S old. True when a
## full scan was published this step.
func step(delta: float) -> bool:
	_clock += maxf(delta, 0.0)
	_since += maxf(delta, 0.0)
	if _queue.is_empty() and _building.is_empty():
		if _since < REFRESH_S:
			return false
		_since = 0.0
		_scan_at = _clock
		_queue = _list()
		if _queue.is_empty():
			return false
	var start := Time.get_ticks_usec()
	while not _queue.is_empty():
		var pid_name := _queue[_queue.size() - 1]
		_queue.remove_at(_queue.size() - 1)
		var p := _read_one(pid_name)
		if not p.is_empty():
			_building[int(pid_name)] = p
		if Time.get_ticks_usec() - start > budget_us:
			break
	if not _queue.is_empty():
		return false
	_publish()
	return true


## Every value let go.
func drop() -> void:
	opened.clear()
	snapshot.clear()
	_building.clear()
	_queue.clear()
	_ticks.clear()


func _publish() -> void:
	var span := _scan_at - _last_scan_at if _last_scan_at >= 0.0 else 0.0
	var ticks_now := {}
	for pid in _building:
		var p: Dictionary = _building[pid]
		var t: int = p["ticks"]
		ticks_now[pid] = t
		var before: int = _ticks.get(pid, -1)
		p["cpu"] = clampf(float(t - before) / CLK_TCK / span * 100.0, 0.0, 9999.0) if span > 0.0 and before >= 0 and t >= before else 0.0
		p.erase("ticks")
	_ticks = ticks_now
	_last_scan_at = _scan_at
	snapshot = _building
	_building = {}
	scans += 1


## The numbered folders under the root (PIDs), at most MOST_PIDS: names only.
func _list() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	for entry in dir.get_directories():
		if entry.is_valid_int() and int(entry) > 0:
			out.append(entry)
			if out.size() >= MOST_PIDS:
				break
	return out


## One process from its two files, or {} (gone, unreadable, a kernel thread).
func _read_one(pid_name: String) -> Dictionary:
	var stat := parse_stat(_small(root.path_join(pid_name).path_join(STAT)))
	if stat.is_empty() or stat["pid"] != int(pid_name) or stat["ppid"] == KTHREADD or stat["pid"] == KTHREADD:
		return {}
	var status := _small(root.path_join(pid_name).path_join(STATUS))
	var rss := parse_rss(status)
	if rss < 0:
		return {}
	return {"ppid": stat["ppid"], "comm": stat["comm"], "state": stat["state"], "ticks": stat["ticks"], "mem_kb": rss, "threads": parse_threads(status)}


## At most SMALL bytes of a file, as text; "" when it cannot be read or is longer.
func _small(path: String) -> String:
	if path.get_file() != STAT and path.get_file() != STATUS:
		return ""  # nothing else, ever
	reads += 1
	if opened.size() < OPENED_KEPT:
		opened.append(path)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(SMALL + 1)
	file.close()
	if bytes.is_empty() or bytes.size() > SMALL:
		return ""
	return bytes.get_string_from_ascii()


## A `stat` line: {"pid", "comm", "state", "ppid", "ticks"} (user plus system), or {}. The name is what stands between
## the first "(" and the last ")" (a name may hold either), printable characters only.
static func parse_stat(text: String) -> Dictionary:
	var open := text.find("(")
	var close := text.rfind(")")
	if open < 1 or close < open:
		return {}
	var pid_part := text.substr(0, open).strip_edges()
	if not pid_part.is_valid_int():
		return {}
	var rest := text.substr(close + 1).strip_edges().split(" ", false)
	if rest.size() < 13 or not rest[1].is_valid_int() or not rest[11].is_valid_int() or not rest[12].is_valid_int():
		return {}
	return {"pid": int(pid_part), "comm": clean_comm(text.substr(open + 1, close - open - 1)), "state": rest[0].left(1), "ppid": int(rest[1]), "ticks": int(rest[11]) + int(rest[12])}


## Resident memory from a `status` text, kB; -1 when it has none (a kernel thread).
static func parse_rss(text: String) -> int:
	for line in text.split("\n"):
		if line.begins_with("VmRSS:"):
			var fields := line.trim_prefix("VmRSS:").strip_edges().split(" ", false)
			return int(fields[0]) if not fields.is_empty() and fields[0].is_valid_int() else -1
	return -1


## How many threads a `status` text says the process runs (W1); 1 when it says nothing.
static func parse_threads(text: String) -> int:
	for line in text.split("\n"):
		if line.begins_with("Threads:"):
			var fields := line.trim_prefix("Threads:").strip_edges().split(" ", false)
			return maxi(int(fields[0]), 1) if not fields.is_empty() and fields[0].is_valid_int() else 1
	return 1


## A process name as the visor shows it: printable ASCII only, at most COMM_LONGEST characters.
static func clean_comm(raw: String) -> String:
	var out := ""
	for i in raw.length():
		var c := raw.unicode_at(i)
		out += char(c) if c >= 32 and c < 127 else "?"
		if out.length() >= COMM_LONGEST:
			break
	return out

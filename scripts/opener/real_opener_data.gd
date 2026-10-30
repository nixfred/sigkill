class_name RealOpenerData
extends OpenerData
## The opener's real data (C39; PRD 5.7: "built from the player's real machine so it makes them blink"): the fields
## DemoOpenerData fills, read from this machine, read-only, and only when the player has said yes (Settings,
## Privacy and AI, "opener data"; the [privacy] opener_real_data answer, off unless turned on; never on a demo run).
## What it reads, all of it:
##   the user name    the session's USER (LOGNAME if that is empty; else the home folder's own name)
##   the home folder  the session's HOME: where the walk starts and where the theme is found
##   the host name    the first line of /proc/sys/kernel/hostname (else /etc/hostname), at most SMALL_FILE bytes
##   the uptime       the first number in /proc/uptime, at most SMALL_FILE bytes
##   the theme        the active Omarchy theme's colors.toml (THEME_FILES: Omarchy 4's, then Omarchy 3's), at
##                    most THEME_LARGEST bytes, its colours only (scripts/opener/theme_colors.gd), and whether a
##                    light.mode file stands beside it
##   the folders      names under the home folder, how many entries each holds, and the modification times of what
##                    the walk passes: a bounded walk (WALK_DEPTH, MOST_ENTRIES, MOST_LISTINGS, PER_LISTING,
##                    BUDGET_MS), never a file's contents
##   the clock        the system's time and its zone's offset: "now", and the file times read as local hours
## Those three small files are the only ones it opens, to read; it writes, saves, prints, logs and sends nothing,
## and runs nothing. GDScript has no call for the user, the home folder or the host name, so the first two come
## from the environment and the third from the kernel's own file.
##
## The walk: the home folder's own entries, hidden ones included; then, breadth first and in name order, the
## entries of each folder down to WALK_DEPTH levels, hidden ones below the top skipped. A symbolic link is never
## listed, walked or timed. A folder on another filesystem than the home folder's (a network share, a removable
## disk) stays a name, never walked; a folder it may not read stays a name with no count, quietly. Every
## node_modules met is counted (C40's pit) and never walked. File times are taken from what is not hidden (an app's
## cache stirring at 3 in the morning says nothing about the player). The walk stops at the first cap it meets and
## keeps what it found.
##
## Off the main thread: start() reads on a thread of its own, so the opener never waits on it, and a share that
## hangs can stall only that thread. Each value is published as it is read; the opener takes them as soon as all
## are in or at its take_by second regardless (scripts/opener/opener.gd), and any value not in by then, unreadable
## or unusable (no theme, a theme too low in contrast, nothing found) is the demo's, for that value alone; the file
## times and "now" fall back together. drop(), as the opener ends, cancels a read still going and lets every value
## go: they lived only in this object's memory.

const WALK_DEPTH := 3
const MOST_ENTRIES := 600
const MOST_LISTINGS := 64
const PER_LISTING := 200
const MOST_FOLDERS := 128
const MOST_TIMES := 256
const BUDGET_MS := 150
const SMALL_FILE := 64
const THEME_LARGEST := 16384
const HOST_FILES := ["/proc/sys/kernel/hostname", "/etc/hostname"]
const UPTIME_FILE := "/proc/uptime"
const THEME_FILES := [".local/state/omarchy/current/theme/colors.toml", ".config/omarchy/current/theme/colors.toml"]
const LIGHT_FILE := "light.mode"
const NODE_MODULES := "node_modules"
## Every value it reads, by name (real_fields()).
const FIELDS := ["user", "host", "palette", "uptime", "folders", "times"]
## zone_s's "ask the system".
const SYSTEM_ZONE := -1000000

## Where it reads: set by for_this_machine(); the tests hand in a fake home and fake files.
var home := ""
var user_name := ""
var host_files := PackedStringArray(HOST_FILES)
var uptime_file := UPTIME_FILE
var theme_files := PackedStringArray(THEME_FILES)
## The caps (the tests tighten them).
var depth := WALK_DEPTH
var most_entries := MOST_ENTRIES
var most_listings := MOST_LISTINGS
var budget_ms := BUDGET_MS
## The clock: unix seconds (-1 asks the system) and the zone's offset in seconds (SYSTEM_ZONE asks the system).
var clock_unix := -1
var zone_s := SYSTEM_ZONE
## The filesystem the walk stays on; "" is the home folder's own (a test names another to prove the rule).
var home_filesystem := ""

var _mutex := Mutex.new()
var _thread: Thread = null
var _got := {}
var _done := false
var _cancel := false
var _report := {}

## Readers whose thread may still be running: kept alive here until it ends and is joined.
static var _running: Array = []


## A reader for this machine: the home folder and the user name from the session's HOME and USER (LOGNAME when
## USER is empty), the only environment it reads. Nothing else is read until start().
static func for_this_machine() -> RealOpenerData:
	var reader := RealOpenerData.new()
	reader.home = OS.get_environment("HOME")
	reader.user_name = OS.get_environment("USER")
	if reader.user_name == "":
		reader.user_name = OS.get_environment("LOGNAME")
	return reader


func kind() -> String:
	return "real"


func start() -> void:
	_reap()
	if _thread != null:
		return
	_thread = Thread.new()
	if _thread.start(_read, Thread.PRIORITY_LOW) != OK:
		_thread = null
		_mutex.lock()
		_done = true
		_mutex.unlock()
		return
	_running.append(self)


func is_ready() -> bool:
	_mutex.lock()
	var done := _done
	_mutex.unlock()
	return done


func drop() -> void:
	_mutex.lock()
	_cancel = true
	_got.clear()
	_mutex.unlock()
	_reap()
	if _running.has(self):
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and not tree.process_frame.is_connected(_reap_when_done):
			tree.process_frame.connect(_reap_when_done)


func user() -> String:
	return _value("user", DemoOpenerData.USER)


func host() -> String:
	return _value("host", DemoOpenerData.HOST)


func palette() -> OpenerPalette:
	return _value("palette", null)


func folders() -> PackedStringArray:
	return _value("folders", DemoOpenerData.new().folders())


func folder_counts() -> PackedInt32Array:
	return _value("counts", DemoOpenerData.new().folder_counts()) if _has("folders") else DemoOpenerData.new().folder_counts()


func uptime_s() -> int:
	return _value("uptime", DemoOpenerData.UPTIME_S)


func file_times() -> PackedInt64Array:
	return _value("times", DemoOpenerData.new().file_times())


func now() -> int:
	return _value("now", 0) if _has("times") else DemoOpenerData.new().now()


## Which of FIELDS hold this machine's own values now; the rest are the demo's.
func real_fields() -> PackedStringArray:
	var out := PackedStringArray()
	for field in FIELDS:
		if _has(field):
			out.append(field)
	return out


## How the walk went, in numbers only: entries read, folders listed, why it stopped ("done", "entries",
## "listings", "time", "cancelled", or "no home"), the milliseconds the whole read took, and whether it ran off the
## main thread.
func walk_report() -> Dictionary:
	_mutex.lock()
	var out := _report.duplicate()
	_mutex.unlock()
	return out


# --- On the reader's own thread. ---

func _read() -> void:
	var began := Time.get_ticks_usec()
	var deadline := began + budget_ms * 1000
	var at_home := home.is_absolute_path() and home != "/" and DirAccess.dir_exists_absolute(home)
	var name := user_name if user_name != "" else (home.get_file() if at_home else "")
	if name != "":
		_put("user", name)
	var host_name := _first_line(host_files)
	if host_name != "":
		_put("host", host_name)
	var up := _uptime()
	if up >= 0:
		_put("uptime", up)
	var walk := {"entries": 0, "listings": 0, "stopped": "no home"}
	if at_home:
		var colours := _theme()
		if colours != null:
			_put("palette", colours)
		walk = _walk(deadline)
	walk["ms"] = (Time.get_ticks_usec() - began) / 1000.0
	walk["off_main"] = OS.get_thread_caller_id() != OS.get_main_thread_id()
	_mutex.lock()
	_report = walk
	_done = true
	_mutex.unlock()


## The walk (see the top): publishes the folders, their counts, the file times and "now"; returns its numbers.
func _walk(deadline: int) -> Dictionary:
	var clock := _clock()
	var top := DirAccess.open(home)
	if top == null:
		return {"entries": 0, "listings": 0, "stopped": "no home"}
	var filesystem := home_filesystem if home_filesystem != "" else top.get_filesystem_type()
	var found := PackedStringArray()
	var counts := {}
	var times := PackedInt64Array()
	var queue := [["", 0, false]]
	var entries := 0
	var listings := 0
	var stopped := "done"
	while not queue.is_empty() and stopped == "done":
		var item: Array = queue.pop_front()
		var rel: String = item[0]
		var level: int = item[1]
		var count_only: bool = item[2]
		if listings >= most_listings:
			stopped = "listings"
			break
		var path := home if rel == "" else home.path_join(rel)
		var dir := top if rel == "" else DirAccess.open(path)
		if dir == null or (rel != "" and dir.get_filesystem_type() != filesystem):
			continue
		dir.include_hidden = true
		dir.include_navigational = false
		if dir.list_dir_begin() != OK:
			continue
		listings += 1
		var names: Array = []
		var held := 0
		var entry := dir.get_next()
		while entry != "":
			stopped = _stop_reason(deadline, entries)
			if stopped != "done":
				break
			entries += 1
			held += 1
			if not dir.is_link(entry):
				names.append([entry, dir.current_is_dir()])
			if held >= PER_LISTING:
				break
			entry = dir.get_next()
		dir.list_dir_end()
		counts[rel] = held
		if count_only:
			continue
		names.sort_custom(func(a: Array, b: Array) -> bool: return _order_key(a[0]) < _order_key(b[0]))
		for named in names:
			var child_name: String = named[0]
			var hidden := child_name.begins_with(".")
			if hidden and level > 0:
				continue
			var child := child_name if rel == "" else rel + "/" + child_name
			if not hidden:
				var at := FileAccess.get_modified_time(path.path_join(child_name))
				if at > 0:
					times.append(at + clock[1])
			if not named[1]:
				continue
			if found.size() < MOST_FOLDERS:
				found.append(child)
			if hidden:
				continue
			if child_name == NODE_MODULES:
				queue.append([child, level + 1, true])
			elif level + 1 < depth:
				queue.append([child, level + 1, false])
	var shown := Array(found)
	shown.sort_custom(func(a: String, b: String) -> bool: return _order_key(a) < _order_key(b))
	var shown_counts := PackedInt32Array()
	for rel in shown:
		shown_counts.append(counts.get(rel, -1))
	times.sort()
	times.reverse()
	if times.size() > MOST_TIMES:
		times.resize(MOST_TIMES)
	if not shown.is_empty():
		_put("folders", PackedStringArray(shown))
		_put("counts", shown_counts)
	if not times.is_empty():
		_put("times", times)
		_put("now", clock[0] + clock[1])
	return {"entries": entries, "listings": listings, "stopped": stopped}


## Why the walk stops before its next entry, or "done" to go on.
func _stop_reason(deadline: int, entries: int) -> String:
	_mutex.lock()
	var cancelled := _cancel
	_mutex.unlock()
	if cancelled:
		return "cancelled"
	if Time.get_ticks_usec() >= deadline:
		return "time"
	if entries >= most_entries:
		return "entries"
	return "done"


## The active theme's palette, or null: the first of theme_files that is there, read for its colours.
func _theme() -> OpenerPalette:
	for rel in theme_files:
		var path := home.path_join(rel)
		if not FileAccess.file_exists(path):
			continue
		var text := _read_small(path, THEME_LARGEST)
		if text == "":
			return null
		return ThemeColors.palette_from(text, FileAccess.file_exists(path.get_base_dir().path_join(LIGHT_FILE)))
	return null


## Whole seconds since boot from the uptime file's first number, or -1.
func _uptime() -> int:
	var first := _read_small(uptime_file, SMALL_FILE).strip_edges().get_slice(" ", 0)
	if not first.is_valid_float():
		return -1
	var seconds := first.to_float()
	return int(seconds) if seconds >= 0.0 and seconds < 1.0e9 else -1


## The first non-empty first line of `files`, trimmed, or "".
static func _first_line(files: PackedStringArray) -> String:
	for path in files:
		var line := _read_small(path, SMALL_FILE).get_slice("\n", 0).strip_edges()
		if line != "":
			return line
	return ""


## At most `most` bytes of the file at `path`, as text; "" when it cannot be read, is empty or is longer.
static func _read_small(path: String, most: int) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(most + 1)
	file.close()
	if bytes.is_empty() or bytes.size() > most:
		return ""
	return bytes.get_string_from_utf8()


## [unix seconds, the zone's offset in seconds].
func _clock() -> Array:
	var unix := clock_unix if clock_unix >= 0 else int(Time.get_unix_time_from_system())
	var zone := zone_s if zone_s != SYSTEM_ZONE else int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return [unix, zone]


## Name order, without case, a folder straight before what is inside it.
static func _order_key(rel: String) -> String:
	return rel.to_lower().replace("/", char(1))


func _put(key: String, value: Variant) -> void:
	_mutex.lock()
	if not _cancel:
		_got[key] = value
	_mutex.unlock()


# --- On the main thread. ---

func _value(key: String, fallback: Variant) -> Variant:
	_mutex.lock()
	var value: Variant = _got.get(key, fallback)
	_mutex.unlock()
	return value


func _has(key: String) -> bool:
	_mutex.lock()
	var there := _got.has(key)
	_mutex.unlock()
	return there


func _reap_when_done() -> void:
	if _thread != null and _thread.is_alive():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.process_frame.is_connected(_reap_when_done):
		tree.process_frame.disconnect(_reap_when_done)
	_reap()


## Every reader whose thread has ended, joined and let go.
static func _reap() -> void:
	for reader in _running.duplicate():
		var thread: Thread = reader._thread
		if thread == null or not thread.is_alive():
			if thread != null:
				thread.wait_to_finish()
			_running.erase(reader)

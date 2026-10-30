extends SceneTree
## Headless test of the opener's real-data reader for SIGKILL (C39; PRD 5.7: the opener "built from the player's
## real machine", read-only, opted into, never saved). scripts/check.sh runs it as step 49, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/opener_real_test.gd
##
## Never the player's machine: every reader here reads a FAKE home folder this test builds in its own folder under
## user:// (invented names, a fake theme, fake host and uptime files, a pinned clock), and the folder is removed at
## the end; nothing of the machine's own is read, shown or printed. The reader's code: read-only, writing, saving,
## printing, logging, sending and running nothing, its environment and every engine call it makes listed. The walk:
## names, counts and times, the depth, entry, listing, per-folder and time caps, a symbolic link never listed,
## walked or timed, an unreadable folder kept as a name and skipped quietly, another filesystem never walked,
## hidden folders listed at the top only, wide-character names whole, on its own thread, nothing written. The theme:
## Omarchy's names, the older names, the derived shades and the mode, and every unusable theme falling back. Each
## value falling back alone. The opt-in: off, or a demo run, is the demo data; on is the reader, through the Esc
## menu's settings row and the opener itself on the fake home, its values dropped as it ends. The opener taking its
## data by take_by from a source that is never ready. The terminal's cells for wide characters, and clean()'s cut.

const MainScene = preload("res://scenes/main.tscn")
const OpenerScene = preload("res://scenes/opener.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const Privacy = preload("res://scripts/boot/guide_settings.gd")
const PauseMenu = preload("res://scripts/hud/pause_menu.gd")

const READER := "res://scripts/opener/real_opener_data.gd"
## Words the reader's code (comments aside) never holds: no write, save, print, log, network, execution or
## environment change, and no worker pool (whose end the game would wait on).
const NEVER := ["print", "push_error", "push_warning", "printerr", "store_", "save", "ResourceSaver", "FileAccess.WRITE", "READ_WRITE", "WRITE_READ", "make_dir", "remove", "rename", "copy", "create_link", "set_unix_permissions", "set_hidden", "set_read_only", "HTTP", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "ENet", "WebSocket", "WebRTC", "execute", "create_process", "OS.kill", "shell_open", "set_environment", "unset_environment", "JavaScriptBridge", "http://", "https://", "WorkerThreadPool", "get_cmdline", "get_user_data_dir", "Marshalls", "JSON", "ConfigFile"]
## Every engine call the reader makes on a class, and why (the README and DESIGN.md say the same).
const CALLS := {
	"OS.get_environment": "HOME, USER and LOGNAME: the home folder and the user name, which GDScript has no call for",
	"OS.get_thread_caller_id": "its report: the read ran off the main thread",
	"OS.get_main_thread_id": "its report: the read ran off the main thread",
	"Time.get_ticks_usec": "the time budget",
	"Time.get_unix_time_from_system": "\"now\", for the late-night line",
	"Time.get_time_zone_from_system": "the zone's offset, so file times read as local hours",
	"FileAccess.open": "reading the host name, the uptime and the theme's colours, at most their caps",
	"FileAccess.READ": "the one mode it opens a file in",
	"FileAccess.file_exists": "whether the theme and a light.mode file are there",
	"FileAccess.get_modified_time": "the modification times (mtimes only)",
	"DirAccess.open": "listing a folder's names",
	"DirAccess.dir_exists_absolute": "whether the home folder is there",
	"Engine.get_main_loop": "joining its own thread once it ends",
}
## Calls on a folder it lists, and on a file it reads.
const DIR_CALLS := ["include_hidden", "include_navigational", "list_dir_begin", "get_next", "is_link", "current_is_dir", "list_dir_end", "get_filesystem_type"]
const FILE_CALLS := ["get_buffer", "close"]
## The fake machine: a pinned clock (2025-11-05, before any file this test makes), a zone five hours west.
const CLOCK := 1762300000
const ZONE_S := -5 * 3600
const USER := "rook"
const HOST := "lab-node-7"
const UPTIME := 273754
const CJK := "写真"
const CAFE := "café"
const BULK_FILES := 205
## The fake home's folders as the reader must find them, in its order, with their counts.
const EMOJI_DIR_TAIL := " games"
const THEME := "# an invented theme\nmode = \"dark\"\naccent = \"#3fa7d6\"\nbackground = \"#0b1015\"\nforeground = \"#c8d3dc\"\nbright_foreground = \"#eef4f8\"\ngreen = \"#6cc070\"\nblue = \"#4d9de0\"\nyellow = \"#e0b44d\"\nred = \"#e05d5d\"\ncyan = \"#45c4c4\"\nmagenta = \"#c879d8\"\nbrown = \"#6b4a2a\"\n"
const MOST_FRAMES := 2800
const FPS := 60.0
const LONG_ROUND_S := 100000.0


## A source that is never ready: the opener must take it at take_by anyway.
class NeverReady extends OpenerData:
	func kind() -> String:
		return "stub"

	func is_ready() -> bool:
		return false

	func user() -> String:
		return "late"

	func host() -> String:
		return "stub"


var _fails := 0
var _checks := 0
var _root := ""
var _abs := ""
var _arenas: Array = []


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_root = "user://opener-real-test-%d" % OS.get_process_id()
	_abs = ProjectSettings.globalize_path(_root)
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	Controls.ensure()
	GameSettings.current().reset()
	_build_home()
	_code_checks()
	await _walk_checks()
	await _cap_checks()
	_theme_checks()
	await _fallback_checks()
	_terminal_checks()
	await _take_checks()
	await _menu_checks()
	await _cleanup()
	print("OPENER REAL: %d checks" % _checks)
	print("OPENER REAL RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The fake machine. ---

func _emoji_dir() -> String:
	return char(0x1F3AE) + EMOJI_DIR_TAIL


## The fake home, under the test's own folder: hidden folders at the top (one holding the fake theme), a folder of
## BULK_FILES files, a project with a node_modules pit and a folder too deep to walk, wide-character names, a
## folder it may not read, links in and out of it, and a folder outside it with a name that must never show.
func _build_home() -> void:
	for rel in [".cache/thumbnails", ".config/deep", ".local/state/omarchy/current/theme", "bulk", CAFE, "code/game/node_modules/a", "code/game/node_modules/b", "code/game/node_modules/c", "code/game/src/deep", "Documents/taxes", "locked/inside", CJK, _emoji_dir()]:
		DirAccess.make_dir_recursive_absolute(_abs.path_join("home").path_join(rel))
	DirAccess.make_dir_recursive_absolute(_abs.path_join("outside/secret-plans"))
	DirAccess.make_dir_recursive_absolute(_abs.path_join("empty-home"))
	DirAccess.make_dir_recursive_absolute(_abs.path_join("hidden-home/.only-hidden"))
	DirAccess.make_dir_recursive_absolute(_abs.path_join("sys"))
	_write("home/.bashrc", "# nothing\n")
	_write("home/todo.txt", "a fake list\n")
	_write("home/Documents/notes.txt", "fake notes\n")
	for i in BULK_FILES:
		_write("home/bulk/file-%03d.txt" % i, "")
	_write("home/.local/state/omarchy/current/theme/colors.toml", THEME)
	_write("sys/hostname", HOST + "\n")
	_write("sys/uptime", "%d.41 1043920.88\n" % UPTIME)
	_write("sys/garbage", "not a number\n")
	var home := DirAccess.open(_abs.path_join("home"))
	home.create_link(_abs.path_join("outside"), _abs.path_join("home/link_out"))
	home.create_link(_abs.path_join("home/Documents"), _abs.path_join("home/link_in"))
	FileAccess.set_unix_permissions(_abs.path_join("home/locked"), 0)


func _write(rel: String, text: String) -> void:
	var file := FileAccess.open(_abs.path_join(rel), FileAccess.WRITE)
	file.store_string(text)
	file.close()


## A reader on the fake machine, its clock pinned.
func _reader(home := "home") -> RealOpenerData:
	var reader := RealOpenerData.new()
	reader.home = _abs.path_join(home)
	reader.user_name = USER
	reader.host_files = PackedStringArray([_abs.path_join("sys/hostname")])
	reader.uptime_file = _abs.path_join("sys/uptime")
	reader.clock_unix = CLOCK
	reader.zone_s = ZONE_S
	return reader


## Frames until `reader` has read everything (or MOST_FRAMES).
func _read(reader: RealOpenerData) -> void:
	reader.start()
	var frames := 0
	while not reader.is_ready() and frames < MOST_FRAMES:
		await process_frame
		frames += 1


## Every path in the fake folder with its modification time, a link as itself (never followed).
func _snapshot(path: String, rel: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(path)
	if dir == null:
		return PackedStringArray([rel + " (unreadable)"])
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	var names := []
	while name != "":
		names.append([name, dir.is_link(name), dir.current_is_dir()])
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	for entry in names:
		var child := rel.path_join(entry[0])
		if entry[1]:
			out.append(child + " -> link")
			continue
		out.append("%s %d" % [child, FileAccess.get_modified_time(path.path_join(entry[0]))])
		if entry[2]:
			out.append_array(_snapshot(path.path_join(entry[0]), child))
	return out


# --- The reader's code. ---

func _code_checks() -> void:
	var source := FileAccess.get_file_as_string(READER)
	var code := _without_comments(source)
	var found := PackedStringArray()
	for word in NEVER:
		if code.contains(word):
			found.append(word)
	_check("acceptance: the reader writes, saves, prints, logs and sends nothing, runs nothing and changes no environment (none of %d words in its code: print, push_error, store_, save, make_dir, remove, rename, create_link, HTTP, socket, execute, set_environment, the worker pool...)" % NEVER.size(), found.is_empty() and code.length() > 1000, ", ".join(found))
	var env := RegEx.create_from_string("OS\\.get_environment\\(\"([A-Z]+)\"\\)")
	var vars := PackedStringArray()
	for m in env.search_all(code):
		vars.append(m.get_string(1))
	var maker := _body(code, "for_this_machine")
	_check("acceptance: its environment is HOME, USER and LOGNAME (LOGNAME only when USER is empty), read only in for_this_machine(), never by a test: %s" % ", ".join(vars), vars == PackedStringArray(["HOME", "USER", "LOGNAME"]) and code.count("get_environment") == 3 and maker.count("get_environment") == 3 and code.count("has_environment") == 0)
	var small := _body(code, "_read_small")
	_check("acceptance: the only file it opens is to read, at one place: _read_small() opens with FileAccess.READ and reads at most its cap plus one byte (a longer file is refused, never read on); its callers are the host name, the uptime and the theme", code.count("FileAccess.open(") == 1 and small.contains("FileAccess.open(path, FileAccess.READ)") and small.contains("get_buffer(most + 1)") and code.count("_read_small(") == 4 and code.count("get_as_text") == 0 and code.count("get_file_as") == 0)
	var calls := RegEx.create_from_string("\\b(OS|Time|FileAccess|DirAccess|Engine|ProjectSettings|ResourceLoader|ClassDB|IP|Thread|Mutex)\\.(\\w+)")
	var seen := {}
	var odd := PackedStringArray()
	for m in calls.search_all(code):
		var call := m.get_string(1) + "." + m.get_string(2)
		if call in ["Thread.new", "Mutex.new", "Thread.PRIORITY_LOW"]:
			continue
		seen[call] = true
		if not CALLS.has(call):
			odd.append(call)
	for m in RegEx.create_from_string("\\b(?:dir|top)\\.(\\w+)").search_all(code):
		if not DIR_CALLS.has(m.get_string(1)):
			odd.append("a folder's " + m.get_string(1))
	for m in RegEx.create_from_string("\\bfile\\.(\\w+)").search_all(code):
		if not FILE_CALLS.has(m.get_string(1)):
			odd.append("a file's " + m.get_string(1))
	var listed := PackedStringArray()
	for call in CALLS:
		listed.append("%s (%s)" % [call, CALLS[call]])
	_check("acceptance: every engine call it makes is one of these, each for a reason: %s; on a folder only %s; on a file only %s" % ["; ".join(listed), ", ".join(DIR_CALLS), ", ".join(FILE_CALLS)], odd.is_empty() and seen.size() == CALLS.size(), ", ".join(odd) + (" (unused: %d of %d)" % [seen.size(), CALLS.size()] if seen.size() != CALLS.size() else ""))
	_check("acceptance: it reads on a thread of its own (a Thread at low priority; never the worker pool, whose end the game would wait on), and every value crosses to the main thread under one mutex", code.contains("_thread = Thread.new()") and code.contains("_thread.start(_read, Thread.PRIORITY_LOW)") and code.count("_mutex.lock()") == code.count("_mutex.unlock()") and code.count("_mutex.lock()") >= 6)
	_check("the walk never follows a link: it skips one before it can list, walk or time it, and only the names it listed are walked or timed", _body(code, "_walk").contains("if not dir.is_link(entry):") and not code.contains("read_link"))


## `source` with every comment taken off (a "#" outside a string starts one).
static func _without_comments(source: String) -> String:
	var out := PackedStringArray()
	for line in source.split("\n"):
		var quoted := false
		var cut := line.length()
		for i in line.length():
			if line[i] == "\"":
				quoted = not quoted
			elif line[i] == "#" and not quoted:
				cut = i
				break
		out.append(line.left(cut))
	return "\n".join(out)


## The text of function `name` in `source`, up to the next function.
static func _body(source: String, name: String) -> String:
	var at := source.find("\nfunc %s(" % name)
	if at < 0:
		at = source.find("\nstatic func %s(" % name)
	if at < 0:
		return ""
	var end := source.find("\nfunc ", at + 1)
	var end_static := source.find("\nstatic func ", at + 1)
	if end < 0 or (end_static >= 0 and end_static < end):
		end = end_static
	return source.substr(at, end - at if end >= 0 else -1)


# --- The walk. ---

func _walk_checks() -> void:
	var before := _snapshot(_abs)
	var reader := _reader()
	var began := Time.get_ticks_msec()
	await _read(reader)
	var report := reader.walk_report()
	var folders := reader.folders()
	var counts := reader.folder_counts()
	var expected := PackedStringArray([".cache", ".config", ".local", "bulk", CAFE, "code", "code/game", "code/game/node_modules", "code/game/src", "Documents", "Documents/taxes", "locked", CJK, _emoji_dir()])
	var expected_counts := PackedInt32Array([-1, -1, -1, RealOpenerData.PER_LISTING, 0, 1, 2, 3, -1, 2, 0, -1, 0, 0])
	_check("acceptance: on a fake home, its own values: user \"%s\", host \"%s\", up %d s, the theme's palette; kind \"real\", every field real (%s)" % [reader.user(), reader.host(), reader.uptime_s(), ", ".join(reader.real_fields())], reader.kind() == "real" and reader.user() == USER and reader.host() == HOST and reader.uptime_s() == UPTIME and reader.palette() != null and reader.palette().id == ThemeColors.ID and reader.real_fields() == PackedStringArray(RealOpenerData.FIELDS))
	_check("acceptance: the folder names, in name order, each folder just before what is in it, hidden ones at the top only: %s" % ", ".join(folders), folders == expected, "expected " + ", ".join(expected))
	_check("acceptance: how many entries each holds: a listed folder its count, %d at most (the bulk folder holds %d), node_modules counted (3) and never walked, an unlisted one -1: %s" % [RealOpenerData.PER_LISTING, BULK_FILES, str(Array(counts))], counts == expected_counts, "expected " + str(Array(expected_counts)))
	var deepest := 0
	for f in folders:
		deepest = maxi(deepest, f.split("/").size())
	_check("acceptance: the depth cap: nothing past %d levels (code/game/src is a name, its own folder never listed), nothing inside node_modules or a hidden folder" % RealOpenerData.WALK_DEPTH, deepest == RealOpenerData.WALK_DEPTH and not _has_part(folders, "deep") and not _has_part(folders, "thumbnails") and not folders.has("code/game/node_modules/a"))
	_check("acceptance: a symbolic link is never followed or listed: neither link (into the home folder, out of it) shows, nothing behind the outside one shows, and the walk listed only real folders (%d)" % report.get("listings", -1), not _has_part(folders, "link_out") and not _has_part(folders, "link_in") and not _has_part(folders, "secret-plans") and not folders.has("Documents/notes.txt") and report.get("listings", -1) == 10)
	_check("acceptance: a folder it may not read is skipped quietly: \"locked\" stays a name with no count, nothing inside it shows, and the walk went on to the end (\"%s\")" % report.get("stopped", ""), folders.has("locked") and counts[folders.find("locked")] == -1 and not _has_part(folders, "inside") and report.get("stopped", "") == "done")
	var candidates := {}
	for rel in ["bulk", CAFE, "code", "Documents", "locked", "todo.txt", CJK, _emoji_dir(), "code/game", "Documents/notes.txt", "Documents/taxes", "code/game/node_modules", "code/game/src"]:
		candidates[FileAccess.get_modified_time(_abs.path_join("home").path_join(rel)) + ZONE_S] = true
	for i in BULK_FILES:
		candidates[FileAccess.get_modified_time(_abs.path_join("home/bulk/file-%03d.txt" % i)) + ZONE_S] = true
	var times := reader.file_times()
	var outside := 0
	var newest_first := true
	for i in times.size():
		if not candidates.has(times[i]):
			outside += 1
		if i > 0 and times[i] > times[i - 1]:
			newest_first = false
	_check("acceptance: the modification times of what it walked and nothing else (%d: the 13 visible entries it listed and the %d bulk files it read; no hidden entry, link or node_modules entry), newest first, read as local hours (zone %+d h); \"now\" the pinned clock in the same zone" % [times.size(), RealOpenerData.PER_LISTING, ZONE_S / 3600], times.size() == 13 + RealOpenerData.PER_LISTING and outside == 0 and newest_first and reader.now() == CLOCK + ZONE_S, "%d not from a walked entry" % outside)
	_check("acceptance: wide-character names come back whole, as on disk (\"%s\", \"%s\", \"%s\"), and clean() keeps them" % [CJK, _emoji_dir(), CAFE], folders.has(CJK) and folders.has(_emoji_dir()) and folders.has(CAFE) and OpenerData.clean(CJK, OpenerData.FOLDER_LONGEST) == CJK and OpenerData.clean(_emoji_dir(), OpenerData.FOLDER_LONGEST) == _emoji_dir())
	_check("acceptance: bounded and fast, off the main thread: the whole read took %.1f ms (its budget %d ms), %d entries (cap %d), %d folders listed (cap %d), on a thread of its own; the game's frames ran on meanwhile (%d ms)" % [report.get("ms", -1.0), RealOpenerData.BUDGET_MS, report.get("entries", -1), RealOpenerData.MOST_ENTRIES, report.get("listings", -1), RealOpenerData.MOST_LISTINGS, Time.get_ticks_msec() - began], report.get("off_main", false) and report.get("ms", 1e9) < RealOpenerData.BUDGET_MS and report.get("entries", 0) == 222 and report.get("entries", 0) <= RealOpenerData.MOST_ENTRIES)
	_check("acceptance: read-only: every file, folder and link in the test's folder is as it was, with the same modification time (%d paths), and nothing new appeared" % before.size(), _snapshot(_abs) == before and before.size() > BULK_FILES)
	reader.drop()
	var reaped := not RealOpenerData._running.has(reader)
	_check("acceptance: drop() lets every value go (no field real afterwards, the demo's user back) and its thread is joined", reader.real_fields().is_empty() and reader.user() == DemoOpenerData.USER and reader.folders() == DemoOpenerData.new().folders() and reaped)


static func _has_part(folders: PackedStringArray, part: String) -> bool:
	for f in folders:
		if part in f.split("/"):
			return true
	return false


func _cap_checks() -> void:
	var tops := PackedStringArray([".cache", ".config", ".local", "bulk", CAFE, "code", "Documents", "locked", CJK, _emoji_dir()])
	var few := _reader()
	few.most_entries = 5
	await _read(few)
	var few_ok := true
	for f in few.folders():
		few_ok = few_ok and (tops.has(f) or not few.real_fields().has("folders"))
	_check("acceptance: the entry cap: at %d entries the walk stops (\"%s\", %d read) and keeps what it found (top-level names only, or the demo's if those were all files)" % [few.most_entries, few.walk_report().get("stopped", ""), few.walk_report().get("entries", -1)], few.walk_report().get("stopped", "") == "entries" and few.walk_report().get("entries", -1) == 5 and few_ok)
	var one := _reader()
	one.most_listings = 1
	await _read(one)
	var counts_unknown := true
	for c in one.folder_counts():
		counts_unknown = counts_unknown and c == -1
	_check("acceptance: the listing cap: with 1 folder listed (\"%s\") only the home folder's own names show, none counted" % one.walk_report().get("stopped", ""), one.walk_report().get("stopped", "") == "listings" and one.folders() == tops and counts_unknown)
	var hurried := _reader()
	hurried.budget_ms = 0
	await _read(hurried)
	_check("acceptance: the time cap: with no time left the walk stops at once (\"%s\"); its folders and times are the demo's, the small files' values still real (%s)" % [hurried.walk_report().get("stopped", ""), ", ".join(hurried.real_fields())], hurried.walk_report().get("stopped", "") == "time" and hurried.real_fields() == PackedStringArray(["user", "host", "palette", "uptime"]) and hurried.folders() == DemoOpenerData.new().folders() and hurried.file_times() == DemoOpenerData.new().file_times() and hurried.now() == DemoOpenerData.new().now())
	var shared := _reader()
	shared.home_filesystem = "NFS"
	await _read(shared)
	var none_counted := true
	for c in shared.folder_counts():
		none_counted = none_counted and c == -1
	_check("acceptance: never into another filesystem (a network share, a removable disk): with the home folder's taken as another, every folder under it stays a name, never walked", shared.folders() == tops and none_counted and shared.walk_report().get("listings", -1) == 1 and shared.walk_report().get("stopped", "") == "done")
	for reader in [few, one, hurried, shared]:
		reader.drop()


# --- The theme. ---

func _theme_checks() -> void:
	var p := ThemeColors.palette_from(THEME, false)
	_check("acceptance: a theme's colors.toml maps onto the palette key for key (background #0b1015, foreground #c8d3dc, accent #3fa7d6, green #6cc070), a comment and an unknown key ignored, its mode its own", p != null and p.colors["background"] == "#0b1015" and p.colors["foreground"] == "#c8d3dc" and p.colors["accent"] == "#3fa7d6" and p.colors["green"] == "#6cc070" and not p.colors.has("brown") and p.mode == "dark" and p.id == ThemeColors.ID)
	var legacy := ThemeColors.palette_from("bg = \"#101820\"\nfg = '#d0d8e0'\ncolor1 = \"#cc3333\" # red\ncolor2=\"#33cc33\"\ncolor4 = \"#3366ff\"\ncolor5 = \"#aa55cc\"\ncolor8 = \"#555c66\"\ncolor15 = \"#ffffff\"\n", false)
	var dark := Color.html("#101820").lerp(Color.BLACK, 0.25)
	var bright_red := Color.html("#cc3333").lerp(Color.WHITE, 0.2)
	_check("acceptance: an older theme by Omarchy's own cascade: bg and fg, the ANSI colours (color1 red, color2 green, color4 blue, color5 magenta, color8 muted, color15 bright_foreground), the shades derived (dark_background 25%% toward black, bright_red 20%% toward white)", legacy != null and legacy.colors["background"] == "#101820" and legacy.colors["foreground"] == "#d0d8e0" and legacy.colors["red"] == "#cc3333" and legacy.colors["green"] == "#33cc33" and legacy.colors["magenta"] == "#aa55cc" and legacy.colors["muted"] == "#555c66" and legacy.colors["bright_foreground"] == "#ffffff" and legacy.colors["dark_background"] == "#" + dark.to_html(false) and legacy.colors["bright_red"] == "#" + bright_red.to_html(false))
	var light_file := ThemeColors.palette_from("background = \"#202020\"\nforeground = \"#f0f0f0\"\n", true)
	var bright := ThemeColors.palette_from("background = \"#f4f2ee\"\nforeground = \"#303030\"\n", false)
	var said := ThemeColors.palette_from("theme_type = \"light\"\nbackground = \"#202020\"\nforeground = \"#f0f0f0\"\n", false)
	_check("its mode as Omarchy decides it: a light.mode file beside it, a bright background, or its own word (the older theme_type)", light_file.mode == "light" and bright.mode == "light" and said.mode == "light" and p.mode == "dark")
	var unusable := {
		"its text 1.5:1 on its background": "background = \"#303030\"\nforeground = \"#4a4a4a\"\n",
		"no background": "foreground = \"#ffffff\"\n",
		"no colours at all": "this is not a theme\n[section]\n= nothing\n",
		"empty": "",
		"colours that are not #rrggbb": "background = \"rgb(1,2,3)\"\nforeground = \"white\"\n",
	}
	var wrong := PackedStringArray()
	for why in unusable:
		if ThemeColors.palette_from(unusable[why], false) != null:
			wrong.append(why)
	_check("acceptance: a theme that would make the text unreadable, or is no theme, is not used (null, so the opener draws the default demo palette): %s" % ", ".join(unusable.keys()), wrong.is_empty(), ", ".join(wrong))
	var dim := ThemeColors.palette_from("background = \"#101010\"\nforeground = \"#e8e8e8\"\ngreen = \"#1f3a1f\"\nblue = \"#3a6ea5\"\n", false)
	var drawn := dim.readable()
	var night := OpenerPalette.named(OpenerPalette.DEFAULT_ID)
	var latte := OpenerPalette.named("latte").readable()
	var low := PackedStringArray()
	for pal in [drawn, latte, night.readable()]:
		for key in OpenerPalette.DRAWN:
			if OpenerPalette.contrast(pal.color(key), pal.color("background")) < OpenerPalette.SHAPE_CONTRAST:
				low.append("%s.%s" % [pal.id, key])
	var green := drawn.color("green")
	_check("acceptance: as crisp as the demo palettes: a theme's coloured text under %.0f:1 is drawn pulled toward its foreground until it reaches it (green %.1f:1 -> %.1f:1, still green), latte's green and yellow too; a palette that needs nothing is drawn as it is" % [OpenerPalette.SHAPE_CONTRAST, OpenerPalette.contrast(dim.color("green"), dim.color("background")), OpenerPalette.contrast(green, drawn.color("background"))], low.is_empty() and green.g > green.r and green.g > green.b and drawn.color("blue") == dim.color("blue") and night.readable() == night and dim.colors["green"] == "#1f3a1f", ", ".join(low))
	var big := _abs.path_join("big-theme")
	DirAccess.make_dir_recursive_absolute(big.path_join(".local/state/omarchy/current/theme"))
	_write("big-theme/.local/state/omarchy/current/theme/colors.toml", THEME + "# padding\n".repeat(2000))
	var reader := _reader("big-theme")
	reader._read()
	_check("acceptance: a theme file over %d bytes is refused unread past its cap, and the palette falls back (no palette field)" % RealOpenerData.THEME_LARGEST, not reader.real_fields().has("palette") and reader.palette() == null)


# --- Each value falling back alone. ---

func _fallback_checks() -> void:
	var bare := _reader("empty-home")
	bare.host_files = PackedStringArray([_abs.path_join("sys/missing")])
	bare.uptime_file = _abs.path_join("sys/garbage")
	await _read(bare)
	var demo := DemoOpenerData.new()
	_check("acceptance: each value falls back to the demo's alone: no host file, an uptime that is no number, no theme and an empty home leave only the user real (%s); host \"%s\", the demo's uptime, folders, counts, times and now, no palette" % [", ".join(bare.real_fields()), bare.host()], bare.real_fields() == PackedStringArray(["user"]) and bare.user() == USER and bare.host() == DemoOpenerData.HOST and bare.uptime_s() == DemoOpenerData.UPTIME_S and bare.palette() == null and bare.folders() == demo.folders() and bare.folder_counts() == demo.folder_counts() and bare.file_times() == demo.file_times() and bare.now() == demo.now())
	var hidden := _reader("hidden-home")
	await _read(hidden)
	_check("acceptance: the file times and \"now\" fall back together: a home with only hidden entries shows its folder (real) but has no times, so the late-night line runs on the demo's times and the demo's clock", hidden.real_fields().has("folders") and not hidden.real_fields().has("times") and hidden.folders() == PackedStringArray([".only-hidden"]) and hidden.file_times() == demo.file_times() and hidden.now() == demo.now())
	var homeless := _reader("no-such-home")
	await _read(homeless)
	var rootless := _reader()
	rootless.home = "/"
	rootless.user_name = ""
	await _read(rootless)
	var relative := _reader()
	relative.home = "home"
	await _read(relative)
	var named := _reader()
	named.user_name = ""
	await _read(named)
	_check("no home folder, the root, or a relative one: no walk and no theme (\"%s\"), the rest still read; with no USER the user is the home folder's own name (\"%s\")" % [homeless.walk_report().get("stopped", ""), named.user()], homeless.walk_report().get("stopped", "") == "no home" and not homeless.real_fields().has("folders") and homeless.real_fields().has("host") and rootless.walk_report().get("stopped", "") == "no home" and not rootless.real_fields().has("user") and relative.walk_report().get("stopped", "") == "no home" and named.user() == "home")
	for reader in [bare, hidden, homeless, rootless, relative, named]:
		reader.drop()


# --- The terminal's cells. ---

func _terminal_checks() -> void:
	var mark := "e" + char(0x301)
	var flag := char(0x1F1EF) + char(0x1F1F5)
	var family := char(0x1F468) + char(0x200D) + char(0x1F469) + char(0x200D) + char(0x1F467)
	var wave := char(0x1F44B) + char(0x1F3FD)
	var widths := {CJK: 4, _emoji_dir(): 8, CAFE: 4, mark: 1, flag: 2, family: 2, wave: 2, "ok": 2, "ｆｕｌｌ": 8, "한글": 4}
	var wrong := PackedStringArray()
	for text in widths:
		if CellWidth.total(text) != widths[text]:
			wrong.append("%s: %d" % [text, CellWidth.total(text)])
	_check("acceptance: wide characters take two cells and marks none, as a terminal counts them: CJK, an emoji folder, a combining accent, a flag, a joined family, a skin tone, fullwidth letters, hangul", wrong.is_empty(), ", ".join(wrong))
	var term := FakeTerminal.new()
	term.size = Vector2(1280, 720)
	term.palette = OpenerPalette.named(OpenerPalette.DEFAULT_ID)
	root.add_child(term)
	var cols := term.columns()
	for ch in "~/" + CJK:
		term.put(ch)
	var after_cjk := term.cursor_cell()
	term.newline()
	for i in cols - 1:
		term.put("x")
	term.put(CJK[0])
	var cells := term.row_cells()
	term.back()
	var back_one := term.line_text(term.line_count() - 1)
	term.newline()
	for ch in family:
		term.put(ch)
	term.put(mark[0])
	term.put(mark[1])
	term.back()
	var cluster_back := term.line_text(term.line_count() - 1)
	term.newline()
	for i in cols:
		term.put("a")
	var full := term.row_cells()
	_check("acceptance: the terminal lays rows out in cells: after \"~/%s\" the cursor stands at column %d; a wide character that would split at a row's end (%d columns) starts the next row; back() takes a whole cluster back (an accented letter and its mark); a plain row still holds %d characters" % [CJK, after_cjk.x, cols, cols], after_cjk.x == 6 and cells[-2] == cols - 1 and cells[-1] == 2 and back_one == "x".repeat(cols - 1) and cluster_back == family and full[-2] == cols and full[-1] == 0)
	term.queue_free()
	var long_cjk := OpenerData.clean(CJK.repeat(20), 32)
	var bidi := OpenerData.clean("evil" + char(0x202E) + "txt.exe" + char(0x2066) + char(0x200B), 32)
	var joined := OpenerData.clean(family + "home", 32)
	var cut_mark := OpenerData.clean("a".repeat(28) + mark + "zzzz", 32)
	_check("acceptance: clean() measures in cells and never cuts inside a cluster: twenty \"%s\" cut to %d cells (\"...\" included); a bidirectional override, an isolate and a zero-width space dropped (\"%s\"); a joined emoji kept whole; a letter's mark kept with it" % [CJK, CellWidth.total(long_cjk), bidi], CellWidth.total(long_cjk) <= 32 and long_cjk.ends_with("...") and long_cjk.trim_suffix("...") == CJK.repeat(7) and bidi == "eviltxt.exe" and joined == family + "home" and cut_mark == "a".repeat(28) + mark + "...")


# --- Taking the data. ---

func _take_checks() -> void:
	var stub := NeverReady.new()
	var o: Opener = OpenerScene.instantiate()
	o.data = stub
	root.add_child(o)
	var frames := 0
	while frames < MOST_FRAMES and o.playing() and o.event_time("prompt_done") < 0.0:
		await process_frame
		frames += 1
	var taken := o.event_time("taken")
	var t := o.timing()
	_check("acceptance: a source that is never ready is taken at take_by anyway (%.2f s; take_by %.1f s), during the crash, before the terminal shows (%.2f s): the prompt types from what it has (\"%s\")" % [taken, t.take_by, o.event_time("terminal"), o.prompt_text()], absf(taken - t.take_by) <= 2.0 / FPS and taken < o.event_time("terminal") and o.prompt_text() == "late@stub:~$ ")
	o.skip()
	o.free()
	var late := OpenerTuning.new()
	late.take_by = 7.0
	_check("a timeline that takes its data after the terminal shows is refused (\"%s\")" % ", ".join(late.problems()), late.problems().has("the data is taken after the terminal shows") and OpenerTuning.new().problems().is_empty())
	var demo_o: Opener = OpenerScene.instantiate()
	root.add_child(demo_o)
	await process_frame
	_check("the demo data is ready at once: taken as the opener starts, as in C38", demo_o.taken() and demo_o.event_time("taken") == 0.0)
	demo_o.skip()
	demo_o.free()


# --- The opt-in, through the Esc menu. ---

func _menu_checks() -> void:
	var path := _root + "/settings.cfg"
	var main := await _lab(path, false)
	var menu = main.get_node("Hud").pause_menu()
	var made: Array = []
	menu.real_opener_source = func() -> OpenerData:
		var reader := _reader()
		made.append(reader)
		return reader
	menu.open()
	menu.open_settings()
	await process_frame
	var row := _opener_row(menu)
	var note := false
	for l in menu.find_children("*", "Label", true, false):
		note = note or (l as Label).text == PauseMenu.OPENER_DATA_NOTE
	_check("acceptance: Settings, Privacy and AI: an \"%s\" switch, off unless turned on, with a one-line plain note of what it reads (\"%s\") and a tooltip saying it never reads contents and keeps or sends nothing" % [PauseMenu.OPENER_DATA, PauseMenu.OPENER_DATA_NOTE], row != null and not row.button_pressed and not row.disabled and note and _row_note(row) == "" and PauseMenu.OPENER_DATA_TIP.contains("never opens a file") and PauseMenu.OPENER_DATA_TIP.contains("nothing is saved, logged or sent"))
	menu.close()
	await process_frame
	var off = menu.open_opener()
	_check("acceptance: opt-in off means demo data only: with no answer saved, the opener plays the demo data and no reader is made", off != null and off.data is DemoOpenerData and made.is_empty())
	_key(KEY_ESCAPE)
	await process_frame
	menu.close()
	menu.open()
	menu.open_settings()
	await process_frame
	row.button_pressed = true
	await process_frame
	var saved := FileAccess.get_file_as_string(path)
	_check("turning it on saves opener_real_data=\"on\" next to the other privacy answers, for the next time the opener plays (\"%s\")" % menu.status_text(), saved.contains("opener_real_data=\"on\"") and saved.contains("real_machine_data=\"on\"") and Privacy.opener_real_on(path) and menu.status_text() == "Opener data on: the next time it plays.")
	menu.close()
	await process_frame
	var on = menu.open_opener()
	var o: Opener = on
	var ok_source: bool = o != null and o.data is RealOpenerData and made.size() == 1
	var frames := 0
	while frames < MOST_FRAMES and o != null and is_instance_valid(o) and o.playing() and o.event_time("uptime") < 0.0:
		await process_frame
		frames += 1
	var screen := o.terminal().all_text() if is_instance_valid(o) else ""
	var lines := screen.split("\n")
	var drawn: Dictionary = o.terminal().colors() if is_instance_valid(o) else {}
	_check("acceptance: on, the opener plays the player's own data (here the fake home's): the prompt \"%s\", the theme's colours (background %s), its folders scrolling, its uptime ticking" % [o.prompt_text() if is_instance_valid(o) else "", drawn.get("background", Color.BLACK).to_html(false)], ok_source and o.prompt_text() == USER + "@" + HOST + ":~$ " and lines[0].begins_with(USER + "@" + HOST + ":~$ ") and drawn.get("background") == Color.html("#0b1015") and drawn.get("foreground") == Color.html("#c8d3dc") and lines.has("~/code/game/node_modules") and lines.has("~/" + CJK) and lines.has("~/" + _emoji_dir()) and lines[-2].begins_with("up 3 days, 04:0"), screen.left(200).c_escape())
	_check("its beats keep the PRD's windows on real data: the prompt typed by 0:15 (%.2f s), the uptime inside 0:15 to 0:35 (%.2f s); the late-night line from its times (\"%s\")" % [o.event_time("prompt_done"), o.event_time("uptime"), o.late_text()], o.event_time("prompt_done") < 15.0 and o.event_time("uptime") > 15.0 and o.event_time("uptime") < 35.0 and o.late_text() == Opener.NEVER_LATE + Opener.NEVER_LATE_ECHO)
	var reader: RealOpenerData = made[0]
	_key(KEY_ESCAPE)
	await process_frame
	await process_frame
	_check("acceptance: as it ends (Esc here), the reader is dropped: no value of the machine's left in it, the menu back as it was", reader.real_fields().is_empty() and reader.user() == DemoOpenerData.USER and menu.is_open() and not menu.showing_opener())
	menu.close()
	Privacy.save_real_data(false, path)
	var no_real = menu.open_opener()
	_check("acceptance: real-machine data off beats the answer: demo data, no reader made", no_real != null and no_real.data is DemoOpenerData and made.size() == 1)
	_key(KEY_ESCAPE)
	await process_frame
	menu.close()
	await _drop(main)
	Privacy.save_real_data(true, path)
	var demo_main := await _lab(path, true)
	var demo_menu = demo_main.get_node("Hud").pause_menu()
	demo_menu.real_opener_source = func() -> OpenerData:
		made.append(null)
		return _reader()
	var demo_run = demo_menu.open_opener()
	var demo_ok: bool = demo_run != null and demo_run.data is DemoOpenerData and made.size() == 1
	_key(KEY_ESCAPE)
	await process_frame
	demo_menu.open_settings()
	await process_frame
	var demo_note := _row_note(_opener_row(demo_menu)) == PauseMenu.REAL_DATA_DEMO
	_check("acceptance: a demo run (--demo, or the link's demo) beats the answer too: demo data with it on, no reader made, and the row says \"%s\"" % PauseMenu.REAL_DATA_DEMO, demo_ok and demo_note and Privacy.opener_real_on(path))
	demo_menu.close()
	await _drop(demo_main)


## The settings row's "opener data" switch, or null.
static func _opener_row(menu: Node) -> CheckButton:
	for b in menu.find_children("*", "CheckButton", true, false):
		if (b as CheckButton).tooltip_text == PauseMenu.OPENER_DATA_TIP:
			return b
	return null


## The note beside a settings row's switch.
static func _row_note(row: CheckButton) -> String:
	if row == null or row.get_index() + 1 >= row.get_parent().get_child_count():
		return "(none)"
	var note := row.get_parent().get_child(row.get_index() + 1) as Label
	return note.text if note != null else "(none)"


## The arena alone, practice on, a link parked for its guide HUD: its settings in `path`, on demo data or not (a
## headless run's link is inert either way: no detector, no AI, no call).
func _lab(path: String, demo: bool) -> Node:
	GameSettings.current().set_value("gameplay", "practice", true)
	GameSettings.current().set_value("gameplay", "ice", false)
	var link := Link.new()
	link.settings_path = path
	link.demo = demo
	Link.park(link)
	var main = MainScene.instantiate()
	root.add_child(main)
	_arenas.append(main)
	main.get_node("Hud").guide().focus_check = func(): return false
	main.get_node("Hud").round_hud()._left_s = LONG_ROUND_S
	main.get_node("Player").assume_captured = true
	await process_frame
	return main


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		main.free()
	_arenas.erase(main)
	var left = Link.take_parked()
	if left != null:
		left.shut_down(null)
	await process_frame


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	root.push_input(down)


func _cleanup() -> void:
	for node in _arenas.duplicate():
		await _drop(node)
	paused = false
	GameSettings.current().reset()
	Controls.apply_binds({})
	FileAccess.set_unix_permissions(_abs.path_join("home/locked"), FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER)
	_wipe(_abs)
	_check("the test's own folder is gone, nothing of it left under user://", not DirAccess.dir_exists_absolute(_abs))
	await process_frame
	# A stopped sound is let go on the audio thread's next mix, in real time: give it that before quitting.
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

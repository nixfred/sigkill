class_name FolderReader
extends RefCounted
## The filesystem map's real layer (W2, PRD 5.5): a read-only reader of the player's home folder, made only when the
## player has said yes (the same answer as the opener's real data, the Audit Trail visor's and the process hunt's:
## Settings, Privacy and AI, "opener data", with real-machine data on, never on a demo run; scripts/fsmap/folder_map.gd
## asks AuditVisor.real_gate_for()). Off by default: when it is off, no reader is made at all and nothing is read.
##
## What it reads, all of it: the names in a folder's listing (DirAccess, hidden entries left out), whether each is a
## folder or a symbolic link, and each plain file's size (FileAccess.get_size(): a stat of the path, which never opens
## the file; only for what FileAccess.file_exists(), a stat too, calls a regular file: a pipe, a socket or a device is
## counted and never sized, so nothing blocks and nothing prints). A file's
## name is used only for its extension's kind (FolderTree.kind_of_name()) and then dropped: no file name is kept, shown
## or sent. It never opens a file, never reads a byte of one, never follows a symbolic link (a link, to a folder or a
## file, is skipped outright, so nothing outside home is ever reached), never goes into a hidden folder, and never
## creates, writes, renames, moves, deletes or runs anything. It writes, saves, logs and sends nothing.
##
## Caps, so a huge home never hangs the game: a scan reads the folder asked for and DEPTH_MOST levels under it, at most
## ENTRIES_MOST entries a folder, DIRS_MOST subfolders listed a folder, SCAN_ENTRIES_MOST entries a scan, NODES_MOST
## folders kept, and SCAN_S of wall-clock a scan; whatever a cap cuts is marked partial ("at least"). It reads a slice a
## frame (step(): at most budget_us of the main thread), a folder's listing kept open across frames. drop() lets every
## name and number go: they live only here, in memory, while the map runs.

const BUDGET_US := 1500
const DEPTH_MOST := 3
const ENTRIES_MOST := 4000
const DIRS_MOST := 48
const SCAN_ENTRIES_MOST := 40000
const NODES_MOST := 6000
const SCAN_S := 8.0

## Every folder listed and every file sized by any reader this run, and every reader made (the tests' proof that an
## off map reads nothing).
static var made := 0
static var lists := 0
static var sizes := 0

## The home folder (a test hands in a fake one under its own folder). Never shown, never kept anywhere else.
var root := ""
var budget_us := BUDGET_US
var depth_most := DEPTH_MOST
var entries_most := ENTRIES_MOST
var dirs_most := DIRS_MOST
var scan_entries_most := SCAN_ENTRIES_MOST
var nodes_most := NODES_MOST
var scan_s := SCAN_S
## For the tests only (off in the game): every folder listed and every file sized, as paths under root.
var keep_trail := false
var listed := PackedStringArray()
var sized := PackedStringArray()
## Links met and skipped, hidden entries never listed (the listing leaves them out), for the checks.
var links_skipped := 0
var scans := 0

var home: Dictionary = {}
var _nodes := 0
var _done := {}
var _target := ""
var _scanning := false
var _queue: Array = []
var _dir: DirAccess = null
var _dir_rel := ""
var _dir_node: Dictionary = {}
var _dir_depth := 0
var _dir_entries := 0
var _scan_entries := 0
var _scan_started := 0


func _init(at: String) -> void:
	made += 1
	root = at
	home = FolderTree.node(FolderTree.HOME_NAME)
	_nodes = 1


## The node at `path` (names from home), or {} while it has not been listed.
func node_at(path: PackedStringArray) -> Dictionary:
	return FolderTree.find(home, path)


## True once a scan of `path` has finished (its own entries and its subfolders' sizes, to the caps).
func ready_for(path: PackedStringArray) -> bool:
	return _done.has(_rel(path))


## Asks for `path` to be scanned next (any scan under way gives way to it). Nothing when it is already done.
func want(path: PackedStringArray) -> void:
	var rel := _rel(path)
	if _done.has(rel) or (_scanning and _target == rel):
		return
	_close()
	_target = rel
	_scanning = true
	_queue = [[rel, 0]]
	_scan_entries = 0
	_scan_started = Time.get_ticks_msec()


func busy() -> bool:
	return _scanning


## Reads on, within the frame's budget. True when the scan asked for finished this step.
func step(_delta: float) -> bool:
	if not _scanning:
		return false
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start < budget_us:
		if Time.get_ticks_msec() - _scan_started >= int(scan_s * 1000.0) or _scan_entries >= scan_entries_most:
			_cut_short()
			break
		if _dir == null:
			if _queue.is_empty():
				break
			var next: Array = _queue.pop_front()
			_open(str(next[0]), int(next[1]))
			continue
		_read_entry()
	if _dir == null and _queue.is_empty():
		_finish()
		return true
	return false


## Every name and number let go.
func drop() -> void:
	_close()
	_queue.clear()
	_done.clear()
	_target = ""
	_scanning = false
	home = FolderTree.node(FolderTree.HOME_NAME)
	_nodes = 1


func _rel(path: PackedStringArray) -> String:
	return "/".join(path)


func _abs(rel: String) -> String:
	return root if rel == "" else root.path_join(rel)


func _open(rel: String, depth: int) -> void:
	var n := FolderTree.find(home, rel.split("/", false))
	if n.is_empty():
		return
	if bool(n["scanned"]):
		# Listed by an earlier scan: its subfolders still go in, as deep as this scan reaches.
		if depth < depth_most:
			for d in n["dirs"]:
				_queue.append([(rel + "/" if rel != "" else "") + str(d["name"]), depth + 1])
		return
	# Listed afresh: whatever a scan cut off mid-listing (another folder asked for first) is counted again from nothing,
	# never twice.
	n["own_files"] = 0
	n["own_size"] = 0
	n["more"] = 0
	# Its subfolders from the cut-off listing (and anything listed under them since) were counted as nodes: they leave the
	# count with it, or each interrupted scan of this folder would eat into nodes_most for good.
	_nodes = maxi(_nodes - (FolderTree.count(n) - 1), 1)
	n["dirs"] = []
	for k in FolderTree.KINDS:
		n["kinds"][k] = 0
	lists += 1
	if keep_trail:
		listed.append(rel)
	_dir = DirAccess.open(_abs(rel))
	if _dir == null:
		n["scanned"] = true
		n["partial"] = true
		return
	_dir.include_hidden = false
	_dir.include_navigational = false
	if _dir.list_dir_begin() != OK:
		_dir = null
		n["scanned"] = true
		n["partial"] = true
		return
	_dir_rel = rel
	_dir_node = n
	_dir_depth = depth
	_dir_entries = 0


func _read_entry() -> void:
	var name := _dir.get_next()
	if name == "":
		_dir_node["scanned"] = true
		_close()
		return
	if name.begins_with(".") or name.contains("/"):
		return  # hidden (never listed anyway), and never a name with a path in it
	_dir_entries += 1
	_scan_entries += 1
	if _dir.is_link(name):
		links_skipped += 1
		return  # a link is never followed, to a folder or a file
	if _dir.current_is_dir():
		if (_dir_node["dirs"] as Array).size() >= dirs_most or _nodes >= nodes_most:
			_dir_node["more"] = int(_dir_node["more"]) + 1
		else:
			var child := FolderTree.node(name)
			_dir_node["dirs"].append(child)
			_nodes += 1
			if _dir_depth < depth_most:
				_queue.append([(_dir_rel + "/" if _dir_rel != "" else "") + name, _dir_depth + 1])
	else:
		var full := _abs(_dir_rel).path_join(name)
		# A pipe, a socket or a device is counted, never sized (W3's fold-in): FileAccess.file_exists() is a stat that says
		# no to anything not a regular file, quietly, where get_size() printed an engine error refusing it.
		var bytes := FileAccess.get_size(full) if FileAccess.file_exists(full) else 0
		sizes += 1
		if keep_trail:
			sized.append((_dir_rel + "/" if _dir_rel != "" else "") + name)
		_dir_node["own_files"] = int(_dir_node["own_files"]) + 1
		_dir_node["own_size"] = int(_dir_node["own_size"]) + maxi(bytes, 0)
		var kind := FolderTree.kind_of_name(name)
		_dir_node["kinds"][kind] = int(_dir_node["kinds"][kind]) + 1
	if _dir_entries >= entries_most:
		_dir_node["partial"] = true
		_dir_node["scanned"] = true
		_close()


func _close() -> void:
	if _dir != null:
		_dir.list_dir_end()
	_dir = null
	_dir_node = {}


## A cap cut the scan short: the folder being read is partial, what was still queued is known by name only.
func _cut_short() -> void:
	if not _dir_node.is_empty():
		_dir_node["partial"] = true
		_dir_node["scanned"] = true
	_close()
	_queue.clear()


func _finish() -> void:
	FolderTree.total(home)
	_done[_target] = true
	_target = ""
	_scanning = false
	scans += 1

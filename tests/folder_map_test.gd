extends SceneTree
## Headless test of filesystem maps (W2, PRD 5.5: the folder map). scripts/check.sh runs it as step 66, and any FAIL
## exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/folder_map_test.gd
##
## Fixtures are fake only: the mapping is checked on the game's own demo tree and folders made up here, and the real
## layer reads a fake folder tree the test makes under its own folder (fake names, a planted word in every file that must
## never come out, a hidden folder, links out of the tree, a deep chain, a crowded folder). Nothing of this machine is
## read, named or printed.
##
## The code: nothing of the map runs, signals, sends, writes, renames, moves or deletes anything; the reader opens no
## file (sizes from a stat only). The mapping: a folder a room, its size the room's scale and height, its files how busy
## it is and how many daemons live there, its subfolders doors (biggest first, capped) and a back door; node_modules the
## maze, never a room. The ruins' own districts unchanged. The maze: every cell reachable, the way out the farthest cell,
## the ways down at dead ends, every closed side a wall, a new maze every level, the same level the same maze, a path out
## from anywhere. The reader: names, sizes and counts only, hidden folders skipped, links never followed out of the root,
## its caps (depth, entries, time, the frame's budget), the tree as it was after it read. The arena: off by default, the
## real layer off by default; queued, home's room, its doors named, the roster; through a door and back; into the maze,
## deeper, and out by the way out; the visor's breadcrumb, door numbers and lines; labels names only. The Esc menu's
## entry. The world modes' kill credit capped. Its files live in its own folder under user://, removed at the end.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## The map's code: none of it may run, signal, send, write, rename, move or delete anything.
const MAP_CODE := ["res://scripts/fsmap/folder_map.gd", "res://scripts/fsmap/folder_rooms.gd", "res://scripts/fsmap/folder_tree.gd", "res://scripts/fsmap/demo_folders.gd", "res://scripts/fsmap/node_maze.gd", "res://scripts/fsmap/maze_world.gd", "res://scripts/fsmap/folder_map_hud.gd", "res://scripts/fsmap/folder_reader.gd"]
const NEVER := ["OS.execute", "create_process", "execute_with_pipe", "OS.kill", "kill(", "shell_open", "move_to_trash", "HTTPRequest", "HTTPClient", "PacketPeer", "StreamPeer", "TCPServer", "UDPServer", "WebSocket", "store_", "ResourceSaver", ".remove(", "remove_absolute", "rename", ".copy(", "copy_absolute", "make_dir", "create_link", "set_unix_permissions", "set_hidden_attribute", "set_read_only_attribute", "set_extended_attribute", "remove_extended_attribute", "FileAccess.WRITE", "FileAccess.READ_WRITE", "FileAccess.WRITE_READ", "user://", "OS.crash", "print(", "push_warning"]
## Only the reader touches files or folders at all, and it opens none: these are never in it.
const READER := "res://scripts/fsmap/folder_reader.gd"
const READER_NEVER := ["FileAccess.open", "get_file_as_string", "get_file_as_bytes", "get_buffer", "get_line", "get_as_text", "get_csv_line", "get_var", "load(", "ResourceLoader", "Image.", "open_compressed", "open_encrypted", "read_link", "get_extended_attribute"]
const PLANT := "PLANTED-WORD-NEVER-READ"
const MOST_FRAMES := 2400
const LONG_ROUND_S := 100000.0
## Pinned here, so a changed constant cannot move its own check: the brief's caps and the map's.
const DOORS_MOST := 10
const DAEMONS_MOST := 6

var _fails := 0
var _checks := 0
var _abs := ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_abs = ProjectSettings.globalize_path("user://folder-map-test-%d" % OS.get_process_id())
	if DirAccess.dir_exists_absolute(_abs):
		print("FAIL the test's own folder already exists; not touching it")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_abs)
	Controls.ensure()
	GameSettings.current().reset()
	SettingsApply.apply_audio(GameSettings.current())
	MissionRunner.clear_pending()
	ProcHunt.clear()
	FolderMap.clear()
	MissionProgress.current().path = _abs.path_join("progress.cfg")
	MissionProgress.current().clear()
	Progress.current().path = _abs.path_join("progress.cfg")
	Progress.current().clear()
	AuditVisor.remembered = false
	_code_checks()
	_mapping_checks()
	_layout_checks()
	_maze_checks()
	await _reader_checks()
	await _arena_checks()
	await _walk_checks()
	await _maze_arena_checks()
	await _real_arena_checks()
	await _menu_checks()
	_credit_checks()
	await _cleanup()
	print("FOLDER MAP: %d checks" % _checks)
	print("FOLDER MAP RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


# --- The code. ---

func _code_checks() -> void:
	var found := PackedStringArray()
	for path in MAP_CODE:
		var code := _code_of(path)
		if code == "":
			found.append(path + ": unreadable")
		for word in NEVER:
			if code.contains(word):
				found.append("%s: %s" % [path.get_file(), word])
	_check("acceptance (safety): nothing in the map can write, remove, rename, move, copy, link, run, signal or send: no such call in any of its %d files" % MAP_CODE.size(), found.is_empty(), ", ".join(found))
	var reader := _code_of(READER)
	var bad := PackedStringArray()
	for word in READER_NEVER:
		if reader.contains(word):
			bad.append(word)
	_check("acceptance (safety): the reader never opens a file's contents: no open, read or load of a file anywhere in it; a size only through FileAccess.get_size (a stat), a folder through DirAccess's listing, links checked first", bad.is_empty() and reader.contains("FileAccess.get_size(") and reader.contains("is_link(") and reader.contains("include_hidden = false"), ", ".join(bad))
	var touch := PackedStringArray()
	for path in MAP_CODE:
		if path != READER and (_code_of(path).contains("FileAccess") or _code_of(path).contains("DirAccess")):
			touch.append(path.get_file())
	_check("only the reader touches the filesystem at all: the rest of the map has no FileAccess or DirAccess", touch.is_empty(), ", ".join(touch))


## A script's code with its comments taken out (the words in its notes are not calls).
func _code_of(path: String) -> String:
	var out := PackedStringArray()
	for line in FileAccess.get_file_as_string(path).split("\n"):
		var at := line.find("#")
		out.append(line.substr(0, at) if at >= 0 else line)
	return "\n".join(out)


# --- The mapping (pure). ---

func _folder(name: String, bytes: int, files: int, kind: String = "other", dirs: Array = []) -> Dictionary:
	var n := FolderTree.node(name)
	n["own_size"] = bytes
	n["own_files"] = files
	if files > 0:
		n["kinds"][kind] = files
	n["dirs"] = dirs
	n["scanned"] = true
	for d in dirs:
		d["scanned"] = true
	FolderTree.total(n)
	return n


func _mapping_checks() -> void:
	var demo := DemoFolders.new()
	# Every folder of the demo tree a room the kit takes (no problems), node_modules a maze.
	var problems := PackedStringArray()
	var rooms := 0
	var mazes := 0
	var stack: Array = [[PackedStringArray(), demo.root]]
	while not stack.is_empty():
		var top: Array = stack.pop_back()
		var at: PackedStringArray = top[0]
		var n: Dictionary = top[1]
		if FolderRooms.is_maze(n):
			mazes += 1
			for lv in [1, 2, 5]:
				problems.append_array(FolderRooms.maze_set(n, at, lv).problems())
			continue
		rooms += 1
		var s := FolderRooms.set_for(n, at)
		problems.append_array(s.problems())
		if not s.back_door or s.doors.size() != mini((n["dirs"] as Array).size(), DOORS_MOST):
			problems.append("%s: doors %d for %d subfolders" % [FolderTree.path_text(at), s.doors.size(), (n["dirs"] as Array).size()])
		for d in n["dirs"]:
			stack.append([at + PackedStringArray([str(d["name"])]), d])
	_check("rooms from folders: every folder of the demo tree is a room the ruins kit takes (%d rooms, no problems), a door a subfolder (at most %d) and a back door; node_modules a maze, never a room (%d)" % [rooms, DOORS_MOST, mazes], problems.is_empty() and rooms >= 30 and mazes >= 2, ", ".join(problems.slice(0, 6)))
	# Height and scale from size: a tiny folder is a small low room, a huge one a big tall one, growing with size.
	var tiny := FolderRooms.set_for(_folder("scratch", 4 * 1024, 3, "code"), PackedStringArray(["scratch"]))
	var huge := FolderRooms.set_for(_folder("Videos", 150 * 1024 * 1024 * 1024, 212, "video"), PackedStringArray(["Videos"]))
	var grows := true
	var last_tall := -1.0
	var last_cells := Vector2i.ZERO
	for p in range(2, 14):
		var bytes := int(pow(10.0, float(p)))
		var c := FolderRooms.cells_for(bytes)
		var tall := FolderRooms.tall_for(bytes)
		grows = grows and c.x >= last_cells.x and c.y >= last_cells.y and tall >= last_tall
		last_tall = tall
		last_cells = c
	_check("height and scale from size: a 4 KB folder's room (%s cells, towers x%.2f) is smaller and lower than a 150 GB one's (%s, x%.2f), and the room grows with size, never shrinks" % [str(tiny.cells), tiny.tall, str(huge.cells), huge.tall], tiny.cells.x < huge.cells.x and tiny.cells.y < huge.cells.y and tiny.tall * 3.0 < huge.tall and huge.towers > tiny.towers and huge.giants > tiny.giants and grows and FolderRooms.cells_for(1024) == RuinsLayout.CELLS_LEAST and FolderRooms.cells_for(1024 * 1024 * 1024 * 1024) == RuinsLayout.CELLS_MOST)
	# Busy from the file count; daemons from it too.
	var empty := FolderRooms.set_for(_folder("Templates", 0, 0), PackedStringArray(["Templates"]))
	var busy := FolderRooms.set_for(_folder("screenshots", 3 * 1024 * 1024 * 1024, 1820, "image"), PackedStringArray(["screenshots"]))
	var calm := FolderRooms.set_for(_folder("calm", 3 * 1024 * 1024 * 1024, 4, "image"), PackedStringArray(["calm"]))
	var daemons_grow := true
	for f in [0, 1, 9, 99, 999, 9999]:
		daemons_grow = daemons_grow and FolderRooms.daemons_for(f) <= FolderRooms.daemons_for(f * 10 + 10)
	_check("busy from the file count: an empty folder is an empty pristine hall with no daemons, a folder of 1,820 files has more ruins, cover and signs than one of 4 the same size, and up to %d daemons (more files, more daemons)" % DAEMONS_MOST, empty.pristine and empty.cover == 0 and empty.blocks == 0 and FolderRooms.daemons_for(0) == 0 and busy.cover > calm.cover and busy.blocks >= calm.blocks and busy.signs > calm.signs and FolderRooms.daemons_for(1820) > FolderRooms.daemons_for(4) and FolderRooms.daemons_for(100000000) == DAEMONS_MOST and daemons_grow)
	var regs := {"code": FolderRooms.set_for(_folder("a", 9000, 9, "code"), PackedStringArray(["a"])).register, "video": huge.register, "docs": FolderRooms.set_for(_folder("b", 9000, 9, "docs"), PackedStringArray(["b"])).register, "audio": FolderRooms.set_for(_folder("c", 9000, 9, "audio"), PackedStringArray(["c"])).palette}
	_check("the room's register from what the folder holds: code the Matrix, video the ruins, documents Tron, audio the ruins in the abyss palette", regs["code"] == "matrix" and regs["video"] == "cyberpunk" and regs["docs"] == "tron" and regs["audio"] == "abyss", str(regs))
	# Doors biggest first, each as big as its folder.
	var kids: Array = []
	for i in 14:
		kids.append(_folder("d%02d" % i, (i + 1) * 1000 * (i + 1) * 1000, 2))
	var parent := _folder("parent", 10, 1, "other", kids)
	var ps := FolderRooms.set_for(parent, PackedStringArray(["parent"]))
	var ordered := true
	for i in range(1, ps.doors.size()):
		ordered = ordered and ps.doors[i] <= ps.doors[i - 1]
	_check("subfolders are doors, biggest first, at most %d (the rest counted, not built), each door's share its folder's size" % DOORS_MOST, ps.doors.size() == DOORS_MOST and ordered and str(FolderRooms.doors_of(parent)[0]["name"]) == "d13" and ps.doors[0] > ps.doors[DOORS_MOST - 1])
	# Names on the signs cleaned to the sign font, never a word the ruins keep off them; labels never `~`.
	var odd := FolderRooms.set_for(_folder("weïrd ~ folder pid 6666 name that is long", 1000, 1, "other", [_folder("nohup-stuff", 10, 1)]), PackedStringArray(["x"]))
	_check("the signs and monoliths carry folder names cleaned to the sign font (upper case, unknown letters \"_\", at most %d), never a word the ruins keep off their signs" % RuinsLayout.NAME_LAST, odd.problems().is_empty(), ", ".join(odd.problems()))


# --- The layout's doors. ---

func _layout_checks() -> void:
	var demo := DemoFolders.new()
	var videos := demo.node_at(PackedStringArray(["Videos"]))
	var s := FolderRooms.set_for(videos, PackedStringArray(["Videos"]))
	var layout := RuinsLayout.new(s)
	var void_ok := true
	var seen := {}
	for d in layout.doors:
		var c: Vector2i = d["cell"]
		void_ok = void_ok and layout.cell(c + RuinsLayout.SIDES[int(d["side"])]) == RuinsLayout.Cell.VOID and layout.cell(c) == RuinsLayout.Cell.FLOOR
		seen["%s:%d" % [str(c), int(d["side"])]] = true
	var back := layout.door(-1)
	var clear := true
	for t in layout.towers:
		if not t["inside"]:
			clear = clear and not layout.in_door_way(t["at"], 0.0)
	var thresholds := 0
	for name in layout.points:
		if str(name).begins_with("folder_door_"):
			thresholds += 1
	_check("the doors stand on the floor's edge onto the void, one a subfolder (%d) and the back door behind the start, no two on one edge, no tower in a door's way, every threshold a point (no cover in it, walkable from the start)" % s.doors.size(), layout.doors.size() == s.doors.size() + 1 and void_ok and seen.size() == layout.doors.size() and not back.is_empty() and back["cell"] == layout.start_cell and int(back["side"]) == 2 and clear and thresholds == layout.doors.size() and layout.unreachable().is_empty())
	var big := layout.door(0)
	var small := layout.door(s.doors.size() - 1)
	_check("a bigger folder's door stands taller and its island is bigger and farther out (%.1f m and %.1f m tall)" % [RuinsPieces.door_tall(big), RuinsPieces.door_tall(small)], RuinsPieces.door_tall(big) > RuinsPieces.door_tall(small) and float(big["island_r"]) > float(small["island_r"]) and float(big["bridge"]) > float(small["bridge"]))
	var same := true
	for b in RuinsBook.all():
		var l := RuinsLayout.of(b)
		same = same and l.doors.is_empty() and is_equal_approx(b.tall, 1.0) and b.doors.is_empty() and not b.back_door
		for t in l.towers:
			if not t["inside"]:
				same = same and float(t["tall"]) >= RuinsLayout.TOWER_TALL.x and float(t["tall"]) <= RuinsLayout.TOWER_TALL.y
	_check("the ruins' own districts are as they were: no doors, towers at their usual height (tall 1)", same)


# --- The maze (pure). ---

func _maze_of(level: int) -> NodeMaze:
	var demo := DemoFolders.new()
	var at := PackedStringArray(["Code", "starfall", "node_modules"])
	var n := demo.node_at(at)
	var s := FolderRooms.maze_set(n, at, level)
	return NodeMaze.new(RuinsLayout.new(s), FolderRooms.seed_for(at, level) ^ 0x5a5a, level)


func _closed_sides(m: NodeMaze) -> int:
	var n := 0
	for c in m.cells:
		for side in 4:
			var o: Vector2i = c + RuinsLayout.SIDES[side]
			var floor := m.layout.cell(o) == RuinsLayout.Cell.FLOOR
			if not floor:
				n += 1
			elif (side == 1 or side == 2) and not m.is_open(c, side):
				n += 1
	return n


func _maze_checks() -> void:
	var ok := true
	var detail := ""
	for level in [1, 2, 3, 6]:
		var m := _maze_of(level)
		var far := 0
		for c in m.cells:
			far = maxi(far, int(m.dist.get(c, -1)))
		var dead := true
		for p in m.pits:
			var ways := 0
			for side in 4:
				ways += 1 if m.is_open(p, side) else 0
			dead = dead and ways == 1 and p != m.start and p != m.exit
		var this := m.reachable_from_start() == m.cells.size() and int(m.dist[m.exit]) == far and far > 8 and dead and m.pits.size() >= 1 and m.pits.size() <= NodeMaze.PITS_MOST and m.walls.size() == _closed_sides(m)
		ok = ok and this
		if not this:
			detail = "level %d: reach %d of %d, way out %d of %d, %d ways down, walls %d of %d\n%s" % [level, m.reachable_from_start(), m.cells.size(), int(m.dist.get(m.exit, -1)), far, m.pits.size(), m.walls.size(), _closed_sides(m), m.ascii()]
	_check("node_modules maze generation: every cell reachable from the start, the way out the farthest cell along the maze, the ways down at dead ends (1 to %d), a wall on every closed side and the floor's edge walled (levels 1, 2, 3, 6)" % NodeMaze.PITS_MOST, ok, detail)
	var a := _maze_of(4)
	var b := _maze_of(4)
	var c := _maze_of(5)
	var deep := _maze_of(40)
	_check("endless: a way down makes a new maze every level, bigger to the kit's most, and the same level is always the same maze (level 40 still a maze)", a.ascii() == b.ascii() and a.walls.size() == b.walls.size() and a.ascii() != c.ascii() and c.cells.size() >= a.cells.size() and deep.reachable_from_start() == deep.cells.size() and deep.layout.size.x <= RuinsLayout.CELLS_MOST.x and deep.layout.size.y <= RuinsLayout.CELLS_MOST.y)
	var m := _maze_of(2)
	var way := m.path(m.start, m.exit)
	var walks := way.size() >= 2 and way[0] == m.start and way[way.size() - 1] == m.exit
	for i in range(1, way.size()):
		var step: Vector2i = way[i] - way[i - 1]
		var side := RuinsLayout.SIDES.find(step)
		walks = walks and side >= 0 and m.is_open(way[i - 1], side)
	var from_any := true
	for cell in m.cells:
		from_any = from_any and not m.path(cell, m.exit).is_empty()
	_check("the maze has a way out: a path from the start to the way out through open sides only (%d cells), and one from every cell" % way.size(), walks and from_any)


# --- The reader, on a fake tree. ---

func _write(path: String, bytes: int) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var text := (PLANT + " ").repeat(bytes / (PLANT.length() + 1) + 1)
	f.store_string(text.left(maxi(bytes, PLANT.length())))
	f.close()


func _fake_home() -> String:
	var home := _abs.path_join("fakehome")
	for d in ["Alpha", "Alpha/Beta", "Alpha/Beta/Gamma", "Alpha/Beta/Gamma/Delta", "Alpha/Beta/Gamma/Delta/Epsilon", ".hidden", ".hidden/inner", "Crowd", "node_modules", "node_modules/left-pad-pro", "Empty"]:
		DirAccess.make_dir_recursive_absolute(home.path_join(d))
	DirAccess.make_dir_recursive_absolute(_abs.path_join("outside/deep"))
	_write(home.path_join("Alpha/one.mp4"), 4000)
	_write(home.path_join("Alpha/two.mp4"), 6000)
	_write(home.path_join("Alpha/notes.txt"), 300)
	_write(home.path_join("Alpha/Beta/song.flac"), 2500)
	_write(home.path_join("Alpha/Beta/Gamma/Delta/far.txt"), 100)
	_write(home.path_join("Alpha/Beta/Gamma/Delta/Epsilon/farther.txt"), 100)
	_write(home.path_join(".hidden/secret.txt"), 999)
	_write(home.path_join(".hidden/inner/secret2.txt"), 999)
	_write(home.path_join(".dotfile"), 500)
	for i in 30:
		_write(home.path_join("Crowd/item%02d.png" % i), 100)
	_write(home.path_join("node_modules/left-pad-pro/index.js"), 800)
	_write(_abs.path_join("outside/secret.txt"), 7777)
	_write(_abs.path_join("outside/deep/more.txt"), 7777)
	var dir := DirAccess.open(home)
	dir.create_link(_abs.path_join("outside"), home.path_join("linkout"))
	dir.create_link(_abs.path_join("outside/secret.txt"), home.path_join("linkfile.txt"))
	dir.create_link(_abs.path_join("outside"), home.path_join("Alpha/linkback"))
	return home


## Every file and folder under `at` (links themselves, never followed), with its size and time: the tree as it stands.
func _snapshot(at: String, rel: String = "") -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(at)
	if dir == null:
		return out
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := at.path_join(name)
		if dir.is_link(name):
			out.append("L %s/%s" % [rel, name])
		elif dir.current_is_dir():
			out.append("D %s/%s" % [rel, name])
			out.append_array(_snapshot(full, rel + "/" + name))
		else:
			out.append("F %s/%s %d %d" % [rel, name, FileAccess.get_size(full), FileAccess.get_modified_time(full)])
		name = dir.get_next()
	out.sort()
	return out


func _scan(reader: FolderReader, path: PackedStringArray) -> Array:
	reader.want(path)
	var steps := 0
	var worst := 0
	while steps < 20000:
		var t := Time.get_ticks_usec()
		var done := reader.step(1.0 / 60.0)
		worst = maxi(worst, Time.get_ticks_usec() - t)
		steps += 1
		if done:
			break
	return [steps, worst]


func _reader_checks() -> void:
	var home := _fake_home()
	var before := _snapshot(_abs)
	var reader := FolderReader.new(home)
	reader.keep_trail = true
	reader.depth_most = 2
	reader.entries_most = 12
	reader.budget_us = 1500
	var run := _scan(reader, PackedStringArray())
	var ready := reader.ready_for(PackedStringArray())
	var alpha := reader.node_at(PackedStringArray(["Alpha"]))
	_check("the reader reads names, sizes and counts: Alpha's 3 files are 10,300 bytes, 2 videos and a text by their names' extensions, its folder Beta listed", ready and int(alpha.get("own_files", 0)) == 3 and int(alpha.get("own_size", 0)) == 10300 and int(alpha["kinds"]["video"]) == 2 and int(alpha["kinds"]["docs"]) == 1 and not reader.node_at(PackedStringArray(["Alpha", "Beta"])).is_empty(), str(alpha.get("own_size", -1)))
	var text := JSON.stringify(reader.home)
	_check("acceptance (safety): no file's contents came through: the planted word in every file is nowhere in what the reader holds; no file name is kept (only folder names)", not text.contains(PLANT) and not text.contains("one.mp4") and not text.contains("notes.txt"))
	var hidden := text.contains(".hidden") or text.contains("secret") or text.contains(".dotfile")
	var listed_hidden := false
	for p in reader.listed + reader.sized:
		listed_hidden = listed_hidden or p.contains(".hidden") or p.contains(".dotfile")
	_check("hidden folders skipped: nothing of .hidden (or a dotfile) listed, sized or held", not hidden and not listed_hidden, text.left(200))
	var escaped := false
	for p in reader.listed + reader.sized:
		escaped = escaped or p.contains("linkout") or p.contains("linkfile") or p.contains("linkback") or p.contains("outside")
	_check("symlinks are never followed out of the root: the links to a folder and a file outside it are skipped (%d), nothing outside listed or sized, no node for them" % reader.links_skipped, not escaped and reader.links_skipped >= 3 and not text.contains("linkout") and not text.contains("linkback") and not text.contains("7777"))
	var gamma := reader.node_at(PackedStringArray(["Alpha", "Beta", "Gamma"]))
	var delta := reader.node_at(PackedStringArray(["Alpha", "Beta", "Gamma", "Delta"]))
	var crowd := reader.node_at(PackedStringArray(["Crowd"]))
	_check("caps: depth (Gamma, %d levels down, known by name only and marked partial; nothing under it read), entries (Crowd stops at %d of its 30 and is partial), home marked partial" % [reader.depth_most + 1, reader.entries_most], not gamma.is_empty() and not bool(gamma["scanned"]) and bool(gamma["partial"]) and delta.is_empty() and int(crowd["own_files"]) == reader.entries_most and bool(crowd["partial"]) and bool(reader.home["partial"]))
	var sliced := FolderReader.new(home)
	sliced.budget_us = 1
	var thin := _scan(sliced, PackedStringArray())
	_check("the reader never blocks the frame past its budget: %d steps, the longest %.2f ms (budget %.1f ms, a slice a frame); held to 1 us a frame it reads a few entries a step (%d steps)" % [run[0], float(run[1]) / 1000.0, float(reader.budget_us) / 1000.0, thin[0]], int(run[1]) < reader.budget_us + 6000 and int(run[0]) >= 1 and int(thin[0]) >= 12)
	var deeper := _scan(reader, PackedStringArray(["Alpha", "Beta"]))
	var now_delta := reader.node_at(PackedStringArray(["Alpha", "Beta", "Gamma", "Delta"]))
	_check("going into a folder reads deeper from there (Delta listed once Beta is asked for), what was read kept", reader.ready_for(PackedStringArray(["Alpha", "Beta"])) and not now_delta.is_empty() and int(reader.node_at(PackedStringArray(["Alpha"]))["own_files"]) == 3 and int(deeper[0]) >= 1)
	var timed := FolderReader.new(home)
	timed.scan_s = 0.0
	_scan(timed, PackedStringArray())
	_check("the time cap: a scan given no time ends at once, partial, and still says it is done (the map never waits on it forever)", timed.ready_for(PackedStringArray()) and bool(timed.home["partial"]))
	_check("acceptance (safety): the reader changed nothing: every file, folder and link under the test's tree exactly as it was (sizes and times the same, nothing added or removed)", _snapshot(_abs) == before, "%d before, %d after" % [before.size(), _snapshot(_abs).size()])
	# Cut off mid-listing (a door walked through while home is still being read): nothing is ever counted twice.
	var cut := FolderReader.new(home)
	cut.budget_us = 1
	cut.depth_most = 1
	cut.want(PackedStringArray())
	for i in 4:
		cut.step(1.0 / 60.0)
	_scan(cut, PackedStringArray(["Crowd"]))
	_scan(cut, PackedStringArray())
	var names := {}
	var twice := false
	for d in cut.home["dirs"]:
		twice = twice or names.has(d["name"])
		names[d["name"]] = true
	var crowd2 := cut.node_at(PackedStringArray(["Crowd"]))
	_check("a scan cut off mid-listing by another folder is listed afresh, never counted twice (home's folders once each, Crowd's 30 files 30)", not twice and names.has("Alpha") and int(crowd2.get("own_files", 0)) == 30 and int(cut.home["own_files"]) == 0, "%s, crowd %d" % [str(names.keys()), int(crowd2.get("own_files", -1))])
	reader.drop()
	_check("drop() lets every name and number go", reader.home["dirs"].is_empty() and not reader.ready_for(PackedStringArray()))


# --- The arena. ---

func _arena(queue_map: bool, practice: bool = true) -> Node:
	MissionRunner.clear_pending()
	for old in root.get_children():
		if old.scene_file_path == "res://scenes/main.tscn":
			await _drop(old)
	ProcHunt.clear()
	if queue_map:
		FolderMap.queued = true
	else:
		FolderMap.clear()
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
	player.velocity = Vector3.ZERO
	await _frames(3)


func _after_reload(old_id: int) -> Node:
	await _until(func(): return current_scene != null and current_scene.get_instance_id() != old_id and current_scene.has_node("Hud") and current_scene.is_node_ready())
	var main := current_scene
	await _ready_arena(main)
	var map := FolderMap.of(main)
	await _until(func(): return map != null and map.running and (map.maze != null or not map.doors.is_empty()))
	await _frames(2)
	return main


## The map's own labels (its doors' names and numbers), not the parked daemons' tags.
func _labels(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for l in node.find_children("Door_*", "Label3D", false, false):
		out.append((l as Label3D).text)
	return out


func _arena_checks() -> void:
	var made_before := FolderReader.made
	var plain := await _arena(false)
	var m0 := FolderMap.of(plain)
	await _frames(10)
	_check("acceptance: off by default: the map stands in the arena, not running, no room staged; the arena's own four daemons are its", m0 != null and not m0.running and RuinsWorld.of(plain) == null and plain.get_tree().get_nodes_in_group("targets").size() == 4)
	FolderMap.path = PackedStringArray()
	FolderMap.level = 0
	FolderMap.came_from = ""
	var main := await _arena(true)
	var map := FolderMap.of(main)
	await _until(func(): return map.running and not map.doors.is_empty())
	var demo := DemoFolders.new()
	var home := demo.root
	var want := PackedStringArray()
	for d in FolderRooms.doors_of(home):
		want.append(str(d["name"]))
	var names := PackedStringArray()
	for e in map.doors:
		if int(e["index"]) >= 0:
			names.append(str(e["name"]))
	var parked := true
	for name in ["DummyA", "DummyB", "DummyC", "DummyD"]:
		parked = parked and main.get_node_or_null("Arena/Targets/" + name) == null
	_check("acceptance: queued (the Esc menu, or --fsmap), the map begins at home on the demo tree: home's room staged, a door each for home's folders, biggest first (%s), the back door \"exit\", the arena's own daemons parked" % ", ".join(names), map.running and FolderMap.layer == "demo" and map.world != null and map.world.ruins.id == FolderRooms.id_for(PackedStringArray()) and names == want and map.door_named("exit").size() > 0 and parked)
	_check("acceptance (safety): the real layer is off by default: no reader made, nothing read (a demo run)", FolderReader.made == made_before and FolderMap.source is DemoFolders)
	var count := FolderRooms.daemons_for(int(home["own_files"]))
	var tags := {}
	for e in map.enemies:
		tags[e.tag_text] = true
	await _frames(80)
	_check("its daemons are the arena's roster (rogue.d, zombies, runaways), as many as home's files say (%d), climbing out of the room's daemon points" % count, map.enemies.size() == count and count >= 1 and tags.keys().all(func(t): return ["rogue.d", "zombie", "runaway"].has(t)) and map.standing() == count)
	var labels := _labels(map)
	var allowed := not labels.is_empty()
	for t in labels:
		allowed = allowed and (want.has(t.trim_suffix("/")) or t == "exit" or t == ".." or t.contains(" files ") or t == "exit the map" or t == "cd .. (up)") and not t.contains("~")
	_check("labels are folder names only (and their numbers); home is \"home\", never `~`", allowed and FolderTree.path_text(PackedStringArray()) == "home" and not "\n".join(map._hud.lines()).contains("~"), " | ".join(labels))
	# The visor in the map.
	map.visor.set_on(true)
	await _frames(4)
	var crumb: String = map._hud.breadcrumb_text()
	var through := true
	for e in map.doors:
		through = through and (e["info"] as Label3D).no_depth_test
	_check("the visor in the map: a breadcrumb of folders from home with their sizes (\"%s\"), every door's numbers seen through the walls, a line from each door to the way up (%d)" % [crumb, map._lines.drawn_lines], crumb.begins_with("home ") and crumb.contains("B") and through and map._lines.drawn_lines == map.doors.size() - 1)
	map.visor.set_on(false)
	await _frames(2)
	_check("visor off: no breadcrumb, no lines, door numbers behind the walls again", map._hud.breadcrumb_text() == "" and map._lines.drawn_lines == 0 and not (map.doors[0]["info"] as Label3D).no_depth_test)


func _walk_checks() -> void:
	var main := current_scene
	var map := FolderMap.of(main)
	var home_room := map.world.ruins
	var old_id := main.get_instance_id()
	map.through(map.door_named("Videos"))
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var videos := map.world.ruins
	var small_name := str(FolderRooms.doors_of(map.room).back()["name"])
	_check("through a door: the arena reloads into that folder (`cd Videos`): its own room, its doors its folders, the back door \"..\"", FolderMap.path == PackedStringArray(["Videos"]) and videos.id == FolderRooms.id_for(PackedStringArray(["Videos"])) and map.door_named("..").size() > 0 and map.door_named("recordings").size() > 0)
	old_id = main.get_instance_id()
	map.through(map.door_named(small_name))
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var small := map.world.ruins
	_check("a small room off the big one: %s's room (%s cells, towers x%.2f) is smaller and lower than Videos' (%s, x%.2f)" % [small_name, str(small.cells), small.tall, str(videos.cells), videos.tall], small.cells.x < videos.cells.x and small.cells.y < videos.cells.y and small.tall < videos.tall)
	old_id = main.get_instance_id()
	map.through(map.door_named(".."))
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var door := map.door_named(small_name)
	var player := main.get_node("Player") as Node3D
	var d: Dictionary = door["d"]
	var at: Vector3 = map.world.global_transform * (d["at"] as Vector3)
	_check("the back door goes up (`cd ..`), and the player stands just inside the door it came out of, facing into the room", FolderMap.path == PackedStringArray(["Videos"]) and Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < FolderMap.BACK_IN_M + 1.0)
	# Walking into a door's portal takes the player through on its own (the trigger, not a call).
	old_id = main.get_instance_id()
	var out: Vector3 = d["out"]
	player.global_position = at - out * 0.6 + Vector3(0, RuinsLayout.STAND_Y, 0)
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	_check("stepping into a door's portal takes the player through (into %s), nothing to press" % small_name, FolderMap.path == PackedStringArray(["Videos", small_name]))


func _maze_arena_checks() -> void:
	FolderMap.path = PackedStringArray(["Code", "starfall"])
	FolderMap.level = 0
	FolderMap.came_from = ""
	var main := await _arena(true)
	var map := FolderMap.of(main)
	await _until(func(): return map.running and not map.doors.is_empty())
	var old_id := main.get_instance_id()
	map.through(map.door_named("node_modules"))
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var walls_ok: bool = map.maze != null and map.maze_view != null and map.maze_view.wall_count == map.maze.walls.size() and map.maze_view.wall_count > 40
	var solid := main.find_child("MazeSolid", true, false)
	_check("into node_modules: the maze, level 1, not a room: its walls built (%d), solid (one box each), package names on them, the way out's beacon over the far cell, the ways down lit (%d)" % [map.maze_view.wall_count if map.maze_view != null else -1, map.maze_view.ways_down() if map.maze_view != null else -1], FolderMap.level == 1 and walls_ok and solid != null and solid.get_child_count() == map.maze.walls.size() and map.maze_view.label_count > 8 and map.maze_view.way_out_at().is_finite() and map.maze_view.ways_down() == map.maze.pits.size() and map.doors.is_empty())
	# A wall stops a look (and a shot): a ray across a closed side hits the maze.
	var space := (main as Node3D).get_world_3d().direct_space_state
	var w: Dictionary = map.maze.walls[0]
	var xf := map.world.global_transform
	var o := Vector3(RuinsLayout.SIDES[int(w["side"])].x, 0, RuinsLayout.SIDES[int(w["side"])].y)
	var from: Vector3 = xf * ((w["at"] as Vector3) - o * 1.2 + Vector3(0, 1.6, 0))
	var to: Vector3 = xf * ((w["at"] as Vector3) + o * 1.2 + Vector3(0, 1.6, 0))
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
	_check("the maze's walls are solid: a look across a wall stops at it", not hit.is_empty())
	var tall_enough := NodeMaze.WALL_H > 2.0 * RuinsLayout.STAND_Y + 1.5
	map.visor.set_on(true)
	await _frames(4)
	var way := map.maze.path(map.maze.start, map.maze.exit)
	var walked := map.way_out_from(map.maze.start)
	_check("the visor's way out is the maze's own shortest way (%d cells walked down its steps, %d by the search)" % [walked.size(), way.size()], walked.size() == way.size() and walked[walked.size() - 1] == map.maze.exit and walked[0] == map.maze.start)
	_check("the visor in the maze draws the way out, cell by cell, from where the player stands (%d lines), and its breadcrumb says the depth" % map._lines.drawn_lines, map._lines.drawn_lines >= mini(way.size() - 1, VisorLines.LINES_MOST) - 2 and map._lines.drawn_lines > 2 and map._hud.breadcrumb_text().contains("node_modules") and map._hud.breadcrumb_text().contains("depth 1") and tall_enough)
	map.visor.set_on(false)
	var first_cells: int = map.maze.cells.size()
	old_id = main.get_instance_id()
	map.deeper(0)
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	_check("a way down goes deeper: node_modules level 2, a new maze, bigger (%d cells from %d)" % [map.maze.cells.size(), first_cells], FolderMap.level == 2 and map.maze != null and map.maze.cells.size() > first_cells and FolderMap.deepest >= 2)
	# Stand on the way out: the trigger takes the player out of the maze whole.
	old_id = main.get_instance_id()
	var player := main.get_node("Player") as Node3D
	player.global_position = map.world.global_transform * map.world.layout.center(map.maze.exit) + Vector3(0, RuinsLayout.STAND_Y, 0)
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var d: Dictionary = map.door_named("node_modules").get("d", {})
	var near := false
	if not d.is_empty():
		var at: Vector3 = map.world.global_transform * (d["at"] as Vector3)
		player = main.get_node("Player") as Node3D
		near = Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length() < FolderMap.BACK_IN_M + 1.0
	_check("acceptance: the maze has a way out: standing on it leaves node_modules whole, from any depth, back in the folder that holds it at its node_modules door", FolderMap.level == 0 and FolderMap.path == PackedStringArray(["Code", "starfall"]) and map.maze == null and near)


func _real_arena_checks() -> void:
	FolderMap.clear()
	var main := await _arena(false)
	var map := FolderMap.of(main)
	var gate := [true]
	FolderMap.home_root = _abs.path_join("fakehome")
	FolderMap.gate = func(): return gate[0]
	FolderMap.queued = true
	var made := FolderReader.made
	var old_id := main.get_instance_id()
	map.begin()
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	var names := PackedStringArray()
	for e in map.doors:
		names.append(str(e["name"]))
	_check("the real layer, behind its gate, from a fake home: the reader made, home's room from it, its doors the fake folders (%s), never the hidden one or a link" % ", ".join(names), FolderMap.layer == "real" and FolderReader.made > made and names.has("Alpha") and names.has("Crowd") and not names.has(".hidden") and not names.has("linkout") and not names.has("linkback") and names.has("exit"))
	gate[0] = false
	old_id = main.get_instance_id()
	main = await _after_reload(old_id)
	map = FolderMap.of(main)
	_check("the gate closing drops the reader and every name it read, back home on the demo tree", FolderMap.layer == "demo" and FolderMap.source is DemoFolders and map.door_named("Videos").size() > 0)
	FolderMap.clear()
	FolderMap.gate = Callable()
	FolderMap.home_root = ""


func _menu_checks() -> void:
	var main := await _arena(false)
	var menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var b: Button = menu.map_button()
	var plain_ok: bool = b != null and b.text == "Folder map" and not b.disabled and b.is_visible_in_tree()
	menu.close()
	FolderMap.path = PackedStringArray()
	main = await _arena(true)
	menu = main.get_node("Hud").pause_menu()
	menu.open()
	await _frames(2)
	var leave_ok: bool = menu.map_button().text == "Leave folder map"
	menu.close()
	_check("acceptance: the Esc menu reaches it: \"Folder map\" in the free arena, \"Leave folder map\" while it runs", plain_ok and leave_ok)
	FolderMap.clear()


func _credit_checks() -> void:
	ProcHunt.reset_world_credits()
	var given := 0
	for i in 30:
		if ProcHunt.world_credit_ok():
			given += 1
	ProcHunt.reset_world_credits()
	_check("a world mode's kills earn a sudo charge's kill and a feat at most %d a minute (W1's farming, capped): %d of 30 at once" % [ProcHunt.WORLD_CREDITS, given], given == ProcHunt.WORLD_CREDITS and ProcHunt.WORLD_CREDITS == 12)


# --- Helpers. ---

func _cleanup() -> void:
	MissionRunner.clear_pending()
	ProcHunt.clear()
	FolderMap.clear()
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


## The test's own folder only, file by file; a link is removed as a link, never followed.
func _wipe(path: String) -> void:
	if not path.begins_with(ProjectSettings.globalize_path("user://folder-map-test-")):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	dir.list_dir_begin()
	var name := dir.get_next()
	var kids: Array = []
	while name != "":
		kids.append([name, dir.is_link(name), dir.current_is_dir()])
		name = dir.get_next()
	dir.list_dir_end()
	for k in kids:
		var full: String = path.path_join(k[0])
		if k[1] or not k[2]:
			DirAccess.remove_absolute(full)
		else:
			_wipe(full)
	DirAccess.remove_absolute(path)


func _drop(main: Node) -> void:
	if is_instance_valid(main):
		for sfx in main.find_children("*", "AudioStreamPlayer", true, false):
			(sfx as AudioStreamPlayer).stop()
		for sfx in main.find_children("*", "AudioStreamPlayer3D", true, false):
			(sfx as AudioStreamPlayer3D).stop()
		if current_scene == main:
			current_scene = null
		main.queue_free()
		await _frames(3)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _until(condition: Callable) -> bool:
	var frames := 0
	while frames < MOST_FRAMES and not condition.call():
		await process_frame
		frames += 1
	return condition.call()

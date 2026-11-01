class_name FolderMap
extends Node3D
## Filesystem maps (W2, PRD 5.5; the second of M5's world features): the folder map, a mode of the free arena where the
## player's folder tree is the level. Reached from the Esc menu ("Folder map"; "Leave folder map" ends it), or with
## --fsmap on a demo or test run. Made by the arena (scripts/main.gd) beside the directors; it begins when queued.
##
## A folder is a room: a ruins district made at play from it (scripts/fsmap/folder_rooms.gd: its size the room's scale
## and height, its files how busy it is and how many daemons live there, its kind the register), stood in as the arena
## loads (RuinsStage.queue_set(), from prepare()). Its subfolders are doors on the room's edges, biggest first, each as
## tall as its folder is big, a bridge out to an island the size of what is behind it, its name over the lintel; walk
## through one and the arena reloads into that folder (`$ cd <name>`). The back door behind the start goes up (`cd ..`);
## home's goes out of the map (`exit`). A node_modules folder is never a room: it is the maze (scripts/fsmap/node_maze.gd
## and maze_world.gd), endless, a level a depth: its ways down go deeper, its way out (the beacon) leaves it whole.
##
## Where the tree comes from, two layers as the visor's (C43) and the process hunt's (W1):
##   demo  the default, and the only layer the tests and captures use: a home folder the game makes up (scripts/fsmap/
##         demo_folders.gd). Nothing of the machine is read.
##   real  opt-in, behind the same answer as the opener's real data, the visor's real layer and the hunt's (Settings,
##         Privacy and AI, "opener data", with real-machine data on, never on a demo run): the read-only reader
##         (scripts/fsmap/folder_reader.gd), names, sizes and counts only, a slice a frame within its budget, hidden
##         folders skipped, links never followed. Off, no reader is made and nothing is read.
## Labels are folder names only; home is always "home" (its real name is the user's).
##
## Its daemons are the arena's own roster (rogue.d, zombies, runaways; FolderRooms.roster_for()), as many as the room's
## files say, out of the room's daemon points (in the maze, deep in it); the arena's own four are parked, ICE stands down
## and the rounds hold, as in the hunt. Killing one is the game's own: nothing real is touched. Nothing here writes,
## saves, logs, sends or runs anything; the only thing it reads is through the reader above.

const DummyScene = preload("res://scenes/target_dummy.tscn")
const RogueArt = preload("res://scripts/daemons/rogue_daemon.gd")
const ZombieArt = preload("res://scripts/daemons/zombie_process.gd")
const RunawayArt = preload("res://scripts/daemons/runaway_swarm.gd")
const Palette = preload("res://scripts/palette.gd")

const GROUP := &"folder_map"
const NODE_NAME := "FolderMap"
## The dev and test flag that begins it as the arena loads (with --demo, or under --script).
const FLAG := "--fsmap"
const GATE_EVERY_S := 2.0
## A door takes the player through when they stand within REACH_M of its edge line and WIDE_M of its middle; a way down
## or the way out when within PIT_M of its cell's middle. None for SETTLE_S after a room loads.
const REACH_M := 1.2
const WIDE_M := 1.7
const PIT_M := 1.25
const SETTLE_S := 0.8
## Where the player stands back in a room it came up into: this far inside the door it came out of.
const BACK_IN_M := 3.4
## A door's name over its lintel, and its numbers under the name.
const NAME_FONT := 120
const NAME_PIXEL := 0.012
const INFO_FONT := 56
const EVENTS_KEPT := 5
const TAGS := {"rogue": "rogue.d", "zombie": "zombie", "runaway": "runaway"}

## Queued for the next arena (the Esc menu, the flag); kept while it runs, so a reload stays in it. Where it stands now:
## the folder's path (names from home), the maze's level (0 outside one), and the subfolder it came back up from (its
## door is where the player stands).
static var queued := false
static var path := PackedStringArray()
static var level := 0
static var came_from := ""
## Its tree: a DemoFolders or a FolderReader, kept across reloads (a walk through the doors keeps what was read), and
## which layer.
static var source: RefCounted = null
static var layer := "demo"
## For the HUD and the checks: rooms entered, the deepest maze level reached.
static var rooms_seen := 0
static var deepest := 0
## The tests' own gate and fake home (kept across the map's reloads, as the map is); unset in the game.
static var gate: Callable
static var home_root := ""
static var _flag_taken := false
static var _going := false

signal began
signal ended
## An enemy climbed out (the arena counts it as its own: a kill toward sudo, the top table).
signal spawned(dummy: Node3D)
signal event(kind: String, text: String)

var running := false
## Set by the arena.
var player: Node3D = null
var director: DaemonDirector = null
var runner: MissionRunner = null
var ice: Node = null
var rounds: Node = null
var guide: Node = null
var visor: Node = null
## The folder it stands in, its room, and its maze when it is one.
var room: Dictionary = {}
var world: RuinsWorld = null
var maze: NodeMaze = null
var maze_view: MazeWorld = null
## Its doors: {index, name, child (a folder, {} for the back door), d (the layout's door), label, tag}.
var doors: Array = []
var enemies: Array = []
var events: Array = []
var waiting := false
var _wait: Array = []
var _parked: Array = []
var _hud: CanvasLayer = null
var _lines: VisorLines = null
var _clock := 0.0
var _gate_wait := 0.0
var _settle := SETTLE_S


static func of(node: Node) -> FolderMap:
	if node == null or not node.is_inside_tree():
		return null
	for m in node.get_tree().get_nodes_in_group(GROUP):
		return m as FolderMap
	return null


## The map as the next arena loads, at home.
static func queue() -> void:
	queued = true
	path = PackedStringArray()
	level = 0
	came_from = ""


## Out of the map: every name and number it read let go.
static func clear() -> void:
	queued = false
	path = PackedStringArray()
	level = 0
	came_from = ""
	_drop_source()


static func _drop_source() -> void:
	if source != null and source.has_method("drop"):
		source.drop()
	source = null


## --fsmap (with --demo, or under --script): queued once a run.
static func take_flag(args: PackedStringArray) -> void:
	if _flag_taken:
		return
	_flag_taken = true
	if args.has(FLAG) and (args.has("--demo") or OS.get_cmdline_args().has("--script")):
		queue()


## As the arena loads, before it is staged (scripts/main.gd): the room for where the map stands, queued for the stage,
## when the map is queued, alone and with no mission; else nothing queued. `real` is the visor's gate for this run;
static func prepare(args: PackedStringArray, online: bool, real: bool) -> void:
	take_flag(args)
	_going = false
	RuinsStage.queue_set(null)
	if not queued or online or MissionRunner.pending() != "":
		return
	ensure_source(bool(gate.call()) if gate.is_valid() else real)
	if not source.ready_for(path):
		return  # the reader has not read it yet: the map begins in the plain arena and reads it there
	var n: Dictionary = source.node_at(path)
	if n.is_empty() and not path.is_empty():
		path = PackedStringArray()  # gone from the tree (a layer change): back home
		level = 0
		n = source.node_at(path)
	if n.is_empty():
		return
	if FolderRooms.is_maze(n) and level <= 0:
		level = 1
	elif not FolderRooms.is_maze(n):
		level = 0
	RuinsStage.queue_set(FolderRooms.maze_set(n, path, level) if level > 0 else FolderRooms.set_for(n, path))


## The tree for this layer, made when there is none or the layer changed (a change goes back home).
static func ensure_source(real: bool) -> void:
	var want := "real" if real else "demo"
	if source != null and layer == want:
		return
	_drop_source()
	layer = want
	path = PackedStringArray()
	level = 0
	came_from = ""
	if real:
		source = FolderReader.new(home_root if home_root != "" else OS.get_environment("HOME"))
	else:
		source = DemoFolders.new()


func _ready() -> void:
	name = NODE_NAME
	add_to_group(GROUP)


## True when the real layer is allowed: the visor's own gate (the opener's answer, real-machine data on, not a demo run).
func real_allowed() -> bool:
	if gate.is_valid():
		return bool(gate.call())
	var link = guide.session_link() if guide != null and is_instance_valid(guide) and guide.has_method("session_link") else null
	return AuditVisor.real_gate_for(link)


## Begins the map where it stands: the arena's own daemons parked, ICE stood down, the rounds held; the room's doors or
## the maze, its daemons, the player at the right door. False online or in a mission.
func begin() -> bool:
	if running or _online() or (runner != null and is_instance_valid(runner) and runner.running()):
		return false
	running = true
	queued = true
	ensure_source(real_allowed())
	world = _world()
	_park_arena_daemons()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = true
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(true)
	_hud = FolderMapHud.new()
	_hud.map = self
	add_child(_hud)
	_lines = VisorLines.new()
	add_child(_lines)
	room = source.node_at(path) if source.ready_for(path) else {}
	if room.is_empty() or world == null or world.ruins == null or world.ruins.id != (FolderRooms.id_for(path, level)):
		# Not stood in its room yet (the reader still reading, or a plain arena): read it here, then go.
		_go(path, level, "$ cd " + FolderTree.path_text(path), came_from)
		began.emit()
		return true
	if level > 0:
		_build_maze()
	else:
		_build_doors()
	_spawn_daemons()
	_place_player()
	rooms_seen += 1
	deepest = maxi(deepest, level)
	_note("cd", "$ cd %s" % FolderTree.path_text(path) if level == 0 else "node_modules: depth %d" % level)
	began.emit()
	return true


## Ends the map where it stands (a match starting, the Esc menu's way out): its daemons gone, the arena's own back, ICE and
## the rounds as they were. The room stays standing until the next load; not queued any more.
func end() -> void:
	if not running:
		return
	running = false
	for e in enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	enemies.clear()
	_release_parked()
	if ice != null and is_instance_valid(ice) and "stand_down" in ice:
		ice.stand_down = false
	if rounds != null and is_instance_valid(rounds) and rounds.has_method("hold"):
		rounds.hold(false)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	if _hud != null and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	clear()
	ended.emit()


func _world() -> RuinsWorld:
	var host := get_parent()
	return host.get_node_or_null("Arena/" + RuinsWorld.NODE_NAME) as RuinsWorld if host != null else null


func _online() -> bool:
	var session = director.session if director != null and is_instance_valid(director) else null
	return session != null and is_instance_valid(session) and session.has_method("is_online") and session.is_online()


# --- The room. ---

func _build_doors() -> void:
	var kids := FolderRooms.doors_of(room)
	for d in world.layout.doors:
		var index := int(d["index"])
		var child: Dictionary = kids[index] if index >= 0 and index < kids.size() else {}
		var name := (".." if not path.is_empty() else "exit") if index < 0 else str(child.get("name", "?"))
		var entry := {"index": index, "name": name, "child": child, "d": d}
		_door_label(entry)
		doors.append(entry)


func _door_label(entry: Dictionary) -> void:
	var d: Dictionary = entry["d"]
	var out: Vector3 = d["out"]
	var tall := RuinsPieces.door_tall(d)
	var at: Vector3 = world.global_transform * ((d["at"] as Vector3) + Vector3(0, tall + 1.6, 0) - out * 0.2)
	var big := Label3D.new()
	big.name = "Door_%s" % str(entry["name"]).validate_node_name()
	big.text = str(entry["name"])
	big.font = Palette.mono_font()
	big.font_size = NAME_FONT
	big.pixel_size = NAME_PIXEL * lerpf(0.8, 1.6, float(d["share"])) if int(d["index"]) >= 0 else NAME_PIXEL
	big.outline_size = 18
	big.outline_modulate = Color(0, 0, 0, 0.85)
	big.modulate = Color(Palette.ICE_HI if int(d["index"]) < 0 else Palette.MINT, 1.0) * 1.6
	big.shaded = false
	big.double_sided = false
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.visibility_range_end = 90.0
	add_child(big)
	big.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), at)
	var info := Label3D.new()
	info.name = big.name + "_info"
	info.text = door_info(entry)
	info.font = Palette.mono_font()
	info.font_size = INFO_FONT
	info.pixel_size = NAME_PIXEL * 0.9
	info.outline_size = 10
	info.outline_modulate = Color(0, 0, 0, 0.85)
	info.modulate = Color(Palette.TEAL, 1.0) * 1.4
	info.shaded = false
	info.double_sided = false
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.visibility_range_end = 40.0
	add_child(info)
	info.global_transform = Transform3D(Basis.looking_at(out, Vector3.UP), at - Vector3(0, big.pixel_size * NAME_FONT * 0.8, 0))
	entry["label"] = big
	entry["info"] = info


## A door's numbers: "61 GB   212 files   4 dirs" (">=" when a cap cut its reading), "up" or "out" for the back door.
func door_info(entry: Dictionary) -> String:
	if int(entry["index"]) < 0:
		return "cd .. (up)" if not path.is_empty() else "exit the map"
	var c: Dictionary = entry["child"]
	var more := ">=" if bool(c.get("partial", false)) else ""
	return "%s%s   %s files   %d dirs" % [more, FolderTree.human_size(int(c.get("size", 0))), FolderTree.thousands(int(c.get("files", 0))), (c.get("dirs", []) as Array).size() + int(c.get("more", 0))]


func _build_maze() -> void:
	maze = NodeMaze.new(world.layout, FolderRooms.seed_for(path, level) ^ 0x5a5a, level)
	maze_view = MazeWorld.new()
	maze_view.maze = maze
	maze_view.names = _package_names()
	maze_view.level = level
	maze_view.installed = maxi(int(room.get("files", 0)), 1) * level
	world.add_child(maze_view)


## The maze's package names: the node_modules folder's own subfolders (a level down, the names roll on).
func _package_names() -> PackedStringArray:
	var out := PackedStringArray()
	for d in room.get("dirs", []):
		if str(d["name"]) != FolderRooms.MAZE_NAME:
			out.append(str(d["name"]))
	if out.is_empty():
		out.append(FolderRooms.MAZE_NAME)
	var roll := (level - 1) * 5 % out.size()
	return out.slice(roll) + out.slice(0, roll)


func _spawn_daemons() -> void:
	var targets := _targets()
	if targets == null:
		return
	var count := FolderRooms.maze_daemons(level) if level > 0 else FolderRooms.daemons_for(int(room.get("own_files", 0)))
	var kinds := FolderRooms.roster_for(path + PackedStringArray(["#%d" % level]), count)
	var spots := _daemon_spots(count)
	for i in mini(kinds.size(), spots.size()):
		var dummy = DummyScene.instantiate()
		var kind := kinds[i]
		dummy.name = "Folder_%d" % i
		dummy.tag_text = TAGS[kind]
		dummy.respawns = false
		dummy.art = ZombieArt if kind == "zombie" else (RunawayArt if kind == "runaway" else RogueArt)
		dummy.seed_wanted = DaemonArt.seed_of("fsmap:%s:%d:%d" % [FolderTree.path_text(path), level, i]) if _fixed_seeds() else randi() & DaemonArt.SEED_LAST
		dummy.set_meta(&"fsmap", i)
		dummy.set_meta(&"world", true)
		targets.add_child(dummy)
		dummy.global_position = spots[i]
		dummy.spawn_in(1.1)
		enemies.append(dummy)
		spawned.emit(dummy)
	if director != null and is_instance_valid(director):
		director.forget_brains()


static func _fixed_seeds() -> bool:
	return OS.get_cmdline_user_args().has("--demo") or OS.get_cmdline_args().has("--script")


## Where the room's daemons stand: its daemon points (in the maze, cells deep in it, spread out).
func _daemon_spots(count: int) -> Array:
	var out: Array = []
	if maze != null:
		var deep := maze.cells.filter(func(c): return int(maze.dist.get(c, 0)) >= 4 and c != maze.exit and not maze.pits.has(c))
		deep.sort_custom(func(a, b): return [int(maze.dist[a]), a.x, a.y] > [int(maze.dist[b]), b.x, b.y])
		var step := maxi(deep.size() / maxi(count, 1), 1)
		for i in count:
			if i * step < deep.size():
				out.append(world.global_transform * world.layout.center(deep[i * step]))
		return out
	for i in count:
		var at := world.point("daemon_%d" % i)
		if at.is_finite():
			out.append(at)
	return out


## The player at the start, or just inside the door it came back up out of, facing into the room.
func _place_player() -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("set_spawn"):
		return
	if level > 0 or came_from == "":
		return
	for e in doors:
		if str(e["name"]) == came_from and int(e["index"]) >= 0:
			var d: Dictionary = e["d"]
			var out: Vector3 = d["out"]
			var at: Vector3 = world.global_transform * ((d["at"] as Vector3) - out * BACK_IN_M + Vector3(0, RuinsLayout.STAND_Y, 0))
			player.set_spawn(Transform3D(Basis.looking_at(-out, Vector3.UP), at))
			return


# --- Going places. ---

## Through door `entry`: into its folder, up, or out of the map.
func through(entry: Dictionary) -> void:
	if int(entry["index"]) < 0:
		if path.is_empty():
			leave()
		else:
			var up := path.slice(0, path.size() - 1)
			_go(up, 0, "$ cd ..", path[path.size() - 1])
		return
	var name := str(entry["name"])
	var into := path + PackedStringArray([name])
	_go(into, 1 if name == FolderRooms.MAZE_NAME else 0, "$ cd " + name, "")


## Down a way in the maze: node_modules a level deeper.
func deeper(pit: int) -> void:
	var names := _package_names()
	_go(path, level + 1, "$ cd %s/node_modules" % names[pit % names.size()], "")


## The maze's way out: out of node_modules whole, back in the folder that holds it, at its node_modules door.
func way_out() -> void:
	_note("out", "escaped node_modules from depth %d" % level)
	_go(path.slice(0, path.size() - 1), 0, "$ cd ..  # escaped node_modules", FolderRooms.MAZE_NAME)


## Out of the map, back to the plain arena.
func leave() -> void:
	if _going:
		return
	_going = true
	clear()
	MissionRunner.reload_after_mount(get_tree(), "$ exit")


func _go(to: PackedStringArray, to_level: int, label: String, from: String) -> void:
	if _going:
		return
	if not source.ready_for(to):
		source.want(to)
		waiting = true
		_wait = [to, to_level, label, from]
		return
	waiting = false
	_wait = []
	path = to
	level = to_level
	came_from = from
	_going = true
	_note("cd", label)
	MissionRunner.reload_after_mount(get_tree(), label)


func _physics_process(delta: float) -> void:
	if not running:
		return
	if _online():
		end()  # a match started mid-map: the match's rules, the arena's own daemons back
		return
	_clock += delta
	_settle -= delta
	_gate_wait -= delta
	if _gate_wait <= 0.0:
		_gate_wait = GATE_EVERY_S
		if (layer == "real") != real_allowed() and not _going:
			ensure_source(real_allowed())  # the answer changed: the other layer's home
			_go(PackedStringArray(), 0, "$ cd " + FolderTree.HOME_NAME, "")
			return
	if source != null and source.step(delta) and waiting and not _wait.is_empty():
		var w := _wait.duplicate()
		_go(w[0], w[1], w[2], w[3])
	if _settle > 0.0 or _going or player == null or not is_instance_valid(player):
		return
	var p: Vector3 = player.global_position
	if maze != null:
		var c := world.layout.cell_at(world.to_local(p))
		if c == maze.exit and _near_cell(p, c):
			way_out()
			return
		for i in maze.pits.size():
			if c == maze.pits[i] and _near_cell(p, c):
				deeper(i)
				return
		return
	for e in doors:
		var d: Dictionary = e["d"]
		var out: Vector3 = d["out"]
		var rel: Vector3 = world.to_local(p) - (d["at"] as Vector3)
		var along := rel.dot(out)
		var across := absf(rel.dot(Vector3(-out.z, 0, out.x)))
		if along > -REACH_M and along < 1.0 and across < WIDE_M and absf(rel.y - RuinsLayout.STAND_Y) < 1.6:
			through(e)
			return


func _near_cell(p: Vector3, c: Vector2i) -> bool:
	var mid := world.global_transform * world.layout.center(c)
	return Vector2(p.x - mid.x, p.z - mid.z).length() < PIT_M


func _process(_delta: float) -> void:
	if not running or _lines == null:
		return
	var on := visor != null and is_instance_valid(visor) and bool(visor.get("on"))
	if not on or world == null:
		_lines.draw([], [])
		for e in doors:
			if e.has("info"):
				(e["info"] as Label3D).no_depth_test = false
		return
	_lines.draw(visor_lines(), [])
	for e in doors:
		if e.has("info"):
			(e["info"] as Label3D).no_depth_test = true  # the visor sees every door's numbers through the walls


## What the visor draws in the map (W2): in a room, a line from every door's lintel to the back door's (each folder to
## its parent, the tree drawn in the room); in the maze, the way out, cell by cell from where the player stands.
func visor_lines() -> Array:
	var out: Array = []
	if world == null:
		return out
	var xf := world.global_transform
	if maze != null and player != null and is_instance_valid(player):
		var here := world.layout.cell_at(world.to_local(player.global_position))
		var way := maze.path(here, maze.exit) if maze.dist.has(here) else []
		for i in mini(way.size() - 1, VisorLines.LINES_MOST):
			out.append(_line(xf * (world.layout.center(way[i]) + Vector3(0, 0.25, 0)), xf * (world.layout.center(way[i + 1]) + Vector3(0, 0.25, 0)), 0.85, i))
		return out
	var back := {}
	for e in doors:
		if int(e["index"]) < 0:
			back = e["d"]
	if back.is_empty():
		return out
	var top := xf * ((back["at"] as Vector3) + Vector3(0, RuinsPieces.door_tall(back) + 0.6, 0))
	for e in doors:
		if int(e["index"]) < 0:
			continue
		var d: Dictionary = e["d"]
		out.append(_line(xf * ((d["at"] as Vector3) + Vector3(0, RuinsPieces.door_tall(d) + 0.6, 0)), top, clampf(float(d["share"]), 0.1, 1.0), int(e["index"])))
	return out


func _line(a: Vector3, b: Vector3, heat: float, i: int) -> Dictionary:
	return {"a": a, "b": b, "heat": heat, "width": 0.09, "grown": 1.0, "phase": fposmod(float(i) * 0.37, 1.0), "burn": 0.0, "bright": 1.0, "depth": 0.0, "lift": 0.35 if maze == null else 0.0}


## The breadcrumb the visor shows (W2): every folder from home to here, each with its size; "home" for home, always.
func breadcrumb() -> Array:
	var out: Array = []
	var at := PackedStringArray()
	var n: Dictionary = source.node_at(at) if source != null else {}
	out.append([FolderTree.HOME_NAME, int(n.get("size", 0))])
	for name in path:
		at.append(name)
		n = source.node_at(at)
		out.append([name, int(n.get("size", 0))])
	return out


# --- The arena's own daemons. ---

func _targets() -> Node3D:
	var host := get_parent()
	var t = host.get_node_or_null("Arena/Targets") if host != null else null
	return t as Node3D if t != null else (host as Node3D)


## The arena's own daemons parked under the map (out of the targets, still, hidden, nothing colliding), as the hunt does.
func _park_arena_daemons() -> void:
	var host := get_parent()
	for dummy in get_tree().get_nodes_in_group("targets"):
		if host != null and host.is_ancestor_of(dummy) and not dummy.has_meta(&"fsmap") and not dummy.has_meta(&"proc"):
			dummy.remove_from_group("targets")
			_parked.append([dummy, dummy.get_parent(), dummy.collision_layer])
			dummy.process_mode = Node.PROCESS_MODE_DISABLED
			dummy.visible = false
			dummy.collision_layer = 0
			dummy.reparent(self)
	if director != null and is_instance_valid(director):
		director.forget_brains()
	for driver in get_tree().get_nodes_in_group(&"code_rain_driver"):
		if driver.has_method("invalidate"):
			driver.invalidate()


func _release_parked() -> void:
	for entry in _parked:
		var dummy: Node3D = entry[0]
		if not is_instance_valid(dummy) or not is_instance_valid(entry[1]):
			continue
		dummy.reparent(entry[1])
		dummy.collision_layer = entry[2]
		dummy.visible = true
		dummy.process_mode = Node.PROCESS_MODE_INHERIT
		dummy.add_to_group("targets")
	_parked.clear()


# --- For the HUD and the checks. ---

func _note(kind: String, text: String) -> void:
	events.append({"t": _clock, "kind": kind, "text": text})
	while events.size() > EVENTS_KEPT:
		events.pop_front()
	event.emit(kind, text)


func clock() -> float:
	return _clock


## Daemons still standing in the room.
func standing() -> int:
	var n := 0
	for e in enemies:
		if is_instance_valid(e) and e.is_alive():
			n += 1
	return n


func door_named(name: String) -> Dictionary:
	for e in doors:
		if str(e["name"]) == name:
			return e
	return {}


static func going() -> bool:
	return _going

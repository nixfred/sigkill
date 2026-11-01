class_name FolderRooms
extends RefCounted
## The filesystem map's mapping (W2, PRD 5.5): a folder (FolderTree's shape) to its room, a ruins district made at play
## (a RuinsSet the kit's layout and world build, scripts/ruins/), and the roster that lives in it. Pure: the same folder
## always makes the same room, and the tests check every rule here without building one.
##
##   size     (the folder and everything under it) sets the room's scale: its floor from 6 by 8 cells (a few kilobytes)
##            to 16 by 24 (hundreds of gigabytes), its towers and giants from under half their height to 2.7 times it,
##            how many stand round it; logarithmic, so a tiny folder and a huge one are a different kind of place.
##   files    (directly in it) set how busy it is: ruins, cover, cables and signs, and how many daemons live there
##            (none in an empty folder, up to DAEMONS_MOST).
##   kind     (what most of its files are, by extension) sets its register: code the Matrix, video and pictures the
##            cyberpunk ruins, audio the cyberpunk in the abyss palette, documents and the rest Tron; an empty folder a
##            pristine Tron hall with nothing in it.
##   subfolders  are doors on its edges (biggest first, at most DOORS_MOST; the rest counted on the HUD), each as tall as
##            its folder is big, its bridge reaching out to an island of that size; and the back door, the way up.
##   node_modules  is never a room: it is the maze (maze_set(), scripts/fsmap/node_maze.gd), endless, a level a depth.
##
## Its monoliths carry the subfolders' names and its signs the room's numbers, cleaned to the sign font. Nothing here
## reads anything: the names and numbers are handed in.

const ArenaFont = preload("res://scripts/arena/arena_font.gd")

const DOORS_MOST := 10
const DAEMONS_MOST := 6
## The maze's daemons: this many at its first level, one more a level down, to DAEMONS_MOST.
const MAZE_DAEMONS := 3
## The roster (the arena's own types): what each daemon in a room is, in turn from a seeded start.
const ROSTER := ["rogue", "zombie", "runaway", "rogue", "zombie", "rogue"]
## Bytes of a folder at the bottom and the top of the scale (log10): 1 KB and about 316 GB.
const SCALE_LOW := 3.0
const SCALE_HIGH := 11.5
## Files directly in a folder at the top of the busy scale (log10): 4,000.
const BUSY_HIGH := 3.6
const MAZE_NAME := "node_modules"
const REGISTER_OF := {"code": "matrix", "video": "cyberpunk", "image": "cyberpunk", "audio": "cyberpunk", "docs": "tron", "other": "tron", "empty": "tron"}
const PALETTE_OF := {"audio": "abyss"}


## 0 (a kilobyte or less) to 1 (a few hundred gigabytes and up).
static func scale_of(bytes: int) -> float:
	return clampf((log(float(maxi(bytes, 1))) / log(10.0) - SCALE_LOW) / (SCALE_HIGH - SCALE_LOW), 0.0, 1.0)


## 0 (no files in it) to 1 (thousands).
static func busy_of(files: int) -> float:
	return clampf(log(float(maxi(files, 0)) + 1.0) / log(10.0) / BUSY_HIGH, 0.0, 1.0)


static func is_maze(n: Dictionary) -> bool:
	return str(n.get("name", "")) == MAZE_NAME


## The room's floor in cells for a folder of `bytes`.
static func cells_for(bytes: int) -> Vector2i:
	var t := scale_of(bytes)
	return Vector2i(roundi(lerpf(RuinsLayout.CELLS_LEAST.x, RuinsLayout.CELLS_MOST.x, t)), roundi(lerpf(RuinsLayout.CELLS_LEAST.y, RuinsLayout.CELLS_MOST.y, t)))


static func tall_for(bytes: int) -> float:
	return lerpf(0.42, 2.7, pow(scale_of(bytes), 1.2))


## How many daemons live in a room with `files` directly in it: none in an empty folder, more the busier, at most
## DAEMONS_MOST.
static func daemons_for(files: int) -> int:
	return clampi(ceili(log(float(maxi(files, 0)) + 1.0) / log(10.0) * 1.6), 0, DAEMONS_MOST)


static func maze_daemons(level: int) -> int:
	return clampi(MAZE_DAEMONS + maxi(level, 1) - 1, 0, DAEMONS_MOST)


## The roster for `count` daemons in the folder at `path`, each "rogue", "zombie" or "runaway".
static func roster_for(path: PackedStringArray, count: int) -> PackedStringArray:
	var out := PackedStringArray()
	var start := absi(hash("roster:" + "/".join(path))) % ROSTER.size()
	for i in count:
		out.append(ROSTER[(start + i) % ROSTER.size()])
	return out


## The subfolders that get a door, biggest first, at most DOORS_MOST; the maze's own folder among them as any other.
static func doors_of(n: Dictionary) -> Array:
	return (n.get("dirs", []) as Array).slice(0, DOORS_MOST)


## A door's share (0 to 1): its folder's place on the size scale, a little of it whatever its size so a tiny folder
## still has a door to walk through.
static func door_share(child: Dictionary) -> float:
	return clampf(0.08 + 0.92 * scale_of(int(child.get("size", 0))), 0.0, 1.0)


## The id of the room for the folder at `path` (a maze level adds its level): ids "fs_<8 hex>", always the same.
static func id_for(path: PackedStringArray, level: int = 0) -> String:
	return "fs_%08x" % (hash(FolderTree.path_text(path) + ("#%d" % level if level > 0 else "")) & 0xffffffff)


static func seed_for(path: PackedStringArray, level: int = 0) -> int:
	return (hash("seed:" + FolderTree.path_text(path) + ":%d" % level) & 0x7fffffff) | 1


## The room for folder `n` at `path` (home first not included), its doors and the back door (none at home's top...
## home has one too: its way out of the map).
static func set_for(n: Dictionary, path: PackedStringArray) -> RuinsSet:
	var s := RuinsSet.new()
	var size: int = int(n.get("size", 0))
	var files: int = int(n.get("own_files", 0))
	var kind := FolderTree.kind_of(n)
	var t := scale_of(size)
	var b := busy_of(files)
	s.id = id_for(path)
	s.title = "the folder %s" % FolderTree.path_text(path)
	s.seed = seed_for(path)
	s.register = REGISTER_OF.get(kind, "tron")
	s.palette = PALETTE_OF.get(kind, "")
	s.cells = cells_for(size)
	var area := s.cells.x * s.cells.y
	var empty := kind == "empty"
	s.pristine = empty
	s.blocks = 0 if empty else clampi(roundi(lerpf(0.0, 9.0, b) * clampf(area / 90.0, 0.4, 1.6)), 0, mini(area / 12, 24))
	s.cover = 0 if empty else clampi(roundi(lerpf(1.0, 26.0, b)), 0, mini(area / 5, 40))
	s.holes = 0 if empty or kind == "docs" else clampi(roundi(lerpf(0.0, 3.0, b * t + 0.2)), 0, 3)
	s.cables = 0 if empty else clampi(roundi(lerpf(2.0, 22.0, maxf(t, b))), 0, 40)
	s.towers = clampi(roundi(lerpf(8.0, 46.0, t) + b * 8.0), 4, 60)
	s.giants = clampi(roundi(lerpf(3.0, 34.0, t)), 0, 40)
	s.signs = clampi(roundi(lerpf(2.0, 14.0, maxf(b, t * 0.6))), 2, 24)
	s.tall = tall_for(size)
	s.folders = _names_for(n)
	s.words = _words_for(n, kind)
	var shares := PackedFloat32Array()
	for d in doors_of(n):
		shares.append(door_share(d))
	s.doors = shares
	s.back_door = true
	return s


## A node_modules folder's maze, level `level` (1 its first): a Matrix floor, open (no ruins, holes or cover: the maze's
## walls are its own), bigger a level down to the kit's most, its towers and giants as tall as the folder is big. Its
## doors are none: the way out and the ways down are the maze's (scripts/fsmap/node_maze.gd).
static func maze_set(n: Dictionary, path: PackedStringArray, level: int) -> RuinsSet:
	var s := RuinsSet.new()
	var grow := clampi(level - 1, 0, 8)
	s.id = id_for(path, level)
	s.title = "the maze %s, level %d" % [FolderTree.path_text(path), level]
	s.seed = seed_for(path, level)
	s.register = "matrix"
	s.cells = Vector2i(mini(9 + grow, RuinsLayout.CELLS_MOST.x), mini(12 + grow * 2, RuinsLayout.CELLS_MOST.y))
	s.blocks = 0
	s.holes = 0
	s.cover = 0
	s.cables = 6
	s.towers = 30
	s.giants = 22
	s.signs = 10
	s.tall = clampf(tall_for(int(n.get("size", 0))) * 1.3, 0.6, 2.7)
	s.folders = _names_for(n)
	s.words = PackedStringArray(["NODE_MODULES", "DEPTH %d" % level, "NPM WARN", "DEPRECATED", "PEER DEPS", _sign(FolderTree.human_size(int(n.get("size", 0))))])
	return s


## The monoliths' names: the subfolders', cleaned to the sign font; padded so there are always three.
static func _names_for(n: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for d in (n.get("dirs", []) as Array).slice(0, 24):
		var name := _sign(str(d["name"]))
		if name != "" and not out.has(name):
			out.append(name)
	for pad in [_sign(str(n.get("name", "")) if str(n.get("name", "")) != "" else FolderTree.HOME_NAME), "..", "."]:
		if out.size() >= 3:
			break
		if pad != "" and not out.has(pad):
			out.append(pad)
	while out.size() < 3:
		out.append("DIR %d" % out.size())
	return out


## The signs' words: the room's size, its file count, its kind, its name.
static func _words_for(n: Dictionary, kind: String) -> PackedStringArray:
	var out := PackedStringArray([_sign(FolderTree.human_size(int(n.get("size", 0)))), _sign("%s FILES" % FolderTree.thousands(int(n.get("own_files", 0)))), _sign(kind)])
	var name := _sign(str(n.get("name", "")))
	if name != "" and not out.has(name):
		out.append(name)
	return out


## `text` as the sign font can draw it: upper case, a letter it has not as "_", at most RuinsLayout.NAME_LAST long, and
## never a word the ruins keep off their signs (RuinsLayout.NEVER_SHOWN: it reads "#").
static func _sign(text: String) -> String:
	var up := text.to_upper()
	var out := ""
	for c in up:
		out += c if ArenaFont.covers(c) else "_"
		if out.length() >= RuinsLayout.NAME_LAST:
			break
	for word in RuinsLayout.NEVER_SHOWN:
		var w := str(word).to_upper()
		while out.contains(w):
			out = out.replace(w, "#".repeat(w.length()))
	return out.strip_edges()
